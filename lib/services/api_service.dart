import 'dart:convert';   //Json verileri okumak için
import 'package:flutter/widgets.dart';   //GlobalKey<NavigatorState> ve debugPrint için

import 'package:http/http.dart' as http;    //Backend'e istek atmak için
import 'package:shared_preferences/shared_preferences.dart';    //Token'ı telefonun hafızasına kaydetmek için

class ApiService{
    static const String baseUrl = 'http://10.0.2.2:5059/api';   //Tüm metodlar bu adresi kullanır, tek yönden yönetilir.

    // Sunucuya hic ulasilamadigi (ag donuk, yanlis adres vb.) durumlarda
    // istegin sinirsiz beklemesini engeller — aksi halde kullanici ekranda
    // sonsuza dek "yukleniyor" durumunda kalabilir.
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

    static Future<void> saveToken(String token) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token',token);
    }

    static Future<String?> getToken() async{
        final prefs=await SharedPreferences.getInstance();
        return prefs.getString('auth_token');
    }

    static Future<void> saveRefreshToken(String refreshToken) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('refresh_token', refreshToken);
    }

    static Future<String?> getRefreshToken() async {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString('refresh_token');
    }

    static Future<void> removeToken() async{
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
        await prefs.remove('refresh_token');
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
                await http.post(
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

    /// Erişim (JWT) token'inin süresi dolunca kullanıcıyı login'e düşürmeden
    /// önce saklanan refresh token ile sessizce yeni bir token çifti almayı
    /// dener. Backend rotasyon uyguladığı için (kullanılan refresh token
    /// iptal edilir) dönen yeni refresh token da kaydedilmeli.
    static Future<bool> _tryRefreshToken() async {
        final refreshToken = await getRefreshToken();
        if (refreshToken == null) return false;
        try {
            final response = await http.post(
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
            final response = await http.post(
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
        final response = await http.post(
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

    static Future<dynamic> authenticatedGet(String endpoint) async{
        try{
            final response = await _sendWithAuth((token) => http.get(
                Uri.parse('$baseUrl$endpoint'),
                headers:{
                    'Content-Type':'application/json',
                    'Authorization':'Bearer $token',
                },
            ).timeout(_timeout));
            return _decodeResponse(response);
        }catch(e){
            return {'error': 'Bağlantı hatası: $e'};
        }
    }


    static Future<dynamic> authenticatedPost(String endpoint,Map<String,dynamic> body,) async{
        try{
            final response = await _sendWithAuth((token) => http.post(
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
            final response = await _sendWithAuth((token) => http.put(
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

    static Future<dynamic> authenticatedDelete(String endpoint) async {
        try {
            final response = await _sendWithAuth((token) => http.delete(
                Uri.parse('$baseUrl$endpoint'),
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                },
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
