import 'package:local_auth/local_auth.dart';

// Parmak izi/yüz verisi hiçbir zaman cihazdan çıkmaz — Android/iOS donanımı
// doğrulamayı kendi içinde yapar, bu sınıf sadece "başarılı mı?" sonucunu okur.
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
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
