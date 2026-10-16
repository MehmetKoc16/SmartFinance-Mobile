import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfinance_mobile/main.dart';
import 'package:smartfinance_mobile/services/api_service.dart';
import 'helpers/test_app.dart';

void main() {
  testWidgets('MaterialApp Turkce takvim ve yerellestirme kullanir', (tester) async {
    await setUpFakeApi();
    addTearDown(tearDownFakeApi);
    await ApiService.removeToken();
    await tester.pumpWidget(testApp(const SmartFinanceApp()));
    await settle(tester);
    final app = tester.widgetList<MaterialApp>(find.byType(MaterialApp)).last;
    expect(app.locale, const Locale('tr', 'TR'));
    expect(app.supportedLocales, [const Locale('tr', 'TR')]);
    expect(app.localizationsDelegates, hasLength(3));
    expect(MaterialLocalizations.of(tester.element(find.byType(Scaffold).last)).cancelButtonLabel, 'İptal');
    // Splash zamanlayıcısı giriş ekranına geçerek tamamlanır; IAP başlatılmaz.
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
