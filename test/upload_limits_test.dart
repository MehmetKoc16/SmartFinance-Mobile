import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartfinance_mobile/services/api_service.dart';
import 'helpers/test_app.dart';

void main() {
  setUp(() => setUpFakeApi());
  tearDown(() {
    ApiService.uploadTimeoutForTest = null;
    tearDownFakeApi();
  });
  test('15 MB ustu dosya ag istemcisine gonderilmez', () async {
    final directory = await Directory.systemTemp.createTemp('upload-limit');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/test.pdf');
    final handle = await file.open(mode: FileMode.write);
    await handle.truncate(15 * 1024 * 1024 + 1);
    await handle.close();
    var sent = false;
    ApiService.httpClientForTest = MockClient((_) async {
      sent = true;
      return http.Response('{}', 200);
    });
    final result = await ApiService.authenticatedUpload('/pdfimport/parse', file.path);
    expect(result['error'], 'Dosya çok büyük (en fazla 15 MB).');
    expect(sent, false);
  });
  test('Yukleme zaman asimi yanit govdesini de kapsar', () async {
    final directory = await Directory.systemTemp.createTemp('upload-timeout');
    addTearDown(() => directory.delete(recursive: true));
    final file = await File('${directory.path}/test.pdf').writeAsString('test');
    final body = StreamController<List<int>>();
    addTearDown(body.close);
    ApiService.uploadTimeoutForTest = const Duration(milliseconds: 10);
    ApiService.httpClientForTest = MockClient.streaming((_, _) async => http.StreamedResponse(body.stream, 200));
    final result = await ApiService.authenticatedUpload('/pdfimport/parse', file.path);
    expect(result, contains('error'));
  });
}
