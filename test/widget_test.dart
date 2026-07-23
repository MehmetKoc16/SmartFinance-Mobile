// Basit bir duman (smoke) testi: uygulama gercekten baslatilabiliyor mu,
// acilis ekrani cakmadan render oluyor mu kontrol eder. Flutter'in varsayilan
// sayac-uygulamasi sablonunun yerini alir (o sablon bu projede hic var
// olmayan bir 'MyApp' sinifina referans veriyordu, derlenmiyordu bile).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smartfinance_mobile/core/theme/theme_controller.dart';
import 'package:smartfinance_mobile/main.dart';

void main() {
  testWidgets('Uygulama cakmadan acilir ve acilis ekranini gosterir', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeController(),
        child: const SmartFinanceApp(),
      ),
    );

    expect(find.text('Wallet Mark'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Acilis ekranindaki 2 saniyelik gecikmeyi bekleyip token kontrolunun
    // (bos SharedPreferences -> Login ekrani) cakmadan tamamlandigini dogrula.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Giriş Yap'), findsWidgets);
  });
}
