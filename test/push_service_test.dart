import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfinance_mobile/screens/main_screen.dart';
import 'package:smartfinance_mobile/screens/notifications_screen.dart';
import 'package:smartfinance_mobile/services/api_service.dart';
import 'package:smartfinance_mobile/services/push_service.dart';

import 'helpers/test_app.dart';

class _SahteFcm implements PushMessaging {
  bool izin = true;
  String? token = 'tel-token-1';
  int silinme = 0;
  PushPayload? ilkMesaj;
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
  Future<void> deleteToken() async => silinme++;
  @override
  Future<PushPayload?> getInitialMessage() async => ilkMesaj;
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
    await setUpFakeApi();
    fcm = _SahteFcm();
    PushService.messaging = fcm;
    PushService.enabled = true;
  });

  tearDown(() async {
    await PushService.resetForTest();
    tearDownFakeApi();
  });

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

  testWidgets('Ana ekran acilinca bildirim kaydi baslar', (tester) async {
    await tester.pumpWidget(testApp(const MainScreen()));
    await settle(tester);

    expect(govdeler('/devicetoken'), [
      {'token': 'tel-token-1'},
    ]);
  });

  testWidgets('Bildirime dokunulunca bildirimler ekrani acilir', (tester) async {
    await tester.pumpWidget(uygulama(const Scaffold(body: Text('ana'))));
    await PushService.start();

    fcm.acilan.add(_butceBildirimi);
    await settle(tester);

    expect(find.byType(NotificationsScreen), findsOneWidget);
  });

  testWidgets('Uygulama kapaliyken dokunulan bildirim acilista karsilanir', (tester) async {
    fcm.ilkMesaj = _butceBildirimi;
    await tester.pumpWidget(uygulama(const Scaffold(body: Text('ana'))));
    await PushService.start();
    await settle(tester);

    expect(find.byType(NotificationsScreen), findsOneWidget);
  });

  testWidgets('Uygulama acikken gelen bildirim alt bantta gosterilir', (tester) async {
    await tester.pumpWidget(uygulama(const Scaffold(body: Text('ana'))));
    await PushService.start();

    fcm.onPlanda.add(_butceBildirimi);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750)); // alt bant kayarak giriyor

    expect(find.textContaining('Bütçe limiti aşıldı'), findsOneWidget);
    await tester.tap(find.text('Gör'));
    await settle(tester);
    expect(find.byType(NotificationsScreen), findsOneWidget);
  });
}
