import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfinance_mobile/screens/transactions_screen.dart';
import 'package:smartfinance_mobile/widgets/transaction_card.dart';

import 'helpers/test_app.dart';

/// Regresyon (15.09.2026, gercek cihaz geri bildirimi: "kategori select yapisi
/// bozulmus"): duzenleme ekranindaki dropdown tum kategorileri tipten bagimsiz
/// listeliyordu; islemin kategorisi silinmisse secili deger listede olmadigi
/// icin DropdownButton dogrulama hatasi verip ekrani bozuyordu.
const _kategoriler = [
  {'id': 1, 'name': 'Maaş', 'type': 1},
  {'id': 2, 'name': 'Market', 'type': 2},
];

Map<String, dynamic> _islem({required int type, int? categoryId}) => {
      'id': 10,
      'amount': 50.0,
      'description': 'Migros alışverişi',
      'merchantName': null,
      'transactionDate': '2026-09-10T00:00:00',
      'type': type,
      'categoryId': categoryId,
      'createdDate': '2026-09-10T00:00:00',
    };

final _dropdown = find.byWidgetPredicate((w) => w is DropdownButton<int>);

Future<void> _openEditSheet(WidgetTester tester) async {
  await tester.pumpWidget(testApp(const TransactionsScreen()));
  await settle(tester);
  await tester.tap(find.byType(TransactionCard).first);
  await settle(tester);
}

void main() {
  tearDown(tearDownFakeApi);

  testWidgets('Silinmis kategoriye bagli islem hatasiz duzenlenir', (tester) async {
    await setUpFakeApi(categories: _kategoriler, transactions: [_islem(type: 2, categoryId: 99)]);
    await _openEditSheet(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('İşlemi Düzenle'), findsOneWidget);
    expect(find.text('Kategori seçin'), findsOneWidget);
  });

  testWidgets('Gider isleminde yalnizca gider kategorileri listelenir', (tester) async {
    await setUpFakeApi(categories: _kategoriler, transactions: [_islem(type: 2, categoryId: 2)]);
    await _openEditSheet(tester);

    await tester.ensureVisible(_dropdown);
    await tester.tap(_dropdown);
    await settle(tester);

    expect(find.text('Maaş'), findsNothing);
  });

  testWidgets('Gelir/Gider degisince uyumsuz kategori secimi temizlenir', (tester) async {
    await setUpFakeApi(categories: _kategoriler, transactions: [_islem(type: 2, categoryId: 2)]);
    await _openEditSheet(tester);

    await tester.tap(find.text('Gelir').last);
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Kategori seçin'), findsOneWidget);
  });
}
