import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

// Parmak izi/yüz verisi hiçbir zaman cihazdan çıkmaz — Android/iOS donanımı
// doğrulamayı kendi içinde yapar, bu sınıf sadece "başarılı mı?" sonucunu okur.
class BiometricService {
  static LocalAuthentication _auth = LocalAuthentication();

  @visibleForTesting
  static set authForTest(LocalAuthentication auth) => _auth = auth;

  @visibleForTesting
  static void resetForTest() => _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!supported || !canCheck) return false;
      // canCheckBiometrics yalnizca DONANIM var mi diyor. Parmak izi kayitli
      // degilse kilit ekrani cihaz PIN'ine dusuyordu: kullanici uygulama
      // sifresinin ustune bir de telefon sifresi giriyordu.
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Devam etmek için kimliğinizi doğrulayın',
        options: const AuthenticationOptions(
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
