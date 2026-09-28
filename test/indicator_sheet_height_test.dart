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

/// Regresyon (28.09.2026, testcinin telefonu + emulator): gosterge listesi
/// ekrandan uzun oldugu icin alt sayfa icerik kadar uzuyor, tam ekran aciliyor
/// ve ustu durum cubugunun altina giriyordu. Pencere yarim acilmali, liste
/// icinde kaydirilmali.
void main() {
  tearDown(tearDownFakeApi);

  testWidgets('Gosterge penceresi yarim acilir, liste icinde kaydirilir', (tester) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(1080, 2400); // 360x800 telefon
    addTearDown(tester.view.reset);

    await setUpFakeApi(
      technicalAnalysisByRange: {'6m': _analiz(), '1d': _analiz()},
      subscriptionStatus: {'isPremium': true, 'indicatorsIncluded': true},
    );
    await tester.pumpWidget(testApp(const TechnicalAnalysisScreen(
      investmentId: 47,
      name: 'THYAO',
      investment: {'id': 47, 'name': 'THYAO', 'investmentType': 'stock', 'purchasePrice': 80, 'quantity': 1, 'currentPrice': 110},
    )));
    await settle(tester);

    await tester.ensureVisible(find.text('Gösterge Ekle/Çıkar'));
    await tester.tap(find.text('Gösterge Ekle/Çıkar'));
    await settle(tester);

    // Baslik ekranin ust yarisinda degil: pencere yaklasik yarim yukseklikte.
    expect(tester.getTopLeft(find.text('Göstergeler')).dy, greaterThan(800 * 0.4));

    // Son gosterge kaydirarak ulasilabilir.
    await tester.scrollUntilVisible(find.text('Force Index (13)'), 200,
        scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first);
    expect(find.text('Force Index (13)').hitTestable(), findsOneWidget);
  });
}
