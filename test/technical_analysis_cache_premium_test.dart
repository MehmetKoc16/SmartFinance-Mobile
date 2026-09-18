import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfinance_mobile/screens/technical_analysis_screen.dart';

import 'helpers/test_app.dart';

Map<String, dynamic> _analiz() => {
      'symbol': 'THYAO',
      'investmentType': 'stock',
      'priceBars': [
        {'date': '2026-09-17T00:00:00', 'open': 100, 'high': 101, 'low': 99, 'close': 100, 'volume': 1},
        {'date': '2026-09-18T00:00:00', 'open': 100, 'high': 111, 'low': 99, 'close': 110, 'volume': 1},
      ],
      'indicators': [],
      'statistics': null,
    };

Future<void> _ac(WidgetTester tester, {bool? gostergelerAcik}) async {
  await setUpFakeApi(
    technicalAnalysisByRange: {'6m': _analiz(), '1d': _analiz()},
    subscriptionStatus: gostergelerAcik == null
        ? null
        : {'isPremium': gostergelerAcik, 'indicatorsIncluded': gostergelerAcik},
  );
  await tester.pumpWidget(testApp(const TechnicalAnalysisScreen(
    investmentId: 47,
    name: 'THYAO',
    investment: {'id': 47, 'name': 'THYAO', 'investmentType': 'stock', 'purchasePrice': 80, 'quantity': 1, 'currentPrice': 110},
  )));
  await settle(tester);
}

Iterable<Uri> _grafikIstekleri() => fakeApiRequests.where((u) => u.path.endsWith('/technical-analysis'));

void main() {
  tearDown(tearDownFakeApi);

  /// Regresyon (18.09.2026, test kullanicisi): aralik secicisine her dokunus,
  /// daha once acilmis aralik icin bile yeni istek atiyordu. Bir dakikada 20
  /// istek sinirina (6A tek basina ~10 kez) takiliniyor, ardindan yatirimlar
  /// ekraninin fiyat yenilemesi de 429 alip "Fiyatlar guncellenemedi"
  /// gosteriyordu.
  testWidgets('Daha once acilan araliga donunce sunucuya yeniden istek atilmaz', (tester) async {
    await _ac(tester);
    await tester.tap(find.text('1G'));
    await settle(tester);
    await tester.tap(find.text('6A'));
    await settle(tester);

    expect(_grafikIstekleri().length, 2);
  });

  /// Onbellek, kullanicinin bilerek yaptigi yenilemeyi yutmamali.
  testWidgets('Asagi cekip yenileme onbellegi atlar ve sunucudan yeniden ister', (tester) async {
    await _ac(tester);
    await tester.fling(find.byType(SingleChildScrollView), const Offset(0, 400), 1000);
    await settle(tester, frames: 40);

    expect(_grafikIstekleri().length, 2);
  });

  /// Regresyon (18.09.2026): gostergeler premium'a ait; sunucu ucretsiz
  /// kullanicida onlari sessizce bosaltiyordu ve uygulama nedenini hic
  /// soylemiyordu.
  testWidgets('Premium olmayan kullaniciya gostergelerin premium ozellik oldugu soylenir', (tester) async {
    await _ac(tester, gostergelerAcik: false);

    expect(find.textContaining('Premium'), findsOneWidget);
    expect(find.text('Gösterge Ekle/Çıkar'), findsNothing);
    expect(_grafikIstekleri().every((u) => !u.queryParameters.containsKey('indicators')), isTrue);
  });

  testWidgets('Premium kullanici gosterge secebilir', (tester) async {
    await _ac(tester, gostergelerAcik: true);

    expect(find.text('Gösterge Ekle/Çıkar'), findsOneWidget);
    expect(find.textContaining('Premium'), findsNothing);
  });
}
