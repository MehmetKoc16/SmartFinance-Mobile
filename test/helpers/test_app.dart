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

/// JSON govdeli isteklerin cozulmus govdeleri, yola gore (son gelen kalir).
final Map<String, dynamic> fakeApiBodies = {};

/// Ekranlar initState'te sunucuya istek atiyor; testlerde sahte sunucu cevap
/// veriyor. Tanimlanmamis uclar bos nesne doner.
Future<void> setUpFakeApi({
  List<Map<String, dynamic>> categories = const [],
  List<Map<String, dynamic>> transactions = const [],
  List<Map<String, dynamic>> deletedTransactions = const [],
  int restoreStatus = 200,
  int deletedStatus = 200,
  Map<String, dynamic> transactionSummary = const {},
  Object categorySummary = const [],
  Map<String, Map<String, dynamic>> technicalAnalysisByRange = const {},
  Map<String, dynamic>? subscriptionStatus,
  Map<String, dynamic>? subscriptionVerifyResult,
  int subscriptionVerifyStatus = 200,
  Duration subscriptionVerifyDelay = Duration.zero,
  Duration technicalAnalysisDelay = Duration.zero,
  Map<String, dynamic>? pdfParseResult,
  Map<String, dynamic>? pdfParseWordsResult,
  Object? symbolSearch,
  int symbolSearchStatus = 200,
  // Verilirse /transaction/filter sorguya gore cevaplanir (kategori, tarih, sayfa).
  Map<String, dynamic> Function(Uri uri)? transactionFilter,
  List<Map<String, dynamic>> budgetStatus = const [],
  Future<http.Response?> Function(http.Request request)? accountApi,
}) async {
  fakeApiRequests.clear();
  fakeApiBodies.clear();
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({'auth_token': 'test', 'refresh_token': 'test'});
  ApiService.resetLegacyMigrationForTest();
  ApiService.resetRefreshStateForTest();
  await initializeDateFormatting('tr_TR', null);

  var currentSubscriptionStatus = subscriptionStatus;
  ApiService.httpClientForTest = MockClient((request) async {
    fakeApiRequests.add(request.url);
    final path = request.url.path;
    if ((request.headers['Content-Type'] ?? '').startsWith('application/json') && request.body.isNotEmpty) {
      fakeApiBodies[path] = jsonDecode(request.body);
    }
    final accountResponse = await accountApi?.call(request);
    if (accountResponse != null) return accountResponse;
    if (path.endsWith('/restore')) {
      return http.Response(jsonEncode(restoreStatus == 200 ? {'id': 71} : {}), restoreStatus,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    final Object body;
    if (path.endsWith('/subscription/verify')) {
      if (subscriptionVerifyDelay > Duration.zero) {
        await Future<void>.delayed(subscriptionVerifyDelay);
      }
      final result = subscriptionVerifyResult ?? currentSubscriptionStatus ?? {};
      if (subscriptionVerifyStatus >= 200 && subscriptionVerifyStatus < 300 && result['isPremium'] is bool) {
        currentSubscriptionStatus = result;
      }
      return http.Response(jsonEncode(result),
          subscriptionVerifyStatus, headers: {'content-type': 'application/json; charset=utf-8'});
    }
    if (path.endsWith('/investment/search-symbols')) {
      return http.Response(jsonEncode(symbolSearch ?? []), symbolSearchStatus,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    if (path.endsWith('/transaction/deleted')) {
      return http.Response(jsonEncode(deletedTransactions), deletedStatus,
          headers: {'content-type': 'application/json; charset=utf-8'});
    } else if (path.contains('/transaction/summary/')) {
      body = transactionSummary;
    } else if (path.endsWith('/pdfimport/parse')) {
      body = pdfParseResult ?? {};
    } else if (path.endsWith('/pdfimport/parse-words')) {
      body = pdfParseWordsResult ?? {};
    } else if (path.endsWith('/subscription/status')) {
      body = currentSubscriptionStatus ?? {};
    } else if (path.contains('/transaction/category-summary/')) {
      body = categorySummary;
    } else if (path == '/api/account' && request.method == 'GET') {
      body = [];
    } else if (path.endsWith('/category')) {
      body = categories;
    } else if (path.endsWith('/transaction/filter')) {
      body = transactionFilter?.call(request.url) ??
          {'items': transactions, 'totalCount': transactions.length, 'page': 1, 'pageSize': 15, 'totalPages': 1};
    } else if (path.contains('/budget/status/')) {
      body = budgetStatus;
    } else if (path.endsWith('/investment') || path.endsWith('/notification')) {
      body = [];
    } else if (path.endsWith('/technical-analysis')) {
      if (technicalAnalysisDelay > Duration.zero) {
        await Future<void>.delayed(technicalAnalysisDelay);
      }
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

Widget testApp(
  Widget home, {
  ThemeData? theme,
  GlobalKey<NavigatorState>? navigatorKey,
  GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey,
}) =>
    ChangeNotifierProvider(
      create: (_) => ThemeController(),
      child: MaterialApp(
        theme: theme ?? AppTheme.light,
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        home: home,
      ),
    );

// pumpAndSettle, yukleme sirasinda donen sonsuz CircularProgressIndicator
// yuzunden zaman asimina ugrayabiliyor; sabit sayida kare yeterli.
Future<void> settle(WidgetTester tester, {int frames = 20}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// testWidgets FakeAsync bölgesinde bir servis Future'ını doğrudan `await`
/// etmek testi sonsuza kadar asıyor (16.10.2026: startAppWide testleri 10 dk
/// takıldı): içindeki zamanlayıcılar pump ile, gerçek I/O (platform kanalı,
/// HttpClient) ise yalnız runAsync içinde ilerliyor; ikisini sırayla ver.
Future<T> pumpUntilDone<T>(WidgetTester tester, Future<T> future, {int maxFrames = 200}) async {
  var done = false;
  future.whenComplete(() => done = true).ignore();
  for (var i = 0; i < maxFrames && !done; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (!done) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    }
  }
  if (!done) fail('Future $maxFrames kare içinde tamamlanmadı');
  return future;
}

/// Dosya okuması artık asenkron: gerçek dosya I/O'sunu FakeAsync saatinin
/// dışında bitir, ardından UI karelerini normal test saatinde çiz.
Future<void> analyzeSelectedFile(WidgetTester tester) async {
  final button = tester.widget<ElevatedButton>(
    find.widgetWithText(ElevatedButton, 'Analiz Et'),
  );
  await tester.runAsync(() => (button.onPressed! as Future<void> Function())());
  await settle(tester);
}
