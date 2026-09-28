import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regresyon (28.09.2026, testcinin telefonunda): yazi tipleri uygulamada
/// degildi, ilk acilista internetten (fonts.gstatic.com) indiriliyordu.
/// Indirme olmayinca telefonun kendi yazi tipi kullanildi ve uygulama
/// gelistiricinin telefonundan farkli gorundu. Ayrica her kurulumda Google'a
/// istek gidiyordu (gizlilik politikasinda yok).
///
/// Uygulama internetten cekmeyi kapatiyor (main.dart). google_fonts dosyayi
/// `Aile-Agirlik.ttf` adiyla varliklar arasinda arar; kullanilan her
/// aile/agirlik burada olmali, yoksa o yazi cihazda sessizce telefonun yazi
/// tipiyle cizilir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Kullanilan tum yazi tipleri uygulamanin icinde', () async {
    final varliklar = (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets();

    const beklenen = [
      // Govde metni (tema) — Material metin temasi 400/500, ekranlar 600/700 kullaniyor.
      'Inter-Regular', 'Inter-Medium', 'Inter-SemiBold', 'Inter-Bold',
      // Basliklar ve buyuk rakamlar (jakarta()) — acilis ekrani 800.
      'PlusJakartaSans-Medium', 'PlusJakartaSans-SemiBold', 'PlusJakartaSans-Bold', 'PlusJakartaSans-ExtraBold',
    ];
    final eksik = beklenen.where((ad) => !varliklar.any((v) => v.endsWith('/$ad.ttf'))).toList();

    expect(eksik, isEmpty, reason: 'pubspec assets altinda olmayan yazi tipleri');
  });
}
