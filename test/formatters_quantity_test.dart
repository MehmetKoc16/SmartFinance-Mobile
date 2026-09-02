import 'package:flutter_test/flutter_test.dart';
import 'package:smartfinance_mobile/core/utils/formatters.dart';

/// Miktar biçimlendirmesi kriptoyu destekledikten sonra kritik hale geldi:
/// sabit 2 ondalık, küçük kripto pozisyonlarını ekranda "0,00" gösteriyordu.
void main() {

  group('formatQuantity', () {
    test('kucuk kripto miktari sifira yuvarlanmaz', () {
      // 0,004 BTC bugunku kurla ~15.000 TL. Eskiden "0,00" goruluyordu.
      expect(formatQuantity(0.004), '0,004');
      expect(formatQuantity(0.00012345), '0,00012345');
      // 1 satoshi
      expect(formatQuantity(0.00000001), '0,00000001');
    });

    test('buyuk adetlerde gereksiz sifir gostermez', () {
      expect(formatQuantity(10), '10');
      expect(formatQuantity(2.5), '2,5');
      expect(formatQuantity(1234.5), '1.234,5');
    });

    test('sifir ve negatif deger cokmez', () {
      expect(formatQuantity(0), '0');
      expect(formatQuantity(-0.004), '-0,004');
    });
  });

  group('quantityForInput', () {
    test('kayan nokta gurultusunu kirpar', () {
      // 0.1 + 0.2 double'da 0.30000000000000004 ediyor; duzenleme alanina
      // ham haliyle yaziliyordu.
      expect(quantityForInput(0.1 + 0.2), '0.3');
    });

    test('binlik ayrac koymaz — geri okunabilmeli', () {
      // Alan geri okunurken replaceAll(',', '.') uygulaniyor; binlik noktasi
      // olsaydi "1.234,5" -> "1.234.5" olur ve ayristirilamazdi.
      final metin = quantityForInput(1234.5);
      expect(metin, '1234.5');
      expect(double.tryParse(metin.replaceAll(',', '.')), 1234.5);
    });

    test('tam sayida ondalik eklemez', () {
      expect(quantityForInput(10), '10');
    });
  });
}
