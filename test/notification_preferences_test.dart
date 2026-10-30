import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:smartfinance_mobile/screens/notification_preferences_screen.dart';
import 'package:smartfinance_mobile/screens/profile_screen.dart';
import 'package:smartfinance_mobile/services/api_service.dart';

import 'helpers/test_app.dart';

void main() {
  var sunucuTercihleri = <String, dynamic>{};
  var getStatus = 200;
  var putStatus = 200;
  var putHata = '';
  Completer<void>? putBekletici;
  final getIstekleri = <Uri>[];
  final putGovdeleri = <Map<String, dynamic>>[];

  http.Response respond(Object body, [int status = 200]) => http.Response(jsonEncode(body), status,
      headers: {'content-type': 'application/json; charset=utf-8'});

  setUp(() async {
    await setUpFakeApi();
    PackageInfo.setMockInitialValues(appName: 'Wallet Mark', packageName: 'com.walletmark.app',
        version: '1.0.0', buildNumber: '1', buildSignature: '');
    sunucuTercihleri = {'budgetAlerts': true, 'recurringReminders': true, 'announcements': false};
    getStatus = 200;
    putStatus = 200;
    putHata = '';
    putBekletici = null;
    getIstekleri.clear();
    putGovdeleri.clear();
    // Ortak sahte sunucu tanımadığı uçlara boş nesne döner; tercih ucu için
    // durum kodu ve PUT gövdesi burada denetlenmeli.
    ApiService.httpClientForTest = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith(notificationPreferencesPath)) {
        if (request.method == 'GET') {
          getIstekleri.add(request.url);
          return getStatus == 200
              ? respond(sunucuTercihleri)
              : respond({'message': 'Sunucu hatası'}, getStatus);
        }
        if (request.method == 'PUT') {
          final body = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
          putGovdeleri.add(body);
          if (putBekletici != null) await putBekletici!.future;
          if (putStatus != 200) return respond({'message': putHata}, putStatus);
          sunucuTercihleri = {...sunucuTercihleri, ...body};
          return respond(sunucuTercihleri);
        }
      }
      if (path.endsWith('/auth/me')) {
        return respond({'fullName': 'Test Kullanıcı', 'email': 'kullanici@example.com'});
      }
      if (path.endsWith('/category')) return respond([]);
      return respond({});
    });
  });
  tearDown(tearDownFakeApi);

  Finder anahtar(String alan) => find.byKey(Key('bildirim-tercih-$alan'));
  SwitchListTile tile(WidgetTester tester, String alan) => tester.widget<SwitchListTile>(anahtar(alan));

  Future<void> ekraniAc(WidgetTester tester) async {
    await tester.pumpWidget(testApp(const NotificationPreferencesScreen()));
    await settle(tester);
  }

  /// NEDEN: KVKK gereği hiçbir tür önceden açık varsayılmamalı; ekran yalnız
  /// sunucudaki kaydı göstermeli (duyurular kapalıysa kapalı görünmeli).
  testWidgets('Ekran sunucudaki tercihleri aynen gösterir', (tester) async {
    await ekraniAc(tester);

    expect(getIstekleri, hasLength(1));
    expect(tile(tester, 'budgetAlerts').value, isTrue);
    expect(tile(tester, 'recurringReminders').value, isTrue);
    expect(tile(tester, 'announcements').value, isFalse);
    expect(find.text('Bütçe uyarıları'), findsOneWidget);
    expect(find.text('Planlı ödeme hatırlatmaları'), findsOneWidget);
    expect(find.text('Duyurular ve kampanyalar'), findsOneWidget);
    expect(find.textContaining('Güvenlik ve hesabınla ilgili zorunlu bildirimler'), findsOneWidget);
    expect(find.text('Tercihler yüklenemedi'), findsNothing);
  });

  /// NEDEN: Yalnız değişen alan gönderilmeli; tüm alanları göndermek başka
  /// bir cihazda yapılmış değişikliği eski değerle ezebilir.
  testWidgets('Duyurular açılınca PUT gövdesi yalnız announcements alanını taşır', (tester) async {
    await ekraniAc(tester);

    await tester.tap(anahtar('announcements'));
    await settle(tester);

    expect(putGovdeleri.single, {'announcements': true});
    expect(tile(tester, 'announcements').value, isTrue);
    expect(tile(tester, 'budgetAlerts').value, isTrue);
  });

  /// NEDEN: İyimser güncelleme sunucu reddederse geri alınmalı; aksi halde
  /// ekran kullanıcıya kaydedilmemiş bir tercihi kaydedilmiş gibi gösterir.
  testWidgets('PUT hata verirse anahtar eski haline döner ve sunucu mesajı görünür', (tester) async {
    putStatus = 400;
    putHata = 'Tercih kaydedilemedi.';
    await ekraniAc(tester);

    await tester.tap(anahtar('budgetAlerts'));
    await settle(tester);

    expect(putGovdeleri.single, {'budgetAlerts': false});
    expect(tile(tester, 'budgetAlerts').value, isTrue);
    expect(find.text('Tercih kaydedilemedi.'), findsOneWidget);
  });

  /// NEDEN: Aynı anahtar için üst üste iki istek giderse sıraları karışıp
  /// sunucuda yanlış değer kalabilir; istek sürerken anahtar kilitlenmeli.
  testWidgets('İstek sürerken o anahtar devre dışı, diğerleri açık kalır', (tester) async {
    putBekletici = Completer<void>();
    await ekraniAc(tester);

    await tester.tap(anahtar('announcements'));
    await settle(tester);

    expect(tile(tester, 'announcements').value, isTrue);
    expect(tile(tester, 'announcements').onChanged, isNull);
    expect(tile(tester, 'budgetAlerts').onChanged, isNotNull);
    await tester.tap(anahtar('announcements'));
    await settle(tester);
    expect(putGovdeleri, hasLength(1));

    putBekletici!.complete();
    await settle(tester);
    expect(tile(tester, 'announcements').onChanged, isNotNull);
    expect(tile(tester, 'announcements').value, isTrue);
  });

  /// NEDEN: Değerler bilinmeden anahtarlar oynatılabilirse kullanıcı
  /// sunucudaki gerçek durumu görmeden onay vermiş olur.
  testWidgets('GET hata verirse anahtarlar devre dışı ve Tekrar dene görünür', (tester) async {
    getStatus = 500;
    await ekraniAc(tester);

    expect(find.text('Tercihler yüklenemedi'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
    for (final alan in ['budgetAlerts', 'recurringReminders', 'announcements']) {
      expect(tile(tester, alan).onChanged, isNull, reason: alan);
      expect(tile(tester, alan).value, isFalse, reason: alan);
    }

    getStatus = 200;
    await tester.tap(find.text('Tekrar dene'));
    await settle(tester);

    expect(getIstekleri, hasLength(2));
    expect(find.text('Tercihler yüklenemedi'), findsNothing);
    expect(tile(tester, 'budgetAlerts').value, isTrue);
    expect(tile(tester, 'budgetAlerts').onChanged, isNotNull);
  });

  /// NEDEN: Cihaz düzeyindeki anahtar korunurken türe göre seçime profilden
  /// ulaşılabilmeli.
  testWidgets('Profilde Bildirim tercihleri satırı yeni ekranı açar', (tester) async {
    await tester.pumpWidget(testApp(const ProfileScreen()));
    await settle(tester);

    expect(find.byKey(const Key('notifications-toggle')), findsOneWidget);
    final satir = find.text('Bildirim tercihleri');
    await tester.scrollUntilVisible(satir, 200);
    await tester.tap(satir);
    await settle(tester);

    expect(find.byType(NotificationPreferencesScreen), findsOneWidget);
    expect(getIstekleri, hasLength(1));
  });
}
