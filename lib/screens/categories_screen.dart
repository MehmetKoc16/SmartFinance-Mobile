import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/constants/category_style.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/formatters.dart';
import '../services/api_service.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<dynamic> _categories = [];
  Map<int, double> _spendByCategory = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 1).subtract(const Duration(seconds: 1));

      final results = await Future.wait([
        ApiService.authenticatedGet('/category'),
        ApiService.authenticatedGet(
          '/transaction/filter?page=1&pageSize=100'
          '&startDate=${monthStart.toIso8601String()}&endDate=${monthEnd.toIso8601String()}',
        ),
      ]);

      final categories = results[0];
      final txResponse = results[1];

      final Map<int, double> spend = {};
      if (txResponse is Map && txResponse['items'] is List) {
        for (final t in (txResponse['items'] as List)) {
          final catId = t['categoryId'];
          if (catId == null) continue;
          final amt = (t['amount'] ?? 0).toDouble();
          spend[catId as int] = (spend[catId] ?? 0) + amt;
        }
      }

      if (mounted) {
        setState(() {
          _categories = categories is List ? categories : [];
          _spendByCategory = spend;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddCategoryDialog() {
    final t = AppTokens.of(context);
    final nameController = TextEditingController();
    int selectedType = 2; // varsayılan: Gider
    String selectedIcon = 'shopping-bag';
    Color selectedColor = CategoryStyles.colorPicker.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: t.textTert, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Yeni Kategori', style: jakarta(fontSize: 18, fontWeight: FontWeight.w700, color: t.text)),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  style: TextStyle(color: t.text),
                  decoration: const InputDecoration(hintText: 'Kategori adı'),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: t.inputBg, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() => selectedType = 2),
                          child: Container(
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selectedType == 2 ? t.brand : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text('Gider',
                                style: TextStyle(
                                    color: selectedType == 2 ? Colors.white : t.textSec,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() => selectedType = 1),
                          child: Container(
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selectedType == 1 ? t.brand : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Text('Gelir',
                                style: TextStyle(
                                    color: selectedType == 1 ? Colors.white : t.textSec,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Simge', style: TextStyle(color: t.textSec, fontSize: 12.5, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: CategoryStyles.iconByName.entries.map((e) {
                    final isSelected = selectedIcon == e.key;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedIcon = e.key),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isSelected ? t.brandSoft : t.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSelected ? t.brand : t.border, width: 2),
                        ),
                        child: Icon(e.value, color: t.text, size: 19),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text('Renk', style: TextStyle(color: t.textSec, fontSize: 12.5, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: CategoryStyles.colorPicker.map((c) {
                    final isSelected = selectedColor == c;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedColor = c),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(color: isSelected ? t.text : Colors.transparent, width: 2),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty) return;
                      Navigator.pop(ctx);
                      final colorHex =
                          '#${selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
                      final result = await ApiService.authenticatedPost('/category', {
                        'name': nameController.text.trim(),
                        'type': selectedType,
                        'icon': selectedIcon,
                        'color': colorHex,
                      });
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
                      _loadData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Kategori eklendi.'),
                            backgroundColor: t.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      }
                    },
                    child: const Text('Kaydet'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(dynamic category) {
    final t = AppTokens.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: t.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Kategoriyi Sil', style: TextStyle(color: t.text)),
        content: Text(
          '"${category['name']}" kategorisini silmek istediğinize emin misiniz?',
          style: TextStyle(color: t.textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal', style: TextStyle(color: t.textTert)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: t.red),
            onPressed: () async {
              Navigator.pop(context);
              final result = await ApiService.authenticatedDelete('/category/${category['id']}');
              if (result is Map && result.containsKey('error')) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
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
              _loadData();
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: const Text('Kategori silindi.'),
                    backgroundColor: t.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Kategoriler', style: jakarta(fontSize: 20, fontWeight: FontWeight.w700, color: t.text)),
                  GestureDetector(
                    onTap: _showAddCategoryDialog,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: t.brand, borderRadius: BorderRadius.circular(11)),
                      child: const Icon(LucideIcons.plus, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: t.brand))
                    : _categories.isEmpty
                        ? _buildEmptyState(t)
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            color: t.brand,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: t.card,
                                  border: Border.all(color: t.border),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  children: [
                                    for (var i = 0; i < _categories.length; i++)
                                      _buildCategoryRow(t, _categories[i], i != _categories.length - 1),
                                  ],
                                ),
                              ),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryRow(AppTokens t, dynamic cat, bool showDivider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = CategoryStyles.resolve(cat['name'] ?? '', icon: cat['icon'], color: cat['color']);
    final isIncome = cat['type'] == 1;
    final spend = _spendByCategory[cat['id']] ?? 0;

    return GestureDetector(
      onLongPress: () => _showDeleteConfirmation(cat),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(border: showDivider ? Border(bottom: BorderSide(color: t.divider)) : null),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: isDark ? 0.22 : 0.13),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(style.icon, color: style.color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cat['name'] ?? 'Kategori', style: TextStyle(color: t.text, fontSize: 14.5, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isIncome ? t.greenSoft : t.redSoft,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      isIncome ? 'Gelir' : 'Gider',
                      style: TextStyle(color: isIncome ? t.green : t.red, fontSize: 10.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            Text(formatTRY(spend), style: TextStyle(color: t.text, fontSize: 13.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppTokens t) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.tag, size: 56, color: t.textTert),
          const SizedBox(height: 16),
          Text('Henüz kategori yok', style: TextStyle(color: t.textSec, fontSize: 18)),
          const SizedBox(height: 8),
          Text('Sağ üstteki + ile kategori ekleyin', style: TextStyle(color: t.textTert, fontSize: 13)),
        ],
      ),
    );
  }
}
