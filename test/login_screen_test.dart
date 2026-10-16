import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/testing.dart';
import 'package:smartfinance_mobile/services/api_service.dart';
import 'helpers/test_app.dart';

import 'package:smartfinance_mobile/screens/login_screen.dart';
import 'package:smartfinance_mobile/screens/register_screen.dart';

void main() {
  testWidgets('Baglanti hatasi kullaniciya anlasilir mesaj gosterir', (tester) async {
    await setUpFakeApi();
    addTearDown(tearDownFakeApi);
    ApiService.httpClientForTest = MockClient((_) async => throw Exception('sahte-baglanti-hatasi'));
    await tester.pumpWidget(testApp(const LoginScreen()));
    await tester.enterText(find.byType(TextField).at(0), 'deneme@example.invalid');
    await tester.enterText(find.byType(TextField).at(1), 'Deneme123!');
    await tester.tap(find.text('Giriş Yap'));
    await settle(tester);
    expect(find.text('Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.'), findsOneWidget);
  });
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

  // Regresyon testi: "Kayıt Ol" linki eskiden Navigator.pushReplacement
  // kullanıyordu, bu LoginScreen'i yığından tamamen siliyordu. Kayıt
  // ekranındayken sistem geri tuşuna basınca pop edilecek hiçbir şey
  // kalmıyor ve Android doğrudan uygulamayı kapatıyordu.
  testWidgets('Kayit Ol linki push kullanir — LoginScreen yiginda kalir', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.tap(find.text('Kayıt Ol'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);

    // canPop true olmali: pushReplacement kullanilsaydi LoginScreen
    // yigindan silinir, geri gidilecek bir route kalmazdi.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    expect(navigator.canPop(), isTrue);

    // navigator.pop() cagirmak, WidgetsApp'in sistem geri tusunda (Android
    // hardware back) YAPTIGI SEYIN AYNISI — pageBack() kullanmadik cunku o
    // bir AppBar geri butonu ariyor, bizim ozel tasarimda oyle bir widget
    // yok.
    navigator.pop();
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(RegisterScreen), findsNothing);
  });
}
