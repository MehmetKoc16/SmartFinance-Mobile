import 'dart:convert';   //Json verileri okumak için
import 'package:http/http.dart' as http;    //Backend'e istek atmak için
import 'package:shared_preferences/shared_preferences.dart';    //Token'ı telefonun hafızasına kaydetmek için

class ApiService{
    static const String baseUrl = 'http://10.0.2.2:5059/api';   //Tüm metodlar bu adresi kullanır, tek yönden yönetilir.

    static Future<void> saveToken(String token) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token',token);
    }

    static Future<String?> getToken() async{
        final prefs=await SharedPreferences.getInstance();
        return prefs.getString('auth_token');
    }

    static Future<void> removeToken() async{
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
    }

    static Future<bool> isLoggedIn() async{
        final token = await getToken();
        return token != null;
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
            );

            final data = jsonDecode(response.body);

            if(response.statusCode == 200){
                await saveToken(data['token']);
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
        );

        final data = jsonDecode(response.body);

        if (response.statusCode == 200) {
          await saveToken(data['token']);
          return {'success': true, 'data': data};
        } else {
          return {'success': false, 'message': data['message'] ?? 'Giriş başarısız'};
        }
      } catch (e) {
        return {'success': false, 'message': 'Bağlantı hatası: $e'};
      }
    }

    static Future<Map<String,dynamic>> authenticatedGet(String endpoint) async{
        try{
            final token = await getToken();

            final response = await http.get(
                Uri.parse('$baseUrl$endpoint'),
                headers:{
                    'Content-Type':'application/json',
                    'Authorization':'Bearer $token',
                },
            );
            return jsonDecode(response.body);
        }catch(e){
            return {'error': 'Bağlantı hatası: $e'};
        }
    }


    static Future<Map<String,dynamic>> authenticatedPost(String endpoint,Map<String,dynamic> body,) async{
        try{
            final token = await getToken();

            final response = await http.post(
                Uri.parse('$baseUrl$endpoint'),
                headers:{
                    'Content-Type':'application/json',
                    'Authorization':'Bearer $token',
                },
                body:jsonEncode(body),
            );
            return jsonDecode(response.body);
        }catch(e){
            return {'error':'Bağlantı hatası: $e'};
        }
    }
}




