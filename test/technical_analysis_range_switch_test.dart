import 'package:flutter_test/flutter_test.dart';
import 'package:smartfinance_mobile/screens/technical_analysis_screen.dart';

import 'helpers/test_app.dart';

Map<String, dynamic> _bar(String date, num close) =>
    {'date': date, 'open': close, 'high': close, 'low': close, 'close': close, 'volume': 1};

// 6A: 100 -> 110 (+%10). 1G: 100 -> 150; 6A etiketiyle gosterilirse +%50 cikar.
final _altiAy = {
  'priceBars': [_bar('2026-03-20T00:00:00', 100), _bar('2026-09-18T00:00:00', 110)],
  'indicators': [],
  'statistics': null,
};
final _birGun = {
  'priceBars': [_bar('2026-09-18T06:55:00', 100), _bar('2026-09-18T07:30:00', 150)],
  'indicators': [],
  'statistics': null,
};

Future<void> _ac(WidgetTester tester) async {
  await setUpFakeApi(
    technicalAnalysisDelay: const Duration(milliseconds: 300),
    technicalAnalysisByRange: {'6m': _altiAy, '1d': _birGun},
  );
  await tester.pumpWidget(testApp(const TechnicalAnalysisScreen(
    investmentId: 47,
    name: 'THYAO',
    investment: {'id': 47, 'name': 'THYAO', 'investmentType': 'stock', 'purchasePrice': 80, 'quantity': 1, 'currentPrice': 110},
  )));
  await settle(tester);
}

void main() {
  tearDown(tearDownFakeApi);

  /// Regresyon (18.09.2026, telefonda goruldu): yeni aralik yuklenirken eski
  /// 6 aylik grafik ekranda kaliyor ama ekseni "00:00 00:00", basligi "Bugun"
  /// oluyordu — gorunum secili araliga gore bicimleniyordu, ekrandaki veriye
  /// gore degil.
  testWidgets('Yukleme sirasinda baslik ve eksen ekrandaki verinin araligina gore kalir', (tester) async {
    await _ac(tester);

    await tester.tap(find.text('1G'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Son 6 ay'), findsOneWidget);
    expect(find.text('00:00'), findsNothing);
    await settle(tester);
    expect(find.text('Bugün'), findsOneWidget);
  });

  /// 1G'ye dokunup cevap gelmeden onbellekteki 6A'ya donulurse, gec gelen 1G
  /// cevabi 6A grafiginin ustune yazilmamali.
  testWidgets('Gec gelen eski aralik cevabi yeni secimin ustune yazilmaz', (tester) async {
    await _ac(tester);

    await tester.tap(find.text('1G'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('6A'));
    await settle(tester);

    expect(find.text('Son 6 ay'), findsOneWidget);
    expect(find.text('+10.00%'), findsOneWidget);
  });
}
