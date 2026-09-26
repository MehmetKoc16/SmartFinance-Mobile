import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfinance_mobile/screens/investments_screen.dart';

import 'helpers/test_app.dart';

/// Regresyon (26.09.2026, cihazda): sunucu yayin sirasinda birkac saniye
/// kapaliyken "ase" aramasi bos dondu; kullanici "ASELSAN yok" sandi. Hata ve
/// "sonuc yok" durumlari bos listeyle ayni gorunuyordu.
void main() {
  tearDown(tearDownFakeApi);

  Future<void> ara(WidgetTester tester, String metin) async {
    await tester.pumpWidget(testApp(const InvestmentsScreen()));
    await settle(tester);
    await tester.tap(find.text('İlk yatırımını ekle'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Sembol (örn: THYAO)'), metin);
    await tester.pump(const Duration(milliseconds: 400)); // yazma gecikmesi (debounce)
    await settle(tester);
  }

  testWidgets('Sunucuya ulasilamazsa arama hatasi gosterilir', (tester) async {
    await setUpFakeApi(symbolSearch: {'message': 'Sunucu hatası'}, symbolSearchStatus: 502);

    await ara(tester, 'ase');

    expect(find.textContaining('Arama yapılamadı'), findsOneWidget);
  });

  testWidgets('Sonuc yoksa bulunamadi denir', (tester) async {
    await setUpFakeApi(symbolSearch: []);

    await ara(tester, 'xyzq');

    expect(find.textContaining('"xyzq" için hisse bulunamadı'), findsOneWidget);
  });

  testWidgets('Sonuclar listelenir, hata yazisi cikmaz', (tester) async {
    await setUpFakeApi(symbolSearch: [
      {'symbol': 'ASELS', 'name': 'ASELSAN', 'exchange': 'BIST'},
    ]);

    await ara(tester, 'ase');

    // Regresyon: sonuc listesi ListView'di; AlertDialog'un boyut olcumunu
    // bozuyordu (testte hata, cihazda Alis Fiyati/Miktar alanlari kayboluyordu).
    expect(tester.takeException(), isNull);
    expect(find.text('ASELS'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Miktar'), findsOneWidget);
    expect(find.textContaining('Arama yapılamadı'), findsNothing);
    expect(find.textContaining('bulunamadı'), findsNothing);
  });
}
