import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/formatters.dart';
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
  final int _pageSize = 15;
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadTransactions();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
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
      if (_searchCtrl.text.trim().isNotEmpty) {
        endpoint += '&search=${Uri.encodeQueryComponent(_searchCtrl.text.trim())}';
      }

      final response = await ApiService.authenticatedGet(endpoint);
      if (!mounted) return;

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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      _currentPage = 1;
      _loadTransactions();
    });
  }

  String _getCategoryName(dynamic transaction) {
    final catId = transaction['categoryId'];
    if (catId != null && _categoryMap.containsKey(catId)) {
      return _categoryMap[catId]!;
    }
    return '';
  }

  void _onFilterChanged(int filter) {
    setState(() {
      _selectedFilter = filter;
      _currentPage = 1;
    });
    _loadTransactions();
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

  List<MapEntry<String, List<dynamic>>> _groupByDay() {
    final Map<String, List<dynamic>> grouped = {};
    final List<String> order = [];
    for (final t in _transactions) {
      final day = _formatDay(t['transactionDate']);
      if (!grouped.containsKey(day)) {
        grouped[day] = [];
        order.add(day);
      }
      grouped[day]!.add(t);
    }
    return order.map((d) => MapEntry(d, grouped[d]!)).toList();
  }

  // ─── SİLME DİALOG'U ──────────────────────────────────────

  Future<void> _showDeleteDialog(int id, int index) async {
    final t = AppTokens.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('İşlemi Sil', style: TextStyle(color: t.text)),
        content: Text('Bu işlemi silmek istediğinize emin misiniz?', style: TextStyle(color: t.textSec)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal', style: TextStyle(color: t.textTert)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: t.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final result = await ApiService.authenticatedDelete('/transaction/$id');
      if (result is Map && result.containsKey('error')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error']),
              backgroundColor: t.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return;
      }
      setState(() {
        _transactions.removeAt(index);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('İşlem silindi.'),
            backgroundColor: t.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // ─── DÜZENLEME BOTTOM SHEET ───────────────────────────────

  void _showEditDialog(dynamic t) {
    final tk = AppTokens.of(context);
    final amountCtrl = TextEditingController(text: (t['amount'] ?? 0).toString());
    final descCtrl = TextEditingController(text: t['description'] ?? '');
    int selectedType = t['type'] ?? 2;
    int? selectedCategoryId = t['categoryId'];
    DateTime selectedDate = DateTime.tryParse(t['transactionDate'] ?? '') ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: tk.card,
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
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: tk.textTert, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Text('İşlemi Düzenle', style: jakarta(fontSize: 20, fontWeight: FontWeight.w700, color: tk.text)),
                const SizedBox(height: 20),

                // Gelir / Gider toggle
                Container(
                  decoration: BoxDecoration(color: tk.inputBg, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() => selectedType = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: selectedType == 1 ? tk.greenSoft : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: selectedType == 1 ? Border.all(color: tk.green, width: 1.5) : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.arrowDownLeft, color: selectedType == 1 ? tk.green : tk.textTert, size: 20),
                                const SizedBox(width: 8),
                                Text('Gelir', style: TextStyle(
                                  color: selectedType == 1 ? tk.green : tk.textTert,
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
                              color: selectedType == 2 ? tk.redSoft : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: selectedType == 2 ? Border.all(color: tk.red, width: 1.5) : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.arrowUpRight, color: selectedType == 2 ? tk.red : tk.textTert, size: 20),
                                const SizedBox(width: 8),
                                Text('Gider', style: TextStyle(
                                  color: selectedType == 2 ? tk.red : tk.textTert,
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

                Text('Tutar', style: TextStyle(color: tk.textSec, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: tk.text, fontSize: 20, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                      child: Text('₺', style: TextStyle(color: tk.brand, fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text('Açıklama', style: TextStyle(color: tk.textSec, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  style: TextStyle(color: tk.text),
                  decoration: InputDecoration(
                    hintText: 'Açıklama girin',
                    prefixIcon: Icon(LucideIcons.fileText, color: tk.textTert, size: 18),
                  ),
                ),
                const SizedBox(height: 16),

                Text('Tarih', style: TextStyle(color: tk.textSec, fontSize: 13)),
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
                          colorScheme: ColorScheme.dark(primary: tk.brand, surface: tk.card),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setSheetState(() => selectedDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(color: tk.inputBg, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(LucideIcons.calendar, color: tk.textTert, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('dd MMMM yyyy', 'tr_TR').format(selectedDate),
                          style: TextStyle(color: tk.text, fontSize: 15),
                        ),
                        const Spacer(),
                        Icon(LucideIcons.chevronRight, color: tk.textTert),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text('Kategori', style: TextStyle(color: tk.textSec, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: tk.inputBg, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: selectedCategoryId,
                      hint: Text('Kategori seçin', style: TextStyle(color: tk.textTert)),
                      dropdownColor: tk.card,
                      icon: Icon(LucideIcons.chevronDown, color: tk.textTert),
                      items: _categories.map<DropdownMenuItem<int>>((cat) {
                        return DropdownMenuItem<int>(
                          value: cat['id'],
                          child: Text(cat['name'] ?? 'Kategori', style: TextStyle(color: tk.text)),
                        );
                      }).toList(),
                      onChanged: (value) => setSheetState(() => selectedCategoryId = value),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: const Text('Geçerli bir tutar giriniz!'),
                              backgroundColor: tk.red, behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        );
                        return;
                      }
                      if (descCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: const Text('Açıklama giriniz!'),
                              backgroundColor: tk.red, behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        );
                        return;
                      }
                      if (selectedCategoryId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: const Text('Kategori seçiniz!'),
                              backgroundColor: tk.red, behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        );
                        return;
                      }

                      final result = await ApiService.authenticatedPut('/transaction/${t['id']}', {
                        'amount': amount,
                        'description': descCtrl.text,
                        'transactionDate': selectedDate.toIso8601String(),
                        'type': selectedType,
                        'categoryId': selectedCategoryId,
                      });

                      if (result is Map && result.containsKey('error')) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(result['error']),
                              backgroundColor: tk.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                        return;
                      }

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      _loadTransactions();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('İşlem güncellendi!'),
                            backgroundColor: tk.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    },
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
    final t = AppTokens.of(context);
    final groups = _groupByDay();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('İşlemler', style: jakarta(fontSize: 20, fontWeight: FontWeight.w700, color: t.text)),
              const SizedBox(height: 14),

              // Arama
              TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                style: TextStyle(color: t.text, fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: 'Ara...',
                  prefixIcon: Icon(LucideIcons.search, color: t.textSec, size: 17),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              // Filtre çipleri
              Row(
                children: [
                  _buildFilterChip(t, 'Tümü', 0),
                  const SizedBox(width: 8),
                  _buildFilterChip(t, 'Gelir', 1),
                  const SizedBox(width: 8),
                  _buildFilterChip(t, 'Gider', 2),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: t.brand))
                    : _transactions.isEmpty
                        ? _buildEmptyState(t)
                        : RefreshIndicator(
                            onRefresh: _loadTransactions,
                            color: t.brand,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: groups.length,
                              itemBuilder: (context, groupIndex) {
                                final group = groups[groupIndex];
                                final net = group.value.fold<double>(0, (sum, tx) {
                                  final amt = (tx['amount'] ?? 0).toDouble();
                                  return sum + ((tx['type'] ?? 2) == 1 ? amt : -amt);
                                });
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(group.key, style: TextStyle(color: t.textSec, fontSize: 13, fontWeight: FontWeight.w600)),
                                            Text(
                                              (net >= 0 ? '+' : '') + formatTRY(net),
                                              style: TextStyle(
                                                color: net >= 0 ? t.green : t.red,
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: t.card,
                                          border: Border.all(color: t.border),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: Column(
                                          children: [
                                            for (var i = 0; i < group.value.length; i++)
                                              GestureDetector(
                                                onLongPress: () => _showDeleteDialog(
                                                  group.value[i]['id'],
                                                  _transactions.indexOf(group.value[i]),
                                                ),
                                                child: TransactionCard(
                                                  description: group.value[i]['description'] ?? '',
                                                  merchantName: group.value[i]['merchantName'],
                                                  amount: (group.value[i]['amount'] ?? 0).toDouble(),
                                                  type: group.value[i]['type'] ?? 2,
                                                  categoryName: _getCategoryName(group.value[i]),
                                                  date: '',
                                                  showDivider: i != group.value.length - 1,
                                                  onTap: () => _showEditDialog(group.value[i]),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
              ),

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
                        icon: Icon(LucideIcons.chevronLeft, color: _currentPage > 1 ? t.text : t.textTert),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: t.card, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(8)),
                        child: Text('Sayfa $_currentPage / $_totalPages', style: TextStyle(color: t.textSec, fontSize: 13)),
                      ),
                      IconButton(
                        onPressed: _currentPage < _totalPages
                            ? () {
                                setState(() => _currentPage++);
                                _loadTransactions();
                              }
                            : null,
                        icon: Icon(LucideIcons.chevronRight, color: _currentPage < _totalPages ? t.text : t.textTert),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(AppTokens t, String label, int value) {
    final isActive = _selectedFilter == value;
    return GestureDetector(
      onTap: () => _onFilterChanged(value),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? t.brand : t.card,
          border: Border.all(color: isActive ? t.brand : t.border),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : t.textSec,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppTokens t) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.receipt, size: 56, color: t.textTert),
          const SizedBox(height: 16),
          Text('Henüz işlem yok', style: TextStyle(color: t.textSec, fontSize: 18)),
          const SizedBox(height: 8),
          Text('İlk işleminizi eklemek için + butonuna dokunun', style: TextStyle(color: t.textTert, fontSize: 13)),
        ],
      ),
    );
  }
}
