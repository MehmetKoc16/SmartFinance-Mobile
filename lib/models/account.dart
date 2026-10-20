class Account {
  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.openingBalance,
    required this.isArchived,
    required this.sortOrder,
    this.creditLimit,
    this.statementDay,
    this.dueDay,
    this.balance,
    this.debt,
    this.availableLimit,
  });
  final int id, type, sortOrder;
  final String name;
  final double openingBalance;
  final double? creditLimit, balance, debt, availableLimit;
  final int? statementDay, dueDay;
  final bool isArchived;
  bool get isCard => type == 3;
  String get typeLabel =>
      const {1: 'Nakit', 2: 'Banka', 3: 'Kredi kartı'}[type]!;
  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: json['id'] as int,
    name: json['name'] as String,
    type: json['type'] as int,
    openingBalance: (json['openingBalance'] as num).toDouble(),
    creditLimit: (json['creditLimit'] as num?)?.toDouble(),
    statementDay: json['statementDay'] as int?,
    dueDay: json['dueDay'] as int?,
    isArchived: json['isArchived'] as bool,
    sortOrder: json['sortOrder'] as int,
    balance: (json['balance'] as num?)?.toDouble(),
    debt: (json['debt'] as num?)?.toDouble(),
    availableLimit: (json['availableLimit'] as num?)?.toDouble(),
  );
}

class Transfer {
  const Transfer({
    required this.id,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amount,
    required this.transferDate,
    this.description,
  });
  final int id, fromAccountId, toAccountId;
  final double amount;
  final DateTime transferDate;
  final String? description;
  factory Transfer.fromJson(Map<String, dynamic> json) => Transfer(
    id: json['id'] as int,
    fromAccountId: json['fromAccountId'] as int,
    toAccountId: json['toAccountId'] as int,
    amount: (json['amount'] as num).toDouble(),
    transferDate: DateTime.parse(json['transferDate'] as String),
    description: json['description'] as String?,
  );
}

class TransferPage {
  const TransferPage({required this.items, required this.totalCount});
  final List<Transfer> items;
  final int totalCount;
  factory TransferPage.fromJson(Map<String, dynamic> json) => TransferPage(
    items: (json['items'] as List)
        .map((e) => Transfer.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    totalCount: json['totalCount'] as int,
  );
}

class Statement {
  const Statement({
    required this.periodStart,
    required this.periodEnd,
    required this.dueDate,
    required this.amount,
    required this.paid,
    required this.remaining,
    required this.status,
  });
  final DateTime periodStart, periodEnd, dueDate;
  final double amount, paid, remaining;
  final String status;
  String get statusLabel =>
      const {
        'paid': 'Ödendi',
        'partial': 'Kısmen ödendi',
        'unpaid': 'Ödenmedi',
        'overdue': 'Gecikti',
        'open': 'Açık dönem',
        'empty': 'Harcama yok',
      }[status] ??
      status;
  factory Statement.fromJson(Map<String, dynamic> json) => Statement(
    periodStart: DateTime.parse(json['periodStart'] as String),
    periodEnd: DateTime.parse(json['periodEnd'] as String),
    dueDate: DateTime.parse(json['dueDate'] as String),
    amount: (json['amount'] as num).toDouble(),
    paid: (json['paid'] as num).toDouble(),
    remaining: (json['remaining'] as num).toDouble(),
    status: json['status'] as String,
  );
}

class Statements {
  const Statements({required this.current, required this.past});
  final Statement current;
  final List<Statement> past;

  /// Sunucunun FIFO hesabını tekrarlamayız; dönen dönemlerdeki en eski kalanı seçeriz.
  Statement? get oldestRemaining {
    final unpaid = [current, ...past].where((s) => s.remaining > 0).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return unpaid.isEmpty ? null : unpaid.first;
  }

  factory Statements.fromJson(Map<String, dynamic> json) => Statements(
    current: Statement.fromJson(
      Map<String, dynamic>.from(json['current'] as Map),
    ),
    past: (json['past'] as List)
        .map((e) => Statement.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );
}
