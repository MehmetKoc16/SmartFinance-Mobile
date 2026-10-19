/// DateOnly: yerel takvim günü; bu alanlara UTC dönüşümü uygulanmaz.
String recurringDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String recurringStatusLabel(String status, int daysUntil) => switch (status) {
  'overdue' => 'Gecikti',
  'today' => 'Bugün',
  'upcoming' => daysUntil == 1 ? 'Yarın' : '$daysUntil gün sonra',
  'ended' => 'Sona erdi',
  _ => status,
};

class RecurringPayment {
  const RecurringPayment({
    required this.id,
    required this.name,
    required this.amount,
    required this.type,
    this.categoryId,
    this.accountId,
    required this.frequency,
    required this.startDate,
    required this.anchorDay,
    required this.nextDueDate,
    this.endDate,
    required this.remindDaysBefore,
    required this.isActive,
    required this.daysUntil,
    required this.status,
  });
  final int id, type, frequency, anchorDay, remindDaysBefore, daysUntil;
  final int? categoryId, accountId;
  final String name, status;
  final double amount;
  final DateTime startDate, nextDueDate;
  final DateTime? endDate;
  final bool isActive;
  String get statusLabel => recurringStatusLabel(status, daysUntil);
  factory RecurringPayment.fromJson(Map<String, dynamic> j) => RecurringPayment(
    id: j['id'] as int,
    name: j['name'] as String,
    amount: (j['amount'] as num).toDouble(),
    type: j['type'] as int,
    categoryId: j['categoryId'] as int?,
    accountId: j['accountId'] as int?,
    frequency: j['frequency'] as int,
    startDate: DateTime.parse(j['startDate'] as String),
    anchorDay: j['anchorDay'] as int,
    nextDueDate: DateTime.parse(j['nextDueDate'] as String),
    endDate: j['endDate'] == null
        ? null
        : DateTime.parse(j['endDate'] as String),
    remindDaysBefore: j['remindDaysBefore'] as int,
    isActive: j['isActive'] as bool,
    daysUntil: j['daysUntil'] as int,
    status: j['status'] as String,
  );
}

class UpcomingItem {
  const UpcomingItem({
    required this.recurringPaymentId,
    required this.name,
    required this.amount,
    required this.type,
    this.categoryId,
    this.accountId,
    required this.dueDate,
    required this.status,
  });
  final int recurringPaymentId, type;
  final int? categoryId, accountId;
  final String name, status;
  final double amount;
  final DateTime dueDate;
  factory UpcomingItem.fromJson(Map<String, dynamic> j) => UpcomingItem(
    recurringPaymentId: j['recurringPaymentId'] as int,
    name: j['name'] as String,
    amount: (j['amount'] as num).toDouble(),
    type: j['type'] as int,
    categoryId: j['categoryId'] as int?,
    accountId: j['accountId'] as int?,
    dueDate: DateTime.parse(j['dueDate'] as String),
    status: j['status'] as String,
  );
}

class Upcoming {
  const Upcoming({
    required this.items,
    required this.expenseTotal,
    required this.incomeTotal,
  });
  final List<UpcomingItem> items;
  final double expenseTotal, incomeTotal;
  factory Upcoming.fromJson(Map<String, dynamic> j) => Upcoming(
    items: (j['items'] as List)
        .map((e) => UpcomingItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    expenseTotal: (j['expenseTotal'] as num).toDouble(),
    incomeTotal: (j['incomeTotal'] as num).toDouble(),
  );
}

class RecurringPaymentPayResult {
  const RecurringPaymentPayResult({
    required this.transaction,
    required this.recurringPayment,
  });
  // Uygulamadaki işlem ekranları da TransactionDto'yu JSON olarak kullanır.
  final Map<String, dynamic> transaction;
  final RecurringPayment recurringPayment;
  factory RecurringPaymentPayResult.fromJson(Map<String, dynamic> j) =>
      RecurringPaymentPayResult(
        transaction: Map<String, dynamic>.from(j['transaction'] as Map),
        recurringPayment: RecurringPayment.fromJson(
          Map<String, dynamic>.from(j['recurringPayment'] as Map),
        ),
      );
}
