import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:smartfinance_mobile/services/biometric_service.dart';

class _SahteCihaz implements LocalAuthentication {
  _SahteCihaz({required this.donanim, required this.kayitli});

  final bool donanim;
  final List<BiometricType> kayitli;

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> get canCheckBiometrics async => donanim;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => kayitli;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Regresyon (24.09.2026, test kullanicisi): parmak izi tanimli olmayan
/// telefonda kilit ekrani aciliyor, Android cihaz PIN'ini soruyordu — uygulama
/// sifresinin ustune ikinci bir sifre. canCheckBiometrics yalnizca "donanim var
/// mi" diyor, "parmak izi kayitli mi" demiyor.
void main() {
  tearDown(BiometricService.resetForTest);

  test('Donanim var ama parmak izi kayitli degilse biyometrik kilit kullanilmaz', () async {
    BiometricService.authForTest = _SahteCihaz(donanim: true, kayitli: []);

    expect(await BiometricService.isAvailable(), isFalse);
  });

  test('Parmak izi kayitliysa biyometrik kilit kullanilir', () async {
    BiometricService.authForTest = _SahteCihaz(donanim: true, kayitli: [BiometricType.strong]);

    expect(await BiometricService.isAvailable(), isTrue);
  });

  test('Donanim yoksa biyometrik kilit kullanilmaz', () async {
    BiometricService.authForTest = _SahteCihaz(donanim: false, kayitli: []);

    expect(await BiometricService.isAvailable(), isFalse);
  });
}
