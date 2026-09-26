import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdfx/pdfx.dart';

/// Taranmis ekstre sayfasindaki bir kelime. Koordinatlar sayfa goruntusunun
/// sol ust kosesinden, piksel (sunucudaki `OcrWordDto` ile ayni alanlar).
class OcrWord {
  const OcrWord({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.page,
  });

  final String text;
  final double left, top, right, bottom;
  final int page;

  Map<String, dynamic> toJson() => {
        'text': text,
        'left': left,
        'top': top,
        'right': right,
        'bottom': bottom,
        'page': page,
      };
}

/// Okunan sayfa sayisi / toplam sayfa.
typedef OcrProgress = void Function(int done, int total);

class OcrException implements Exception {
  const OcrException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Gomulu metni olmayan (taranmis) PDF ekstresini telefonda okur.
///
/// KVKK: sayfa goruntusu telefondan cikmaz. Sayfa gecici dosyaya cizilir,
/// ML Kit cihaz ustu modelle okur, dosya hemen silinir; sunucuya yalnizca
/// kelimeler ve konumlari gider.
abstract class StatementOcr {
  // Sunucudaki ParseWordsRequestDto ile ayni sinir.
  static const maxPages = 50;

  Future<List<OcrWord>> readPdf(String path, {OcrProgress? onProgress});

  static StatementOcr instance = MlKitStatementOcr();

  @visibleForTesting
  static void resetForTest() => instance = MlKitStatementOcr();
}

/// Sayfanin egimi (radyan), ML Kit satirlarinin ust kenarlarindan. Kose
/// sirasi: sol ust, sag ust, sag alt, sol alt. Yalnizca yuksekliginin en az
/// 3 kati uzunlugundaki satirlar sayilir (kisa kutularin acisi gurultulu);
/// ortanca alinir, birkac yanlis okunmus satir sonucu kaydirmasin.
@visibleForTesting
double sayfaEgimi(List<List<Offset>> satirKoseleri) {
  final acilar = <double>[];
  for (final k in satirKoseleri) {
    if (k.length < 4) continue;
    final ust = k[1] - k[0];
    final yukseklik = (k[3] - k[0]).distance;
    if (yukseklik <= 0 || ust.distance < 3 * yukseklik) continue;
    acilar.add(math.atan2(ust.dy, ust.dx));
  }
  if (acilar.isEmpty) return 0;
  acilar.sort();
  return acilar[acilar.length ~/ 2];
}

/// Kelime koselerini [egim] kadar geri dondurup eksene hizali kutulara cevirir.
/// Sunucudaki ayristirici satirlari dikey konuma gore grupluyor; egik taramada
/// ayni satirin solu ile sagi farkli satir sanilirdi.
@visibleForTesting
List<OcrWord> duzeltilmisKelimeler(List<(String, List<Offset>)> kelimeler, double egim, int sayfa) {
  final c = math.cos(egim), s = math.sin(egim);
  return [
    for (final (metin, koseler) in kelimeler)
      () {
        final xs = [for (final p in koseler) p.dx * c + p.dy * s];
        final ys = [for (final p in koseler) -p.dx * s + p.dy * c];
        return OcrWord(
          text: metin,
          left: xs.reduce(math.min),
          top: ys.reduce(math.min),
          right: xs.reduce(math.max),
          bottom: ys.reduce(math.max),
          page: sayfa,
        );
      }(),
  ];
}

class MlKitStatementOcr implements StatementOcr {
  // PDF birimi 1/72 inc. 3 kat ~216 DPI: 8 puntoluk ekstre yazisi ~24 piksel
  // olur, ML Kit'in onerdigi 16-24 piksel araligina girer.
  static const _olcek = 3.0;
  // Alisilmadik buyuk sayfalarda bellegi korumak icin uzun kenar siniri.
  static const _maksKenar = 3000.0;

  @override
  Future<List<OcrWord>> readPdf(String path, {OcrProgress? onProgress}) async {
    final PdfDocument belge;
    try {
      belge = await PdfDocument.openFile(path);
    } catch (_) {
      // Sifreli veya bozuk PDF.
      throw const OcrException('PDF açılamadı. Dosya şifreli veya bozuk olabilir.');
    }

    final okuyucu = TextRecognizer(script: TextRecognitionScript.latin);
    final kelimeler = <OcrWord>[];
    try {
      final toplam = belge.pagesCount;
      if (toplam > StatementOcr.maxPages) {
        throw const OcrException('Taranmış ekstre en fazla ${StatementOcr.maxPages} sayfa olabilir.');
      }

      for (var no = 1; no <= toplam; no++) {
        final sayfa = await belge.getPage(no);
        File? gecici;
        try {
          final olcek = math.min(_olcek, _maksKenar / math.max(sayfa.width, sayfa.height));
          final resim = await sayfa.render(
            width: sayfa.width * olcek,
            height: sayfa.height * olcek,
            format: PdfPageImageFormat.png,
            backgroundColor: '#FFFFFF',
          );
          if (resim == null) continue;

          gecici = File('${Directory.systemTemp.path}/ekstre_ocr_$no.png');
          await gecici.writeAsBytes(resim.bytes, flush: true);
          final RecognizedText sonuc;
          try {
            sonuc = await okuyucu.processImage(InputImage.fromFilePath(gecici.path));
          } on PlatformException catch (e) {
            // Model Play Hizmetleri'nden iniyor (uygulama yeni kurulduysa).
            if ('${e.message}'.toLowerCase().contains('download')) {
              throw const OcrException(
                  'Metin okuma modeli telefonunuza indiriliyor. Birkaç dakika sonra tekrar deneyin.');
            }
            rethrow;
          }

          Offset nokta(math.Point<int> p) => Offset(p.x.toDouble(), p.y.toDouble());
          final satirKoseleri = <List<Offset>>[];
          final hamKelimeler = <(String, List<Offset>)>[];
          for (final blok in sonuc.blocks) {
            for (final satir in blok.lines) {
              satirKoseleri.add(satir.cornerPoints.map(nokta).toList());
              for (final e in satir.elements) {
                // Sunucu bos veya 200 karakterden uzun kelimede tum istegi
                // reddeder; tek bir bozuk okuma ekstreyi bosa cikarmasin.
                if (e.text.trim().isEmpty || e.text.length > 200) continue;
                final k = e.boundingBox;
                hamKelimeler.add((
                  e.text,
                  e.cornerPoints.length == 4
                      ? e.cornerPoints.map(nokta).toList()
                      : [k.topLeft, k.topRight, k.bottomRight, k.bottomLeft],
                ));
              }
            }
          }
          // Taranmis sayfa hep biraz egik; 10 dereceden fazlasi guvenilmez.
          var egim = sayfaEgimi(satirKoseleri);
          if (egim.abs() > 10 * math.pi / 180) egim = 0;
          kelimeler.addAll(duzeltilmisKelimeler(hamKelimeler, egim, no));
        } finally {
          await sayfa.close();
          if (gecici != null && await gecici.exists()) await gecici.delete();
        }
        onProgress?.call(no, toplam);
      }
    } finally {
      await okuyucu.close();
      await belge.close();
    }
    return kelimeler;
  }
}
