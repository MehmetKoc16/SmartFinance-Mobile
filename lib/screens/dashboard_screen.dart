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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();

      // Aylık özet
      final summary = await ApiService.authenticatedGet(
        '/transaction/summary/${now.year}/${now.month}',
      );

      // Son işlemler
      final transactions = await ApiService.authenticatedGet(
        '/transaction/filter?page=1&pageSize=5',
      );

      if (mounted) {
        setState(() {
          _totalIncome = (summary['totalIncome'] ?? 0).toDouble();
          _totalExpense = (summary['totalExpense'] ?? 0).toDouble();
          _balance = (summary['balance'] ?? 0).toDouble();
          _transactionCount = summary['transactionCount'] ?? 0;
          _recentTransactions = transactions['items'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
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

                      const SizedBox(height: 28),

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
                              categoryName: t['categoryName'] ?? t['category']?['name'] ?? 'Kategori',
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
