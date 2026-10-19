import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smartfinance_mobile/models/account.dart';
import 'package:smartfinance_mobile/screens/account_detail_screen.dart';
import 'package:smartfinance_mobile/screens/account_edit_screen.dart';
import 'package:smartfinance_mobile/screens/accounts_screen.dart';
import 'package:smartfinance_mobile/screens/add_transaction_screen.dart';
import 'package:smartfinance_mobile/screens/dashboard_screen.dart';
import 'package:smartfinance_mobile/screens/profile_screen.dart';
import 'package:smartfinance_mobile/screens/premium_screen.dart';
import 'package:smartfinance_mobile/screens/transfer_screen.dart';
import 'package:smartfinance_mobile/services/amount_privacy.dart';
import 'package:smartfinance_mobile/services/billing_service.dart';
import 'package:smartfinance_mobile/core/utils/formatters.dart';
import 'package:smartfinance_mobile/core/theme/app_theme.dart';
import 'package:smartfinance_mobile/services/account_service.dart';
import 'package:smartfinance_mobile/screens/transactions_screen.dart';
import 'package:smartfinance_mobile/widgets/transaction_card.dart';
import 'helpers/test_app.dart';
import 'helpers/test_store_gateway.dart';

Map<String, dynamic> accountJson(int id, int type, {bool archived = false}) => {
  'id': id,
  'name': type == 3 ? 'Deneme kartı' : 'Deneme banka',
  'type': type,
  'openingBalance': 17,
  'creditLimit': type == 3 ? 137 : null,
  'statementDay': type == 3 ? 20 : null,
  'dueDay': type == 3 ? 25 : null,
  'isArchived': archived,
  'sortOrder': 0,
  'balance': type == 3 ? null : 17,
  'debt': type == 3 ? 37 : null,
  'availableLimit': type == 3 ? 100 : null,
};
Map<String, dynamic> statement(String status, int month, num remaining) => {
  'periodStart': '2026-0$month-01',
  'periodEnd': '2026-0$month-20',
  'dueDate': '2026-0$month-25',
  'amount': 37,
  'paid': 37 - remaining,
  'remaining': remaining,
  'status': status,
};
http.Response response(Object body, [int status = 200]) => http.Response(
  status == 204 ? '' : jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<void> setup({
  List<Map<String, dynamic>> accounts = const [],
  int listStatus = 200,
  int saveStatus = 201,
  bool archivedDelete = false,
}) async {
  await setUpFakeApi(
    categories: [
      {'id': 7, 'name': 'Deneme kategori', 'type': 2},
    ],
    accountApi: (r) async {
      final p = r.url.path;
      if (p == '/api/account' && r.method == 'GET') {
        return response(accounts, listStatus);
      }
      if (p.endsWith('/statements')) {
        return response({
          'current': statement('open', 9, 7),
          'past': [
            statement('partial', 8, 13),
            statement('overdue', 7, 17),
            statement('paid', 6, 0),
          ],
        });
      }
      if (p.endsWith('/transfers')) {
        return response({'items': [], 'totalCount': 0});
      }
      if (p.endsWith('/unarchive')) {
        accounts[0] = {...accounts[0], 'isArchived': false};
        return response(accounts[0]);
      }
      if (p.startsWith('/api/account') && r.method == 'DELETE') {
        return response(
          archivedDelete ? {'archived': true} : {},
          archivedDelete ? 200 : 204,
        );
      }
      if (p == '/api/account/transfer') {
        return response({
          'id': 19,
          ...jsonDecode(r.body) as Map<String, dynamic>,
        }, 201);
      }
      if (p == '/api/account' && r.method == 'POST') {
        return response(
          saveStatus == 402
              ? {'message': 'Deneme ücretsiz hesap sınırı'}
              : accountJson(4, 1),
          saveStatus,
        );
      }
      return null;
    },
  );
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
            child: const Text('Deneme ekranını aç'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Deneme ekranını aç'));
  await settle(tester);
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await settle(tester);
}

Future<void> choose(WidgetTester tester, String key, String label) async {
  await tap(tester, find.byKey(Key(key)));
  await tap(tester, find.text(label).last);
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

  // NEDEN: Uç yolları, sayısal türler, gövdesiz yanıtlar ve UTC sözleşmesi birlikte korunmalı.
  test('HesapServisi_TumUclar_JsonVeGovdesizYanitlar', () async {
    String? unarchiveBody;
    final transfer = {
      'id': 19,
      'fromAccountId': 2,
      'toAccountId': 1,
      'amount': 11,
      'transferDate': '2026-10-19T12:00:00Z',
      'description': null,
    };
    await setUpFakeApi(
      accountApi: (r) async {
        final p = r.url.path;
        if (p == '/api/account') {
          return response(
            r.method == 'GET' ? [accountJson(1, 3)] : accountJson(1, 3),
            r.method == 'POST' ? 201 : 200,
          );
        }
        if (p.endsWith('/unarchive')) {
          unarchiveBody = r.body;
          return response(accountJson(1, 3));
        }
        if (p.endsWith('/statements')) {
          return response({'current': statement('open', 9, 7), 'past': []});
        }
        if (p.endsWith('/transfers')) {
          return response({
            'items': [transfer],
            'totalCount': 1,
          });
        }
        if (p == '/api/account/transfer') {
          return response(transfer, 201);
        }
        if (p == '/api/account/transfer/19') {
          return response({}, 204);
        }
        if (p == '/api/account/1') {
          return response(
            r.method == 'DELETE' ? {'archived': true} : accountJson(1, 3),
          );
        }
        return null;
      },
    );
    final accounts = await AccountService.list(includeArchived: true);
    expect(accounts.single.type, 3);
    expect(accounts.single.availableLimit, 100);
    expect(fakeApiRequests.last.queryParameters, {'includeArchived': 'true'});
    await AccountService.save(
      name: 'Deneme cüzdan',
      type: 1,
      openingBalance: 17,
    );
    expect(fakeApiBodies['/api/account'], {
      'name': 'Deneme cüzdan',
      'type': 1,
      'openingBalance': 17,
    });
    await AccountService.save(
      id: 1,
      name: 'Deneme kartı',
      type: 3,
      openingBalance: 17,
      creditLimit: 137,
      statementDay: 20,
      dueDay: 25,
    );
    expect(fakeApiBodies['/api/account/1'], {
      'name': 'Deneme kartı',
      'type': 3,
      'openingBalance': 17,
      'creditLimit': 137,
      'statementDay': 20,
      'dueDay': 25,
    });
    expect(await AccountService.delete(1), isTrue);
    await AccountService.unarchive(1);
    expect(unarchiveBody, isEmpty);
    final created = await AccountService.createTransfer(
      fromAccountId: 2,
      toAccountId: 1,
      amount: 11,
      transferDate: DateTime.utc(2026, 10, 19, 12),
    );
    expect(created.id, 19);
    expect(
      fakeApiBodies['/api/account/transfer']['transferDate'],
      '2026-10-19T12:00:00.000Z',
    );
    expect(
      (await AccountService.transfers(1, page: 2, pageSize: 17)).totalCount,
      1,
    );
    expect(fakeApiRequests.last.queryParameters, {
      'page': '2',
      'pageSize': '17',
    });
    await AccountService.deleteTransfer(19);
    expect(
      (await AccountService.statements(1, count: 12)).current.status,
      'open',
    );
    expect(fakeApiRequests.last.queryParameters, {'count': '12'});
  });

  // NEDEN: Sunucunun 400 mesajı ve 402 yönlendirme bilgisi serviste kaybolmamalı.
  test('HesapServisi_400MesajiVe402PremiumBilgisiKorunur', () async {
    var status = 400;
    await setUpFakeApi(
      accountApi: (r) async => r.url.path.startsWith('/api/account')
          ? response({'message': 'Deneme doğrulama mesajı'}, status)
          : null,
    );
    await expectLater(
      AccountService.save(name: 'Deneme', type: 1),
      throwsA(
        isA<AccountException>()
            .having((e) => e.message, 'mesaj', 'Deneme doğrulama mesajı')
            .having((e) => e.premiumRequired, 'premium', false),
      ),
    );
    status = 402;
    await expectLater(
      AccountService.unarchive(1),
      throwsA(
        isA<AccountException>().having(
          (e) => e.premiumRequired,
          'premium',
          true,
        ),
      ),
    );
  });

  // NEDEN: Gövdesiz 204 yanıtı arşivleme olarak yorumlanmamalı.
  test('HesapSil_204_SilindiOlarakDoner', () async {
    await setup();
    expect(await AccountService.delete(2), isFalse);
  });

  // NEDEN: Yeni alanlar ve durum rozetleri koyu temada da aynı anlamı korumalı.
  testWidgets('KartDetay_KoyuTema_TutarGizliligiVeOdenmediRozeti', (
    tester,
  ) async {
    await setUpFakeApi(
      accountApi: (r) async {
        if (r.url.path == '/api/account') {
          return response([accountJson(1, 3)]);
        }
        if (r.url.path.endsWith('/statements')) {
          return response({
            'current': statement('open', 9, 7),
            'past': [statement('unpaid', 8, 17)],
          });
        }
        if (r.url.path.endsWith('/transfers')) {
          return response({'items': [], 'totalCount': 0});
        }
        return null;
      },
    );
    await tester.pumpWidget(
      testApp(
        AccountDetailScreen(account: Account.fromJson(accountJson(1, 3))),
        theme: AppTheme.dark,
      ),
    );
    await settle(tester);
    expect(find.text('Ödenmedi'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    AmountPrivacy.gizli.value = true;
    await settle(tester);
    expect(find.text('Borç ₺•••'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // NEDEN: Seçilen hesap filtresi genel gelir/gider filtresiyle birlikte sunucuya gitmeli.
  testWidgets('Islemler_HesapFiltresi_SorguyaEklenir', (tester) async {
    await setup(accounts: [accountJson(2, 2)]);
    await open(tester, const TransactionsScreen());
    await choose(tester, 'transaction-account-filter', 'Deneme banka');
    final query = fakeApiRequests
        .lastWhere((u) => u.path.endsWith('/transaction/filter'))
        .queryParameters;
    expect(query['accountId'], '2');
    expect(query['page'], '1');
  });

  // NEDEN: İşlemi düzenlerken mevcut hesabı korumak ve açıkça kaldırmak mümkün olmalı.
  testWidgets('IslemDuzenle_HesapIdKorunur_VeKaldirilabilir', (tester) async {
    await setUpFakeApi(
      categories: [
        {'id': 7, 'name': 'Deneme kategori', 'type': 2},
      ],
      transactions: [
        {
          'id': 11,
          'amount': 17,
          'description': 'Deneme işlem',
          'type': 2,
          'categoryId': 7,
          'accountId': 2,
          'transactionDate': '2026-10-01T12:00:00Z',
        },
      ],
      accountApi: (r) async =>
          r.url.path == '/api/account' ? response([accountJson(2, 2)]) : null,
    );
    await open(tester, const TransactionsScreen());
    await tap(tester, find.byType(TransactionCard).first);
    await tap(tester, find.text('Güncelle'));
    expect(fakeApiBodies['/api/transaction/11']['accountId'], 2);
    await settle(tester, frames: 40);
    await tap(tester, find.byType(TransactionCard).first);
    await choose(tester, 'edit-transaction-account', 'Hesap seçilmedi');
    await tap(tester, find.text('Güncelle'));
    expect(
      fakeApiBodies['/api/transaction/11'].containsKey('accountId'),
      isTrue,
    );
    expect(fakeApiBodies['/api/transaction/11']['accountId'], isNull);
  });

  // NEDEN: İki ayrı sayfalı kaynakta da tüm hareketler alınmalı; transfer silme onay gerektirmeli.
  testWidgets(
    'HesapDetay_SayfaliHareketler_TariheGoreBirlesir_TransferOnaylaSilinir',
    (tester) async {
      var deleted = false;
      var deleteCalls = 0;
      final transfers = [
        {
          'id': 21,
          'fromAccountId': 2,
          'toAccountId': 1,
          'amount': 11,
          'transferDate': '2026-10-04T12:00:00Z',
          'description': 'Deneme transfer A',
        },
        {
          'id': 22,
          'fromAccountId': 1,
          'toAccountId': 2,
          'amount': 13,
          'transferDate': '2026-10-02T12:00:00Z',
          'description': 'Deneme transfer B',
        },
      ];
      await setUpFakeApi(
        transactionFilter: (uri) {
          final page = int.parse(uri.queryParameters['page']!);
          return {
            'items': [
              {
                'id': 10 + page,
                'type': 2,
                'amount': 7,
                'accountId': 2,
                'description': 'Deneme işlem $page',
                'transactionDate': '2026-10-0${page == 1 ? 3 : 1}T12:00:00Z',
              },
            ],
            'totalCount': 2,
            'page': page,
            'pageSize': 1,
            'totalPages': 2,
          };
        },
        accountApi: (r) async {
          if (r.url.path == '/api/account') {
            return response([accountJson(1, 3), accountJson(2, 2)]);
          }
          if (r.url.path.endsWith('/transfers')) {
            final page = int.parse(r.url.queryParameters['page']!);
            return response({
              'items': [deleted ? transfers[1] : transfers[page - 1]],
              'totalCount': deleted ? 1 : 2,
            });
          }
          if (r.url.path == '/api/account/transfer/21' &&
              r.method == 'DELETE') {
            deleteCalls++;
            deleted = true;
            return response({}, 204);
          }
          return null;
        },
      );
      await open(
        tester,
        AccountDetailScreen(account: Account.fromJson(accountJson(2, 2))),
      );
      final titles = [
        '→ Deneme kartı',
        'Deneme işlem 1',
        '← Deneme kartı',
        'Deneme işlem 2',
      ];
      for (var i = 0; i < titles.length - 1; i++) {
        expect(
          tester.getTopLeft(find.text(titles[i])).dy,
          lessThan(tester.getTopLeft(find.text(titles[i + 1])).dy),
        );
      }
      expect(
        fakeApiRequests
            .where((u) => u.path.endsWith('/transaction/filter'))
            .every((u) => u.queryParameters['accountId'] == '2'),
        isTrue,
      );
      expect(
        fakeApiRequests.any(
          (u) =>
              u.path.endsWith('/transfers') && u.queryParameters['page'] == '2',
        ),
        isTrue,
      );
      await tester.ensureVisible(find.text(titles.first));
      await tester.longPress(find.text(titles.first));
      await settle(tester);
      await tap(tester, find.text('İptal'));
      expect(deleteCalls, 0);
      await tester.longPress(find.text(titles.first));
      await settle(tester);
      await tap(tester, find.text('Onayla'));
      expect(deleteCalls, 1);
      expect(find.text(titles.first), findsNothing);
    },
  );

  // NEDEN: Sunucunun alan doğrulaması kullanıcıya kaydetme formunda görünmeli.
  testWidgets('HesapEkle_400_SunucuMesajiFormdaGorunur', (tester) async {
    await setUpFakeApi(
      accountApi: (r) async => r.method == 'POST'
          ? response({'message': 'Deneme hesap doğrulaması'}, 400)
          : null,
    );
    await open(tester, const AccountEditScreen());
    await tester.enterText(
      find.byKey(const Key('account-name')),
      'Deneme cüzdan',
    );
    await tap(tester, find.text('Kaydet'));
    expect(find.byType(AccountEditScreen), findsOneWidget);
    expect(find.text('Deneme hesap doğrulaması'), findsWidgets);
    expect(find.byType(PremiumScreen), findsNothing);
  });

  // NEDEN: İlk kullanımda boş bakiye yerine hesap ekleme yolu sunulmalı.
  testWidgets('AnaSayfa_HesapYoksa_DavetKarti', (tester) async {
    await setup();
    await open(tester, const DashboardScreen());
    expect(
      find.text(
        'Kartlarını ve hesaplarını ekle — bakiyeni ve kart borcunu takip et',
      ),
      findsOneWidget,
    );
  });
  // NEDEN: Kartın borcu ve harcanabilir limiti ayrı değerlerdir.
  testWidgets('AnaSayfa_KartBorcuVeKalanLimitGorunur', (tester) async {
    await setup(accounts: [accountJson(1, 3)]);
    await open(tester, const DashboardScreen());
    expect(find.text('Borç ${formatTRY(37)}'), findsOneWidget);
    expect(find.text('Kalan limit ${formatTRY(100)}'), findsOneWidget);
    expect(find.text('Son ödeme 25.07.2026'), findsOneWidget);
  });
  // NEDEN: Yeni bakiye kartları mevcut tutar gizliliğini delmemeli.
  testWidgets('AnaSayfa_TutarlarGizliyken_HesapTutarlariGizli', (tester) async {
    await setup(accounts: [accountJson(1, 3)]);
    AmountPrivacy.gizli.value = true;
    await open(tester, const DashboardScreen());
    expect(find.text('Borç ₺•••'), findsOneWidget);
    expect(find.text('Kalan limit ₺•••'), findsOneWidget);
  });
  // NEDEN: Sunucu hatası boş hesap veya sıfır bakiye gibi gösterilmemeli.
  testWidgets('AnaSayfa_HesapYuklenemezse_BolumGizli', (tester) async {
    await setup(listStatus: 500);
    await open(tester, const DashboardScreen());
    expect(find.text('Hesaplarım'), findsNothing);
    expect(find.textContaining('Kartlarını ve hesaplarını ekle'), findsNothing);
  });
  // NEDEN: Nakit/banka gövdesinde kart alanları backend tarafından reddedilir.
  testWidgets('HesapEkle_KartAlanlariYalnizKartta', (tester) async {
    await setup();
    await open(tester, const AccountEditScreen());
    expect(find.byKey(const Key('credit-limit')), findsNothing);
    await choose(tester, 'account-type', 'Kredi kartı');
    expect(find.byKey(const Key('credit-limit')), findsOneWidget);
    expect(find.text('Hesap kesim günü'), findsOneWidget);
    expect(find.text('Son ödeme günü'), findsOneWidget);
    await choose(tester, 'account-type', 'Banka');
    expect(find.byKey(const Key('credit-limit')), findsNothing);
  });
  // NEDEN: Ücretsiz sınır hatası kullanıcının Premium'a ulaşmasını sağlamalı.
  testWidgets('HesapEkle_402_PremiumYonlendirir', (tester) async {
    await setup(saveStatus: 402);
    await open(tester, const AccountEditScreen());
    await tester.enterText(
      find.byKey(const Key('account-name')),
      'Deneme cüzdan',
    );
    await tap(tester, find.text('Kaydet'));
    expect(find.byType(PremiumScreen), findsOneWidget);
  });
  // NEDEN: Tür değişikliği geçmiş bakiye hesaplarını bozabilir ve API yasaklar.
  testWidgets('HesapDuzenle_TurKilitli', (tester) async {
    await setup();
    await open(
      tester,
      AccountEditScreen(account: Account.fromJson(accountJson(1, 3))),
    );
    expect(
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byKey(const Key('account-type')),
          )
          .onChanged,
      isNull,
    );
  });
  // NEDEN: Ödenmiş, kısmi, gecikmiş ve açık dönem birbirinden ayırt edilmeli.
  testWidgets('KartDetay_EkstreDurumRozetleri', (tester) async {
    await setup(accounts: [accountJson(1, 3)]);
    await open(
      tester,
      AccountDetailScreen(account: Account.fromJson(accountJson(1, 3))),
    );
    for (final label in ['Ödendi', 'Kısmen ödendi', 'Gecikti', 'Açık dönem']) {
      expect(find.text(label), findsOneWidget);
    }
  });
  // NEDEN: Kart ödemesi en eski kalan borca yönelmeli, kaynak kullanıcıya bırakılmalı.
  testWidgets('KartDetay_BorcOde_TransferEkraniniDoldurur', (tester) async {
    await setup(accounts: [accountJson(1, 3), accountJson(2, 2)]);
    await open(
      tester,
      AccountDetailScreen(account: Account.fromJson(accountJson(1, 3))),
    );
    await tap(tester, find.text('Borç öde'));
    final screen = tester.widget<TransferScreen>(find.byType(TransferScreen));
    expect(screen.toAccountId, 1);
    expect(screen.amount, 17);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('transfer-amount')))
          .controller!
          .text,
      '17',
    );
    expect(
      tester
          .widget<DropdownButtonFormField<int>>(
            find.descendant(
              of: find.byKey(const Key('transfer-to')),
              matching: find.byType(DropdownButtonFormField<int>),
            ),
          )
          .initialValue,
      1,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<int>>(
            find.descendant(
              of: find.byKey(const Key('transfer-from')),
              matching: find.byType(DropdownButtonFormField<int>),
            ),
          )
          .initialValue,
      isNull,
    );
  });
  // NEDEN: Aynı hesaba transfer bakiye hareketi değildir ve API 400 döner.
  testWidgets('Transfer_AyniHesapSecilemez', (tester) async {
    await setup(accounts: [accountJson(1, 3), accountJson(2, 2)]);
    await open(tester, const TransferScreen(toAccountId: 1));
    final source = tester.widget<DropdownButton<int>>(
      find.descendant(
        of: find.byKey(const Key('transfer-from')),
        matching: find.byType(DropdownButton<int>),
      ),
    );
    expect(source.items!.any((item) => item.value == 1), isFalse);
    await choose(tester, 'transfer-from', 'Deneme banka');
    await tester.enterText(find.byKey(const Key('transfer-amount')), '11');
    await tap(tester, find.text('Transfer yap'));
    expect(fakeApiBodies['/api/account/transfer']['fromAccountId'], 2);
    expect(fakeApiBodies['/api/account/transfer']['toAccountId'], 1);
    expect(
      fakeApiBodies['/api/account/transfer']['transferDate'],
      endsWith('Z'),
    );
  });
  // NEDEN: Başarılı transferden dönünce kullanıcı eski bakiyeyi görmemeli.
  testWidgets('Transfer_BasariliysaGeriDoner_VeListeYenilenir', (tester) async {
    await setup(accounts: [accountJson(1, 3), accountJson(2, 2)]);
    await open(
      tester,
      AccountDetailScreen(account: Account.fromJson(accountJson(1, 3))),
    );
    final before = fakeApiRequests
        .where((u) => u.path == '/api/account')
        .length;
    await tap(tester, find.text('Borç öde'));
    await choose(tester, 'transfer-from', 'Deneme banka');
    await tap(tester, find.text('Transfer yap'));
    expect(find.byType(TransferScreen), findsNothing);
    expect(
      fakeApiRequests.where((u) => u.path == '/api/account').length,
      greaterThan(before),
    );
    expect(
      fakeApiRequests.where((u) => u.path.endsWith('/transfers')).length,
      2,
    );
  });
  // NEDEN: Seçim yalnız ekranda kalmamalı, işlem gövdesine taşınmalı.
  testWidgets('IslemEkle_HesapSeciliyse_AccountIdGonderilir', (tester) async {
    await setup(accounts: [accountJson(2, 2)]);
    await open(tester, const AddTransactionScreen());
    await tester.enterText(find.byType(TextField).at(0), '11');
    await tester.enterText(find.byType(TextField).at(1), 'Deneme işlem');
    await choose(tester, 'transaction-account', 'Deneme banka');
    await tap(tester, find.byType(DropdownButton<int>).first);
    await tap(tester, find.text('Deneme kategori').last);
    await tap(tester, find.text('Kaydet'));
    expect(fakeApiBodies['/api/transaction']['accountId'], 2);
  });
  // NEDEN: Hesap kullanmayan mevcut kullanıcıların akışı sade kalmalı.
  testWidgets('IslemEkle_HesapYoksa_SeciciGizli', (tester) async {
    await setup();
    await open(tester, const AddTransactionScreen());
    expect(find.byKey(const Key('transaction-account')), findsNothing);
  });
  // NEDEN: Hareketli hesabın DELETE yanıtı gerçek silme değil arşivlemedir.
  testWidgets('HesapSil_ArsivlendiYanitiMesaji', (tester) async {
    await setup(accounts: [accountJson(2, 2)], archivedDelete: true);
    await open(
      tester,
      AccountDetailScreen(account: Account.fromJson(accountJson(2, 2))),
    );
    await tap(tester, find.byKey(const Key('account-menu')));
    await tap(tester, find.text('Arşivle/Sil'));
    await tap(tester, find.text('Onayla'));
    expect(find.text('Hesap arşivlendi'), findsOneWidget);
  });
  // NEDEN: Profil arşivleri de listelemeli ve yeniden kullanılabilir kılmalı.
  testWidgets('Profil_ArsivliHesap_ArsivdenCikar', (tester) async {
    await setup(accounts: [accountJson(2, 2, archived: true)]);
    await open(tester, const ProfileScreen());
    await tap(tester, find.text('Hesaplarım'));
    expect(find.byType(AccountsScreen), findsOneWidget);
    expect(
      fakeApiRequests.any(
        (u) => u.queryParameters['includeArchived'] == 'true',
      ),
      isTrue,
    );
    await tap(tester, find.text('Arşivden çıkar'));
    expect(find.text('Arşivden çıkar'), findsNothing);
    expect(fakeApiRequests.any((u) => u.path.endsWith('/2/unarchive')), isTrue);
  });
}
