import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartfinance_mobile/core/utils/formatters.dart';
import 'package:smartfinance_mobile/screens/dashboard_screen.dart';
import 'package:smartfinance_mobile/screens/add_transaction_screen.dart';
import 'package:smartfinance_mobile/screens/trash_screen.dart';
import 'package:smartfinance_mobile/screens/transactions_screen.dart';
import 'package:smartfinance_mobile/services/amount_privacy.dart';
import 'helpers/test_app.dart';

void main() {
  final row = <String, dynamic>{
    'id': 71,
    'amount': 123.45,
    'description': 'Deneme işlem',
    'type': 2,
    'transactionDate': '2026-10-16T12:00:00Z',
    'deletedAt': '2026-10-17T12:00:00Z',
  };
  setUp(() async {
    await setUpFakeApi();
    AmountPrivacy.gizli.value = false;
  });
  tearDown(() {
    AmountPrivacy.gizli.value = false;
    tearDownFakeApi();
  });
  testWidgets('Gizliyken_AnaSayfaBakiyeGorunmez_VeYildizGorunur', (
    tester,
  ) async {
    await pumpUntilDone(
      tester,
      setUpFakeApi(
        transactionSummary: {'totalIncome': 9876.54, 'totalExpense': 123.45},
      ),
    );
    AmountPrivacy.gizli.value = true;
    await tester.pumpWidget(testApp(const DashboardScreen()));
    await settle(tester);
    expect(find.text('₺•••'), findsWidgets);
    expect(find.text('₺9.753,09'), findsNothing);
    expect(find.textContaining('9.876,54'), findsNothing);
    expect(formatTRY(123, respectPrivacy: false), '₺123,00');
    expect(formatCompactTRY(123000), '₺•••');
    expect(formatQuantity(12), '12');
    expect(formatPercent(.1), '%10,00');
  });
  testWidgets('Gizlilik_Tercihi_YenidenAcilistaKorunur', (tester) async {
    await pumpUntilDone(tester, AmountPrivacy.setHidden(true));
    AmountPrivacy.gizli.value = false;
    await pumpUntilDone(tester, AmountPrivacy.load());
    expect(AmountPrivacy.gizli.value, isTrue);
    final prefs = await pumpUntilDone(tester, SharedPreferences.getInstance());
    expect(prefs.getBool('amounts_hidden'), isTrue);
  });
  testWidgets('Gizliyken_IslemEkleme_TutarAlaniDuzenlenebilir', (tester) async {
    AmountPrivacy.gizli.value = true;
    await tester.pumpWidget(testApp(const AddTransactionScreen()));
    await settle(tester);
    final field = find
        .byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.keyboardType ==
                  const TextInputType.numberWithOptions(decimal: true),
        )
        .first;
    await tester.enterText(field, '123.45');
    expect(tester.widget<TextField>(field).controller!.text, '123.45');
  });
  testWidgets('GozIkonu_Dokununca_AcilipKapanir', (tester) async {
    await tester.pumpWidget(testApp(const DashboardScreen()));
    await settle(tester);
    await tester.tap(find.byKey(const Key('amount-privacy-toggle')));
    await settle(tester);
    expect(AmountPrivacy.gizli.value, isTrue);
    expect(find.text('₺•••'), findsWidgets);
    await tester.tap(find.byKey(const Key('amount-privacy-toggle')));
    await settle(tester);
    expect(AmountPrivacy.gizli.value, isFalse);
    expect(find.text('₺•••'), findsNothing);
  });
  testWidgets('CopKutusu_SilinenleriListeler', (tester) async {
    await pumpUntilDone(tester, setUpFakeApi(deletedTransactions: [row]));
    await tester.pumpWidget(testApp(const TrashScreen()));
    await settle(tester);
    expect(find.text('Deneme işlem'), findsOneWidget);
    expect(find.textContaining('gün önce silindi'), findsOneWidget);
    expect(find.textContaining('123,45'), findsOneWidget);
  });
  testWidgets('GeriAl_BasariliysaListedenCikar_VeSnackBar', (tester) async {
    await pumpUntilDone(tester, setUpFakeApi(deletedTransactions: [row]));
    await tester.pumpWidget(testApp(const TrashScreen()));
    await settle(tester);
    await tester.tap(find.text('Geri al'));
    await settle(tester);
    expect(find.text('Deneme işlem'), findsNothing);
    expect(find.text('İşlem geri alındı'), findsOneWidget);
    expect(
      fakeApiRequests.any((u) => u.path.endsWith('/transaction/71/restore')),
      isTrue,
    );
  });
  testWidgets('GeriAl_404_MesajGosterir', (tester) async {
    await pumpUntilDone(
      tester,
      setUpFakeApi(deletedTransactions: [row], restoreStatus: 404),
    );
    await tester.pumpWidget(testApp(const TrashScreen()));
    await settle(tester);
    await tester.tap(find.text('Geri al'));
    await settle(tester);
    expect(find.text('Bu işlem artık geri alınamıyor.'), findsOneWidget);
    expect(find.text('Deneme işlem'), findsOneWidget);
  });
  testWidgets('Bos_CopKutusu_Mesaji', (tester) async {
    await tester.pumpWidget(testApp(const TrashScreen()));
    await settle(tester);
    expect(find.text('Son 30 günde silinen işlem yok.'), findsOneWidget);
  });
  testWidgets('CopKutusu_YuklemeHatasi_BosListeGostermez', (tester) async {
    await pumpUntilDone(tester, setUpFakeApi(deletedStatus: 500));
    await tester.pumpWidget(testApp(const TrashScreen()));
    await settle(tester);
    expect(
      find.text('Çöp kutusu yüklenemedi. Lütfen tekrar deneyin.'),
      findsOneWidget,
    );
    expect(find.text('Son 30 günde silinen işlem yok.'), findsNothing);
  });
  testWidgets('GeriAl_SunucuHatasi_SatiriKorur', (tester) async {
    await pumpUntilDone(
      tester,
      setUpFakeApi(deletedTransactions: [row], restoreStatus: 500),
    );
    await tester.pumpWidget(testApp(const TrashScreen()));
    await settle(tester);
    await tester.tap(find.text('Geri al'));
    await settle(tester);
    expect(find.text('Deneme işlem'), findsOneWidget);
    expect(
      find.text(
        'İşlem geri alınamadı. Bağlantınızı kontrol edip tekrar deneyin.',
      ),
      findsOneWidget,
    );
  });
  testWidgets('IslemSilinince_SnackBarGeriAl_RestoreCagirir', (tester) async {
    await pumpUntilDone(tester, setUpFakeApi(transactions: [row]));
    await tester.pumpWidget(testApp(const TransactionsScreen()));
    await settle(tester);
    await tester.longPress(find.text('Deneme işlem'));
    await settle(tester);
    await tester.tap(find.text('Sil'));
    await settle(tester, frames: 40);
    await tester.tap(find.text('Geri al'));
    await settle(tester);
    expect(
      fakeApiRequests.any((u) => u.path.endsWith('/transaction/71/restore')),
      isTrue,
    );
    expect(find.text('İşlem geri alındı'), findsOneWidget);
    expect(
      fakeApiRequests.where((u) => u.path.endsWith('/transaction/filter')),
      hasLength(2),
    );
    expect(find.text('Deneme işlem'), findsOneWidget);
  });
}
