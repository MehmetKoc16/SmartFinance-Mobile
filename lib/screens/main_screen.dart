import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'transactions_screen.dart';
import 'add_transaction_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Dashboard ve Transactions için GlobalKey (yenileme için)
  final _dashboardKey = GlobalKey<State>();
  final _transactionsKey = GlobalKey<State>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardScreen(key: _dashboardKey),
      const _PlaceholderPage(title: 'Yatırımlar', icon: Icons.show_chart_rounded),
      const SizedBox(), // Ortadaki + butonu için boş sayfa
      TransactionsScreen(key: _transactionsKey),
      _ProfilePage(onLogout: _logout),
    ];
  }

  Future<void> _logout() async {
    await ApiService.removeToken();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.cardBg,
          border: Border(top: BorderSide(color: AppColors.cardBgLight, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index == 2) {
              _showAddMenu();
            } else {
              setState(() => _currentIndex = index);
            }
          },
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Ana Sayfa',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.show_chart_rounded),
              label: 'Yatırımlar',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  gradient: AppColors.gradientPurple,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
              label: '',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded),
              label: 'İşlemler',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
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
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'İşlem Ekle',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            _buildAddOption(
              Icons.edit_note_rounded,
              'Elle Ekle',
              'Gelir veya gider ekle',
              AppColors.purple,
              onTap: () async {
                Navigator.pop(context); // Bottom sheet kapat
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
                );
                // Yeni işlem eklendiyse sayfaları yenile
                if (result == true) {
                  setState(() {
                    _pages[0] = DashboardScreen(key: UniqueKey());
                    _pages[3] = TransactionsScreen(key: UniqueKey());
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            _buildAddOption(
              Icons.picture_as_pdf_rounded,
              'PDF ile Ekle',
              'Banka ekstresini yükle (AI)',
              AppColors.cyan,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 12),
            _buildAddOption(
              Icons.camera_alt_rounded,
              'Fotoğraf Çek',
              'Fiş veya fatura tara',
              AppColors.orange,
              onTap: () => Navigator.pop(context),
            ),
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
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
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

// Yatırımlar placeholder (Faz 4'te değişecek)
class _PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderPage({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 24)),
            const SizedBox(height: 8),
            const Text('Yakında...', style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

// Profil sayfası (Faz 3'te tam ekranla değişecek)
class _ProfilePage extends StatelessWidget {
  final VoidCallback onLogout;

  const _ProfilePage({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.red),
            onPressed: onLogout,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.gradientPurpleCyan,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('SF', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('SmartFinance Kullanıcısı', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 32),
            TextButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout, color: AppColors.red),
              label: const Text('Çıkış Yap', style: TextStyle(color: AppColors.red)),
            ),
          ],
        ),
      ),
    );
  }
}
