import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfinance_mobile/services/api_service.dart';

/// Regresyon: kullanici sifreyle giris yaptiktan bir sure sonra uygulamayi
/// acinca (biyometrik kilit sonrasi) "Oturumunuz sonlandi" uyarisiyla giris
/// ekranina atiliyordu.
///
/// Sebep: ana ekran acilista 6 istegi AYNI ANDA gonderiyor. Erisim token'inin
/// suresi dolmussa altisi da 401 donuyor ve altisi da ayni refresh token'la
/// yenileme deniyordu. Backend rotasyon uyguladigi icin ilk deneme token'i
/// iptal ediyor, kalan besi "iptal edilmis token" hatasi alip oturumu
/// kapatiyordu — gecerli bir oturum varken.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ApiService.resetLegacyMigrationForTest();
    ApiService.resetRefreshStateForTest();
  });

  tearDown(() {
    ApiService.httpClientForTest = http.Client();
  });

  /// Rotasyonu taklit eden sahte sunucu: gecerli refresh token yalnizca BIR kez
  /// kullanilabilir, ikinci kullanimda 401 doner.
  MockClient rotatingServer({
    required String validRefreshToken,
    required List<String> refreshCalls,
    required List<String> authorizedCalls,
  }) {
    var currentAccessToken = 'eski_access';
    var currentRefreshToken = validRefreshToken;

    return MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        final sent = jsonDecode(request.body)['refreshToken'] as String;
        refreshCalls.add(sent);
        if (sent != currentRefreshToken) {
          // Rotasyona ugramis / iptal edilmis token.
          return http.Response(jsonEncode({'message': 'Oturum süresi dolmuş'}), 401);
        }
        currentAccessToken = 'yeni_access';
        currentRefreshToken = 'yeni_refresh';
        return http.Response(
          jsonEncode({'token': currentAccessToken, 'refreshToken': currentRefreshToken}),
          200,
        );
      }

      final auth = request.headers['Authorization'] ?? '';
      authorizedCalls.add(auth);
      if (auth != 'Bearer $currentAccessToken') {
        return http.Response(jsonEncode({'message': 'Yetkisiz'}), 401);
      }
      return http.Response(jsonEncode({'ok': true}), 200);
    });
  }

  test('es zamanli 401 alan istekler TEK bir yenileme paylasir', () async {
    final refreshCalls = <String>[];
    final authorizedCalls = <String>[];
    ApiService.httpClientForTest = rotatingServer(
      validRefreshToken: 'gecerli_refresh',
      refreshCalls: refreshCalls,
      authorizedCalls: authorizedCalls,
    );

    // Suresi dolmus erisim token'i + gecerli refresh token.
    await ApiService.saveToken('suresi_dolmus');
    await ApiService.saveRefreshToken('gecerli_refresh');

    // Ana ekranin acilista yaptigi gibi es zamanli 6 istek.
    final results = await Future.wait(
      List.generate(6, (i) => ApiService.authenticatedGet('/kaynak$i')),
    );

    // Kritik: rotasyona ugrayan token ile ikinci bir yenileme denenmemeli.
    expect(refreshCalls, ['gecerli_refresh'],
        reason: 'Yenileme yalnizca bir kez cagrilmali, aksi halde rotasyona '
            'ugramis token ikinci kez gonderilip oturum kapanir.');

    // Altisi da basarili sonuclanmali, hicbiri oturumu kapatmamali.
    for (final r in results) {
      expect(r, isA<Map>());
      expect((r as Map)['ok'], isTrue);
    }

    // Token'lar yenisiyle degismis olmali.
    expect(await ApiService.getToken(), 'yeni_access');
    expect(await ApiService.getRefreshToken(), 'yeni_refresh');
  });

  test('yenileme basarisiz olursa token\'lar temizlenir', () async {
    ApiService.httpClientForTest = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        return http.Response(jsonEncode({'message': 'Oturum süresi dolmuş'}), 401);
      }
      return http.Response(jsonEncode({'message': 'Yetkisiz'}), 401);
    });

    await ApiService.saveToken('suresi_dolmus');
    await ApiService.saveRefreshToken('iptal_edilmis');

    await ApiService.authenticatedGet('/kaynak');

    expect(await ApiService.getToken(), isNull);
    expect(await ApiService.getRefreshToken(), isNull);
  });

  test('gecerli token ile istek yenileme tetiklemez', () async {
    final refreshCalls = <String>[];
    final authorizedCalls = <String>[];
    ApiService.httpClientForTest = rotatingServer(
      validRefreshToken: 'gecerli_refresh',
      refreshCalls: refreshCalls,
      authorizedCalls: authorizedCalls,
    );

    await ApiService.saveToken('eski_access');
    await ApiService.saveRefreshToken('gecerli_refresh');

    final result = await ApiService.authenticatedGet('/kaynak');

    expect((result as Map)['ok'], isTrue);
    expect(refreshCalls, isEmpty);
  });

  /// Yenileme bittikten SONRA 401 donen yavas bir istek, bosuna yeni bir
  /// rotasyon baslatmadan guncel token'la tekrar denenmeli.
  test('yenileme tamamlandiktan sonra gelen 401 yeni token ile tekrar dener', () async {
    final refreshCalls = <String>[];
    final authorizedCalls = <String>[];
    ApiService.httpClientForTest = rotatingServer(
      validRefreshToken: 'gecerli_refresh',
      refreshCalls: refreshCalls,
      authorizedCalls: authorizedCalls,
    );

    await ApiService.saveToken('suresi_dolmus');
    await ApiService.saveRefreshToken('gecerli_refresh');

    await ApiService.authenticatedGet('/ilk');
    expect(refreshCalls.length, 1);

    // Bu istek artik gecerli token'la gidiyor, yeniden yenileme olmamali.
    await ApiService.authenticatedGet('/ikinci');
    expect(refreshCalls.length, 1);
  });
}
