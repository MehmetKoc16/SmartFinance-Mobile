import 'package:flutter_test/flutter_test.dart';
import 'package:smartfinance_mobile/screens/technical_analysis_screen.dart';

import 'helpers/test_app.dart';

/// Regresyon (18.09.2026, test kullanicisi geri bildirimi: "fiyat gostergesi 1
/// gun icin dogru, 1 hafta / 6 ay icin yanlis"): baslikteki yuzde, secilen
/// donemden bagimsiz olarak hep son iki barin farkiydi. 6 aylik grafigin
/// yaninda gunluk degisim, 1 gunluk grafikte ise 5 dakika onceki bara gore
/// degisim gorunuyordu.
Map<String, dynamic> _bar(String date, num open, num close) =>
    {'date': date, 'open': open, 'high': close, 'low': open, 'close': close, 'volume': 1000};

Map<String, dynamic> _analiz(List<Map<String, dynamic>> bars, {num? previousClose}) => {
      'symbol': 'THYAO',
      'investmentType': 'stock',
      'priceBars': bars,
      'indicators': [],
      'statistics': previousClose == null ? null : {'previousClose': previousClose},
    };

final _gunluk = _analiz([
  _bar('2026-03-20T00:00:00', 99, 100),
  _bar('2026-06-19T00:00:00', 104, 105),
  _bar('2026-09-18T00:00:00', 108, 110),
]);

final _gunIci = _analiz([
  _bar('2026-09-18T06:55:00', 101, 102),
  _bar('2026-09-18T07:25:00', 108, 109),
  _bar('2026-09-18T07:30:00', 109, 110),
], previousClose: 100);

Future<void> _ac(WidgetTester tester) async {
  await setUpFakeApi(technicalAnalysisByRange: {'6m': _gunluk, '1d': _gunIci});
  await tester.pumpWidget(testApp(const TechnicalAnalysisScreen(
    investmentId: 47,
    name: 'THYAO',
    // Alis fiyati bilerek farkli: kar/zarar yuzdesi baslikteki yuzdeyle karismasin.
    investment: {'id': 47, 'name': 'THYAO', 'investmentType': 'stock', 'purchasePrice': 80, 'quantity': 1, 'currentPrice': 110},
  )));
  await settle(tester);
}

void main() {
  tearDown(tearDownFakeApi);

  testWidgets('6 aylik aralikta yuzde, donemin basindan bugune degisimi gosterir', (tester) async {
    await _ac(tester);

    expect(find.text('+10.00%'), findsOneWidget);
    expect(find.text('Son 6 ay'), findsOneWidget);
  });

  testWidgets('1 gunluk aralikta yuzde, 5 dk onceki bara degil onceki kapanisa gore hesaplanir', (tester) async {
    await _ac(tester);
    await tester.tap(find.text('1G'));
    await settle(tester);

    expect(find.text('+10.00%'), findsOneWidget);
    expect(find.text('Bugün'), findsOneWidget);
  });
}
