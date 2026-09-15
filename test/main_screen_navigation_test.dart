import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfinance_mobile/screens/main_screen.dart';

import 'helpers/test_app.dart';

/// Regresyon (15.09.2026, gercek cihaz geri bildirimi): sekmeler route degil
/// widget durumu oldugu icin MainScreen yigindaki tek ekrandi. Android geri
/// tusu pop edecek bir sey bulamayip uygulamayi kapatiyordu; tekrar acilista
/// Splash -> biyometrik kilit geldigi icin "surekli sifre soruyor" sikayeti
/// de ayni sebepten.
void main() {
  late List<String> platformCalls;

  setUp(() async {
    await setUpFakeApi();
    platformCalls = [];
  });
  tearDown(tearDownFakeApi);

  Future<void> pumpMain(WidgetTester tester) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call.method);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(testApp(const MainScreen()));
    await settle(tester);
  }

  PageController controller(WidgetTester tester) => tester.widget<PageView>(find.byType(PageView)).controller!;

  int currentPage(WidgetTester tester) => controller(tester).page!.round();

  // Alt menudeki etiket, sayfa basliklarindan sonra agaca eklendigi icin .last.
  Future<void> tapTab(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await settle(tester);
  }

  // Android geri tusunun Flutter'a ulastigi yolun aynisi.
  Future<void> systemBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }

  bool appExited() => platformCalls.contains('SystemNavigator.pop');

  testWidgets('Profil sekmesindeyken geri tusu uygulamayi kapatmaz, onceki sekmeye doner', (tester) async {
    await pumpMain(tester);
    await tapTab(tester, 'Profil');
    expect(currentPage(tester), 3);

    await systemBack(tester);

    expect(appExited(), isFalse);
    expect(currentPage(tester), 0);
  });

  testWidgets('Geri tusu sekme gecmisini sirayla geri sarar, en sonda Ana Sayfadan cikar', (tester) async {
    await pumpMain(tester);
    await tapTab(tester, 'Yatırımlar');
    await tapTab(tester, 'Profil');

    await systemBack(tester);
    expect(currentPage(tester), 1);
    expect(appExited(), isFalse);

    await systemBack(tester);
    expect(currentPage(tester), 0);
    expect(appExited(), isFalse);

    await systemBack(tester);
    expect(appExited(), isTrue);
  });

  testWidgets('Kaydirarak gecilen sekme de gecmise eklenir', (tester) async {
    await pumpMain(tester);
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await settle(tester);
    expect(currentPage(tester), 1);

    await systemBack(tester);

    expect(appExited(), isFalse);
    expect(currentPage(tester), 0);
  });

  // Regresyon: animateToPage 0 -> 3 giderken Yatirimlar ve Islemler
  // sayfalarini da kaydirarak geciyordu ("kaya kaya gidiyor").
  testWidgets('Uzak sekmeye dokununca aradaki sayfalar kaydirilmadan tek adimda gecilir', (tester) async {
    await pumpMain(tester);

    await tester.tap(find.text('Profil').last);
    await tester.pump();

    expect(controller(tester).page, 3.0);
  });
}
