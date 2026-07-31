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
