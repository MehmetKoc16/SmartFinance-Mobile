/// Boşluk içeren adlar da güvenle avatar baş harflerine dönüşür.
String nameInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'SF';
  return parts.take(2).map((p) => p[0]).join().toUpperCase();
}

bool validSummary(dynamic value) => value is Map &&
    !value.containsKey('error') && value['totalIncome'] is num &&
    value['totalExpense'] is num;
