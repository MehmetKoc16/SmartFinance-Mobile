import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartfinance_mobile/screens/pdf_import_screen.dart';
import 'package:smartfinance_mobile/services/statement_ocr.dart';

import 'helpers/test_app.dart';

/// Telefondaki OCR testte calismaz (ML Kit ve PDF cizimi yerel kod); yerine
/// verilen kelimeleri donduren sahte okuyucu.
class _SahteOcr implements StatementOcr {
  _SahteOcr(this.kelimeler);
  final List<OcrWord> kelimeler;
  int cagrilma = 0;

  @override
  Future<List<OcrWord>> readPdf(String path, {OcrProgress? onProgress}) async {
    cagrilma++;
    onProgress?.call(1, 1);
    return kelimeler;
  }
}

const _kelimeler = [
  OcrWord(text: 'Tarih', left: 60, top: 300, right: 130, bottom: 328, page: 1),
  OcrWord(text: '01.09.2026', left: 60, top: 360, right: 200, bottom: 388, page: 1),
];

// Sunucu metin bulamadiginda (taranmis ekstre) boyle cevap veriyor.
const _metinYok = {
  'message': "PDF'den işlem çıkarılamadı. Dosya metin tabanlı olmayabilir.",
  'needsOcr': true,
  'result': {'transactions': [], 'bankName': 'Bilinmeyen', 'needsOcr': true},
};

void main() {
  tearDown(() {
    tearDownFakeApi();
    StatementOcr.resetForTest();
  });

  Future<File> ornekDosya() async {
    final dosya = File('${Directory.systemTemp.createTempSync('ekstre').path}/tarama.pdf')
      ..writeAsBytesSync([37, 80, 68, 70]);
    addTearDown(() => dosya.parent.deleteSync(recursive: true));
    return dosya;
  }

  Future<void> analizEt(WidgetTester tester, File dosya) async {
    await tester.pumpWidget(testApp(PdfImportScreen(initialFilePath: dosya.path)));
    await settle(tester);
    await tester.ensureVisible(find.text('Analiz Et'));
    await tester.tap(find.text('Analiz Et'));
    await settle(tester);
  }

  testWidgets('Taranmis ekstre telefonda okunur, yalnizca kelimeler sunucuya gider', (tester) async {
    final ocr = _SahteOcr(_kelimeler);
    StatementOcr.instance = ocr;
    await setUpFakeApi(pdfParseResult: _metinYok, pdfParseWordsResult: {
      'transactions': [
        {
          'amount': 420.5, 'description': 'ELEKTRIK FATURASI', 'merchantName': 'ELEKTRIK FATURASI',
          'transactionDate': '2026-09-01T00:00:00', 'type': 2, 'categoryId': null, 'categoryName': null,
          'isDuplicate': false, 'balanceMismatch': false,
        },
      ],
      'bankName': 'Taranmış ekstre (OCR)',
      'duplicateCount': 0,
    });

    await analizEt(tester, await ornekDosya());

    expect(ocr.cagrilma, 1);
    final govde = fakeApiBodies.entries.firstWhere((e) => e.key.endsWith('/pdfimport/parse-words')).value;
    expect(govde['words'], [
      {'text': 'Tarih', 'left': 60.0, 'top': 300.0, 'right': 130.0, 'bottom': 328.0, 'page': 1},
      {'text': '01.09.2026', 'left': 60.0, 'top': 360.0, 'right': 200.0, 'bottom': 388.0, 'page': 1},
    ]);
    expect(find.text('ELEKTRIK FATURASI'), findsOneWidget);
    // OCR yanlis okuyabilir; kullanici ice aktarmadan once uyarilmali.
    expect(find.textContaining('taranmış görüntüden okundu'), findsOneWidget);
  });

  testWidgets('OCR hicbir kelime okuyamazsa taranmis ekstre hatasi gosterilir', (tester) async {
    StatementOcr.instance = _SahteOcr(const []);
    await setUpFakeApi(pdfParseResult: _metinYok);

    await analizEt(tester, await ornekDosya());

    expect(fakeApiRequests.any((u) => u.path.endsWith('/pdfimport/parse-words')), isFalse);
    expect(find.text('Taranmış ekstre okunamadı'), findsOneWidget);
  });

  testWidgets('OCR tablo bulamazsa taranmis ekstre hatasi gosterilir', (tester) async {
    StatementOcr.instance = _SahteOcr(_kelimeler);
    await setUpFakeApi(pdfParseResult: _metinYok, pdfParseWordsResult: {
      'message': 'Taranmış ekstrede işlem tablosu bulunamadı.',
      'result': {'transactions': []},
    });

    await analizEt(tester, await ornekDosya());

    expect(find.text('Taranmış ekstre okunamadı'), findsOneWidget);
  });

  /// Metinli ama taninmayan bir PDF'te OCR bosuna calistirilmamali; eski
  /// mesaj ("goruntu olarak kaydedilmis") bu durumda da yanlis bilgi veriyordu.
  testWidgets('Metinli ama okunamayan PDF icin OCR calismaz, bicim hatasi gosterilir', (tester) async {
    final ocr = _SahteOcr(_kelimeler);
    StatementOcr.instance = ocr;
    await setUpFakeApi(pdfParseResult: {
      'message': "PDF'den işlem çıkarılamadı.",
      'needsOcr': false,
      'result': {'transactions': [], 'needsOcr': false},
    });

    await analizEt(tester, await ornekDosya());

    expect(ocr.cagrilma, 0);
    expect(find.text('Bu ekstrenin biçimini tanıyamadık'), findsOneWidget);
  });
}
