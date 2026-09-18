import 'package:flutter_test/flutter_test.dart';
import 'package:smartfinance_mobile/screens/technical_analysis_screen.dart';

import 'helpers/test_app.dart';

Map<String, dynamic> _bar(String date, num close) =>
    {'date': date, 'open': close, 'high': close, 'low': close, 'close': close, 'volume': 1};

String _yerelSaat(String iso) {
  final d = DateTime.parse(iso).toLocal();
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Regresyon (18.09.2026, telefonda goruldu): gun ici barlar UTC geliyor
/// ("...T06:55:00Z"); eksen yerel saate cevirmeden yazdigi icin Borsa
/// Istanbul'un 09:55 acilisi 06:55 gorunuyordu. Beklenen deger testin
/// calistigi makinenin saat dilimine gore hesaplaniyor.
void main() {
  tearDown(tearDownFakeApi);

  testWidgets('Gun ici grafigin ekseni yerel saati gosterir', (tester) async {
    await setUpFakeApi(technicalAnalysisByRange: {
      '6m': {'priceBars': [_bar('2026-03-20T00:00:00', 100), _bar('2026-09-18T00:00:00', 110)], 'indicators': [], 'statistics': null},
      '1d': {'priceBars': [_bar('2026-09-18T06:55:00Z', 100), _bar('2026-09-18T07:30:00Z', 101)], 'indicators': [], 'statistics': null},
    });
    await tester.pumpWidget(testApp(const TechnicalAnalysisScreen(
      investmentId: 47,
      name: 'THYAO',
      investment: {'id': 47, 'name': 'THYAO', 'investmentType': 'stock', 'purchasePrice': 80, 'quantity': 1, 'currentPrice': 101},
    )));
    await settle(tester);
    await tester.tap(find.text('1G'));
    await settle(tester);

    expect(find.text(_yerelSaat('2026-09-18T06:55:00Z')), findsOneWidget);
  });
}
