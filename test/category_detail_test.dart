import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfinance_mobile/screens/category_detail_screen.dart';
import 'package:smartfinance_mobile/screens/dashboard_screen.dart';

import 'helpers/test_app.dart';

/// Ana sayfadaki "Kategoriye Gore Harcama" kartindan bir kategoriye dokununca
/// o kategorinin aylik ozeti ve islemleri acilir (28.09.2026, kullanici istegi).
void main() {
  tearDown(tearDownFakeApi);

  Map<String, dynamic> islem(int id, int kategori, String tarih, double tutar, {String aciklama = 'Alışveriş'}) => {
        'id': id,
        'amount': tutar,
        'description': aciklama,
        'merchantName': aciklama,
        'transactionDate': '${tarih}T12:00:00',
        'type': 2,
        'categoryId': kategori,
      };

  /// Gercek sunucu gibi: kategori, tarih araligi ve tur suzgeci; sayfalama.
  Map<String, dynamic> Function(Uri) sunucu(List<Map<String, dynamic>> hepsi) => (uri) {
        final q = uri.queryParameters;
        final bas = q['startDate'] != null ? DateTime.parse(q['startDate']!) : null;
        final son = q['endDate'] != null ? DateTime.parse(q['endDate']!) : null;
        final kat = q['categoryId'] != null ? int.parse(q['categoryId']!) : null;
        final tur = q['type'] != null ? int.parse(q['type']!) : null;
        final uyan = hepsi.where((t) {
          final d = DateTime.parse(t['transactionDate'] as String);
          return (kat == null || t['categoryId'] == kat) &&
              (tur == null || t['type'] == tur) &&
              (bas == null || !d.isBefore(bas)) &&
              (son == null || !d.isAfter(son));
        }).toList();
        final sayfa = int.parse(q['page'] ?? '1');
        final boyut = int.parse(q['pageSize'] ?? '10');
        final dilim = uyan.skip((sayfa - 1) * boyut).take(boyut).toList();
        return {
          'items': dilim,
          'totalCount': uyan.length,
          'page': sayfa,
          'pageSize': boyut,
          'totalPages': (uyan.length / boyut).ceil(),
        };
      };

  final market = [
    islem(1, 5, '2026-09-24', 100, aciklama: 'BIM'),
    islem(2, 5, '2026-09-20', 200, aciklama: 'MIGROS'),
    islem(3, 5, '2026-09-02', 700, aciklama: 'CARREFOUR'),
    islem(4, 5, '2026-08-15', 500, aciklama: 'A101'),
    islem(6, 5, '2026-08-03', 300, aciklama: 'SOK'),
    islem(5, 9, '2026-09-10', 999, aciklama: 'BASKA KATEGORI'),
  ];

  Future<void> detayAc(WidgetTester tester, {int ay = 9}) async {
    await tester.pumpWidget(testApp(CategoryDetailScreen(categoryId: 5, categoryName: 'Market', year: 2026, month: ay)));
    await settle(tester);
  }

  testWidgets('Ayin toplami, islem sayisi ve islemleri gosterilir', (tester) async {
    await setUpFakeApi(transactionFilter: sunucu(market));
    await detayAc(tester);

    expect(find.text('Market'), findsWidgets);
    expect(find.text('Eylül 2026'), findsOneWidget);
    expect(find.text('₺1.000,00'), findsOneWidget);
    expect(find.text('3 işlem'), findsOneWidget);
    expect(find.text('BIM'), findsOneWidget);
    expect(find.text('CARREFOUR'), findsOneWidget);
    expect(find.text('BASKA KATEGORI'), findsNothing); // baska kategori karismaz
    expect(find.text('A101'), findsNothing); // gecen ay karismaz
  });

  testWidgets('Gecen aya gore degisim gosterilir', (tester) async {
    await setUpFakeApi(transactionFilter: sunucu(market));
    await detayAc(tester);

    // Eylul 1.000, Agustos 800: %25 artis.
    expect(find.textContaining('%25'), findsOneWidget);
    expect(find.textContaining('geçen aya göre'), findsOneWidget);
  });

  testWidgets('Kategoride butce varsa dolulugu gosterilir', (tester) async {
    await setUpFakeApi(transactionFilter: sunucu(market), budgetStatus: [
      {'categoryId': 5, 'categoryName': 'Market', 'monthlyLimit': 1250, 'spent': 1000, 'ratio': 0.8, 'isOverLimit': false},
      {'categoryId': 9, 'categoryName': 'Baska', 'monthlyLimit': 100, 'spent': 999, 'ratio': 9.99, 'isOverLimit': true},
    ]);
    await detayAc(tester);

    expect(find.textContaining('%80'), findsOneWidget);
    expect(find.textContaining('₺1.250'), findsOneWidget);
  });

  testWidgets('Islem olmayan ayda bos durum gosterilir', (tester) async {
    await setUpFakeApi(transactionFilter: sunucu(market));
    await detayAc(tester, ay: 7);

    expect(find.text('Bu ay bu kategoride işlem yok.'), findsOneWidget);
  });

  testWidgets('Onceki aya gecilince o ayin islemleri yuklenir', (tester) async {
    await setUpFakeApi(transactionFilter: sunucu(market));
    await detayAc(tester);

    await tester.tap(find.byTooltip('Önceki ay'));
    await settle(tester);

    expect(find.text('Ağustos 2026'), findsOneWidget);
    expect(find.text('₺800,00'), findsOneWidget);
    expect(find.text('A101'), findsOneWidget);
    expect(find.text('BIM'), findsNothing);
  });

  /// Sunucu sayfa basina en fazla 100 islem donduruyor; toplam tum sayfalardan.
  testWidgets('100den fazla islemde toplam tum sayfalardan hesaplanir', (tester) async {
    final cok = [for (var i = 0; i < 150; i++) islem(100 + i, 5, '2026-09-${(i % 28 + 1).toString().padLeft(2, '0')}', 10)];
    await setUpFakeApi(transactionFilter: sunucu(cok));
    await detayAc(tester);

    expect(find.text('₺1.500,00'), findsOneWidget);
    expect(find.text('150 işlem'), findsOneWidget);
  });

  group('Ana sayfa', () {
    final kategoriler = [
      for (final (id, ad) in [(1, 'Market'), (2, 'Fatura'), (3, 'Ulaşım'), (4, 'Yeme-İçme'), (5, 'Giyim')])
        {'id': id, 'name': ad, 'type': 2},
    ];
    final now = DateTime.now();
    final buAy = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final giderler = [
      for (final (id, tutar) in [(1, 500.0), (2, 400.0), (3, 300.0), (4, 200.0), (5, 100.0)]) islem(id, id, buAy, tutar),
    ];

    Future<void> anaSayfa(WidgetTester tester) async {
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = const Size(1080, 2400);
      addTearDown(tester.view.reset);
      await setUpFakeApi(categories: kategoriler, transactionFilter: sunucu(giderler));
      await tester.pumpWidget(testApp(const DashboardScreen()));
      await settle(tester);
    }

    testWidgets('Kategoriye dokununca detay ekrani acilir', (tester) async {
      await anaSayfa(tester);

      await tester.tap(find.text('Fatura'));
      await settle(tester);

      final ekran = tester.widget<CategoryDetailScreen>(find.byType(CategoryDetailScreen));
      expect(ekran.categoryId, 2);
      expect(ekran.categoryName, 'Fatura');
      expect((ekran.year, ekran.month), (now.year, now.month));
    });

    testWidgets('Ilk 4e sigmayan kategoriler de acilabilir', (tester) async {
      await anaSayfa(tester);

      expect(find.text('Giyim'), findsNothing);
      await tester.ensureVisible(find.text('Tüm kategoriler (5)'));
      await tester.tap(find.text('Tüm kategoriler (5)'));
      await settle(tester);

      expect(find.text('Giyim'), findsOneWidget);
    });
  });
}
