import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:smartfinance_mobile/models/recurring_payment.dart';
import 'package:smartfinance_mobile/screens/recurring_payments_screen.dart';
import 'package:smartfinance_mobile/screens/recurring_payment_edit_screen.dart';
import 'package:smartfinance_mobile/screens/dashboard_screen.dart';
import 'package:smartfinance_mobile/screens/main_screen.dart';
import 'package:smartfinance_mobile/screens/notifications_screen.dart';
import 'package:smartfinance_mobile/screens/premium_screen.dart';
import 'package:smartfinance_mobile/services/amount_privacy.dart';
import 'package:smartfinance_mobile/services/billing_service.dart';
import 'package:smartfinance_mobile/services/recurring_payment_service.dart';
import 'package:smartfinance_mobile/services/account_service.dart';
import 'package:smartfinance_mobile/core/utils/formatters.dart';
import 'package:smartfinance_mobile/core/theme/app_theme.dart';
import 'package:smartfinance_mobile/screens/profile_screen.dart';
import 'package:smartfinance_mobile/services/transaction_trash.dart';
import 'package:smartfinance_mobile/widgets/upcoming_payments_card.dart';
import 'helpers/test_app.dart';
import 'helpers/test_store_gateway.dart';

Map<String, dynamic> plan({
  int id = 1,
  String status = 'today',
  int days = 0,
}) => {
  'id': id,
  'name': 'Deneme Dijital Abonelik $id',
  'amount': 123.45,
  'type': 2,
  'categoryId': 7,
  'accountId': 4,
  'frequency': 2,
  'startDate': '2026-10-15',
  'anchorDay': 15,
  'nextDueDate': '2026-10-19',
  'endDate': '2027-10-15',
  'remindDaysBefore': 1,
  'isActive': status != 'ended',
  'daysUntil': days,
  'status': status,
};
Map<String, dynamic> upcomingItem(int id, String status, String date) => {
  'recurringPaymentId': id,
  'name': 'Deneme vade $id',
  'amount': 123.45,
  'type': 2,
  'categoryId': null,
  'accountId': null,
  'dueDate': date,
  'status': status,
};
http.Response reply(Object body, [int status = 200]) => http.Response(
  status == 204 ? '' : jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Future<void> setup({
  List<Map<String, dynamic>>? plans,
  int saveStatus = 201,
  int payStatus = 200,
  int skipStatus = 200,
  Object? upcoming,
  int upcomingStatus = 200,
  List<http.Request>? requests,
}) => setUpFakeApi(
  categories: [
    {'id': 7, 'name': 'Deneme gider kategorisi', 'type': 2},
    {'id': 8, 'name': 'Deneme gelir kategorisi', 'type': 1},
  ],
  accountApi: (r) async => r.url.path == '/api/account'
      ? reply([
          {
            'id': 4,
            'name': 'Deneme hesap',
            'type': 2,
            'openingBalance': 0,
            'balance': 0,
            'isArchived': false,
            'sortOrder': 0,
          },
          {
            'id': 5,
            'name': 'Deneme arşiv',
            'type': 2,
            'openingBalance': 0,
            'balance': 0,
            'isArchived': true,
            'sortOrder': 1,
          },
        ])
      : null,
  recurringApi: (r) async {
    requests?.add(r);
    final p = r.url.path;
    if (p == '/api/notification') {
      return reply([
        {
          'id': 1,
          'type': 3,
          'title': 'Deneme hatırlatma',
          'message': 'Deneme',
          'isRead': true,
          'createdDate': '2026-10-19T09:00:00Z',
        },
      ]);
    }
    if (p == '/api/recurring/upcoming') {
      return reply(
        upcoming ?? {'items': [], 'expenseTotal': 0, 'incomeTotal': 0},
        upcomingStatus,
      );
    }
    if (!p.startsWith('/api/recurring')) return null;
    if (r.method == 'GET') return reply(plans ?? [plan()]);
    if (p.endsWith('/pay')) {
      return reply(
        payStatus == 409
            ? {'message': 'Deneme çakışma'}
            : {
                'transaction': {'id': 11},
                'recurringPayment': plan(),
              },
        payStatus,
      );
    }
    if (p.endsWith('/skip')) {
      return reply(
        skipStatus == 409 ? {'message': 'Deneme çakışma'} : plan(),
        skipStatus,
      );
    }
    if (r.method == 'DELETE') return reply({}, 204);
    return reply(
      saveStatus >= 400 ? {'message': 'Deneme sunucu mesajı'} : plan(),
      r.method == 'PUT' && saveStatus == 201 ? 200 : saveStatus,
    );
  },
);
Future<void> tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await settle(tester);
}

Future<void> open(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(
    testApp(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => screen),
            ),
            child: const Text('Aç'),
          ),
        ),
      ),
    ),
  );
  await tap(tester, find.text('Aç'));
}

Future<void> fill(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('recurring-name')),
    'Deneme plan',
  );
  await tester.enterText(find.byKey(const Key('recurring-amount')), '123,45');
}

void main() {
  setUp(() {
    AmountPrivacy.gizli.value = false;
    BillingService.gateway = TestStoreGateway();
  });
  tearDown(() async {
    await BillingService.resetForTest();
    tearDownFakeApi();
    AmountPrivacy.gizli.value = false;
  });

  // NEDEN: Durum sunucudan gelir; bitmiş kayıt tarihine göre yeniden yorumlanmamalı.
  testWidgets('PlanliListe_DurumRozetleri', (tester) async {
    await setup(
      plans: [
        plan(status: 'overdue', days: -2),
        plan(id: 2),
        plan(id: 3, status: 'upcoming', days: 1),
        plan(id: 4, status: 'upcoming', days: 5),
        plan(id: 5, status: 'ended'),
      ],
    );
    await open(tester, const RecurringPaymentsScreen());
    for (final label in [
      'Gecikti',
      'Bugün',
      'Yarın',
      '5 gün sonra',
      'Sona erdi',
    ]) {
      await tester.scrollUntilVisible(find.text(label), 180);
      expect(find.text(label), findsOneWidget);
    }
    await tap(tester, find.text('Deneme Dijital Abonelik 5'));
    expect(find.text('Bu vadeyi atla'), findsNothing);
    expect(find.text('Ödendi olarak işaretle'), findsNothing);
    expect(find.text('Düzenle'), findsOneWidget);
  });
  // NEDEN: İlk kullanımdaki davet doğrudan plan eklemeye götürmeli.
  testWidgets('PlanliListe_BosDurumDaveti', (tester) async {
    await setup(plans: []);
    await open(tester, const RecurringPaymentsScreen());
    expect(
      find.text(
        'Abonelik, kira, fatura gibi düzenli ödemelerini ekle — günü gelince hatırlatalım.',
      ),
      findsOneWidget,
    );
    await tap(tester, find.text('Planlı ödeme ekle'));
    expect(find.byType(RecurringPaymentEditScreen), findsOneWidget);
  });
  // NEDEN: Vade günü planın nextDueDate alanı olmalı; varsayılan hesap ve bakiye yenilenmeli.
  testWidgets('PlanliOde_VarsayilanTutarVeHesap_DogruGovde', (tester) async {
    await setup();
    await open(tester, const RecurringPaymentsScreen());
    await tap(tester, find.text('Deneme Dijital Abonelik 1'));
    await tap(tester, find.text('Ödendi olarak işaretle'));
    expect(find.text('Deneme hesap'), findsOneWidget);
    expect(find.text('Deneme arşiv'), findsNothing);
    final before = AccountService.changes.value;
    await tap(tester, find.text('Onayla'));
    final b = fakeApiBodies['/api/recurring/1/pay'] as Map;
    expect(b['dueDate'], '2026-10-19');
    expect(b['amount'], 123.45);
    expect(b['accountId'], 4);
    expect(DateTime.parse(b['transactionDate'] as String).isUtc, isTrue);
    expect(AccountService.changes.value, greaterThan(before));
    expect(find.text('İşlem eklendi'), findsOneWidget);
  });
  // NEDEN: Çift ödeme 409 döner; kullanıcı bilgilendirilirken güncel vade alınmalı.
  testWidgets('PlanliOde_409_MesajVeYenileme', (tester) async {
    await setup(payStatus: 409);
    await open(tester, const RecurringPaymentsScreen());
    final before = fakeApiRequests
        .where((u) => u.path == '/api/recurring')
        .length;
    await tap(tester, find.text('Deneme Dijital Abonelik 1'));
    await tap(tester, find.text('Ödendi olarak işaretle'));
    await tap(tester, find.text('Onayla'));
    expect(find.text('Bu vade zaten işlendi.'), findsOneWidget);
    expect(
      fakeApiRequests.where((u) => u.path == '/api/recurring').length,
      greaterThan(before),
    );
  });
  // NEDEN: Atlamak işlem üretmeden, yalnız onaydan sonra aynı vadeyi tüketmeli.
  testWidgets('PlanliAtla_OnaylaninceSkipCagrilir', (tester) async {
    await setup();
    await open(tester, const RecurringPaymentsScreen());
    await tap(tester, find.text('Deneme Dijital Abonelik 1'));
    await tap(tester, find.text('Bu vadeyi atla'));
    expect(fakeApiBodies.containsKey('/api/recurring/1/skip'), isFalse);
    expect(
      find.text('19.10.2026 vadesi atlansın mı? İşlem eklenmez.'),
      findsOneWidget,
    );
    await tap(tester, find.text('Atla'));
    expect(fakeApiBodies['/api/recurring/1/skip'], {'dueDate': '2026-10-19'});
  });
  // NEDEN: Tür değiştiğinde gider kategorisi gelir planına taşınmamalı.
  testWidgets('PlanliEkle_TurGelirken_YalnizGelirKategorileri', (tester) async {
    await setup();
    await open(tester, const RecurringPaymentEditScreen());
    await tap(tester, find.text('Gelir'));
    await tap(tester, find.byKey(const Key('recurring-category')));
    expect(find.text('Deneme gelir kategorisi'), findsOneWidget);
    expect(find.text('Deneme gider kategorisi'), findsNothing);
  });
  // NEDEN: Ücretsiz sınır sunucudadır; 402 mevcut Premium ekranına yönlendirmeli.
  testWidgets('PlanliEkle_402_PremiumYonlendirir', (tester) async {
    await setup(saveStatus: 402);
    await open(tester, const RecurringPaymentEditScreen());
    await fill(tester);
    await tap(tester, find.text('Kaydet'));
    expect(find.byType(PremiumScreen), findsOneWidget);
  });
  // NEDEN: Sunucunun doğrulama açıklaması formda kaybolmadan görünmeli.
  testWidgets('PlanliEkle_400_SunucuMesajiGorunur', (tester) async {
    await setup(saveStatus: 400);
    await open(tester, const RecurringPaymentEditScreen());
    await fill(tester);
    await tap(tester, find.text('Kaydet'));
    expect(find.text('Deneme sunucu mesajı'), findsOneWidget);
    expect(find.byType(RecurringPaymentEditScreen), findsOneWidget);
  });
  // NEDEN: PUT tam güncellemedir; DateOnly alanlarında UTC dönüşümü gün kaydırmamalı.
  testWidgets('PlanliDuzenle_AlanlarDolu_PutGovdesi', (tester) async {
    final requests = <http.Request>[];
    await setup(requests: requests);
    await open(
      tester,
      RecurringPaymentEditScreen(payment: RecurringPayment.fromJson(plan())),
    );
    expect(find.text('Deneme Dijital Abonelik 1'), findsOneWidget);
    expect(find.text('Deneme gider kategorisi'), findsOneWidget);
    expect(find.text('Deneme hesap'), findsOneWidget);
    await tap(tester, find.text('Kaydet'));
    expect(
      requests.singleWhere((r) => r.url.path == '/api/recurring/1').method,
      'PUT',
    );
    expect(fakeApiBodies['/api/recurring/1'], {
      'name': 'Deneme Dijital Abonelik 1',
      'amount': 123.45,
      'type': 2,
      'categoryId': 7,
      'accountId': 4,
      'frequency': 2,
      'startDate': '2026-10-15',
      'endDate': '2027-10-15',
      'remindDaysBefore': 1,
    });
  });
  // NEDEN: Ana sayfa üç vadeyi ve sunucu toplamını gösterir; gecikmiş önce gelmeli.
  testWidgets('AnaSayfa_YaklasanOdemeler_GecikmisOnce_VeToplam', (
    tester,
  ) async {
    await setup(
      upcoming: {
        'items': [
          upcomingItem(2, 'upcoming', '2026-10-21'),
          upcomingItem(1, 'overdue', '2026-10-18'),
          upcomingItem(3, 'today', '2026-10-19'),
          upcomingItem(4, 'upcoming', '2026-10-22'),
        ],
        'expenseTotal': 493.8,
        'incomeTotal': 0,
      },
    );
    await tester.pumpWidget(testApp(const DashboardScreen()));
    await settle(tester);
    await tester.ensureVisible(find.byType(UpcomingPaymentsCard));
    expect(find.text('30 günde ${formatTRY(493.8)}'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Deneme vade 1')).dy,
      lessThan(tester.getTopLeft(find.text('Deneme vade 3')).dy),
    );
    expect(find.text('Deneme vade 4'), findsNothing);
    expect(find.text('Gecikti'), findsOneWidget);
  });
  // NEDEN: Hiç planı olmayan kullanıcı davetten doğrudan ekleme ekranına ulaşmalı.
  testWidgets('AnaSayfa_PlanliYoksa_DavetSatiri', (tester) async {
    await setup(plans: []);
    await tester.pumpWidget(testApp(const UpcomingPaymentsCard()));
    await settle(tester);
    await tap(
      tester,
      find.text('Düzenli ödemelerini ekle, günü gelince hatırlatalım'),
    );
    expect(find.byType(RecurringPaymentEditScreen), findsOneWidget);
  });
  // NEDEN: Ek kartın hatası ana sayfayı kapatmamalı.
  testWidgets('AnaSayfa_YaklasanYuklenemezse_KartGizli', (tester) async {
    await setup(upcoming: {'message': 'Deneme hata'}, upcomingStatus: 500);
    await tester.pumpWidget(testApp(const UpcomingPaymentsCard()));
    await settle(tester);
    expect(find.text('Yaklaşan ödemeler'), findsNothing);
    expect(
      find.text('Düzenli ödemelerini ekle, günü gelince hatırlatalım'),
      findsNothing,
    );
  });
  // NEDEN: Hem satır hem toplam gizlilik değişikliğine yeniden çizilerek uymalı.
  testWidgets('AnaSayfa_TutarlarGizliyken_YaklasanTutarGizli', (tester) async {
    await setup(
      upcoming: {
        'items': [upcomingItem(1, 'today', '2026-10-19')],
        'expenseTotal': 123.45,
        'incomeTotal': 0,
      },
    );
    await tester.pumpWidget(testApp(const UpcomingPaymentsCard()));
    await settle(tester);
    AmountPrivacy.gizli.value = true;
    await tester.pump();
    expect(find.textContaining('123,45'), findsNothing);
    expect(find.text('30 günde ${formatTRY(123.45)}'), findsOneWidget);
  });
  // NEDEN: Sunucudan gelen type=3 planlı ödeme hatırlatması olarak ayırt edilmeli.
  testWidgets('Bildirim_Tur3_TakvimIkonu', (tester) async {
    await setup();
    await tester.pumpWidget(testApp(const NotificationsScreen()));
    await settle(tester);
    expect(find.byIcon(LucideIcons.calendar), findsOneWidget);
  });
  // NEDEN: Ortak ekle menüsünden yeni akış erişilebilir olmalı.
  testWidgets('ArtiMenusu_PlanliOdemeEkleGirisi', (tester) async {
    await setup();
    await tester.pumpWidget(testApp(const MainScreen()));
    await settle(tester);
    await pumpUntilDone(tester, BillingService().stopAppWide());
    await tap(tester, find.byIcon(LucideIcons.plus).last);
    expect(find.text('Abonelik, kira, fatura'), findsOneWidget);
    await tap(tester, find.text('Planlı ödeme ekle'));
    expect(find.byType(RecurringPaymentEditScreen), findsOneWidget);
  });
  // NEDEN: Gövdesiz DELETE ve servis bildirimleri tüm giriş noktalarında aynı davranmalı.
  test('PlanliServis_SilmeGovdesiz_Bildirim', () async {
    await setup();
    final before = RecurringPaymentService.changes.value;
    await RecurringPaymentService.delete(1);
    expect(RecurringPaymentService.changes.value, before + 1);
    expect(fakeApiBodies.containsKey('/api/recurring/1'), isFalse);
  });

  // NEDEN: Tüm tipli uçlar sözleşme alanlarını korumalı; DateOnly ve işlem UTC'si ayrı yazılmalı.
  test('PlanliServis_TumUclar_SozlesmeVeUtc', () async {
    await setup(
      upcoming: {
        'items': [upcomingItem(1, 'today', '2026-10-19')],
        'expenseTotal': 123.45,
        'incomeTotal': 0,
      },
    );
    final listed = await RecurringPaymentService.list();
    expect(listed.single.anchorDay, 15);
    expect(listed.single.endDate, DateTime(2027, 10, 15));
    final window = await RecurringPaymentService.upcoming(days: 30);
    expect(window.items.single.recurringPaymentId, 1);
    expect(window.expenseTotal, 123.45);
    expect(window.incomeTotal, 0);
    expect(
      fakeApiRequests.any(
        (u) => u.path == '/api/recurring/upcoming' && u.query == 'days=30',
      ),
      isTrue,
    );
    final created = await RecurringPaymentService.save(
      name: 'Deneme plan',
      amount: 123.45,
      type: 1,
      frequency: 1,
      startDate: DateTime(2026, 10, 19),
    );
    expect(created.id, 1);
    expect(fakeApiBodies['/api/recurring'], {
      'name': 'Deneme plan',
      'amount': 123.45,
      'type': 1,
      'categoryId': null,
      'accountId': null,
      'frequency': 1,
      'startDate': '2026-10-19',
      'endDate': null,
      'remindDaysBefore': 1,
    });
    final before = TransactionTrash.changes.value;
    final result = await RecurringPaymentService.pay(
      1,
      dueDate: DateTime(2026, 10, 19),
      amount: 127.45,
      accountId: 4,
      transactionDate: DateTime(2026, 10, 19, 13, 24),
      description: 'Deneme açıklama',
    );
    expect(result.transaction['id'], 11);
    expect(result.recurringPayment.id, 1);
    final b = fakeApiBodies['/api/recurring/1/pay'] as Map;
    expect(b['dueDate'], '2026-10-19');
    expect(
      b['transactionDate'],
      DateTime(2026, 10, 19, 13, 24).toUtc().toIso8601String(),
    );
    expect(b['amount'], 127.45);
    expect(b['description'], 'Deneme açıklama');
    expect(TransactionTrash.changes.value, before + 1);
    expect(
      (await RecurringPaymentService.skip(
        1,
        dueDate: DateTime(2026, 10, 19),
      )).id,
      1,
    );
  });
  // NEDEN: Skip de eşzamanlı vade işleme yarışına girer; 409 ödeme ile aynı ele alınmalı.
  testWidgets('PlanliAtla_409_MesajVeYenileme', (tester) async {
    await setup(skipStatus: 409);
    await open(tester, const RecurringPaymentsScreen());
    final before = fakeApiRequests
        .where((u) => u.path == '/api/recurring')
        .length;
    await tap(tester, find.text('Deneme Dijital Abonelik 1'));
    await tap(tester, find.text('Bu vadeyi atla'));
    await tap(tester, find.text('Atla'));
    expect(find.text('Bu vade zaten işlendi.'), findsOneWidget);
    expect(
      fakeApiRequests.where((u) => u.path == '/api/recurring').length,
      greaterThan(before),
    );
    expect(fakeApiBodies.containsKey('/api/recurring/1/pay'), isFalse);
  });
  // NEDEN: Boş 30 günlük pencere, ileri tarihli veya sona ermiş planların yokluğu anlamına gelmez.
  testWidgets('AnaSayfa_PencereBos_PlanVarsaBosVadeMetni', (tester) async {
    await setup();
    await tester.pumpWidget(testApp(const UpcomingPaymentsCard()));
    await settle(tester);
    expect(find.text('Önümüzdeki 30 günde ödeme yok.'), findsOneWidget);
    expect(
      find.text('Düzenli ödemelerini ekle, günü gelince hatırlatalım'),
      findsNothing,
    );
    await tap(tester, find.text('Tümünü gör'));
    expect(find.byType(RecurringPaymentsScreen), findsOneWidget);
  });
  // NEDEN: Pay/skip ve çöp kutusu hareketlerinden sonra ana sayfa güncel vadeleri tekrar almalı.
  testWidgets('AnaSayfa_YaklasanDegisiklikleri_Dinler', (tester) async {
    await setup();
    await tester.pumpWidget(testApp(const UpcomingPaymentsCard()));
    await settle(tester);
    int requests() => fakeApiRequests
        .where((u) => u.path == '/api/recurring/upcoming')
        .length;
    final initial = requests();
    RecurringPaymentService.notifyChanged();
    await settle(tester);
    expect(requests(), initial + 1);
    TransactionTrash.changes.value++;
    await settle(tester);
    expect(requests(), initial + 2);
  });
  // NEDEN: Hesap seçicisi açıldığında bile arşivlenmiş hesap seçeneği sunulmamalı.
  testWidgets('PlanliOde_ArsivliHesapSecilemez_TutarDuzenlenir', (
    tester,
  ) async {
    await setup();
    await open(tester, const RecurringPaymentsScreen());
    await tap(tester, find.text('Deneme Dijital Abonelik 1'));
    await tap(tester, find.text('Ödendi olarak işaretle'));
    await tap(tester, find.text('Deneme hesap'));
    expect(find.text('Deneme arşiv'), findsNothing);
    await tap(tester, find.text('Deneme hesap').last);
    await tester.enterText(
      find.byKey(const Key('recurring-pay-amount')),
      '127,45',
    );
    await tap(tester, find.text('Onayla'));
    expect(fakeApiBodies['/api/recurring/1/pay']['amount'], 127.45);
  });
  // NEDEN: Yeni profil girişinden listeye gidilebilmeli.
  testWidgets('Profil_PlanliOdemelerGirisi', (tester) async {
    await setup();
    await tester.pumpWidget(testApp(const ProfileScreen()));
    await settle(tester);
    await tap(tester, find.text('Planlı ödemeler'));
    expect(find.byType(RecurringPaymentsScreen), findsOneWidget);
  });
  // NEDEN: AccountPanel ve rozetler açık/koyu temada dar ekranda çizim assert'i üretmemeli.
  testWidgets('PlanliEkranlar_AcikKoyuTema_HatasizCizilir', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await setup(plans: [plan(status: 'overdue', days: -1)]);
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(
        testApp(const RecurringPaymentsScreen(), theme: theme),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tap(tester, find.byTooltip('Planlı ödeme ekle'));
      expect(find.byType(RecurringPaymentEditScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
