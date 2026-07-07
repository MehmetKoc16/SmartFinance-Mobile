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
  List<dynamic> _categories = [];
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
          _categories = categories;
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

  // ─── SİLME DİALOG'U ──────────────────────────────────────

  Future<void> _showDeleteDialog(int id, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('İşlemi Sil', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Bu işlemi silmek istediğinize emin misiniz?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ApiService.authenticatedDelete('/transaction/$id');
      setState(() {
        _transactions.removeAt(index);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('İşlem silindi.'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // ─── DÜZENLEME BOTTOM SHEET ───────────────────────────────

  void _showEditDialog(dynamic t) {
    final amountCtrl = TextEditingController(text: (t['amount'] ?? 0).toString());
    final descCtrl = TextEditingController(text: t['description'] ?? '');
    int selectedType = t['type'] ?? 2;
    int? selectedCategoryId = t['categoryId'];
    DateTime selectedDate = DateTime.tryParse(t['transactionDate'] ?? '') ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sürükleme çubuğu
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('İşlemi Düzenle',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),

                // Gelir / Gider toggle
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() => selectedType = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: selectedType == 1 ? AppColors.green.withValues(alpha: 0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: selectedType == 1 ? Border.all(color: AppColors.green, width: 1.5) : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_downward_rounded,
                                    color: selectedType == 1 ? AppColors.green : AppColors.textMuted, size: 20),
                                const SizedBox(width: 8),
                                Text('Gelir', style: TextStyle(
                                  color: selectedType == 1 ? AppColors.green : AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                )),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() => selectedType = 2),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: selectedType == 2 ? AppColors.red.withValues(alpha: 0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: selectedType == 2 ? Border.all(color: AppColors.red, width: 1.5) : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_upward_rounded,
                                    color: selectedType == 2 ? AppColors.red : AppColors.textMuted, size: 20),
                                const SizedBox(width: 8),
                                Text('Gider', style: TextStyle(
                                  color: selectedType == 2 ? AppColors.red : AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                )),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Tutar
                const Text('Tutar', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
                      child: Text('₺', style: TextStyle(color: AppColors.purple, fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Açıklama
                const Text('Açıklama', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Açıklama girin',
                    prefixIcon: Icon(Icons.description_outlined, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 16),

                // Tarih
                const Text('Tarih', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.dark(primary: AppColors.purple, surface: AppColors.cardBg),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setSheetState(() => selectedDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.cardBgLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, color: AppColors.textMuted, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('dd MMMM yyyy', 'tr_TR').format(selectedDate),
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Kategori
                const Text('Kategori', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBgLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: selectedCategoryId,
                      hint: const Text('Kategori seçin', style: TextStyle(color: AppColors.textMuted)),
                      dropdownColor: AppColors.cardBg,
                      icon: const Icon(Icons.expand_more, color: AppColors.textMuted),
                      items: _categories.map<DropdownMenuItem<int>>((cat) {
                        return DropdownMenuItem<int>(
                          value: cat['id'],
                          child: Text(cat['name'] ?? 'Kategori', style: const TextStyle(color: AppColors.textPrimary)),
                        );
                      }).toList(),
                      onChanged: (value) => setSheetState(() => selectedCategoryId = value),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Güncelle butonu
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientPurple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: const Text('Geçerli bir tutar giriniz!'),
                              backgroundColor: AppColors.red, behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        );
                        return;
                      }
                      if (descCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: const Text('Açıklama giriniz!'),
                              backgroundColor: AppColors.red, behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        );
                        return;
                      }
                      if (selectedCategoryId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: const Text('Kategori seçiniz!'),
                              backgroundColor: AppColors.red, behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        );
                        return;
                      }

                      await ApiService.authenticatedPut('/transaction/${t['id']}', {
                        'amount': amount,
                        'description': descCtrl.text,
                        'transactionDate': selectedDate.toIso8601String(),
                        'type': selectedType,
                        'categoryId': selectedCategoryId,
                      });

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      _loadTransactions();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('İşlem güncellendi!'),
                            backgroundColor: AppColors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                    child: const Text('Güncelle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
                            return GestureDetector(
                              onTap: () => _showEditDialog(t),
                              onLongPress: () => _showDeleteDialog(t['id'], index),
                              child: TransactionCard(
                                description: t['description'] ?? '',
                                amount: (t['amount'] ?? 0).toDouble(),
                                type: t['type'] ?? 2,
                                categoryName: _getCategoryName(t),
                                date: _formatDate(t['transactionDate']),
                              ),
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
          Icon(Icons.receipt_long_rounded, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
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
