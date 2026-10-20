import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smartfinance_mobile/core/theme/app_theme.dart';
import 'package:smartfinance_mobile/core/theme/app_tokens.dart';
import 'package:smartfinance_mobile/core/utils/formatters.dart';
import 'package:smartfinance_mobile/core/utils/turkish_suffix.dart';
import 'package:smartfinance_mobile/models/account.dart';
import 'package:smartfinance_mobile/screens/account_detail_screen.dart';
import 'package:smartfinance_mobile/screens/add_transaction_screen.dart';
import 'package:smartfinance_mobile/screens/dashboard_screen.dart';
import 'package:smartfinance_mobile/screens/recurring_payment_edit_screen.dart';
import 'package:smartfinance_mobile/screens/recurring_payments_screen.dart';
import 'package:smartfinance_mobile/services/amount_privacy.dart';
import 'package:smartfinance_mobile/widgets/account_widgets.dart';
import 'package:smartfinance_mobile/widgets/accounts_overview.dart';
import 'package:smartfinance_mobile/widgets/upcoming_payments_card.dart';

import 'helpers/test_app.dart';

Map<String, dynamic> _account(int id, int type) => {
  'id': id,
  'name': 'Deneme hesap $id',
  'type': type,
  'openingBalance': 0,
  'balance': 0,
  'debt': 199.99,
  'creditLimit': 900,
  'availableLimit': 700.01,
  'statementDay': 20,
  'dueDay': 25,
  'isArchived': false,
  'sortOrder': id,
};

Map<String, dynamic> _statement(int month, String status) => {
  'periodStart': '2026-${month.toString().padLeft(2, '0')}-01',
  'periodEnd': '2026-${month.toString().padLeft(2, '0')}-20',
  'dueDate': '2026-${month.toString().padLeft(2, '0')}-25',
  'amount': status == 'empty' ? 0 : 199.99,
  'paid': 0,
  'remaining': status == 'empty' || status == 'open' ? 0 : 199.99,
  'status': status,
};

final _plan = <String, dynamic>{
  'id': 1,
  'name': 'Deneme plan',
  'amount': 199.99,
  'type': 2,
  'frequency': 2,
  'anchorDay': 19,
  'startDate': '2026-10-19',
  'nextDueDate': '2026-10-19',
  'remindDaysBefore': 1,
  'isActive': true,
  'daysUntil': 0,
  'status': 'today',
};

http.Response _reply(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<void> _setup({
  int pastCount = 1,
  bool empty = false,
  bool Function()? refreshed,
}) => setUpFakeApi(
  accountApi: (r) async {
    if (r.url.path == '/api/account') {
      return _reply([
        _account(1, 2),
        _account(2, 3),
        if (refreshed?.call() ?? false) _account(3, 2),
      ]);
    }
    if (r.url.path.endsWith('/statements')) {
      return _reply({
        'current': _statement(10, 'open'),
        'past': [
          for (var i = 0; i < pastCount; i++)
            _statement(9 - i, empty ? 'empty' : 'unpaid'),
        ],
      });
    }
    if (r.url.path.endsWith('/transfers')) {
      return _reply({'items': [], 'totalCount': 0});
    }
    return null;
  },
  recurringApi: (r) async {
    if (r.url.path == '/api/recurring') return _reply([_plan]);
    if (r.url.path == '/api/recurring/upcoming') {
      return _reply({
        'items': [
          {
            'recurringPaymentId': 1,
            'name': (refreshed?.call() ?? false)
                ? 'Deneme yeni vade'
                : 'Deneme plan',
            'amount': 199.99,
            'type': 2,
            'dueDate': '2026-10-19',
            'status': 'today',
          },
        ],
        'expenseTotal': 199.99,
        'incomeTotal': 0,
      });
    }
    return null;
  },
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await settle(tester);
}

Future<void> _detail(WidgetTester tester) async {
  await tester.pumpWidget(
    testApp(AccountDetailScreen(account: Account.fromJson(_account(2, 3)))),
  );
  await settle(tester);
}

void main() {
  setUp(() => AmountPrivacy.gizli.value = false);
  tearDown(tearDownFakeApi);

  // NEDEN: Ek, yazılan son rakamdan değil sayının okunuşundan türemeli.
  test('GunEki_1den31e_TumDegerler', () {
    const expected = [
      "1'inde",
      "2'sinde",
      "3'ünde",
      "4'ünde",
      "5'inde",
      "6'sında",
      "7'sinde",
      "8'inde",
      "9'unda",
      "10'unda",
      "11'inde",
      "12'sinde",
      "13'ünde",
      "14'ünde",
      "15'inde",
      "16'sında",
      "17'sinde",
      "18'inde",
      "19'unda",
      "20'sinde",
      "21'inde",
      "22'sinde",
      "23'ünde",
      "24'ünde",
      "25'inde",
      "26'sında",
      "27'sinde",
      "28'inde",
      "29'unda",
      "30'unda",
      "31'inde",
    ];
    for (var day = 1; day <= 31; day++) {
      expect(gunEki(day), expected[day - 1], reason: '$day. gün');
    }
  });

  // NEDEN: Aylık sıklık metni saf yardımcıyı gerçek listede kullanmalı.
  testWidgets('PlanliListe_AylikMetin_DogruEk', (tester) async {
    await _setup();
    await tester.pumpWidget(testApp(const RecurringPaymentsScreen()));
    await settle(tester);
    expect(find.text("Her ay 19'unda"), findsOneWidget);
  });

  // NEDEN: Ön dolu para alanı uygulamanın Türkçe ondalık ayracını kullanmalı.
  testWidgets('PlanliOde_OnDoldurulanTutar_Virgullu', (tester) async {
    await _setup();
    await tester.pumpWidget(testApp(const RecurringPaymentsScreen()));
    await settle(tester);
    await _tap(tester, find.text('Deneme plan'));
    await _tap(tester, find.text('Ödendi olarak işaretle'));
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('recurring-pay-amount')))
          .controller!
          .text,
      '199,99',
    );
  });

  // NEDEN: Borç öde geçişi, en eski kalan borcu virgülle ön doldurmalı.
  testWidgets('KartDetay_BorcOde_TutarVirgullu', (tester) async {
    await _setup();
    await _detail(tester);
    await _tap(tester, find.text('Borç öde'));
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('transfer-amount')))
          .controller!
          .text,
      '199,99',
    );
  });

  // NEDEN: Sıfır harcamalı geçmiş dönem borç ya da ödeme başarısı gibi görünmemeli.
  testWidgets('KartDetay_EmptyRozeti_HarcamaYok', (tester) async {
    await _setup(empty: true);
    await _detail(tester);
    final badge = find.text('Harcama yok');
    expect(badge, findsOneWidget);
    expect(
      tester.widget<Text>(badge).style!.color,
      AppTokens.of(tester.element(badge)).textTert,
    );
  });

  // NEDEN: Uzun ekstre geçmişi hareketlere ulaşmayı zorlaştırmamalı; kapanabilmeli.
  testWidgets('KartDetay_UctenFazlaGecmisEkstre_DugmeIleAcilir', (
    tester,
  ) async {
    await _setup(pastCount: 5);
    await _detail(tester);
    expect(find.text('Ödenmedi'), findsNWidgets(3));
    await _tap(tester, find.text('Tüm ekstreleri göster (5)'));
    expect(find.text('Ödenmedi'), findsNWidgets(5));
    await _tap(tester, find.text('Daha az ekstre göster'));
    expect(find.text('Ödenmedi'), findsNWidgets(3));
  });

  // NEDEN: Gerçek aşağı çekme her kartın uç noktasını tam bir kez yenilemeli.
  testWidgets('AnaSayfa_AsagiCekince_HesaplarVeYaklasanYenilenir', (
    tester,
  ) async {
    var refreshed = false;
    await _setup(refreshed: () => refreshed);
    await tester.pumpWidget(testApp(const DashboardScreen()));
    await settle(tester);
    int count(String path) =>
        fakeApiRequests.where((u) => u.path == path).length;
    final paths = [
      '/api/account',
      '/api/account/2/statements',
      '/api/recurring',
      '/api/recurring/upcoming',
    ];
    final before = {for (final path in paths) path: count(path)};
    refreshed = true;
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, 450),
    );
    await settle(tester, frames: 40);
    for (final path in paths) {
      expect(count(path), before[path]! + 1, reason: path);
    }
    expect(find.text('Deneme hesap 3'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(UpcomingPaymentsCard),
        matching: find.text('Deneme yeni vade'),
      ),
      findsOneWidget,
    );
  });

  // NEDEN: Material varsayılan turkuazı açık/koyu temada marka mavisini ezmemeli.
  testWidgets('PlanliEkle_SeciliTur_MarkaRengi', (tester) async {
    await _setup();
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(
        testApp(const RecurringPaymentEditScreen(), theme: theme),
      );
      await settle(tester);
      final finder = find.byType(SegmentedButton<int>);
      final button = tester.widget<SegmentedButton<int>>(finder);
      final t = AppTokens.of(tester.element(finder));
      expect(
        button.style!.backgroundColor!.resolve({WidgetState.selected}),
        t.brand,
      );
      expect(
        button.style!.foregroundColor!.resolve({WidgetState.selected}),
        Colors.white,
      );
      expect(button.style!.foregroundColor!.resolve({}), t.textSec);
      expect(
        button.style!.iconColor!.resolve({WidgetState.selected}),
        Colors.white,
      );
      await _tap(tester, find.text('Gelir'));
      expect(tester.widget<SegmentedButton<int>>(finder).selected, {1});
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  // NEDEN: İşlem ekleme ve planlı ödeme tür seçicileri aynı marka dilini kullanmalı.
  testWidgets('IslemEkle_SeciliTur_MarkaRengi', (tester) async {
    await _setup();
    await tester.pumpWidget(testApp(const AddTransactionScreen()));
    await settle(tester);
    for (final label in ['Gider', 'Gelir']) {
      if (label == 'Gelir') await _tap(tester, find.text(label));
      final text = find.text(label);
      final t = AppTokens.of(tester.element(text));
      expect(tester.widget<Text>(text).style!.color, Colors.white);
      final containers = tester.widgetList<Container>(
        find.ancestor(of: text, matching: find.byType(Container)),
      );
      expect(
        containers.any(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).color == t.brand,
        ),
        isTrue,
      );
    }
  });

  // NEDEN: Banka, kredi kartı ve ekleme kartı aynı üst kenarı ve yüksekliği paylaşmalı.
  testWidgets('AnaSayfa_HesapKartlari_AyniYukseklik', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await _setup();
    await tester.pumpWidget(testApp(const Scaffold(body: AccountsOverview())));
    await settle(tester);
    final panels = find.byType(AccountPanel);
    expect(panels, findsNWidgets(3));
    final height = tester.getSize(panels.first).height;
    final top = tester.getTopLeft(panels.first).dy;
    for (var i = 1; i < 3; i++) {
      expect(tester.getSize(panels.at(i)).height, height);
      expect(tester.getTopLeft(panels.at(i)).dy, top);
    }
    expect(tester.takeException(), isNull);
  });

  // NEDEN: İşlem satırındaki 14,5 punto hiyerarşisi iki ödeme görünümünde korunmalı.
  testWidgets('PlanliSatirlar_TipografiVeTutarHizasi', (tester) async {
    await _setup();
    for (final screen in [
      const RecurringPaymentsScreen(),
      const Scaffold(body: UpcomingPaymentsCard()),
    ]) {
      await tester.pumpWidget(testApp(screen));
      await settle(tester);
      final name = find.text('Deneme plan');
      final amount = find.text(formatTRY(199.99));
      expect(tester.widget<Text>(name).style!.fontSize, 14.5);
      expect(tester.widget<Text>(name).style!.fontWeight, FontWeight.w500);
      expect(tester.widget<Text>(amount).style!.fontSize, 14.5);
      expect(tester.widget<Text>(amount).style!.fontWeight, FontWeight.w600);
      expect(
        tester.getTopLeft(amount).dy,
        closeTo(tester.getTopLeft(name).dy, 1),
      );
      expect(
        tester.getTopLeft(amount).dx,
        greaterThan(tester.getTopLeft(name).dx),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  // NEDEN: İki boş durum daveti Material ListTile varsayılanıyla farklı büyümemeli.
  testWidgets('AnaSayfa_BosDavetler_AyniYaziBoyutu', (tester) async {
    await setUpFakeApi();
    await tester.pumpWidget(
      testApp(
        const Scaffold(
          body: Column(children: [AccountsOverview(), UpcomingPaymentsCard()]),
        ),
      ),
    );
    await settle(tester);
    final account = find.text(
      'Kartlarını ve hesaplarını ekle — bakiyeni ve kart borcunu takip et',
    );
    final recurring = find.text(
      'Düzenli ödemelerini ekle, günü gelince hatırlatalım',
    );
    expect(
      tester.widget<Text>(account).style!.fontSize,
      tester.widget<Text>(recurring).style!.fontSize,
    );
  });

  // NEDEN: Türkçe para girdisi binlik ayıracı ve gizleme içermemeli.
  test('ParaGirisi_Turkce_BinliksizVeGizlenmez', () {
    AmountPrivacy.gizli.value = true;
    addTearDown(() => AmountPrivacy.gizli.value = false);
    expect(amountForInput(199.99), '199,99');
    expect(amountForInput(1500), '1500');
  });
}
