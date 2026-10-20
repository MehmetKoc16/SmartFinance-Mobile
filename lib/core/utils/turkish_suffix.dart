/// Takvim gününe, sayının okunuşuna uygun Türkçe bulunma ekini ekler.
String gunEki(int n) {
  RangeError.checkValueInInterval(n, 1, 31, 'n');
  final suffix = switch (n % 10) {
    1 || 5 || 8 => 'inde',
    2 || 7 => 'sinde',
    3 || 4 => 'ünde',
    6 => 'sında',
    9 => 'unda',
    _ => n == 20 ? 'sinde' : 'unda',
  };
  return "$n'$suffix";
}
