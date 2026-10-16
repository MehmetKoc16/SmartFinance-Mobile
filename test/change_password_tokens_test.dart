import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartfinance_mobile/services/api_service.dart';
import 'helpers/test_app.dart';

void main() {
  setUp(() => setUpFakeApi());
  tearDown(tearDownFakeApi);
  test('Sifre degisince login ile ayni guvenli saklama yolu yeni tokenlari saklar', () async {
    ApiService.httpClientForTest = MockClient((_) async => http.Response(jsonEncode({
      'token': 'yeni-test-erisim', 'refreshToken': 'yeni-test-yenileme',
    }), 200));
    await ApiService.authenticatedPut('/auth/change-password', {'currentPassword': 'Ornek123!', 'newPassword': 'YeniOrnek123!'});
    expect(await ApiService.getToken(), 'yeni-test-erisim');
    expect(await ApiService.getRefreshToken(), 'yeni-test-yenileme');
  });
  test('Eski sunucu token dondurmezse oturum korunur', () async {
    await ApiService.authenticatedPut('/auth/change-password', {});
    expect(await ApiService.getToken(), 'test');
    expect(await ApiService.getRefreshToken(), 'test');
  });
}
