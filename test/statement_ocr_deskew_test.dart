import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:smartfinance_mobile/services/statement_ocr.dart';

/// Regresyon (26.09.2026, cihazda): 1,2 derece egik taranmis ekstre hic
/// okunamadi. Sayfa genisligi boyunca ayni satirin solu ile sagi ~37 piksel
/// kayiyor; sunucudaki ayristirici satirlari dikey konuma gore (~16 piksel
/// toleransla) grupladigi icin baslik ve satirlar parcalaniyordu.
void main() {
  // Duz sayfadaki bir kelimenin dort kosesi (sol ust, sag ust, sag alt, sol alt),
  // orijin etrafinda [derece] kadar dondurulmus.
  List<Offset> kose(double sol, double ust, double gen, double yuk, double derece) {
    final a = derece * math.pi / 180;
    Offset d(double x, double y) =>
        Offset(x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a));
    return [d(sol, ust), d(sol + gen, ust), d(sol + gen, ust + yuk), d(sol, ust + yuk)];
  }

  // Ekstre satiri: tarih solda, aciklama ortada, tutar ve bakiye sagda.
  List<(String, List<Offset>)> satir(double ust, double derece) => [
        ('01.09.2026', kose(60, ust, 140, 28, derece)),
        ('MARKET', kose(280, ust, 90, 28, derece)),
        ('150,00', kose(840, ust, 84, 28, derece)),
        ('1.850,00', kose(1290, ust, 112, 28, derece)),
      ];

  test('Egik sayfanin acisi satir ust kenarlarindan bulunur', () {
    final satirlar = [
      for (final ust in [300.0, 360.0, 420.0])
        kose(60, ust, 1340, 28, 1.2), // ML Kit satiri: tum satiri kapsayan kutu
    ];
    expect(sayfaEgimi(satirlar) * 180 / math.pi, closeTo(1.2, 0.01));
  });

  test('Kisa satirlar (tek kelime) aciyi bozmaz', () {
    final satirlar = [
      kose(60, 300, 1340, 28, 1.2),
      kose(60, 360, 1340, 28, 1.2),
      // Bozuk okunmus tek karakterler; ortanca tek basina bunlari eleyemez.
      kose(60, 420, 20, 28, 25),
      kose(90, 420, 20, 28, 25),
      kose(120, 420, 20, 28, 25),
    ];
    expect(sayfaEgimi(satirlar) * 180 / math.pi, closeTo(1.2, 0.01));
  });

  test('Duzeltilince ayni satirin kelimeleri ayni yukseklige gelir', () {
    final kelimeler = [...satir(300, 1.2), ...satir(360, 1.2)];
    final duz = duzeltilmisKelimeler(kelimeler, 1.2 * math.pi / 180, 1);

    double merkez(OcrWord w) => (w.top + w.bottom) / 2;
    final ilk = duz.sublist(0, 4).map(merkez).toList();
    // Once: sol ile sag arasinda ~26 piksel fark. Sonra: pikselin altinda.
    expect(ilk.reduce(math.max) - ilk.reduce(math.min), lessThan(1));
    // Satirlar arasi mesafe korunur.
    expect(merkez(duz[4]) - merkez(duz[0]), closeTo(60, 0.5));
    expect(duz.map((w) => w.page).toSet(), {1});
    expect(duz.first.text, '01.09.2026');
  });

  test('Duz sayfada koordinatlar degismez', () {
    final duz = duzeltilmisKelimeler(satir(300, 0), 0, 2);
    expect(duz.first.left, closeTo(60, 1e-9));
    expect(duz.first.top, closeTo(300, 1e-9));
    expect(duz.first.right, closeTo(200, 1e-9));
    expect(duz.first.bottom, closeTo(328, 1e-9));
  });
}
