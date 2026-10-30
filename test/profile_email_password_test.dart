import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:smartfinance_mobile/screens/profile_screen.dart';
import 'package:smartfinance_mobile/services/api_service.dart';

import 'helpers/test_app.dart';

const _mevcutEposta = 'kullanici@example.com';

void main() {
  final profileBodies = <Map<String, dynamic>>[];
  var profileStatus = 200;
  var profileError = '';

  http.Response respond(Object body, [int status = 200]) => http.Response(jsonEncode(body), status,
      headers: {'content-type': 'application/json; charset=utf-8'});

  setUp(() async {
    await setUpFakeApi();
    PackageInfo.setMockInitialValues(appName: 'Wallet Mark', packageName: 'com.walletmark.app',
        version: '1.0.0', buildNumber: '1', buildSignature: '');
    profileBodies.clear();
    profileStatus = 200;
    profileError = '';
    // Ortak sahte sunucu /auth/me için boş nesne döner; burada e-postası
    // bilinen bir hesap ve /auth/profile gövdesinin kaydı gerekiyor.
    ApiService.httpClientForTest = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/auth/me')) {
        return respond({'fullName': 'Test Kullanıcı', 'email': _mevcutEposta});
      }
      if (path.endsWith('/auth/profile')) {
        final body = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        profileBodies.add(body);
        return profileStatus == 200
            ? respond({'fullName': body['fullName'], 'email': body['email']})
            : respond({'message': profileError}, profileStatus);
      }
      if (path.endsWith('/category')) return respond([]);
      return respond({});
    });
  });
  tearDown(tearDownFakeApi);

  Future<void> openEditSheet(WidgetTester tester) async {
    await tester.pumpWidget(testApp(const ProfileScreen()));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Profil Düzenle'), 200);
    await tester.tap(find.text('Profil Düzenle'));
    await settle(tester);
  }

  Finder nameField() => find.byType(TextField).at(0);
  Finder emailField() => find.byType(TextField).at(1);

  Future<void> tapSave(WidgetTester tester) async {
    final save = find.widgetWithText(ElevatedButton, 'Kaydet');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await settle(tester);
  }

  /// NEDEN: 29.10 denetimi: telefonu açık bırakılan biri hesabın e-postasını
  /// şifre bilmeden değiştirebiliyordu; e-posta değişikliği şifreyle doğrulanmalı.
  testWidgets('E-posta değişince şifre diyaloğu açılır ve currentPassword gönderilir', (tester) async {
    await openEditSheet(tester);
    await tester.enterText(emailField(), 'yeni@example.com');
    await tapSave(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Şifrenizi doğrulayın'), findsOneWidget);
    expect(profileBodies, isEmpty);

    await tester.enterText(find.byKey(const Key('profil-mevcut-sifre')), 'Ornek123!');
    await tester.tap(find.text('Onayla'));
    await settle(tester);

    expect(profileBodies.single, {
      'fullName': 'Test Kullanıcı',
      'email': 'yeni@example.com',
      'currentPassword': 'Ornek123!',
    });
    expect(find.text('Profil güncellendi!'), findsOneWidget);
  });

  /// NEDEN: Yalnız ad değişikliği kimlik değiştirmez; şifre sorulmamalı ve
  /// eski istemci gövdesi aynen korunmalı.
  testWidgets('Yalnız ad değişince şifre diyaloğu açılmaz ve currentPassword gönderilmez', (tester) async {
    await openEditSheet(tester);
    await tester.enterText(nameField(), 'Yeni Ad');
    await tapSave(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(profileBodies.single, {'fullName': 'Yeni Ad', 'email': _mevcutEposta});
  });

  /// NEDEN: Büyük/küçük harf ya da baş/son boşluk farkı aynı adrestir;
  /// kullanıcıya gereksiz şifre sorulmamalı.
  testWidgets('E-posta yalnız harf büyüklüğü ve boşlukla farklıysa şifre sorulmaz', (tester) async {
    await openEditSheet(tester);
    await tester.enterText(emailField(), '  Kullanici@Example.COM ');
    await tapSave(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(profileBodies.single.containsKey('currentPassword'), isFalse);
  });

  /// NEDEN: Kullanıcı şifre diyaloğundan vazgeçerse e-posta değişikliği
  /// sunucuya hiç ulaşmamalı.
  testWidgets('Şifre diyaloğu iptal edilirse profil isteği gönderilmez', (tester) async {
    await openEditSheet(tester);
    await tester.enterText(emailField(), 'yeni@example.com');
    await tapSave(tester);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('İptal'));
    await settle(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(profileBodies, isEmpty);
    expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Kaydet')).onPressed, isNotNull);
  });

  /// NEDEN: Boş şifreyle istek atılmamalı; kullanıcı diyalogda uyarılmalı.
  testWidgets('Şifre boş bırakılırsa diyalog kapanmaz ve istek gönderilmez', (tester) async {
    await openEditSheet(tester);
    await tester.enterText(emailField(), 'yeni@example.com');
    await tapSave(tester);

    await tester.tap(find.text('Onayla'));
    await settle(tester);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Mevcut şifrenizi giriniz!'), findsOneWidget);
    expect(profileBodies, isEmpty);
  });

  /// NEDEN: Yanlış şifre iş kuralı hatasıdır (400); sunucunun mesajı alt
  /// sayfada aynen gösterilmeli ve oturum kapanmamalı.
  testWidgets('Sunucu 400 Mevcut şifre hatalı dönerse mesaj alt sayfada görünür', (tester) async {
    profileStatus = 400;
    profileError = 'Mevcut şifre hatalı.';
    await openEditSheet(tester);
    await tester.enterText(emailField(), 'yeni@example.com');
    await tapSave(tester);
    await tester.enterText(find.byKey(const Key('profil-mevcut-sifre')), 'YanlisSifre1');
    await tester.tap(find.text('Onayla'));
    await settle(tester);

    expect(profileBodies.single['currentPassword'], 'YanlisSifre1');
    expect(find.text('Mevcut şifre hatalı.'), findsOneWidget);
    expect(find.text('Profil güncellendi!'), findsNothing);
  });
}
