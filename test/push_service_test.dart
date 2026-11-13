import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:smartfinance_mobile/services/app_lock.dart';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfinance_mobile/screens/profile_screen.dart';
import 'package:smartfinance_mobile/services/billing_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfinance_mobile/screens/main_screen.dart';
import 'package:smartfinance_mobile/screens/notifications_screen.dart';
import 'package:smartfinance_mobile/services/api_service.dart';
import 'package:smartfinance_mobile/services/push_service.dart';

import 'helpers/test_app.dart';
import 'helpers/test_store_gateway.dart';

class _SahteFcm implements PushMessaging {
  bool izin = true;
  String? token = 'tel-token-1';
  int silinme = 0;
  PushPayload? ilkMesaj;
  final kayitTamamlandi = Completer<void>();
  final silmeTamamlandi = Completer<void>();
  final yenilenen = StreamController<String>.broadcast();
  final acilan = StreamController<PushPayload>.broadcast();
  final onPlanda = StreamController<PushPayload>.broadcast();

  @override
  Future<bool> requestPermission() async => izin;
  @override
  Future<String?> getToken() async => token;
  @override
  Stream<String> get onTokenRefresh => yenilenen.stream;
  @override
  Future<void> deleteToken() async {
    silinme++;
    if (!silmeTamamlandi.isCompleted) silmeTamamlandi.complete();
  }
  @override
  Future<PushPayload?> getInitialMessage() async {
    // start(), sunucu kaydi ve dinleyiciler hazir olduktan sonra buraya gelir.
    if (!kayitTamamlandi.isCompleted) kayitTamamlandi.complete();
    return ilkMesaj;
  }
  @override
  Stream<PushPayload> get onMessageOpenedApp => acilan.stream;
  @override
  Stream<PushPayload> get onForegroundMessage => onPlanda.stream;
}

const _butceBildirimi = PushPayload(
  title: 'Bütçe limiti aşıldı',
  body: 'Market kategorisinde limitinizi aştınız.',
  data: {'type': 'notification', 'notificationId': '7'},
);

void main() {
  late _SahteFcm fcm;

  setUp(() async {
    BillingService.gateway = TestStoreGateway();
    await setUpFakeApi();
    PackageInfo.setMockInitialValues(
      appName: 'Wallet Mark', packageName: 'com.walletmark.app',
      version: '1.1.4', buildNumber: '13', buildSignature: '',
    );
    fcm = _SahteFcm();
    PushService.messaging = fcm;
    PushService.enabled = true;
  });

  tearDown(() async {
    await PushService.resetForTest();
    await BillingService.resetForTest();
    fcm.yenilenen.close().ignore();
    fcm.acilan.close().ignore();
    fcm.onPlanda.close().ignore();
    tearDownFakeApi();
  });

  // Servislerin FakeAsync kuyruklari test bitmeden ilerletilmeli.
  void pushTest(String name, WidgetTesterCallback body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await settle(tester);
        await pumpUntilDone(tester, PushService.resetForTest());
        await pumpUntilDone(tester, BillingService.resetForTest());
      }
    });
  }

  List<dynamic> govdeler(String yol) => [
        for (final e in fakeApiBodies.entries)
          if (e.key.endsWith(yol)) e.value,
      ];

  // Gercek uygulamadaki gibi: gezinme ve alt bant anahtarlari bagli.
  Widget uygulama(Widget home) => testApp(
        home,
        navigatorKey: ApiService.navigatorKey,
        scaffoldMessengerKey: PushService.scaffoldMessengerKey,
      );

  test('TercihKapaliysa_StartKayitYapmaz', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PushService.notificationsEnabledKey, false);
    await PushService.start();
    expect(govdeler('/devicetoken'), isEmpty);
  });

  pushTest('AnahtarKapaninca_UnregisterCagrilir', (tester) async {
    await pumpUntilDone(tester, PushService.start());
    expect(govdeler('/devicetoken'), [{'token': 'tel-token-1'}]);
    await tester.pumpWidget(testApp(const ProfileScreen()));
    await settle(tester);
    final toggle = find.byKey(const Key('notifications-toggle'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await pumpUntilDone(tester, fcm.silmeTamamlandi.future);
    await settle(tester);
    expect(govdeler('/devicetoken/unregister'), [{'token': 'tel-token-1'}]);
    expect(fcm.silinme, 1);
  });

  pushTest('AnahtarAcilinca_YenidenKaydolur', (tester) async {
    final prefs = await pumpUntilDone(tester, SharedPreferences.getInstance());
    await pumpUntilDone(tester, prefs.setBool(PushService.notificationsEnabledKey, false));
    await pumpUntilDone(tester, PushService.start());
    expect(govdeler('/devicetoken'), isEmpty);
    await tester.pumpWidget(testApp(const ProfileScreen()));
    await settle(tester);
    final toggle = find.byKey(const Key('notifications-toggle'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await pumpUntilDone(tester, fcm.kayitTamamlandi.future);
    await settle(tester);
    expect(govdeler('/devicetoken'), [{'token': 'tel-token-1'}]);
  });

  test('Izin verilince token sunucuya kaydedilir', () async {
    await PushService.start();
    expect(govdeler('/devicetoken'), [
      {'token': 'tel-token-1'},
    ]);
  });

  test('Izin reddedilirse token kaydedilmez', () async {
    fcm.izin = false;
    await PushService.start();
    expect(fakeApiRequests.where((u) => u.path.contains('/devicetoken')), isEmpty);
  });

  test('Token yenilenince yenisi kaydedilir', () async {
    await PushService.start();
    fcm.yenilenen.add('tel-token-2');
    await Future<void>.delayed(Duration.zero);
    expect(govdeler('/devicetoken'), [
      {'token': 'tel-token-2'},
    ]); // fakeApiBodies yol basina son govdeyi tutuyor
  });

  test('Firebase baslatilamadiysa hicbir sey yapilmaz', () async {
    PushService.enabled = false;
    await PushService.start();
    await PushService.stop();
    expect(fakeApiRequests.where((u) => u.path.contains('/devicetoken')), isEmpty);
    expect(fcm.silinme, 0);
  });

  /// Cikis yapan kullanicinin telefonuna bildirim gitmeye devam etmemeli.
  /// Sunucudaki kaydi silmek oturum istiyor; oturum token'lari silinmeden once.
  test('Cikista cihaz kaydi sunucudan ve Firebase\'den silinir', () async {
    await PushService.start();

    await ApiService.logout();

    expect(govdeler('/devicetoken/unregister'), [
      {'token': 'tel-token-1'},
    ]);
    expect(fcm.silinme, 1);
  });

  pushTest('Ana ekran acilinca bildirim kaydi baslar', (tester) async {
    await tester.pumpWidget(testApp(const MainScreen()));
    await pumpUntilDone(tester, fcm.kayitTamamlandi.future);
    await pumpUntilDone(tester, BillingService().startAppWide());
    await settle(tester);

    expect(govdeler('/devicetoken'), [
      {'token': 'tel-token-1'},
    ]);
  });

  pushTest('Bildirime dokunulunca bildirimler ekrani acilir', (tester) async {
    await tester.pumpWidget(uygulama(const Scaffold(body: Text('ana'))));
    await pumpUntilDone(tester, PushService.start());

    fcm.acilan.add(_butceBildirimi);
    await settle(tester);

    expect(find.byType(NotificationsScreen), findsOneWidget);
  });

  pushTest('Uygulama kapaliyken dokunulan bildirim acilista karsilanir', (tester) async {
    fcm.ilkMesaj = _butceBildirimi;
    await tester.pumpWidget(uygulama(const Scaffold(body: Text('ana'))));
    await pumpUntilDone(tester, PushService.start());
    await settle(tester);

    expect(find.byType(NotificationsScreen), findsOneWidget);
  });

  pushTest('Uygulama acikken gelen bildirim alt bantta gosterilir', (tester) async {
    await tester.pumpWidget(uygulama(const Scaffold(body: Text('ana'))));
    await pumpUntilDone(tester, PushService.start());

    fcm.onPlanda.add(_butceBildirimi);
    // Alt bant kayarak giriyor; sabit 750 ms, başlangıç beklemesi değişince
    // yetmedi ve "Gör" ekranın dışında (y=634 > 600) kaldı (16.10.2026).
    await settle(tester, frames: 40);

    expect(find.textContaining('Bütçe limiti aşıldı'), findsOneWidget);
    await tester.tap(find.text('Gör'));
    await settle(tester);
    expect(find.byType(NotificationsScreen), findsOneWidget);
  });

  pushTest('ZorunluCikis_PushDinleyicisiniDurdurur', (tester) async {
    // NEDEN: Merkezi token temizliği tüm push dinleyicilerini kapatmalı.
    await pumpUntilDone(tester, PushService.start());
    expect(fcm.onPlanda.hasListener, isTrue);
    // Unregister da 401 döner: çıkış yeniden refresh/çıkış döngüsüne girmemeli.
    ApiService.httpClientForTest = MockClient((_) async => http.Response('{}', 401));
    await pumpUntilDone(tester, ApiService.authenticatedGet('/test'));
    expect(await pumpUntilDone(tester, ApiService.getToken()), isNull);
    expect(fcm.onPlanda.hasListener, isFalse);
    expect(fcm.acilan.hasListener, isFalse);
    expect(fcm.yenilenen.hasListener, isFalse);
    await pumpUntilDone(tester, PushService.stop());
    expect(fcm.silinme, 1);
  });

  pushTest('OturumKapaliyken_OnPlanBildirimiGosterilmez', (tester) async {
    // NEDEN: Henüz dinleyici kapanmamış olsa bile token yokken içerik sızmamalı.
    await tester.pumpWidget(uygulama(const Scaffold()));
    await pumpUntilDone(tester, PushService.start());
    FlutterSecureStorage.setMockInitialValues({});
    fcm.onPlanda.add(_butceBildirimi);
    await settle(tester);
    expect(find.text(_butceBildirimi.title!), findsNothing);
  });

  pushTest('KilitliykenBildirimeDokunma_KilitAcilincaAcilir', (tester) async {
    // NEDEN: Bildirim rotası biyometrik kilidin üstüne çıkmamalı.
    var now = DateTime(2026, 11, 13);
    final auth = Completer<bool>();
    await tester.pumpWidget(uygulama(AppLock(
      now: () => now,
      hasSession: () async => true,
      available: () async => true,
      authenticate: () => auth.future,
      child: const Scaffold(body: Text('Ana ekran')),
    )));
    await pumpUntilDone(tester, PushService.start());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 61));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(AppLock.isLocked, isTrue);
    fcm.acilan.add(_butceBildirimi);
    await settle(tester);
    expect(find.byType(NotificationsScreen, skipOffstage: false), findsNothing);
    auth.complete(true);
    await pumpUntilDone(tester, auth.future);
    await settle(tester);
    expect(AppLock.isLocked, isFalse);
    expect(find.byType(NotificationsScreen), findsOneWidget);
  });

}
