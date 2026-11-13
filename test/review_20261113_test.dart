import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:smartfinance_mobile/core/utils/formatters.dart';
import 'package:smartfinance_mobile/core/utils/review_helpers.dart';
import 'package:smartfinance_mobile/screens/add_transaction_screen.dart';
import 'package:smartfinance_mobile/screens/categories_screen.dart';
import 'package:smartfinance_mobile/screens/dashboard_screen.dart';
import 'package:smartfinance_mobile/screens/pdf_import_screen.dart';
import 'package:smartfinance_mobile/screens/profile_screen.dart';
import 'package:smartfinance_mobile/screens/transactions_screen.dart';
import 'package:smartfinance_mobile/widgets/transaction_card.dart';
import 'package:smartfinance_mobile/services/account_service.dart';
import 'package:smartfinance_mobile/services/api_service.dart';
import 'package:smartfinance_mobile/services/amount_privacy.dart';
import 'helpers/test_app.dart';

http.Response cevap(Object data) => http.Response(jsonEncode(data), 200,
  headers: {'content-type': 'application/json; charset=utf-8'});
const kategori = {'id': 2, 'name': 'Market', 'type': 2};
const butce = {'id': 5, 'categoryId': 2, 'monthlyLimit': 1250.75, 'spent': 0, 'ratio': 0};

Future<void> kapat(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  setUp(() {
    AmountPrivacy.gizli.value = false;
    PackageInfo.setMockInitialValues(appName: 'Wallet Mark', packageName: 'test',
      version: '1', buildNumber: '1', buildSignature: '');
  });
  tearDown(tearDownFakeApi);

  for (final entry in {'Ali  Veli': 'AV', '  Ali ': 'A', '': 'SF', ' ': 'SF'}.entries) {
    test('BasHarfler_BosluklarGuvenleIslenir_${entry.key}', () {
      // NEDEN: Boş parçaya indeksleme çift veya kenar boşluklarda çökmemeli.
      expect(nameInitials(entry.key), entry.value);
    });
  }

  testWidgets('AyHizliDegisince_EskiYanitYeniAyiEzmez', (tester) async {
    // NEDEN: Önceki ayın geç yanıtı son seçilen ayın parasını ezmemeli.
    final now = DateTime.now();
    final oldMonth = DateTime(now.year, now.month - 1);
    final latestMonth = DateTime(now.year, now.month - 2);
    String suffix(DateTime d) => '/summary/${d.year}/${d.month}';
    final old = Completer<http.Response>();
    var oldCalls = 0;
    await setUpFakeApi(accountApi: (r) async {
      final p = r.url.path;
      if (p.endsWith(suffix(oldMonth))) {
        if (++oldCalls == 1) return cevap({'totalIncome': 10, 'totalExpense': 0});
        return old.future;
      }
      if (p.endsWith(suffix(latestMonth))) return cevap({'totalIncome': 700, 'totalExpense': 0});
      if (p.contains('/transaction/summary/')) return cevap({'totalIncome': 1000, 'totalExpense': 0});
      return null;
    });
    await tester.pumpWidget(testApp(const DashboardScreen()));
    await settle(tester);
    final left = find.ancestor(of: find.byIcon(LucideIcons.chevronLeft).first,
      matching: find.byType(IconButton));
    final change = tester.widget<IconButton>(left).onPressed!;
    change();
    change();
    await settle(tester);
    expect(find.text(formatTRY(700)), findsWidgets);
    old.complete(cevap({'totalIncome': 9999, 'totalExpense': 0}));
    await settle(tester);
    expect(find.text(formatTRY(700)), findsWidgets);
    expect(find.text(formatTRY(9999)), findsNothing);
    await kapat(tester);
  });

  testWidgets('OzetHatasi_SifirGosterilmez_OncekiDegerKorunur', (tester) async {
    // NEDEN: Hata haritası, eksik alan veya liste bakiyeyi sıfırlamamalı.
    Object summary = {'totalIncome': 1250, 'totalExpense': 50};
    await setUpFakeApi(accountApi: (r) async => r.url.path.contains('/transaction/summary/')
      ? cevap(summary) : null);
    await tester.pumpWidget(testApp(const DashboardScreen()));
    await settle(tester);
    expect(find.text(formatTRY(1200)), findsOneWidget);
    for (final bad in [<String, dynamic>{'error': 'hata'}, <String, dynamic>{}, <dynamic>[]]) {
      summary = bad;
      await pumpUntilDone(tester, tester.widget<RefreshIndicator>(find.byType(RefreshIndicator).first).onRefresh());
      await settle(tester);
      expect(find.text(formatTRY(1200)), findsOneWidget);
      expect(find.text('—'), findsNothing);
    }
    expect(find.text('Veriler yüklenemedi. Tekrar deneyin.'), findsWidgets);
    await kapat(tester);
  });

  for (final profile in [false, true]) {
    testWidgets('IlkAcilistaOzetHatasi_CizgiGosterir_${profile ? 'Profil' : 'AnaSayfa'}', (tester) async {
      // NEDEN: İlk hata sıfır TL veya sıfır işlem anlamına gelmez.
      await setUpFakeApi(accountApi: (r) async => r.url.path.contains('/transaction/summary/')
        ? cevap({'error': 'hata'}) : null);
      await tester.pumpWidget(testApp(profile ? const ProfileScreen() : const DashboardScreen()));
      await settle(tester);
      expect(find.text('—'), findsNWidgets(3));
      expect(find.text('Veriler yüklenemedi. Tekrar deneyin.'), findsOneWidget);
      await kapat(tester);
    });
  }

  testWidgets('KayitSurerkenCikis_DegisiklikBildirilir', (tester) async {
    // NEDEN: Sunucuda başarılı kayıt kapanmış formdan da hesapları yeniletmeli.
    final result = Completer<http.Response>();
    var started = false;
    await setUpFakeApi(categories: [kategori], accountApi: (r) async {
      if (r.method == 'POST' && r.url.path.endsWith('/transaction')) {
        started = true;
        return result.future;
      }
      return null;
    });
    await tester.pumpWidget(testApp(const AddTransactionScreen()));
    await settle(tester);
    await tester.enterText(find.byType(TextField).at(0), '50');
    await tester.enterText(find.byType(TextField).at(1), 'Deneme');
    final dropdown = find.byWidgetPredicate((w) => w is DropdownButton<int>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await settle(tester);
    await tester.tap(find.text('Market').last);
    await settle(tester);
    final save = find.widgetWithText(ElevatedButton, 'Kaydet');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await settle(tester);
    expect(started, isTrue);
    await kapat(tester);
    var notified = 0;
    void listener() => notified++;
    AccountService.changes.addListener(listener);
    result.complete(cevap({'id': 42}));
    await settle(tester);
    AccountService.changes.removeListener(listener);
    expect(notified, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ButceDuzenleme_KurusluLimitKorunur', (tester) async {
    // NEDEN: Değiştirmeden kaydetmek 1250,75 TL tutarını yuvarlamamalı.
    await setUpFakeApi(categories: [kategori], budgetStatus: [butce]);
    await tester.pumpWidget(testApp(const CategoriesScreen()));
    await settle(tester);
    await tester.tap(find.byIcon(LucideIcons.target));
    await settle(tester);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '1250,75');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Kaydet'));
    await settle(tester);
    expect(fakeApiBodies['/api/budget']['monthlyLimit'], 1250.75);
    await kapat(tester);
  });

  testWidgets('ButceKaydiSurerkenCikis_SetStateCagirilmaz', (tester) async {
    // NEDEN: Geç başarı dispose edilmiş kategorileri yeniden yüklememeli.
    final pending = Completer<http.Response>();
    var started = false;
    await setUpFakeApi(categories: [kategori], budgetStatus: [butce], accountApi: (r) async {
      if (r.method == 'POST' && r.url.path.endsWith('/budget')) {
        started = true;
        return pending.future;
      }
      return null;
    });
    await tester.pumpWidget(testApp(const CategoriesScreen()));
    await settle(tester);
    await tester.tap(find.byIcon(LucideIcons.target));
    await settle(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Kaydet'));
    await settle(tester);
    expect(started, isTrue);
    await kapat(tester);
    final requests = fakeApiRequests.length;
    pending.complete(cevap({}));
    await settle(tester);
    expect(fakeApiRequests.length, requests);
    expect(tester.takeException(), isNull);
  });

  testWidgets('BuyukPdf_OkunmadanReddedilir', (tester) async {
    // NEDEN: Büyük PDF metin taraması ve yükleme yapılmadan reddedilmeli.
    await setUpFakeApi();
    final directory = (await tester.runAsync(() => Directory.current.createTemp('pdf_limit_test_')))!;
    final file = File('${directory.path}/buyuk.pdf');
    await tester.runAsync(() async {
      final handle = await file.open(mode: FileMode.write);
      await handle.truncate(ApiService.maxUploadBytes + 1);
      await handle.close();
    });
    try {
      var probes = 0;
      await tester.pumpWidget(testApp(PdfImportScreen(initialFilePath: file.path, textProbe: (_) async {
        probes++;
        return true;
      })));
      await settle(tester);
      await analyzeSelectedFile(tester);
      expect(probes, 0);
      expect(fakeApiRequests.where((u) => u.path.endsWith('/pdfimport/parse')), isEmpty);
      expect(find.text('Dosya çok büyük (en fazla 15 MB).'), findsOneWidget);
      await kapat(tester);
    } finally {
      await tester.runAsync(() => directory.delete(recursive: true));
    }
  });

  testWidgets('OncekiAyOzetHatasi_YalnizKarsilastirmaGizlenir', (tester) async {
    // NEDEN: Önceki ay okunamasa da güncel ayın geçerli parası gösterilmeli.
    final now = DateTime.now();
    final currentPath = '/summary/${now.year}/${now.month}';
    await setUpFakeApi(accountApi: (r) async {
      if (!r.url.path.contains('/transaction/summary/')) return null;
      return cevap(r.url.path.endsWith(currentPath)
        ? {'totalIncome': 1500, 'totalExpense': 200} : {'error': 'hata'});
    });
    await tester.pumpWidget(testApp(const DashboardScreen()));
    await settle(tester);
    expect(find.text(formatTRY(1300)), findsOneWidget);
    expect(find.textContaining('% geçen aya göre'), findsNothing);
    expect(find.text('Veriler yüklenemedi. Tekrar deneyin.'), findsNothing);
    await kapat(tester);
  });

  testWidgets('DuzenlemeSurerkenCikis_DegisiklikBildirilir', (tester) async {
    // NEDEN: Kapanan düzenleme sayfasının sunucu başarısı da hesaplara ulaşmalı.
    final pending = Completer<http.Response>();
    var started = false;
    await setUpFakeApi(categories: [kategori], transactions: [{
      'id': 10, 'amount': 50, 'description': 'Deneme', 'type': 2,
      'categoryId': 2, 'transactionDate': '2026-11-01T00:00:00',
    }], accountApi: (r) async {
      if (r.method == 'PUT' && r.url.path.endsWith('/transaction/10')) {
        started = true;
        return pending.future;
      }
      return null;
    });
    await tester.pumpWidget(testApp(const TransactionsScreen()));
    await settle(tester);
    await tester.tap(find.byType(TransactionCard).first);
    await settle(tester);
    final update = find.widgetWithText(ElevatedButton, 'Güncelle');
    await tester.ensureVisible(update);
    await tester.tap(update);
    await settle(tester);
    expect(started, isTrue);
    await kapat(tester);
    final before = AccountService.changes.value;
    pending.complete(cevap({'id': 10}));
    await settle(tester);
    expect(AccountService.changes.value, before + 1);
    expect(tester.takeException(), isNull);
  });

}
