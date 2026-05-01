import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../services/api_service.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<dynamic> _categories = [];
  bool _isLoading = true;

  // Kategori ikonları ve renkleri
  final List<Map<String, dynamic>> _categoryStyles = [
    {'icon': Icons.restaurant_rounded, 'color': AppColors.orange},
    {'icon': Icons.shopping_cart_rounded, 'color': AppColors.cyan},
    {'icon': Icons.directions_bus_rounded, 'color': AppColors.purple},
    {'icon': Icons.attach_money_rounded, 'color': AppColors.green},
    {'icon': Icons.card_giftcard_rounded, 'color': AppColors.green},
    {'icon': Icons.receipt_rounded, 'color': AppColors.red},
    {'icon': Icons.home_rounded, 'color': const Color(0xFF8B5CF6)},
    {'icon': Icons.health_and_safety_rounded, 'color': const Color(0xFFEC4899)},
    {'icon': Icons.school_rounded, 'color': const Color(0xFF3B82F6)},
    {'icon': Icons.sports_esports_rounded, 'color': const Color(0xFFF97316)},
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.authenticatedGet('/category');
      if (response is List) {
        setState(() {
          _categories = response;
          _isLoading = false;
        });
      } else if (response is Map && response.containsKey('items')) {
        setState(() {
          _categories = response['items'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _getStyle(int index) {
    return _categoryStyles[index % _categoryStyles.length];
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    int selectedType = 2; // varsayılan: Gider

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Yeni Kategori', style: TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Kategori adı',
                  prefixIcon: Icon(Icons.category_rounded, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setDialogState(() => selectedType = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selectedType == 1 ? AppColors.green.withOpacity(0.2) : AppColors.cardBgLight,
                          borderRadius: BorderRadius.circular(10),
                          border: selectedType == 1 ? Border.all(color: AppColors.green) : null,
                        ),
                        child: Center(
                          child: Text('Gelir', style: TextStyle(
                            color: selectedType == 1 ? AppColors.green : AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          )),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setDialogState(() => selectedType = 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selectedType == 2 ? AppColors.red.withOpacity(0.2) : AppColors.cardBgLight,
                          borderRadius: BorderRadius.circular(10),
                          border: selectedType == 2 ? Border.all(color: AppColors.red) : null,
                        ),
                        child: Center(
                          child: Text('Gider', style: TextStyle(
                            color: selectedType == 2 ? AppColors.red : AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          )),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty) return;
                Navigator.pop(context);
                await ApiService.authenticatedPost('/category', {
                  'name': nameController.text,
                  'type': selectedType,
                });
                _loadCategories();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(dynamic category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Kategoriyi Sil', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '"${category['name']}" kategorisini silmek istediğinize emin misiniz?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ApiService.authenticatedGet('/category/${category['id']}');
              // DELETE isteği için özel metot lazım, şimdilik GET ile silme yok
              // İleride authenticatedDelete eklenecek
              _loadCategories();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategoriler'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.purple),
            onPressed: _showAddCategoryDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.purple))
          : _categories.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadCategories,
                  color: AppColors.purple,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final style = _getStyle(index);
                      final isIncome = cat['type'] == 1;

                      return GestureDetector(
                        onLongPress: () => _showDeleteConfirmation(cat),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: (style['color'] as Color).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(style['icon'] as IconData, color: style['color'] as Color, size: 22),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isIncome
                                          ? AppColors.green.withOpacity(0.12)
                                          : AppColors.red.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isIncome ? 'Gelir' : 'Gider',
                                      style: TextStyle(
                                        color: isIncome ? AppColors.green : AppColors.red,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                cat['name'] ?? 'Kategori',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_rounded, size: 64, color: AppColors.textMuted.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('Henüz kategori yok', style: TextStyle(color: AppColors.textSecondary, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Sağ üstteki + ile kategori ekleyin', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}
