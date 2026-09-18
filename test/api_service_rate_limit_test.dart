import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartfinance_mobile/services/api_service.dart';

import 'helpers/test_app.dart';

/// Regresyon (18.09.2026): hiz sinirina takilan istek (HTTP 429) bos govdeyle
/// donuyor, kullaniciya "Islem basarisiz" gibi sebebi belirsiz bir mesaj
/// gidiyordu.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(tearDownFakeApi);

  test('429 yanitinda kullaniciya anlasilir mesaj doner', () async {
    await setUpFakeApi();
    ApiService.httpClientForTest = MockClient((_) async => http.Response('', 429));

    final sonuc = await ApiService.authenticatedGet('/investment/47/technical-analysis?range=1y');

    expect(sonuc['error'], contains('Çok fazla istek'));
  });
}
