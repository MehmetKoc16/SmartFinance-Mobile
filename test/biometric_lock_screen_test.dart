import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smartfinance_mobile/screens/biometric_lock_screen.dart';

void main() {
  testWidgets(
    'Acilista dogrulama otomatik baslar ve "Dogrulaniyor..." gosterilir',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MaterialApp(home: BiometricLockScreen()));
      await tester.pump();

      expect(find.text('Doğrulanıyor...'), findsOneWidget);
      // Basarisizlik durumundaki kacis kapisi (Tekrar Dene / Sifre ile giris
      // yap) henuz gorunmemeli — dogrulama daha yeni baslamisken.
      expect(find.text('Şifre ile giriş yap'), findsNothing);
    },
  );
}
