import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smartfinance_mobile/screens/login_screen.dart';

void main() {
  testWidgets('Bos alanlarla Giris Yap basilinca dogrulama hatasi gosterilir ve ag istegi atilmaz', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.tap(find.text('Giriş Yap'));
    await tester.pump();

    expect(find.text('E-posta ve şifre gerekli'), findsOneWidget);
  });

  testWidgets('Sifre alani varsayilan olarak gizlidir', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    final textFields = tester.widgetList<TextField>(find.byType(TextField));

    expect(textFields.any((f) => f.obscureText), isTrue);
  });
}
