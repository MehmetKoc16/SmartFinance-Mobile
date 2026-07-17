import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
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
      DashboardScreen(key: UniqueKey()),
      const InvestmentsScreen(),
      const SizedBox(),
      TransactionsScreen(key: UniqueKey()),
      const ProfileScreen(),
    ];
  }

  void _refreshPages() {
    setState(() {
      _pages[0] = DashboardScreen(key: UniqueKey());
      _pages[3] = TransactionsScreen(key: UniqueKey());
    });
  }

  static const _tabs = [
    (icon: Icons.home_rounded, label: 'Ana Sayfa'),
    (icon: Icons.show_chart_rounded, label: 'Yatırımlar'),
    null, // ortadaki FAB yuvası
    (icon: Icons.receipt_long_rounded, label: 'İşlemler'),
    (icon: Icons.person_rounded, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(8, 0, 8, 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (index) {
              final tab = _tabs[index];
              if (tab == null) {
                return Transform.translate(
                  offset: const Offset(0, -14),
                  child: GestureDetector(
                    onTap: _showAddMenu,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                      child: const Icon(Icons.add, color: Colors.white, size: 26),
                    ),
                  ),
                );
              }
              final isActive = index == _currentIndex;
              return GestureDetector(
                onTap: () => setState(() => _currentIndex = index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.cardBgLight : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tab.icon, size: 20, color: isActive ? AppColors.textPrimary : AppColors.textMuted),
                      const SizedBox(height: 3),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isActive ? AppColors.textPrimary : AppColors.textMuted,
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
