import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfinance_mobile/screens/profile_screen.dart';

import 'helpers/test_app.dart';

/// Regresyon (24.09.2026, test kullanicilari): 3 tuslu gezinme cubugu olan
/// telefonlarda Profil Duzenle'nin Kaydet butonu ve gosterge listesinin alti
/// cubugun arkasinda kaliyordu. Alt sayfalar klavye boslugunu (viewInsets)
/// hesaba katiyordu, sistem cubugunu (padding) katmiyordu. Gelistiricinin
/// telefonunda hareketle gezinme acik oldugu icin gorunmuyordu.
void main() {
  tearDown(tearDownFakeApi);

  const ekranYuksekligi = 800.0;
  const gezinmeCubugu = 48.0;

  void ucTusluGezinmeliTelefon(WidgetTester tester) {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(1080, ekranYuksekligi * 3);
    tester.view.padding = const FakeViewPadding(bottom: gezinmeCubugu * 3);
    tester.view.viewPadding = const FakeViewPadding(bottom: gezinmeCubugu * 3);
    addTearDown(tester.view.reset);
  }

  testWidgets('Profil Duzenle Kaydet butonu gezinme cubugunun ustunde kalir', (tester) async {
    ucTusluGezinmeliTelefon(tester);
    await setUpFakeApi();
    await tester.pumpWidget(testApp(const ProfileScreen()));
    await settle(tester);

    await tester.tap(find.text('Profil Düzenle'));
    await settle(tester);

    final butonAlti = tester.getBottomLeft(find.widgetWithText(ElevatedButton, 'Kaydet')).dy;
    expect(butonAlti, lessThanOrEqualTo(ekranYuksekligi - gezinmeCubugu));
  });

  /// Ayni hata her yeni alt sayfada tekrar etmesin: tum alt sayfalar guvenli
  /// alani uygulayan tek yardimcidan acilmali.
  test('Uygulamada showModalBottomSheet yalnizca ortak yardimcida kullanilir', () {
    final ihlaller = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.replaceAll('\\', '/').endsWith('widgets/app_bottom_sheet.dart'))
        .where((f) => f.readAsStringSync().contains('showModalBottomSheet('))
        .map((f) => f.path)
        .toList();

    expect(ihlaller, isEmpty);
  });
}
