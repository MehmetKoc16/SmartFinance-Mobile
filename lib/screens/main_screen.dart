import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/constants/app_colors.dart';
import '../core/theme/app_tokens.dart';
import 'dashboard_screen.dart';
import 'transactions_screen.dart';
import 'add_transaction_screen.dart';
import 'categories_screen.dart';
import 'profile_screen.dart';
import 'investments_screen.dart';
import 'pdf_import_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardScreen(key: UniqueKey(), onSeeAllTransactions: () => setState(() => _currentIndex = 3)),
      const InvestmentsScreen(),
      const SizedBox(),
      TransactionsScreen(key: UniqueKey()),
      const ProfileScreen(),
    ];
  }

  void _refreshPages() {
    setState(() {
      _pages[0] = DashboardScreen(key: UniqueKey(), onSeeAllTransactions: () => setState(() => _currentIndex = 3));
      _pages[3] = TransactionsScreen(key: UniqueKey());
    });
  }

  static const _tabs = [
    (icon: LucideIcons.house, label: 'Ana Sayfa'),
    (icon: LucideIcons.trendingUp, label: 'Yatırımlar'),
    null, // ortadaki FAB yuvası
    (icon: LucideIcons.list, label: 'İşlemler'),
    (icon: LucideIcons.user, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: t.navBg,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 32, offset: const Offset(0, 12))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (index) {
              final tab = _tabs[index];
              if (tab == null) {
                return Transform.translate(
                  offset: const Offset(0, -15),
                  child: GestureDetector(
                    onTap: _showAddMenu,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: t.brand,
                        shape: BoxShape.circle,
                        border: Border.all(color: t.bg, width: 4),
                        boxShadow: [BoxShadow(color: t.brand.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: const Icon(LucideIcons.plus, color: Colors.white, size: 26),
                    ),
                  ),
                );
              }
              final isActive = index == _currentIndex;
              final color = isActive ? t.brand : t.textTert;
              return GestureDetector(
                onTap: () => setState(() => _currentIndex = index),
                child: SizedBox(
                  width: 56,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tab.icon, size: 22, color: color),
                      const SizedBox(height: 3),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            const Text('İşlem Ekle', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            _buildAddOption(Icons.edit_note_rounded, 'Elle Ekle', 'Gelir veya gider ekle', AppColors.accent, onTap: () async {
              Navigator.pop(context);
              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTransactionScreen()));
              if (result == true) _refreshPages();
            }),
            const SizedBox(height: 12),
            _buildAddOption(Icons.category_rounded, 'Kategoriler', 'Kategori ekle veya düzenle', AppColors.accent, onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen()));
            }),
            const SizedBox(height: 12),
            _buildAddOption(Icons.picture_as_pdf_rounded, 'PDF ile Ekle', 'Banka ekstresini içe aktar', AppColors.orange, onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfImportScreen())).then((_) => _refreshPages());
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOption(IconData icon, String title, String subtitle, Color color, {VoidCallback? onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: AppColors.cardBgLight,
      onTap: onTap,
    );
  }
}
