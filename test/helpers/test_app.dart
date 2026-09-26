import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfinance_mobile/core/theme/app_theme.dart';
import 'package:smartfinance_mobile/core/theme/theme_controller.dart';
import 'package:smartfinance_mobile/services/api_service.dart';

/// Sahte sunucuya gelen istekler — testler istek sayisini dogrulayabilsin diye.
final List<Uri> fakeApiRequests = [];

/// Ekranlar initState'te sunucuya istek atiyor; testlerde sahte sunucu cevap
/// veriyor. Tanimlanmamis uclar bos nesne doner.
Future<void> setUpFakeApi({
  List<Map<String, dynamic>> categories = const [],
  List<Map<String, dynamic>> transactions = const [],
  Map<String, Map<String, dynamic>> technicalAnalysisByRange = const {},
  Map<String, dynamic>? subscriptionStatus,
  Duration technicalAnalysisDelay = Duration.zero,
  Map<String, dynamic>? pdfParseResult,
}) async {
  fakeApiRequests.clear();
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({'auth_token': 'test', 'refresh_token': 'test'});
  ApiService.resetLegacyMigrationForTest();
  ApiService.resetRefreshStateForTest();
  await initializeDateFormatting('tr_TR', null);

  ApiService.httpClientForTest = MockClient((request) async {
    fakeApiRequests.add(request.url);
    final path = request.url.path;
    final Object body;
    if (path.endsWith('/pdfimport/parse')) {
      body = pdfParseResult ?? {};
    } else if (path.endsWith('/subscription/status')) {
      body = subscriptionStatus ?? {};
    } else if (path.endsWith('/category')) {
      body = categories;
    } else if (path.endsWith('/transaction/filter')) {
      body = {'items': transactions, 'totalCount': transactions.length, 'page': 1, 'pageSize': 15, 'totalPages': 1};
    } else if (path.endsWith('/investment') || path.endsWith('/notification')) {
      body = [];
    } else if (path.endsWith('/technical-analysis')) {
      await Future<void>.delayed(technicalAnalysisDelay);
      body = technicalAnalysisByRange[request.url.queryParameters['range']] ?? {};
    } else if (path.endsWith('/investment/refresh-prices')) {
      body = {'investments': []};
    } else {
      body = {};
    }
    return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
  });
}

void tearDownFakeApi() => ApiService.httpClientForTest = http.Client();

Widget testApp(Widget home, {ThemeData? theme}) => ChangeNotifierProvider(
      create: (_) => ThemeController(),
      child: MaterialApp(theme: theme ?? AppTheme.light, home: home),
    );

// pumpAndSettle, yukleme sirasinda donen sonsuz CircularProgressIndicator
// yuzunden zaman asimina ugrayabiliyor; sabit sayida kare yeterli.
Future<void> settle(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
