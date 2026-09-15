import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:smartfinance_mobile/core/theme/app_theme.dart';
import 'package:smartfinance_mobile/screens/add_transaction_screen.dart';
import 'package:smartfinance_mobile/screens/dashboard_screen.dart';
import 'package:smartfinance_mobile/screens/transactions_screen.dart';
import 'package:smartfinance_mobile/widgets/transaction_card.dart';

import 'helpers/test_app.dart';

/// Regresyon (15.09.2026, gercek cihaz geri bildirimi: "tarih secimi patlak,
/// duzenlemede de patlak"): uc tarih secici de ColorScheme.dark zorluyordu.
/// Acik temada yuzey beyaz kart rengi, yazi ise koyu semanin beyazi oluyor —
/// gunler okunmuyordu.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void _expectReadablePicker(WidgetTester tester, Brightness appBrightness) {
  final dialog = find.byType(DatePickerDialog);
  expect(dialog, findsOneWidget);
  final scheme = Theme.of(tester.element(dialog)).colorScheme;
  expect(scheme.brightness, appBrightness);
  // WCAG AA normal metin esigi.
  expect(_contrast(scheme.onSurface, scheme.surface), greaterThan(4.5));
}

const _kategoriler = [
  {'id': 1, 'name': 'Maaş', 'type': 1},
  {'id': 2, 'name': 'Market', 'type': 2},
];

void main() {
  tearDown(tearDownFakeApi);

  // Tema test govdesinde olusturuluyor: AppTheme GoogleFonts uzerinden asset
  // manifest'e eristigi icin test binding'i kurulmadan cagrilamiyor.
  for (final (ad, tema, parlaklik) in [
    ('acik', () => AppTheme.light, Brightness.light),
    ('koyu', () => AppTheme.dark, Brightness.dark),
  ]) {
    testWidgets('Islem ekle: $ad temada tarih secici okunur', (tester) async {
      await setUpFakeApi(categories: _kategoriler);
      await tester.pumpWidget(testApp(const AddTransactionScreen(), theme: tema()));
      await settle(tester);

      await tester.ensureVisible(find.byIcon(LucideIcons.calendar));
      await tester.tap(find.byIcon(LucideIcons.calendar));
      await settle(tester);

      _expectReadablePicker(tester, parlaklik);
    });
  }

  testWidgets('Islem duzenle: acik temada tarih secici okunur', (tester) async {
    await setUpFakeApi(categories: _kategoriler, transactions: [
      {
        'id': 10, 'amount': 50.0, 'description': 'Migros alışverişi', 'merchantName': null,
        'transactionDate': '2026-09-10T00:00:00', 'type': 2, 'categoryId': 2,
        'createdDate': '2026-09-10T00:00:00',
      },
    ]);
    await tester.pumpWidget(testApp(const TransactionsScreen()));
    await settle(tester);
    await tester.tap(find.byType(TransactionCard).first);
    await settle(tester);

    await tester.ensureVisible(find.byIcon(LucideIcons.calendar).last);
    await tester.tap(find.byIcon(LucideIcons.calendar).last);
    await settle(tester);

    _expectReadablePicker(tester, Brightness.light);
  });

  testWidgets('Ana sayfa ay secici: acik temada okunur', (tester) async {
    await setUpFakeApi();
    await tester.pumpWidget(testApp(const DashboardScreen()));
    await settle(tester);

    final now = DateTime.now();
    await tester.tap(find.text(DateFormat('MMMM yyyy', 'tr_TR').format(DateTime(now.year, now.month))));
    await settle(tester);

    _expectReadablePicker(tester, Brightness.light);
  });
}
