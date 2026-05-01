import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';
import '../services/api_service.dart';
import '../widgets/transaction_card.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<dynamic> _transactions = [];
  Map<int, String> _categoryMap = {};
  bool _isLoading = true;
  int _currentPage = 1;
  int _totalPages = 1;
  int _selectedFilter = 0; // 0=Tümü, 1=Gelir, 2=Gider
  final int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadTransactions();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await ApiService.authenticatedGet('/category');
      if (categories is List) {
        setState(() {
          _categoryMap = {for (var c in categories) c['id'] as int: c['name'] as String};
        });
      }
    } catch (_) {}
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);

    try {
      String endpoint = '/transaction/filter?page=$_currentPage&pageSize=$_pageSize';

      if (_selectedFilter > 0) {
        endpoint += '&type=$_selectedFilter';
      }

      final response = await ApiService.authenticatedGet(endpoint);

      if (response is Map && response.containsKey('items')) {
        setState(() {
          _transactions = response['items'] ?? [];
          _totalPages = response['totalPages'] ?? 1;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _getCategoryName(dynamic transaction) {
    final catId = transaction['categoryId'];
    if (catId != null && _categoryMap.containsKey(catId)) {
      return _categoryMap[catId]!;
    }
    return transaction['categoryName'] ?? 'Kategori';
  }

  void _onFilterChanged(int filter) {
    setState(() {
      _selectedFilter = filter;
      _currentPage = 1;
    });
    _loadTransactions();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM', 'tr_TR').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İşlemler')),
      body: Column(
        children: [
          // Filtre chip'leri
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('Tümü', 0),
                const SizedBox(width: 10),
                _buildFilterChip('Gelir', 1),
                const SizedBox(width: 10),
                _buildFilterChip('Gider', 2),
              ],
            ),
          ),

          // İşlem listesi
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.purple))
                : _transactions.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadTransactions,
                        color: AppColors.purple,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _transactions.length,
                          itemBuilder: (context, index) {
                            final t = _transactions[index];
                            return TransactionCard(
                              description: t['description'] ?? '',
                              amount: (t['amount'] ?? 0).toDouble(),
                              type: t['type'] ?? 2,
                              categoryName: _getCategoryName(t),
                              date: _formatDate(t['transactionDate']),
                            );
                          },
                        ),
                      ),
          ),

          // Sayfalama
          if (!_isLoading && _transactions.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _currentPage > 1
                        ? () {
                            setState(() => _currentPage--);
                            _loadTransactions();
                          }
                        : null,
                    icon: Icon(
                      Icons.chevron_left,
                      color: _currentPage > 1 ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Sayfa $_currentPage / $_totalPages',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    onPressed: _currentPage < _totalPages
                        ? () {
                            setState(() => _currentPage++);
                            _loadTransactions();
                          }
                        : null,
                    icon: Icon(
                      Icons.chevron_right,
                      color: _currentPage < _totalPages ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int value) {
    final isActive = _selectedFilter == value;
    return GestureDetector(
      onTap: () => _onFilterChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: isActive ? AppColors.gradientPurple : null,
          color: isActive ? null : AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded, size: 64, color: AppColors.textMuted.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'Henüz işlem yok',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'İlk işleminizi eklemek için + butonuna tıklayın',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
