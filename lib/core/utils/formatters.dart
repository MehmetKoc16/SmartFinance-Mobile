import 'package:intl/intl.dart';

final _tryFull = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
final _tryWhole = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);

/// Türkçe binlik/ondalık ayraçlarıyla TL tutarı biçimlendirir (₺1.234,56).
String formatTRY(num value, {bool decimals = true}) {
  return (decimals ? _tryFull : _tryWhole).format(value);
}

final _trNumber2 = NumberFormat('#,##0.00', 'tr_TR');

/// Büyük sayıları Mn/Mr (milyon/milyar) kısaltmasıyla gösterir — para birimi
/// simgesi eklemez, gerekirse çağıran taraf "₺" öneki ekler (piyasa değeri gibi
/// para birimlerinde, ortalama hacim gibi adetlerde eklemez).
String formatCompactNumber(num value) {
  final abs = value.abs();
  if (abs >= 1e9) return '${_trNumber2.format(value / 1e9)} Mr';
  if (abs >= 1e6) return '${_trNumber2.format(value / 1e6)} Mn';
  if (abs >= 1e3) return '${_trNumber2.format(value / 1e3)} Bin';
  return _trNumber2.format(value);
}

/// Oran (0.082 gibi) alıp yüzde olarak biçimlendirir (%8,20).
String formatPercent(num value) {
  return '%${_trNumber2.format(value * 100)}';
}

/// Yatırım miktarını (adet/gram/lot) biçimlendirir.
///
/// Sabit 2 ondalık kullanılamıyor: kripto miktarları çok küçük olabiliyor.
/// 0,004 BTC bugünkü kurla ~15.000 TL ediyor ama iki haneye yuvarlanınca
/// ekranda "0,00 adet" görünüyordu — kullanıcı pozisyonunu göremiyordu.
///
/// Kural tek: 8 ondalığa kadar yaz (1 satoshi = 0,00000001 BTC), sondaki
/// gereksiz sıfırları kırp. Böylece hissede "10 adet", altında "2,5 gram",
/// kriptoda "0,00012345 adet" çıkıyor; ayrıca 8 hanede kesmek double'ın
/// kayan nokta gürültüsünü de (0,1 + 0,2 = 0,30000000000000004) siliyor.
String formatQuantity(num value) => _sifirlariKirp(
      NumberFormat('#,##0.00000000', 'tr_TR').format(value),
      ',',
    );

/// Miktarı DÜZENLEME ALANINA yazılabilir düz metne çevirir.
///
/// [formatQuantity] gösterim içindir: Türkçe ayraçlarla "1.234,5" üretir.
/// Bu metin geri okunurken `replaceAll(',', '.')` ile ayrıştırıldığı için
/// binlik noktası sayıyı bozardı. Burada binlik ayraç yok, ondalık ayraç
/// nokta.
///
/// Ayrıca kayan nokta gürültüsünü kırpıyor: 0,1 + 0,2 toplamı double'da
/// 0.30000000000000004 oluyor ve alana ham hâliyle yazılıyordu.
String quantityForInput(num value) =>
    _sifirlariKirp(value.toStringAsFixed(8), '.');

/// Ondalık kısmın sonundaki gereksiz sıfırları atar; ondalık ayraç yalnız
/// kalırsa onu da kaldırır. "10,00000000" -> "10", "2,50000000" -> "2,5".
String _sifirlariKirp(String metin, String ayrac) {
  if (!metin.contains(ayrac)) return metin;
  metin = metin.replaceAll(RegExp(r'0+$'), '');
  return metin.endsWith(ayrac) ? metin.substring(0, metin.length - 1) : metin;
}
