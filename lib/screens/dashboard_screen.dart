import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';
import '../services/api_service.dart';
import '../widgets/donut_chart.dart';
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
            ? const Center(child: CircularProgressIndicator(color: AppColors.purple))
            : RefreshIndicator(
                onRefresh: _loadDashboardData,
                color: AppColors.purple,
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
                              Text(
                                'Merhaba 👋',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'SmartFinance',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.cardBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Ay seçici
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () => _changeMonth(-1),
                              icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                            Text(
                              DateFormat('MMMM yyyy', 'tr_TR').format(DateTime(_selectedYear, _selectedMonth)),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            IconButton(
                              onPressed: _isCurrentMonth ? null : () => _changeMonth(1),
                              icon: Icon(
                                Icons.chevron_right,
                                color: _isCurrentMonth ? AppColors.textMuted : AppColors.textSecondary,
                              ),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Donut chart
                      DonutChart(
                        totalIncome: _totalIncome,
                        totalExpense: _totalExpense,
                        balance: _balance,
                      ),

                      const SizedBox(height: 24),

                      // Gelir / Gider kartları
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'Gelir',
                              _totalIncome,
                              AppColors.green,
                              Icons.arrow_downward_rounded,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildSummaryCard(
                              'Gider',
                              _totalExpense,
                              AppColors.red,
                              Icons.arrow_upward_rounded,
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

  Widget _buildSummaryCard(String title, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₺${amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
