import 'package:intl/intl.dart';

final _tryFull = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
final _tryWhole = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);

/// Türkçe binlik/ondalık ayraçlarıyla TL tutarı biçimlendirir (₺1.234,56).
String formatTRY(num value, {bool decimals = true}) {
  return (decimals ? _tryFull : _tryWhole).format(value);
}
