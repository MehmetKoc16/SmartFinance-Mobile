import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfinance_mobile/services/api_service.dart';

/// Oturum token'lari cihazda sifreli saklanmali (Android Keystore / iOS Keychain).
/// Duz SharedPreferences'ta tutulsalardi root'lanmis bir cihazda veya cihaz
/// yedegi cikarilarak okunup baskasinin hesabina erisim icin kullanilabilirlerdi.
void main() {
  const tokenKey = 'auth_token';
  const refreshTokenKey = 'refresh_token';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    // Migration bayragi sinif duzeyinde tutuldugu icin testler arasi sizmasin.
    ApiService.resetLegacyMigrationForTest();
  });

  group('token depolama', () {
    test('saveToken yazdigini getToken geri okur', () async {
      await ApiService.saveToken('abc123');

      expect(await ApiService.getToken(), 'abc123');
    });

    test('token guvenli depoya yazilir, SharedPreferences\'a degil', () async {
      await ApiService.saveToken('abc123');
      await ApiService.saveRefreshToken('refresh123');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(tokenKey), isNull);
      expect(prefs.getString(refreshTokenKey), isNull);
    });

    test('removeToken her iki token\'i da siler', () async {
      await ApiService.saveToken('abc123');
      await ApiService.saveRefreshToken('refresh123');

      await ApiService.removeToken();

      expect(await ApiService.getToken(), isNull);
      expect(await ApiService.getRefreshToken(), isNull);
    });

    test('isLoggedIn token yoksa false, varsa true doner', () async {
      expect(await ApiService.isLoggedIn(), isFalse);

      await ApiService.saveToken('abc123');
      expect(await ApiService.isLoggedIn(), isTrue);
    });
  });

  group('eski surumden gecis (migration)', () {
    test('SharedPreferences\'taki eski token guvenli depoya tasinir', () async {
      SharedPreferences.setMockInitialValues({
        tokenKey: 'eski_token',
        refreshTokenKey: 'eski_refresh',
      });

      // Ilk okuma tasimayi tetikler.
      expect(await ApiService.getToken(), 'eski_token');
      expect(await ApiService.getRefreshToken(), 'eski_refresh');
    });

    /// Gecisin asil amaci: duz metin kopya cihazda kalmamali.
    test('tasima sonrasi duz metin kopya silinir', () async {
      SharedPreferences.setMockInitialValues({
        tokenKey: 'eski_token',
        refreshTokenKey: 'eski_refresh',
      });

      await ApiService.getToken();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(tokenKey), isNull);
      expect(prefs.getString(refreshTokenKey), isNull);
    });

    test('eski token yoksa gecis sorunsuz gecilir', () async {
      SharedPreferences.setMockInitialValues({});

      expect(await ApiService.getToken(), isNull);
      expect(await ApiService.isLoggedIn(), isFalse);
    });

    /// Guvenli depoda zaten token varsa (normal calisma), eski deger onu ezmemeli.
    test('guvenli depodaki token eski degerle ezilmez', () async {
      SharedPreferences.setMockInitialValues({tokenKey: 'eski_token'});
      await ApiService.saveToken('yeni_token');

      expect(await ApiService.getToken(), 'yeni_token');
    });
  });
}
