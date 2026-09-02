import 'dart:convert';   //Json verileri okumak için
import 'package:flutter/widgets.dart';   //GlobalKey<NavigatorState> ve debugPrint için

import 'package:flutter_secure_storage/flutter_secure_storage.dart';    //Token'ları şifreli saklamak için
import 'package:http/http.dart' as http;    //Backend'e istek atmak için
import 'package:shared_preferences/shared_preferences.dart';    //Eski sürümden token taşıma (migration) için

class ApiService{
    // Canlı sunucu (Hetzner + Caddy, Let's Encrypt sertifikalı).
    // Yerel geliştirme için: Android emülatörde 'http://10.0.2.2:5059/api',
    // USB'yle bağlı fiziksel cihazda 'adb reverse tcp:5059 tcp:5059' + 'http://localhost:5059/api'.
    static const String baseUrl = 'https://api.walletmark.com.tr/api';   //Tüm metodlar bu adresi kullanır, tek yönden yönetilir.

    // Oturum token'ları cihazda şifreli saklanır: Android'de Keystore destekli
    // EncryptedSharedPreferences, iOS'ta Keychain. Düz SharedPreferences'ta
    // tutulsalardı root'lanmış bir cihazda veya cihaz yedeği çıkarılarak
    // okunabilir, başkasının hesabına erişim için kullanılabilirlerdi.
    static const _tokenKey = 'auth_token';
    static const _refreshTokenKey = 'refresh_token';

    // Android tarafında ek ayar verilmiyor: paketin v10 sürümü Keystore destekli
    // kendi şifrelemesini varsayılan olarak uyguluyor (eski
    // encryptedSharedPreferences seçeneği Google Jetpack Security'yi bıraktığı
    // için kullanımdan kaldırıldı).
    static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
        // "this_device": token cihaz yedeğiyle başka bir cihaza taşınmaz.
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
    );

    // Sunucuya hic ulasilamadigi (ag donuk, yanlis adres vb.) durumlarda
    // istegin sinirsiz beklemesini engeller — aksi halde kullanici ekranda
    // sonsuza dek "yukleniyor" durumunda kalabilir.
    // HTTP istemcisi tek bir yerden veriliyor: testlerde sahte bir istemciyle
    // degistirilebilsin diye. Aksi halde token yenileme davranisi ancak gercek
    // sunucuya baglanarak dogrulanabilirdi.
    static http.Client _client = http.Client();

    @visibleForTesting
    static set httpClientForTest(http.Client client) => _client = client;

    static const Duration _timeout = Duration(seconds: 15);
    static const Duration _uploadTimeout = Duration(seconds: 60);

    // MaterialApp'e bağlanır (main.dart); ekran/context'e bağlı olmadan
    // her yerden login ekranına yönlendirebilmek için kullanılır.
    static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    static bool _isRedirectingToLogin = false;

    // Token süresi dolmuş/geçersizse (401) ve sessiz yenileme (refresh token)
    // de başarısız olursa tüm ekranlar için tek noktadan oturumu kapatıp
    // login ekranına atar; aynı anda birden fazla isteğin aynı anda 401
    // dönmesi durumunda tekrar tekrar yönlendirmeyi engeller.
    static Future<void> _handleUnauthorized() async {
        if (_isRedirectingToLogin) return;
        _isRedirectingToLogin = true;
        await removeToken();
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
            arguments: {'sessionExpired': true},
        );
        _isRedirectingToLogin = false;
    }

    // Uygulamanın önceki sürümü token'ları düz metin olarak SharedPreferences'ta
    // tutuyordu. Güncellemeden sonra bu kullanıcıların oturumu kapanmasın diye
    // eski değerler bir kez güvenli depoya taşınır ve düz metin kopya silinir.
    static bool _legacyMigrationDone = false;

    @visibleForTesting
    static void resetLegacyMigrationForTest() => _legacyMigrationDone = false;

    static Future<void> _migrateLegacyTokensIfNeeded() async {
        if (_legacyMigrationDone) return;
        _legacyMigrationDone = true;
        try {
            final prefs = await SharedPreferences.getInstance();
            for (final key in [_tokenKey, _refreshTokenKey]) {
                final legacyValue = prefs.getString(key);
                if (legacyValue == null) continue;
                // Güvenli depoda geçerli bir değer varsa eski (muhtemelen daha
                // bayat) kopya onu ezmemeli; bu durumda sadece düz metni sil.
                final existing = await _secureStorage.read(key: key);
                if (existing == null) {
                    await _secureStorage.write(key: key, value: legacyValue);
                }
                await prefs.remove(key);
            }
        } catch (_) {
            // Taşıma başarısız olursa kullanıcı yalnızca tekrar giriş yapar;
            // bu, uygulamanın açılışını engellemekten iyidir.
        }
    }

    static Future<void> saveToken(String token) async {
        await _secureStorage.write(key: _tokenKey, value: token);
    }

    static Future<String?> getToken() async{
        await _migrateLegacyTokensIfNeeded();
        return _secureStorage.read(key: _tokenKey);
    }

    static Future<void> saveRefreshToken(String refreshToken) async {
        await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    }

    static Future<String?> getRefreshToken() async {
        await _migrateLegacyTokensIfNeeded();
        return _secureStorage.read(key: _refreshTokenKey);
    }

    static Future<void> removeToken() async{
        await _secureStorage.delete(key: _tokenKey);
        await _secureStorage.delete(key: _refreshTokenKey);
        // Taşıma hiç çalışmamış olabileceği ihtimaline karşı eski düz metin
        // kopyalar da temizlenir — çıkış yapan kullanıcının token'ı cihazda kalmasın.
        try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(_tokenKey);
            await prefs.remove(_refreshTokenKey);
        } catch (_) {}
    }

    static Future<bool> isLoggedIn() async{
        final token = await getToken();
        return token != null;
    }

    /// Sunucu tarafında refresh token'ı da iptal edip (mümkünse) yerel
    /// token'ları temizler. Backend isteği başarısız olsa bile (bağlantı yok
    /// vb.) yerel oturum her halükarda kapatılır.
    static Future<void> logout() async {
        final refreshToken = await getRefreshToken();
        if (refreshToken != null) {
            try {
                await _client.post(
                    Uri.parse('$baseUrl/auth/logout'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({'refreshToken': refreshToken}),
                ).timeout(_timeout);
            } catch (_) {
                // Best-effort — bağlantı yoksa bile yerel oturumu kapatmaya devam et.
            }
        }
        await removeToken();
    }

    // Devam eden yenileme işlemi. Aynı anda birden fazla istek 401 alırsa
    // hepsi BU işlemi paylaşır, her biri ayrı ayrı yenileme denemez.
    //
    // Neden gerekli: ana ekran açılışta 6 isteği aynı anda gönderiyor. Erişim
    // token'ının süresi dolmuşsa altısı da 401 dönüyordu ve altısı da aynı
    // refresh token'la yenileme deniyordu. Backend rotasyon uyguladığı için
    // ilk deneme token'ı iptal ediyor, kalan beşi "iptal edilmiş token" hatası
    // alıp oturumu kapatıyordu — kullanıcı geçerli bir oturumu varken
    // "Oturumunuz sonlandı" uyarısıyla giriş ekranına atılıyordu.
    static Future<bool>? _refreshInFlight;

    @visibleForTesting
    static void resetRefreshStateForTest() {
        _refreshInFlight = null;
        // Yonlendirme kilidi de sinif duzeyinde; testler arasi sizarsa bir
        // sonraki testte oturum kapatma hic calismamis gibi gorunur.
        _isRedirectingToLogin = false;
    }

    /// Erişim (JWT) token'inin süresi dolunca kullanıcıyı login'e düşürmeden
    /// önce saklanan refresh token ile sessizce yeni bir token çifti almayı
    /// dener. Backend rotasyon uyguladığı için (kullanılan refresh token
    /// iptal edilir) dönen yeni refresh token da kaydedilmeli.
    ///
    /// Eşzamanlı çağrılar tek bir istekte birleştirilir.
    static Future<bool> _tryRefreshToken() {
        final inFlight = _refreshInFlight;
        if (inFlight != null) return inFlight;

        final future = _performRefresh();
        _refreshInFlight = future;
        return future.whenComplete(() {
            _refreshInFlight = null;
        });
    }

    static Future<bool> _performRefresh() async {
        final refreshToken = await getRefreshToken();
        if (refreshToken == null) return false;
        try {
            final response = await _client.post(
                Uri.parse('$baseUrl/auth/refresh'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({'refreshToken': refreshToken}),
            ).timeout(_timeout);
            if (response.statusCode != 200) return false;
            final data = jsonDecode(response.body);
            await saveToken(data['token']);
            await saveRefreshToken(data['refreshToken']);
            return true;
        } catch (e) {
            return false;
        }
    }

    /// Verilen isteği mevcut erişim token'ıyla gönderir; 401 dönerse önce
    /// sessizce refresh dener, başarılı olursa isteği yeni token'la bir kez
    /// daha gönderir. Refresh de başarısız olursa oturumu sonlandırır.
    static Future<http.Response> _sendWithAuth(
        Future<http.Response> Function(String token) send,
    ) async {
        final token = await getToken();
        final response = await send(token ?? '');
        if (response.statusCode != 401) return response;

        // Bu istek yoldayken başka bir istek token'ı yenilemiş olabilir.
        // Öyleyse yeniden yenilemeye (ve refresh token'ı bir kez daha
        // rotasyona sokmaya) gerek yok, yalnızca yeni token'la tekrar dene.
        final currentToken = await getToken();
        if (currentToken != null && currentToken != token) {
            return send(currentToken);
        }

        final refreshed = await _tryRefreshToken();
        if (!refreshed) {
            await _handleUnauthorized();
            return response;
        }

        final newToken = await getToken();
        return send(newToken ?? '');
    }

    static Future<Map<String,dynamic>> register({
        required String fullName,
        required String email,
        required String password,
    }) async{
        try{
            final response = await _client.post(
                Uri.parse('$baseUrl/auth/register'),
                headers:{'Content-Type':'application/json'},
                body: jsonEncode({
                    'fullName': fullName,
                    'email' : email,
                    'password' : password,
                }),
            ).timeout(_timeout);

            final data = jsonDecode(response.body);

            if(response.statusCode == 200){
                await saveToken(data['token']);
                await saveRefreshToken(data['refreshToken']);
                return {'success':true,'data': data};
            }else{
                return{'success':false,'message':data['message'] ?? 'Kayıt başarısız'};
            }
        }catch(e){
            return {'success':false,'message':'Bağlantı hatası: $e'};
        }
    }

    static Future<Map<String, dynamic>> login({
      required String email,
      required String password,
    }) async {
      try {
        final response = await _client.post(
          Uri.parse('$baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'password': password,
          }),
        ).timeout(_timeout);

        final data = jsonDecode(response.body);

        if (response.statusCode == 200) {
          await saveToken(data['token']);
          await saveRefreshToken(data['refreshToken']);
          return {'success': true, 'data': data};
        } else {
          return {'success': false, 'message': data['message'] ?? 'Giriş başarısız'};
        }
      } catch (e) {
        return {'success': false, 'message': 'Bağlantı hatası: $e'};
      }
    }

    /// Başarılı (2xx) yanıtlarda decode edilmiş body'yi, hatalı yanıtlarda
    /// {'error': mesaj} döndürür. Backend hata gövdesi {"message": "..."} şeklinde gelir.
    static dynamic _decodeResponse(http.Response response) {
        if (response.statusCode == 401) {
            return {'error': 'Oturumunuz sona erdi, lütfen tekrar giriş yapın.'};
        }
        final data = response.body.isEmpty ? {} : jsonDecode(response.body);
        if (response.statusCode >= 200 && response.statusCode < 300) {
            return data;
        }
        final message = (data is Map && data['message'] != null)
            ? data['message']
            : 'İşlem başarısız';
        return {'error': message};
    }

    static Future<dynamic> authenticatedGet(String endpoint, {Duration? timeout}) async{
        try{
            final response = await _sendWithAuth((token) => _client.get(
                Uri.parse('$baseUrl$endpoint'),
                headers:{
                    'Content-Type':'application/json',
                    'Authorization':'Bearer $token',
                },
            ).timeout(timeout ?? _timeout));
            return _decodeResponse(response);
        }catch(e){
            return {'error': 'Bağlantı hatası: $e'};
        }
    }


    static Future<dynamic> authenticatedPost(String endpoint,Map<String,dynamic> body,) async{
        try{
            final response = await _sendWithAuth((token) => _client.post(
                Uri.parse('$baseUrl$endpoint'),
                headers:{
                    'Content-Type':'application/json',
                    'Authorization':'Bearer $token',
                },
                body:jsonEncode(body),
            ).timeout(_timeout));
            return _decodeResponse(response);
        }catch(e){
            return {'error':'Bağlantı hatası: $e'};
        }
    }

    static Future<dynamic> authenticatedPut(String endpoint, Map<String, dynamic> body) async {
        try {
            final response = await _sendWithAuth((token) => _client.put(
                Uri.parse('$baseUrl$endpoint'),
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                },
                body: jsonEncode(body),
            ).timeout(_timeout));
            return _decodeResponse(response);
        } catch (e) {
            return {'error': 'Bağlantı hatası: $e'};
        }
    }

    /// [body] yalnizca gerektiginde gonderilir. Hesap silme ucu, islemin geri
    /// alinamaz olmasi nedeniyle govdede sifre dogrulamasi istiyor.
    static Future<dynamic> authenticatedDelete(String endpoint, [Map<String, dynamic>? body]) async {
        try {
            final response = await _sendWithAuth((token) => _client.delete(
                Uri.parse('$baseUrl$endpoint'),
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                },
                body: body == null ? null : jsonEncode(body),
            ).timeout(_timeout));
            return _decodeResponse(response);
        } catch (e) {
            return {'error': 'Bağlantı hatası: $e'};
        }
    }

    /// Multipart file upload (PDF yükleme için)
    static Future<dynamic> authenticatedUpload(String endpoint, String filePath) async {
        try {
            final response = await _sendWithAuth((token) async {
                final uri = Uri.parse('$baseUrl$endpoint');
                var request = http.MultipartRequest('POST', uri);
                request.headers['Authorization'] = 'Bearer $token';
                request.files.add(await http.MultipartFile.fromPath('file', filePath));
                final streamedResponse = await request.send().timeout(_uploadTimeout);
                return http.Response.fromStream(streamedResponse);
            });
            return _decodeResponse(response);
        } catch (e) {
            debugPrint('[Upload] ERROR: $e');
            return {'error': 'Bağlantı hatası: $e'};
        }
    }
}
