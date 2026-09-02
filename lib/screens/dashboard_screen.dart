import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/constants/category_style.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/formatters.dart';
import '../services/api_service.dart';
import '../widgets/transaction_card.dart';

class _CategorySpend {
  final String name;
  final Color color;
  final IconData icon;
  final double amount;
  final double pct;
  const _CategorySpend({
    required this.name,
    required this.color,
    required this.icon,
    required this.amount,
    required this.pct,
  });
}

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onSeeAllTransactions;
  const DashboardScreen({super.key, this.onSeeAllTransactions});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double _totalIncome = 0;
  double _totalExpense = 0;
  double? _balanceChangePct;
  List<dynamic> _recentTransactions = [];
  List<_CategorySpend> _topSpendCats = [];
  Map<int, String> _categoryMap = {};
  String _userName = '';
  bool _isLoading = true;

  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _loadDashboardData();
  }

  void _changeMonth(int direction) {
    setState(() {
      _selectedMonth += direction;
      if (_selectedMonth > 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else if (_selectedMonth < 1) {
        _selectedMonth = 12;
        _selectedYear--;
      }
    });
    _loadDashboardData();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedYear == now.year && _selectedMonth == now.month;
  }

  String get _initials {
    final parts = _userName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return 'SF';
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'İyi geceler,';
    if (hour < 12) return 'Günaydın,';
    if (hour < 18) return 'İyi günler,';
    return 'İyi akşamlar,';
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final monthStart = DateTime(_selectedYear, _selectedMonth, 1);
      final monthEnd = DateTime(_selectedYear, _selectedMonth + 1, 1).subtract(const Duration(seconds: 1));
      final prevMonth = _selectedMonth == 1 ? 12 : _selectedMonth - 1;
      final prevYear = _selectedMonth == 1 ? _selectedYear - 1 : _selectedYear;

      final results = await Future.wait([
        ApiService.authenticatedGet('/auth/me'),
        ApiService.authenticatedGet('/category'),
        ApiService.authenticatedGet('/transaction/summary/$_selectedYear/$_selectedMonth'),
        ApiService.authenticatedGet('/transaction/summary/$prevYear/$prevMonth'),
        ApiService.authenticatedGet('/transaction/filter?page=1&pageSize=5'),
        ApiService.authenticatedGet(
          '/transaction/filter?page=1&pageSize=100&type=2'
          '&startDate=${monthStart.toIso8601String()}&endDate=${monthEnd.toIso8601String()}',
        ),
      ]);

      final me = results[0];
      final categories = results[1];
      final summary = results[2] as Map;
      final prevSummary = results[3] as Map;
      final recent = results[4] as Map;
      final monthExpenses = results[5] as Map;

      if (categories is List) {
        _categoryMap = {for (var c in categories) c['id'] as int: c['name'] as String};
      }

      final income = (summary['totalIncome'] ?? 0).toDouble();
      final expense = (summary['totalExpense'] ?? 0).toDouble();
      final net = income - expense;

      final prevIncome = (prevSummary['totalIncome'] ?? 0).toDouble();
      final prevExpense = (prevSummary['totalExpense'] ?? 0).toDouble();
      final prevNet = prevIncome - prevExpense;
      final changePct = prevNet == 0 ? null : ((net - prevNet) / prevNet.abs()) * 100;

      // Kategoriye göre harcama: backend PageSize sınırı 100 — bir ayda 100'den
      // fazla gider işlemi olursa kırılım eksik hesaplanır. Bilgilendirme amaçlı
      // bir bileşen olduğundan bu kabul edilebilir bir sınırlama.
      final Map<int, double> spendByCategory = {};
      for (final t in (monthExpenses['items'] ?? [])) {
        final catId = t['categoryId'];
        if (catId == null) continue;
        final amt = (t['amount'] ?? 0).toDouble();
        spendByCategory[catId as int] = (spendByCategory[catId] ?? 0) + amt;
      }
      final sortedCats = spendByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final top4 = sortedCats.take(4).toList();
      final maxSpend = top4.isNotEmpty ? top4.first.value : 1.0;
      final topSpendCats = top4.map((e) {
        final name = _categoryMap[e.key] ?? 'Silinmiş kategori';
        final style = CategoryStyles.of(name);
        return _CategorySpend(
          name: name,
          color: style.color,
          icon: style.icon,
          amount: e.value,
          pct: maxSpend == 0 ? 0 : (e.value / maxSpend * 100),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _userName = me is Map ? (me['fullName'] ?? '') : '';
          _totalIncome = income;
          _totalExpense = expense;
          _balanceChangePct = changePct;
          _recentTransactions = recent['items'] ?? [];
          _topSpendCats = topSpendCats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getCategoryName(dynamic transaction) {
    final catId = transaction['categoryId'];
    if (catId != null && _categoryMap.containsKey(catId)) {
      return _categoryMap[catId]!;
    }
    return '';
  }

  String _formatDay(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final d = DateTime(date.year, date.month, date.day);
      if (d == today) return 'Bugün';
      if (d == yesterday) return 'Dün';
      return DateFormat('d MMMM', 'tr_TR').format(date);
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: t.brand))
            : RefreshIndicator(
                onRefresh: _loadDashboardData,
                color: t.brand,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Üst karşılama
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_greeting, style: TextStyle(color: t.textSec, fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(
                                _userName.isNotEmpty ? _userName : 'Kullanıcı',
                                style: jakarta(fontSize: 18, fontWeight: FontWeight.w600, color: t.text),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: t.card,
                                  border: Border.all(color: t.border),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(LucideIcons.bell, color: t.text, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 38,
                                height: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: t.brandSoft, shape: BoxShape.circle),
                                child: Text(
                                  _initials,
                                  style: jakarta(fontSize: 14, fontWeight: FontWeight.w700, color: t.brand),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Ay seçici
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: t.card,
                            border: Border.all(color: t.border),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _monthNavButton(t, LucideIcons.chevronLeft, () => _changeMonth(-1)),
                              SizedBox(
                                width: 110,
                                child: Text(
                                  DateFormat('MMMM yyyy', 'tr_TR').format(DateTime(_selectedYear, _selectedMonth)),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: t.text, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ),
                              _monthNavButton(
                                  t, LucideIcons.chevronRight, _isCurrentMonth ? null : () => _changeMonth(1)),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Bakiye kartı — gradient hero
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [t.brand, t.brandDeep],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Bu Ayki Bakiye',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                            const SizedBox(height: 8),
                            Text(
                              formatTRY(_totalIncome - _totalExpense),
                              style: jakarta(
                                  fontSize: 34, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.5),
                            ),
                            if (_balanceChangePct != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _balanceChangePct! >= 0 ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight,
                                      color: Colors.white,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_balanceChangePct! >= 0 ? '+' : ''}${_balanceChangePct!.toStringAsFixed(1)}% geçen aya göre',
                                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Gelir / Gider kartları
                      Row(
                        children: [
                          Expanded(
                            child: _summaryCard(
                              t,
                              'Gelir',
                              _totalIncome,
                              t.green,
                              t.greenSoft,
                              LucideIcons.arrowDownLeft,
                              (_totalIncome + _totalExpense) == 0 ? 0 : _totalIncome / (_totalIncome + _totalExpense),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _summaryCard(
                              t,
                              'Gider',
                              _totalExpense,
                              t.red,
                              t.redSoft,
                              LucideIcons.arrowUpRight,
                              (_totalIncome + _totalExpense) == 0 ? 0 : _totalExpense / (_totalIncome + _totalExpense),
                            ),
                          ),
                        ],
                      ),

                      if (_topSpendCats.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          decoration: BoxDecoration(
                            color: t.card,
                            border: Border.all(color: t.border),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Kategoriye Göre Harcama',
                                  style: TextStyle(color: t.text, fontSize: 13.5, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 12),
                              ..._topSpendCats.map((c) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(color: c.color, shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: 10),
                                        SizedBox(
                                          width: 88,
                                          child: Text(
                                            c.name,
                                            style: TextStyle(color: t.text, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(3),
                                            child: Container(
                                              height: 6,
                                              color: t.divider,
                                              child: FractionallySizedBox(
                                                alignment: Alignment.centerLeft,
                                                widthFactor: (c.pct / 100).clamp(0, 1),
                                                child: Container(color: c.color),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 74,
                                          child: Text(
                                            formatTRY(c.amount, decimals: false),
                                            textAlign: TextAlign.right,
                                            style: TextStyle(color: t.textSec, fontSize: 12.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 28),

                      // Son İşlemler başlığı
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Son İşlemler', style: jakarta(fontSize: 15, fontWeight: FontWeight.w600, color: t.text)),
                          GestureDetector(
                            onTap: widget.onSeeAllTransactions,
                            child: Text('Tümünü Gör',
                                style: TextStyle(color: t.brand, fontSize: 13, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      if (_recentTransactions.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: t.card,
                            border: Border.all(color: t.border),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              'Henüz işlem yok\n+ butonuyla ilk işleminizi ekleyin',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: t.textSec, fontSize: 14),
                            ),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: t.card,
                            border: Border.all(color: t.border),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (var i = 0; i < _recentTransactions.length; i++)
                                TransactionCard(
                                  description: _recentTransactions[i]['description'] ?? '',
                                  merchantName: _recentTransactions[i]['merchantName'],
                                  amount: (_recentTransactions[i]['amount'] ?? 0).toDouble(),
                                  type: _recentTransactions[i]['type'] ?? 2,
                                  categoryName: _getCategoryName(_recentTransactions[i]),
                                  date: _formatDay(_recentTransactions[i]['transactionDate']),
                                  showDivider: i != _recentTransactions.length - 1,
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _monthNavButton(AppTokens t, IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: enabled ? t.textSec : t.textTert),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _summaryCard(
      AppTokens t, String title, double amount, Color color, Color softColor, IconData icon, double ratio) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: softColor, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: t.textSec, fontSize: 12.5, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            formatTRY(amount),
            style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio.clamp(0, 1).toDouble(),
              minHeight: 4,
              backgroundColor: t.divider,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
