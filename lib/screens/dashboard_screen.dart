import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';
import '../services/api_service.dart';
import '../widgets/transaction_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _balance = 0;
  int _transactionCount = 0;
  List<dynamic> _recentTransactions = [];
  Map<int, String> _categoryMap = {};
  bool _isLoading = true;

  // Ay seçici
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

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      // Kategorileri çek (isim eşleştirme için)
      final categories = await ApiService.authenticatedGet('/category');
      if (categories is List) {
        _categoryMap = {for (var c in categories) c['id'] as int: c['name'] as String};
      }

      // Seçilen ayın özeti
      final summary = await ApiService.authenticatedGet(
        '/transaction/summary/$_selectedYear/$_selectedMonth',
      );

      double income = (summary['totalIncome'] ?? 0).toDouble();
      double expense = (summary['totalExpense'] ?? 0).toDouble();
      int count = summary['transactionCount'] ?? 0;

      // Son işlemler (her zaman en son eklenenler)
      final transactions = await ApiService.authenticatedGet(
        '/transaction/filter?page=1&pageSize=5',
      );

      if (mounted) {
        setState(() {
          _totalIncome = income;
          _totalExpense = expense;
          _balance = income - expense;
          _transactionCount = count;
          _recentTransactions = transactions['items'] ?? [];
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
    return transaction['categoryName'] ?? transaction['category']?['name'] ?? 'Kategori';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      if (date.day == now.day && date.month == now.month && date.year == now.year) {
        return 'Bugün';
      }
      return DateFormat('dd MMM', 'tr_TR').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
            : RefreshIndicator(
                onRefresh: _loadDashboardData,
                color: AppColors.accent,
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
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Merhaba 👋',
                                    style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'SmartFinance',
                                    style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.cardBg,
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(color: AppColors.hairline),
                            ),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              color: AppColors.textSecondary,
                              size: 18,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Ay seçici
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildMonthNavButton(Icons.chevron_left, () => _changeMonth(-1)),
                          SizedBox(
                            width: 120,
                            child: Text(
                              DateFormat('MMMM yyyy', 'tr_TR').format(DateTime(_selectedYear, _selectedMonth)),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _buildMonthNavButton(
                            Icons.chevron_right,
                            _isCurrentMonth ? null : () => _changeMonth(1),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Bakiye kartı — halka + rakam
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppColors.hairline),
                        ),
                        child: Row(
                          children: [
                            _buildBalanceRing(),
                            const SizedBox(width: 18),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'BAKİYE',
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                                ),
                                const SizedBox(height: 2),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      const TextSpan(text: '₺', style: TextStyle(color: AppColors.accent, fontSize: 22, fontWeight: FontWeight.w800)),
                                      TextSpan(
                                        text: _balance.toStringAsFixed(0),
                                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 30, fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Gelir / Gider çipleri
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'Gelir',
                              _totalIncome,
                              AppColors.green,
                              Icons.arrow_downward_rounded,
                              1.0,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryCard(
                              'Gider',
                              _totalExpense,
                              AppColors.red,
                              Icons.arrow_upward_rounded,
                              _totalIncome == 0 ? 0 : (_totalExpense / _totalIncome).clamp(0, 1),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Son İşlemler başlığı
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Son İşlemler',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '$_transactionCount işlem',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Son işlemler listesi
                      if (_recentTransactions.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                            child: Text(
                              'Henüz işlem yok\n+ butonuyla ilk işleminizi ekleyin',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                            ),
                          ),
                        )
                      else
                        ...(_recentTransactions.map((t) => TransactionCard(
                              description: t['description'] ?? '',
                              amount: (t['amount'] ?? 0).toDouble(),
                              type: t['type'] ?? 2,
                              categoryName: _getCategoryName(t),
                              date: _formatDate(t['transactionDate']),
                            ))),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildMonthNavButton(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return Container(
      width: 30,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairline),
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: enabled ? AppColors.textSecondary : AppColors.textMuted),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _buildBalanceRing() {
    return Container(
      width: 68,
      height: 68,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [AppColors.accentDark, AppColors.accent, AppColors.accentDark],
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(color: AppColors.cardBg, shape: BoxShape.circle),
        child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.accent, size: 26),
      ),
    );
  }

  Widget _buildSummaryCard(String title, double amount, Color color, IconData icon, num fillRatio) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '₺${amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: fillRatio.toDouble(),
              minHeight: 4,
              backgroundColor: AppColors.cardBgLight,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
