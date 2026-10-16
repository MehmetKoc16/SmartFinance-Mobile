import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfinance_mobile/screens/profile_screen.dart';

import 'helpers/test_app.dart';

/// Regresyon (16.09.2026, gercek cihaz geri bildirimi): Hesabi Sil sayfasindaki
/// kirmizi uyari karti genislik verilmedigi icin icerigi kadar dar kaliyordu;
/// altindaki sifre kutusu ve butondan dar gorunuyordu.
void main() {
  tearDown(tearDownFakeApi);

  testWidgets('Kucuk ekranda abonelik uyarisi kaydirilir ve silme butonu guvenli alanda kalir', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1080, 1800);
    tester.view.padding = const FakeViewPadding(bottom: 144);
    tester.view.viewPadding = const FakeViewPadding(bottom: 144);
    addTearDown(tester.view.reset);
    await setUpFakeApi();
    await tester.pumpWidget(testApp(const ProfileScreen()));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Hesabı Sil'), 250);
    await tester.tap(find.text('Hesabı Sil'));
    await settle(tester);
    await tester.ensureVisible(find.text('Premium aboneliğiniz varsa önce iptal edin'));
    expect(tester.takeException(), null);
    tester.view.viewInsets = const FakeViewPadding(bottom: 750);
    await settle(tester);
    final button = find.widgetWithText(ElevatedButton, 'Hesabımı Kalıcı Olarak Sil');
    await tester.ensureVisible(button);
    await settle(tester);
    expect(tester.getBottomLeft(button).dy, lessThanOrEqualTo(600 - 48));
    expect(tester.takeException(), null);
  });

  testWidgets('Hesabi Sil uyari karti sifre kutusuyla ayni genislikte', (tester) async {
    await setUpFakeApi();
    await tester.pumpWidget(testApp(const ProfileScreen()));
    await settle(tester);

    await tester.scrollUntilVisible(find.text('Hesabı Sil'), 300);
    await tester.tap(find.text('Hesabı Sil').first);
    await settle(tester);

    final kartGenisligi = tester.getSize(find.byKey(const Key('hesap-sil-uyari'))).width;
    final sifreKutusuGenisligi = tester.getSize(find.byType(TextField)).width;

    expect(kartGenisligi, sifreKutusuGenisligi);
  });
}
