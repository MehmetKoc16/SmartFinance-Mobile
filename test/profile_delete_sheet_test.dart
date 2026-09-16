import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfinance_mobile/screens/profile_screen.dart';

import 'helpers/test_app.dart';

/// Regresyon (16.09.2026, gercek cihaz geri bildirimi): Hesabi Sil sayfasindaki
/// kirmizi uyari karti genislik verilmedigi icin icerigi kadar dar kaliyordu;
/// altindaki sifre kutusu ve butondan dar gorunuyordu.
void main() {
  tearDown(tearDownFakeApi);

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
