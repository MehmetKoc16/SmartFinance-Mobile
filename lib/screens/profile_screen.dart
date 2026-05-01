import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  double _totalIncome = 0;
  double _totalExpense = 0;
  int _transactionCount = 0;
  int _categoryCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final now = DateTime.now();

      // Aylık özet
      final summary = await ApiService.authenticatedGet(
        '/transaction/summary/${now.year}/${now.month}',
      );

      // Kategoriler
      final categories = await ApiService.authenticatedGet('/category');

      if (mounted) {
        setState(() {
          _totalIncome = (summary['totalIncome'] ?? 0).toDouble();
          _totalExpense = (summary['totalExpense'] ?? 0).toDouble();
          _transactionCount = summary['transactionCount'] ?? 0;
          _categoryCount = categories is List ? categories.length : 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
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

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Çıkış Yap', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.purple))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Avatar
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: AppColors.gradientPurpleCyan,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'SF',
                          style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'SmartFinance',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Premium Kullanıcı',
                      style: TextStyle(color: AppColors.purple, fontSize: 14),
                    ),

                    const SizedBox(height: 32),

                    // İstatistik kartları
                    Row(
                      children: [
                        Expanded(child: _buildStatCard('İşlemler', '$_transactionCount', Icons.receipt_long_rounded)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard('Kategoriler', '$_categoryCount', Icons.category_rounded)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Gelir',
                            '₺${_totalIncome.toStringAsFixed(0)}',
                            Icons.arrow_downward_rounded,
                            valueColor: AppColors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Gider',
                            '₺${_totalExpense.toStringAsFixed(0)}',
                            Icons.arrow_upward_rounded,
                            valueColor: AppColors.red,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Ayarlar listesi
                    _buildSettingsTile(Icons.person_rounded, 'Profil Düzenle', () {}),
                    _buildSettingsTile(Icons.notifications_rounded, 'Bildirimler', () {}),
                    _buildSettingsTile(Icons.palette_rounded, 'Tema', () {}),
                    _buildSettingsTile(Icons.lock_rounded, 'Şifre Değiştir', () {}),
                    _buildSettingsTile(Icons.help_outline_rounded, 'Yardım', () {}),

                    const SizedBox(height: 16),

                    // Çıkış yap
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.red.withOpacity(0.3)),
                      ),
                      child: TextButton.icon(
                        onPressed: _showLogoutConfirmation,
                        icon: const Icon(Icons.logout, color: AppColors.red),
                        label: const Text('Çıkış Yap', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w600)),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Versiyon
                    const Text(
                      'SmartFinance v1.0.0',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textMuted, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
      ),
    );
  }
}
