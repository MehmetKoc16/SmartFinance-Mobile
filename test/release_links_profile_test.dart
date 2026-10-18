import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:smartfinance_mobile/screens/profile_screen.dart';
import 'package:smartfinance_mobile/screens/register_screen.dart';
import 'package:smartfinance_mobile/screens/premium_screen.dart';
import 'package:smartfinance_mobile/services/links.dart';
import 'package:smartfinance_mobile/services/billing_service.dart';
import 'helpers/test_app.dart';
import 'helpers/test_store_gateway.dart';

void main() {
  final opened = <Uri>[];
  setUp(() async {
    BillingService.gateway = TestStoreGateway();
    await setUpFakeApi();
    PackageInfo.setMockInitialValues(appName: 'Wallet Mark', packageName: 'com.walletmark.app', version: '1.1.4', buildNumber: '13', buildSignature: '');
    opened.clear();
    linkLauncher = (uri) async { opened.add(uri); return true; };
  });
  tearDown(() {
    resetLinkLauncherForTest();
    tearDownFakeApi();
  });

  void linksTest(String name, WidgetTesterCallback body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        // Ekran dinleyicisini kaldir; servisi ayni FakeAsync bolgesinde kapat.
        await tester.pumpWidget(const SizedBox.shrink());
        await settle(tester);
        await pumpUntilDone(tester, BillingService.resetForTest());
      }
    });
  }

  Future<void> openScreen(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(testApp(screen));
    if (screen is PremiumScreen) {
      // initState'in baslattigi yuklemeyi beklemeden baglantilar olusmaz.
      await pumpUntilDone(tester, BillingService().load());
    }
    await settle(tester);
  }

  for (final entry in <String, Widget>{
    'Kayit': const RegisterScreen(),
    'Profil': const ProfileScreen(),
    'Premium': const PremiumScreen(),
  }.entries) {
    linksTest('${entry.key} gizlilik baglantisi dogru URL acar', (tester) async {
      await openScreen(tester, entry.value);
      final link = find.text('Gizlilik Politikası');
      await tester.ensureVisible(link);
      await tester.tap(link);
      await settle(tester);
      expect(opened.single.toString(), gizlilikUrl);
    });
  }

  linksTest('Premium abonelik yonetim baglantisi dogru URL acar', (tester) async {
    await pumpUntilDone(tester, setUpFakeApi(subscriptionStatus: {'isPremium': false}));
    await openScreen(tester, const PremiumScreen());
    final link = find.text('Abonelikleri yönet');
    expect(link, findsOneWidget);
    expect(find.text('Aboneliği yönet'), findsNothing);
    await tester.ensureVisible(link);
    await tester.tap(link);
    await settle(tester);
    expect(opened.single.toString(), abonelikYonetimUrl);
  });

  linksTest('PremiumUyesi_TekYonetBaglantisiGorur', (tester) async {
    await pumpUntilDone(
      tester,
      setUpFakeApi(subscriptionStatus: {'isPremium': true}),
    );
    await openScreen(tester, const PremiumScreen());
    expect(find.text('Aboneliği yönet'), findsOneWidget);
    expect(find.text('Abonelikleri yönet'), findsNothing);
    expect(find.text('Gizlilik Politikası'), findsOneWidget);
    await tester.tap(find.text('Aboneliği yönet'));
    await settle(tester);
    expect(opened.single.toString(), abonelikYonetimUrl);
    expect(find.byType(AlertDialog), findsNothing);
  });

  linksTest('Hesap silmede abonelik uyarisi ve yonetim baglantisi gorunur', (tester) async {
    await tester.pumpWidget(testApp(const ProfileScreen()));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Hesabı Sil'), 250);
    await tester.tap(find.text('Hesabı Sil'));
    await settle(tester);
    expect(find.text('Premium aboneliğiniz varsa önce iptal edin'), findsOneWidget);
    expect(find.text('Hesabınızı silmek Google Play aboneliğinizi iptal etmez; ücretlendirme devam eder. Silmeden önce aboneliğinizi Play Store\'dan iptal edin.'), findsOneWidget);
    final link = find.text('Abonelikleri yönet');
    await tester.ensureVisible(link);
    await tester.tap(link);
    await settle(tester);
    expect(opened.single.toString(), abonelikYonetimUrl);
  });

  linksTest('Profil surumu paket bilgisinden gosterir', (tester) async {
    await tester.pumpWidget(testApp(const ProfileScreen()));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Wallet Mark v1.1.4 (13)'), 250);
    expect(find.text('Wallet Mark v1.1.4 (13)'), findsOneWidget);
  });

  linksTest('Acilamayan baglanti SnackBar gosterir', (tester) async {
    linkLauncher = (_) async => false;
    await tester.pumpWidget(testApp(Scaffold(body: Builder(builder: (context) => TextButton(
      onPressed: () => baglantiAc(context, gizlilikUrl), child: const Text('Aç'),
    )))));
    await tester.tap(find.text('Aç'));
    await settle(tester);
    expect(find.text('Bağlantı açılamadı.'), findsOneWidget);
  });
}
