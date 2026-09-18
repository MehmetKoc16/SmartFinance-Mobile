import 'package:flutter_test/flutter_test.dart';
import 'package:smartfinance_mobile/screens/technical_analysis_screen.dart';

import 'helpers/test_app.dart';

/// PD/DD artik KAP bilancosundan hesaplaniyor (18.09.2026); kullanici rakamin
/// kaynagini ve dayandigi donemi gorebilmeli. F/K duzeltilene kadar sunucudan
/// gelmiyor. Degerler THYAO'nun o gunku canli yaniti.
void main() {
  tearDown(tearDownFakeApi);

  testWidgets('KAP kaynakli PD/DD gosterilir ve kaynagi ile donemi yazilir', (tester) async {
    await setUpFakeApi(technicalAnalysisByRange: {
      '6m': {
        'symbol': 'THYAO',
        'investmentType': 'stock',
        'priceBars': [
          {'date': '2026-09-17T00:00:00', 'open': 290, 'high': 291, 'low': 283, 'close': 289, 'volume': 1},
          {'date': '2026-09-18T00:00:00', 'open': 289, 'high': 290, 'low': 283, 'close': 284.5, 'volume': 1},
        ],
        'indicators': [],
        'statistics': {
          'marketCap': 390071549952,
          'priceToBook': 0.38297991094110356,
          'equityValue': 1018517000000.0,
          'isLossMaking': false,
          'fundamentalsPeriod': '6/2026',
        },
      },
    });
    await tester.pumpWidget(testApp(const TechnicalAnalysisScreen(
      investmentId: 47,
      name: 'THYAO',
      investment: {'id': 47, 'name': 'THYAO', 'investmentType': 'stock', 'purchasePrice': 200, 'quantity': 1, 'currentPrice': 284.5},
    )));
    await settle(tester);

    expect(find.text('F/K'), findsNothing);
    expect(find.text('0.38'), findsOneWidget);
    expect(find.textContaining('KAP'), findsOneWidget);
    expect(find.textContaining('6/2026'), findsOneWidget);
  });
}
