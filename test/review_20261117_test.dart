import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:smartfinance_mobile/core/utils/formatters.dart';
import 'package:smartfinance_mobile/screens/dashboard_screen.dart';
import 'package:smartfinance_mobile/services/account_service.dart';
import 'package:smartfinance_mobile/services/amount_privacy.dart';
import 'package:smartfinance_mobile/services/transaction_trash.dart';
import 'package:smartfinance_mobile/widgets/transaction_card.dart';

import 'helpers/test_app.dart';

const hataMetni = 'Veriler yüklenemedi. Tekrar deneyin.';
http.Response yanit(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});
http.Response hata() => yanit({'error': 'Sunucuya ulaşılamadı'});

Future<void> kapat(WidgetTester tester) async {
  // Kartların mevcut tek otomatik yeniden deneme zamanlayıcısını tüket.
  await tester.pump(const Duration(seconds: 3));
  await settle(tester);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  setUp(() => AmountPrivacy.gizli.value = false);
  tearDown(tearDownFakeApi);

  testWidgets('SunucuHatasi_AdVeSonIslemlerKorunur', (tester) async {
    // NEDEN: Hata haritası kullanıcı verisinin silindiği izlenimi vermemeli.
    var hataVar = false;
    await setUpFakeApi(
      categories: [{'id': 2, 'name': 'Market', 'type': 2}],
      transactions: [
        {'id': 1, 'description': 'Haftalık alışveriş', 'amount': 50,
          'categoryId': 2, 'type': 2},
        {'id': 2, 'description': 'İkinci işlem', 'amount': 20, 'type': 2},
      ],
      categorySummary: [
        {'categoryId': 2, 'categoryName': 'Market', 'total': 50},
      ],
      accountApi: (r) async {
        if (hataVar) return hata();
        if (r.url.path.endsWith('/auth/me')) {
          return yanit({'fullName': 'Deneme  Kullanici'});
        }
        if (r.url.path.endsWith('/notification/unread-count')) {
          return yanit({'count': 3});
        }
        return null;
      },
    );
    await tester.pumpWidget(testApp(const DashboardScreen()));
    await settle(tester);
    expect(find.byType(TransactionCard), findsNWidgets(2));
    hataVar = true;
    await pumpUntilDone(tester,
        tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh());
    await settle(tester);
    expect(find.text('Deneme  Kullanici'), findsOneWidget);
    expect(find.text('DK'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Kategoriye Göre Harcama'), findsOneWidget);
    expect(find.text('Haftalık alışveriş'), findsOneWidget);
    expect(find.text('İkinci işlem'), findsOneWidget);
    expect(tester.widget<TransactionCard>(find.byType(TransactionCard).first)
        .categoryName, 'Market');
    expect(find.textContaining('Henüz işlem yok'), findsNothing);
    expect(find.text(hataMetni), findsOneWidget);
    await kapat(tester);
  });

  testWidgets('IlkAcilistaIslemHatasi_HenuzIslemYokYazmaz', (tester) async {
    // NEDEN: Özet başarılı olsa bile işlem hatası boş liste anlamına gelmez.
    await setUpFakeApi(accountApi: (r) async =>
        r.url.path.endsWith('/transaction/filter') ? hata() : null);
    await tester.pumpWidget(testApp(const DashboardScreen()));
    await settle(tester);
    expect(find.text('İşlemler yüklenemedi'), findsOneWidget);
    expect(find.textContaining('Henüz işlem yok'), findsNothing);
    expect(find.text(hataMetni), findsOneWidget);
    await kapat(tester);
  });

  testWidgets('YenilemeSirasindaDinleyiciTetiklenirse_HataSnackBarYineGorunur',
      (tester) async {
    // NEDEN: Dinleyici devam eden yenilemeyi geçersiz kılıp hatayı yutmamalı;
    // gerçek ekrandaki dış Scaffold/alt menü altında da mesaj görünmeli.
    final bekleyen = Completer<http.Response>();
    var beklet = false;
    await setUpFakeApi(accountApi: (r) async => beklet ? bekleyen.future : null);
    await tester.pumpWidget(testApp(const Scaffold(
      body: DashboardScreen(),
      bottomNavigationBar: SizedBox(height: 80),
    )));
    await settle(tester);
    beklet = true;
    final yenileme = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator)).onRefresh();
    await settle(tester, frames: 2);
    final onceki = fakeApiRequests.where((r) => r.path.endsWith('/auth/me')).length;
    AccountService.notifyChanged();
    TransactionTrash.changes.value++;
    await settle(tester, frames: 2);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    expect(fakeApiRequests.where((r) => r.path.endsWith('/auth/me')).length, onceki);
    bekleyen.complete(hata());
    await pumpUntilDone(tester, yenileme);
    await settle(tester, frames: 6);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text(hataMetni), findsOneWidget);
    final mesaj = tester.getRect(find.text(hataMetni));
    expect(mesaj.top, greaterThanOrEqualTo(0));
    expect(mesaj.bottom, lessThanOrEqualTo(tester.view.physicalSize.height /
        tester.view.devicePixelRatio));
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    expect(find.byType(SnackBar), findsNothing);
    await kapat(tester);
  });

  testWidgets('IlkYuklemedeDinleyici_HataBildirimiKorunur', (tester) async {
    // NEDEN: İlk açılış hatası da araya giren dinleyici yüzünden kaybolmamalı.
    final bekleyen = Completer<http.Response>();
    await setUpFakeApi(accountApi: (_) async => bekleyen.future);
    await tester.pumpWidget(testApp(const DashboardScreen()));
    await settle(tester, frames: 2);
    TransactionTrash.changes.value++;
    await settle(tester, frames: 2);
    expect(fakeApiRequests.where((r) => r.path.endsWith('/auth/me')).length, 1);
    bekleyen.complete(hata());
    await settle(tester);
    expect(find.text(hataMetni), findsOneWidget);
    expect(find.text('İşlemler yüklenemedi'), findsOneWidget);
    await kapat(tester);
  });

  testWidgets('YuklemeSurerkenDegisiklik_YeniVeriGosterilir', (tester) async {
    // NEDEN: Yükleme sürerken kullanıcı işlem ekler/silerse bekleyen istek
    // eski yanıtla yetinmemeli; tamamlanınca tek yeni yüklemeyle güncel tutarı getirmeli.
    final now = DateTime.now();
    final buAyYolu = '/transaction/summary/${now.year}/${now.month}';
    final ilkOzet = Completer<http.Response>();
    var beklet = false;
    var ozetSayisi = 0;

    await setUpFakeApi(accountApi: (r) async {
      if (!beklet || !r.url.path.endsWith(buAyYolu)) return null;
      ozetSayisi++;
      if (ozetSayisi == 1) return ilkOzet.future;
      return yanit({'totalIncome': 250, 'totalExpense': 0, 'transactionCount': 1});
    });

    await tester.pumpWidget(testApp(const DashboardScreen()));
    await settle(tester);

    beklet = true;
    final yenileme = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await settle(tester, frames: 2);
    expect(ozetSayisi, 1);

    TransactionTrash.changes.value++;
    await settle(tester, frames: 2);
    expect(ozetSayisi, 1);

    ilkOzet.complete(
      yanit({'totalIncome': 100, 'totalExpense': 0, 'transactionCount': 1}),
    );
    await pumpUntilDone(tester, yenileme);
    await settle(tester);

    expect(ozetSayisi, 2);
    expect(find.text(formatTRY(250)), findsWidgets);
    expect(find.text(formatTRY(100)), findsNothing);
    await kapat(tester);
  });

  testWidgets('YuklemeSurerkenUcDegisiklik_TekEkYukleme', (tester) async {
    // NEDEN: Yükleme sürerken art arda gelen birden fazla değişiklik bildirimi
    // N ayrı yükleme ya da döngü yerine tek bir birleşik ek yüklemeye düşmeli.
    final now = DateTime.now();
    final buAyYolu = '/transaction/summary/${now.year}/${now.month}';
    final ilkOzet = Completer<http.Response>();
    var beklet = false;
    var ozetSayisi = 0;

    await setUpFakeApi(accountApi: (r) async {
      if (!beklet || !r.url.path.endsWith(buAyYolu)) return null;
      ozetSayisi++;
      if (ozetSayisi == 1) return ilkOzet.future;
      return yanit({'totalIncome': 250, 'totalExpense': 0, 'transactionCount': 1});
    });

    await tester.pumpWidget(testApp(const DashboardScreen()));
    await settle(tester);

    beklet = true;
    final yenileme = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await settle(tester, frames: 2);
    expect(ozetSayisi, 1);

    for (var i = 0; i < 3; i++) {
      TransactionTrash.changes.value++;
      await settle(tester, frames: 1);
    }
    expect(ozetSayisi, 1);

    ilkOzet.complete(
      yanit({'totalIncome': 100, 'totalExpense': 0, 'transactionCount': 1}),
    );
    await pumpUntilDone(tester, yenileme);
    await settle(tester);

    expect(ozetSayisi, 2);
    expect(find.text(formatTRY(250)), findsWidgets);
    await kapat(tester);
  });

  testWidgets('AyDegisinceOzetHatasi_OncekiAyinRakamiGosterilmez',
      (tester) async {
    // NEDEN: 429 veya sunucu hatasında önceki ayın rakamları yeni ayın
    // başlığı altında gösterilmemeli; yanlış para bilgisi riskini önler.
    final now = DateTime.now();
    final oncekiAy = DateTime(now.year, now.month - 1);
    final buAyYolu = '/transaction/summary/${now.year}/${now.month}';
    final oncekiAyYolu =
        '/transaction/summary/${oncekiAy.year}/${oncekiAy.month}';
    final oncekiAyBaslik = DateFormat('MMMM yyyy', 'tr_TR').format(oncekiAy);

    await setUpFakeApi(
      accountApi: (r) async {
        if (r.url.path.endsWith(buAyYolu)) {
          return yanit(
              {'totalIncome': 1200, 'totalExpense': 500, 'transactionCount': 2});
        }
        if (r.url.path.endsWith(oncekiAyYolu)) {
          return hata();
        }
        return null;
      },
    );
    await tester.pumpWidget(testApp(const DashboardScreen()));
    await settle(tester);

    expect(find.text(formatTRY(500)), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.chevronLeft));
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);

    expect(find.text(oncekiAyBaslik), findsOneWidget);
    expect(find.text(formatTRY(500)), findsNothing);
    expect(find.text('—'), findsNWidgets(3));
    expect(find.text(hataMetni), findsOneWidget);
    await kapat(tester);
  });

  testWidgets('AynıAyYenilemeHatasi_RakamlarKorunur', (tester) async {
    // NEDEN: Aynı ay yenilenirken geçici sunucu hatası olursa kullanıcının
    // zaten gördüğü o aya ait rakamlar korunmalı.
    var hataVar = false;
    final now = DateTime.now();
    final buAyYolu = '/transaction/summary/${now.year}/${now.month}';

    await setUpFakeApi(
      accountApi: (r) async {
        if (hataVar) return hata();
        if (r.url.path.endsWith(buAyYolu)) {
          return yanit(
              {'totalIncome': 1200, 'totalExpense': 500, 'transactionCount': 2});
        }
        return null;
      },
    );
    await tester.pumpWidget(testApp(const DashboardScreen()));
    await settle(tester);

    expect(find.text(formatTRY(500)), findsOneWidget);

    hataVar = true;
    await pumpUntilDone(
      tester,
      tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh(),
    );
    await settle(tester);

    expect(find.text(formatTRY(500)), findsOneWidget);
    expect(find.text('—'), findsNothing);
    expect(find.text(hataMetni), findsOneWidget);
    await kapat(tester);
  });

  testWidgets('HizliAyDegisimi_YalnizSonAyYuklenir', (tester) async {
    // NEDEN: Hızlı ay okuna basıldığında her ara ay için istek atmak sunucu
    // hız sınırını (429) tetikler; debounce yalnız son seçilen ayı yüklemeli.
    final now = DateTime.now();
    final sonAy = DateTime(now.year, now.month - 5);

    await setUpFakeApi();
    await tester.pumpWidget(testApp(const DashboardScreen()));
    await settle(tester);

    fakeApiRequests.clear();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byIcon(LucideIcons.chevronLeft));
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(
      fakeApiRequests.where((u) => u.path.contains('/transaction/summary/')),
      isEmpty,
    );

    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);

    final ozetIstekleri = fakeApiRequests
        .where((u) => u.path.contains('/transaction/summary/'))
        .toList();
    expect(
      ozetIstekleri.where(
        (u) =>
            u.path.endsWith('/transaction/summary/${sonAy.year}/${sonAy.month}'),
      ),
      hasLength(1),
    );
    expect(ozetIstekleri, hasLength(2));
    await kapat(tester);
  });

  testWidgets('AyDegisimi_StatikUclariCagirmaz', (tester) async {
    // NEDEN: Profil, kategoriler ve bildirim sayısı aya bağlı değildir;
    // ay değişiminde tekrar çağrılmamalı, yalnız yenilemede güncellenmelidir.
    await setUpFakeApi();
    await tester.pumpWidget(testApp(const DashboardScreen()));
    await settle(tester);

    final meIlk = fakeApiRequests.where((u) => u.path.endsWith('/auth/me')).length;
    final catIlk =
        fakeApiRequests.where((u) => u.path.endsWith('/category')).length;
    final unreadIlk = fakeApiRequests
        .where((u) => u.path.endsWith('/notification/unread-count'))
        .length;
    expect(meIlk, 1);
    expect(catIlk, 1);
    expect(unreadIlk, 1);

    await tester.tap(find.byIcon(LucideIcons.chevronLeft));
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);

    expect(
      fakeApiRequests.where((u) => u.path.endsWith('/auth/me')).length,
      meIlk,
    );
    expect(
      fakeApiRequests.where((u) => u.path.endsWith('/category')).length,
      catIlk,
    );
    expect(
      fakeApiRequests
          .where((u) => u.path.endsWith('/notification/unread-count'))
          .length,
      unreadIlk,
    );

    await pumpUntilDone(
      tester,
      tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh(),
    );
    await settle(tester);

    expect(
      fakeApiRequests.where((u) => u.path.endsWith('/auth/me')).length,
      meIlk + 1,
    );
    expect(
      fakeApiRequests.where((u) => u.path.endsWith('/category')).length,
      catIlk + 1,
    );
    expect(
      fakeApiRequests
          .where((u) => u.path.endsWith('/notification/unread-count'))
          .length,
      unreadIlk + 1,
    );
    await kapat(tester);
  });
}
