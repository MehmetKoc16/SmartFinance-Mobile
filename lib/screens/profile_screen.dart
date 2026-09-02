import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../core/theme/theme_controller.dart';
import '../core/utils/formatters.dart';
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
  String _userName = '';
  String _userEmail = '';
  bool _notifOn = true;

  static const _notifPrefsKey = 'notifications_enabled';

  String get _initials {
    final parts = _userName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return 'SF';
  }

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();

      final me = await ApiService.authenticatedGet('/auth/me');
      if (me is Map) {
        _userName = me['fullName'] ?? '';
        _userEmail = me['email'] ?? '';
      }

      final summary = await ApiService.authenticatedGet(
        '/transaction/summary/${now.year}/${now.month}',
      );

      final categories = await ApiService.authenticatedGet('/category');

      if (mounted) {
        setState(() {
          _totalIncome = (summary['totalIncome'] ?? 0).toDouble();
          _totalExpense = (summary['totalExpense'] ?? 0).toDouble();
          _transactionCount = summary['transactionCount'] ?? 0;
          _categoryCount = categories is List ? categories.length : 0;
          _notifOn = prefs.getBool(_notifPrefsKey) ?? true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleNotif() async {
    setState(() => _notifOn = !_notifOn);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifPrefsKey, _notifOn);
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  void _showLogoutConfirmation() {
    final t = AppTokens.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: t.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Çıkış Yap', style: TextStyle(color: t.text)),
        content: Text('Hesabınızdan çıkış yapmak istediğinize emin misiniz?', style: TextStyle(color: t.textSec)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal', style: TextStyle(color: t.textTert)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: t.red),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }

  // ─── PROFİL DÜZENLE ─────────────────────────────────────

  void _showEditProfileSheet() {
    final t = AppTokens.of(context);
    final nameCtrl = TextEditingController(text: _userName);
    final emailCtrl = TextEditingController(text: _userEmail);
    bool isSubmitting = false;
    // Ayni gerekce: modal alt sayfada SnackBar klavyenin arkasinda kaliyor.
    String? hata;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: t.textTert, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Profil Düzenle', style: jakarta(fontSize: 18, fontWeight: FontWeight.w700, color: t.text)),
                const SizedBox(height: 20),
                Text('Ad Soyad', style: TextStyle(color: t.textSec, fontSize: 12.5, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: t.text),
                  decoration: InputDecoration(hintText: 'Ad Soyad', prefixIcon: Icon(LucideIcons.user, color: t.textTert, size: 18)),
                ),
                const SizedBox(height: 14),
                Text('E-posta', style: TextStyle(color: t.textSec, fontSize: 12.5, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: t.text),
                  decoration: InputDecoration(hintText: 'ornek@eposta.com', prefixIcon: Icon(LucideIcons.mail, color: t.textTert, size: 18)),
                ),
                const SizedBox(height: 22),
                _sheetError(t, hata),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) {
                              setSheetState(() => hata = 'Tüm alanları doldurunuz!');
                              return;
                            }

                            setSheetState(() {
                              isSubmitting = true;
                              hata = null;
                            });

                            final result = await ApiService.authenticatedPut('/auth/profile', {
                              'fullName': nameCtrl.text.trim(),
                              'email': emailCtrl.text.trim(),
                            });

                            setSheetState(() => isSubmitting = false);

                            if (!mounted) return;
                            if (result is Map && result.containsKey('error')) {
                              setSheetState(() => hata = result['error']?.toString() ?? 'İşlem başarısız oldu.');
                              return;
                            }

                            setState(() {
                              _userName = result['fullName'] ?? _userName;
                              _userEmail = result['email'] ?? _userEmail;
                            });
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: const Text('Profil güncellendi!'),
                                  backgroundColor: t.green,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            );
                          },
                    child: isSubmitting
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Kaydet'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── ŞİFRE DEĞİŞTİRME ───────────────────────────────────

  int _strengthScore(String pw) {
    final len = pw.length;
    final variety = [RegExp(r'[a-z]'), RegExp(r'[A-Z]'), RegExp(r'[0-9]'), RegExp(r'[^a-zA-Z0-9]')]
        .where((r) => r.hasMatch(pw))
        .length;
    final score = (len / 3 * 0.5).floor() + variety;
    return score.clamp(0, 4);
  }

  /// Hesap silme akisi. Islem geri alinamadigi icin (a) ne silinecegi acikca
  /// yaziliyor, (b) sifre yeniden isteniyor. Google Play, hesap olusturan
  /// uygulamalarda uygulama icinden silme yolunu zorunlu tutuyor.
  void _showDeleteAccountSheet() {
    final t = AppTokens.of(context);
    final passwordCtrl = TextEditingController();
    bool isSubmitting = false;
    // Ayni gerekce: alt sayfada SnackBar gorunmuyor.
    String? hata;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: t.textTert, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(LucideIcons.triangleAlert, color: t.red, size: 20),
                    const SizedBox(width: 8),
                    Text('Hesabı Sil', style: jakarta(fontSize: 18, fontWeight: FontWeight.w700, color: t.red)),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: t.redSoft, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bu işlem geri alınamaz. Silinecekler:',
                        style: TextStyle(color: t.red, fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Tüm gelir ve gider işlemleriniz\n'
                        '• Yatırım portföyünüz\n'
                        '• Kategorileriniz ve bütçeleriniz\n'
                        '• Hesap bilgileriniz',
                        style: TextStyle(color: t.textSec, fontSize: 13, height: 1.6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text('Devam etmek için şifrenizi girin.', style: TextStyle(color: t.textSec, fontSize: 13.5)),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  style: TextStyle(color: t.text),
                  decoration: InputDecoration(
                    hintText: 'Şifreniz',
                    prefixIcon: Icon(LucideIcons.lock, color: t.textTert, size: 18),
                  ),
                ),
                const SizedBox(height: 22),
                _sheetError(t, hata),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: t.red, foregroundColor: Colors.white),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (passwordCtrl.text.isEmpty) {
                              setSheetState(() => hata = 'Şifrenizi giriniz!');
                              return;
                            }
                            setSheetState(() {
                              isSubmitting = true;
                              hata = null;
                            });

                            final result = await ApiService.authenticatedDelete(
                              '/auth/account',
                              {'password': passwordCtrl.text},
                            );

                            if (!ctx.mounted) return;

                            if (result is Map && result.containsKey('error')) {
                              setSheetState(() => isSubmitting = false);
                              setSheetState(() => hata = result['error'].toString());
                              return;
                            }

                            // Sunucudaki veri gitti; cihazdaki oturum da temizlenmeli.
                            await ApiService.removeToken();
                            if (!mounted) return;
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Hesabımı Kalıcı Olarak Sil', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Vazgeç', style: TextStyle(color: t.textSec)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showChangePasswordSheet() {
    final t = AppTokens.of(context);
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool isSubmitting = false;
    // Hata mesaji sayfanin ICINDE gosteriliyor. SnackBar ekranin en altina
    // ciziliyor ve modal alt sayfa + klavye orayi tamamen kapatiyor: mesaj
    // gosteriliyor ama kullaniciya hic ulasmiyordu.
    String? hata;
    int strength = 0;

    const strengthColors = ['red', 'red', 'amber', 'green', 'green'];
    const strengthLabels = ['Çok zayıf', 'Zayıf', 'Orta', 'Güçlü', 'Çok güçlü'];
    Color colorFor(String key, AppTokens t) => key == 'red' ? t.red : (key == 'amber' ? t.amber : t.green);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: t.textTert, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Şifre Değiştir', style: jakarta(fontSize: 18, fontWeight: FontWeight.w700, color: t.text)),
                const SizedBox(height: 20),
                TextField(
                  controller: currentCtrl,
                  obscureText: true,
                  style: TextStyle(color: t.text),
                  decoration: InputDecoration(hintText: 'Mevcut şifre', prefixIcon: Icon(LucideIcons.lock, color: t.textTert, size: 18)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newCtrl,
                  obscureText: true,
                  style: TextStyle(color: t.text),
                  onChanged: (v) => setSheetState(() => strength = _strengthScore(v)),
                  decoration: InputDecoration(hintText: 'Yeni şifre', prefixIcon: Icon(LucideIcons.lock, color: t.textTert, size: 18)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(4, (i) {
                    final filled = i < strength;
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                        height: 4,
                        decoration: BoxDecoration(
                          color: filled ? colorFor(strengthColors[strength], t) : t.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
                if (newCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(strengthLabels[strength], style: TextStyle(color: colorFor(strengthColors[strength], t), fontSize: 11.5)),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: confirmCtrl,
                  obscureText: true,
                  style: TextStyle(color: t.text),
                  decoration: InputDecoration(hintText: 'Yeni şifre (tekrar)', prefixIcon: Icon(LucideIcons.lock, color: t.textTert, size: 18)),
                ),
                const SizedBox(height: 22),
                _sheetError(t, hata),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (currentCtrl.text.isEmpty || newCtrl.text.isEmpty || confirmCtrl.text.isEmpty) {
                              setSheetState(() => hata = 'Tüm alanları doldurunuz!');
                              return;
                            }
                            if (newCtrl.text.length < 6) {
                              setSheetState(() => hata = 'Yeni şifre en az 6 karakter olmalıdır!');
                              return;
                            }
                            if (newCtrl.text != confirmCtrl.text) {
                              setSheetState(() => hata = 'Yeni şifreler eşleşmiyor!');
                              return;
                            }

                            setSheetState(() {
                              isSubmitting = true;
                              hata = null;
                            });

                            final result = await ApiService.authenticatedPut('/auth/change-password', {
                              'currentPassword': currentCtrl.text,
                              'newPassword': newCtrl.text,
                            });

                            setSheetState(() => isSubmitting = false);

                            if (mounted) {
                              if (result is Map && result.containsKey('error')) {
                                setSheetState(() => hata = result['error']?.toString() ?? 'Mevcut şifre hatalı!');
                              } else {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: const Text('Şifre başarıyla değiştirildi!'),
                                      backgroundColor: t.green,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                );
                              }
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Şifreyi Değiştir'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── YARDIM ──────────────────────────────────────────────

  static const _faqItems = [
    (
      q: 'İşlem nasıl eklerim?',
      a: 'Alt menüdeki + butonuna dokunup "Elle Ekle" ile gelir/gider girebilir, ya da "PDF ile Ekle" ile banka ekstrenizi içe aktarabilirsiniz.',
    ),
    (
      q: 'Hangi banka ekstrelerini içe aktarabilirim?',
      a: 'Şu an Halkbank ve Ziraat Bankası\'nın PDF ekstreleri, ayrıca Ziraat\'in Excel (.xlsx) formatı destekleniyor.',
    ),
    (
      q: 'Yatırım fiyatları nasıl güncelleniyor?',
      a: 'Hisse senedi, kripto para, döviz/altın ve TEFAS fonu fiyatları Yatırımlar ekranını her açtığınızda güncel piyasa verilerinden otomatik çekilir.',
    ),
    (
      q: 'Kategori nasıl eklerim veya silerim?',
      a: 'Kategoriler ekranındaki + butonuyla yeni kategori ekleyebilir, mevcut bir kategoriye uzun basarak silebilirsiniz.',
    ),
    (
      q: 'Verilerim güvende mi?',
      a: 'Tüm verileriniz yalnızca sizin hesabınıza özeldir, şifrelenmiş bağlantı üzerinden saklanır ve üçüncü taraflarla paylaşılmaz.',
    ),
  ];

  void _showHelpSheet() {
    final t = AppTokens.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
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
              const SizedBox(height: 20),
              Text('Yardım', style: jakarta(fontSize: 18, fontWeight: FontWeight.w700, color: t.text)),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final item in _faqItems)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.q, style: TextStyle(color: t.text, fontSize: 14, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(item.a, style: TextStyle(color: t.textSec, fontSize: 13, height: 1.4)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final themeController = context.watch<ThemeController>();

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: t.brand))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: t.brandSoft, shape: BoxShape.circle),
                      child: Text(_initials, style: jakarta(fontSize: 26, fontWeight: FontWeight.w700, color: t.brand)),
                    ),
                    const SizedBox(height: 10),
                    Text(_userName.isNotEmpty ? _userName : 'Kullanıcı',
                        style: jakarta(fontSize: 17, fontWeight: FontWeight.w600, color: t.text)),
                    const SizedBox(height: 2),
                    Text(_userEmail, style: TextStyle(color: t.textSec, fontSize: 13)),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(child: _statCard(t, 'İşlem Sayısı', '$_transactionCount', t.text)),
                        const SizedBox(width: 10),
                        Expanded(child: _statCard(t, 'Kategori Sayısı', '$_categoryCount', t.text)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _statCard(t, 'Aylık Gelir', formatTRY(_totalIncome, decimals: false), t.green)),
                        const SizedBox(width: 10),
                        Expanded(child: _statCard(t, 'Aylık Gider', formatTRY(_totalExpense, decimals: false), t.red)),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Container(
                      decoration: BoxDecoration(
                        color: t.card,
                        border: Border.all(color: t.border),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          _settingsRow(t, LucideIcons.userCog, 'Profil Düzenle',
                              onTap: _showEditProfileSheet, trailing: Icon(LucideIcons.chevronRight, color: t.textTert, size: 18)),
                          _settingsRow(
                            t,
                            LucideIcons.bell,
                            'Bildirimler',
                            trailing: GestureDetector(
                              onTap: _toggleNotif,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 42,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: _notifOn ? t.brand : t.inputBg,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: AnimatedAlign(
                                  duration: const Duration(milliseconds: 150),
                                  alignment: _notifOn ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    width: 20,
                                    height: 20,
                                    margin: const EdgeInsets.symmetric(horizontal: 2),
                                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.divider))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(LucideIcons.sunMoon, color: t.textSec, size: 18),
                                    const SizedBox(width: 12),
                                    Text('Tema', style: TextStyle(color: t.text, fontSize: 14)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(child: _themeChip(t, 'Açık', ThemeMode.light, themeController)),
                                    const SizedBox(width: 6),
                                    Expanded(child: _themeChip(t, 'Koyu', ThemeMode.dark, themeController)),
                                    const SizedBox(width: 6),
                                    Expanded(child: _themeChip(t, 'Sistem', ThemeMode.system, themeController)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          _settingsRow(
                            t,
                            LucideIcons.lock,
                            'Şifre Değiştir',
                            onTap: _showChangePasswordSheet,
                            trailing: Icon(LucideIcons.chevronRight, color: t.textTert, size: 18),
                          ),
                          _settingsRow(t, LucideIcons.circleHelp, 'Yardım',
                              onTap: _showHelpSheet, trailing: Icon(LucideIcons.chevronRight, color: t.textTert, size: 18)),
                          _settingsRow(t, LucideIcons.trash2, 'Hesabı Sil',
                              onTap: _showDeleteAccountSheet,
                              iconColor: t.red,
                              textColor: t.red,
                              trailing: Icon(LucideIcons.chevronRight, color: t.textTert, size: 18),
                              showDivider: false),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _showLogoutConfirmation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: t.redSoft,
                          foregroundColor: t.red,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: t.redSoft)),
                        ),
                        icon: Icon(LucideIcons.logOut, color: t.red, size: 18),
                        label: Text('Çıkış Yap', style: TextStyle(color: t.red, fontWeight: FontWeight.w600)),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Text('Wallet Mark v1.0.0', style: TextStyle(color: t.textTert, fontSize: 12)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _statCard(AppTokens t, String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: t.textSec, fontSize: 11.5)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _themeChip(AppTokens t, String label, ThemeMode mode, ThemeController controller) {
    final isSelected = controller.mode == mode;
    return GestureDetector(
      onTap: () => controller.setMode(mode),
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? t.brand : t.inputBg,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : t.textSec, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // iconColor/textColor: yikici islemleri (hesap silme) kirmizi gostermek icin.
  /// Alt sayfa icindeki hata mesaji.
  ///
  /// Neden SnackBar degil: SnackBar ekranin en altina ciziliyor, modal alt
  /// sayfa ve acik klavye orayi tamamen kapatiyor. Mesaj gosteriliyordu ama
  /// kullaniciya hic ulasmiyordu — "butona basiyorum hicbir sey olmuyor"
  /// sikayetinin sebebi buydu.
  Widget _sheetError(AppTokens t, String? hata) {
    if (hata == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: t.redSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.circleAlert, color: t.red, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(hata, style: TextStyle(color: t.red, fontSize: 13.5, height: 1.35)),
          ),
        ],
      ),
    );
  }

  Widget _settingsRow(AppTokens t, IconData icon, String title,
      {VoidCallback? onTap, Widget? trailing, bool showDivider = true, Color? iconColor, Color? textColor}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(border: showDivider ? Border(bottom: BorderSide(color: t.divider)) : null),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? t.textSec, size: 18),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(color: textColor ?? t.text, fontSize: 14))),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}
