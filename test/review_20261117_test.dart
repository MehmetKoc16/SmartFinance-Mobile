import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
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
}
