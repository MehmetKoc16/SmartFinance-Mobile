import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../services/api_service.dart';
import 'register_screen.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    // Oturum süresi dolduğu için ApiService tarafından buraya yönlendirildiyse bilgilendir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (mounted && args is Map && args['sessionExpired'] == true) {
        _showError('Oturumunuz sona erdi, lütfen tekrar giriş yapın.');
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Şifre sıfırlama talebi.
  ///
  /// Sunucu, e-posta kayıtlı olmasa bile aynı yanıtı döner ve bu ekran da
  /// aynı mesajı gösterir. Böylece uygulama "bu e-posta kayıtlı mı" sorusuna
  /// cevap veren bir araç haline gelmiyor.
  void _showForgotPasswordSheet() {
    final t = AppTokens.of(context);
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    bool isSubmitting = false;
    bool gonderildi = false;
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
                Text('Şifremi Unuttum',
                    style: jakarta(fontSize: 18, fontWeight: FontWeight.w700, color: t.text)),
                const SizedBox(height: 10),

                if (gonderildi) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: t.greenSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(LucideIcons.mailCheck, color: t.green, size: 19),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Bu adres kayıtlıysa şifre sıfırlama bağlantısı gönderildi. '
                            'Lütfen e-postanızı kontrol edin.\n\n'
                            'Bağlantı 60 dakika geçerlidir ve yalnızca bir kez kullanılabilir.',
                            style: TextStyle(color: t.textSec, fontSize: 13.5, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Tamam'),
                    ),
                  ),
                ] else ...[
                  Text(
                    'Hesabınızın e-posta adresini girin. Şifrenizi yeniden '
                    'belirleyebileceğiniz bir bağlantı göndereceğiz.',
                    style: TextStyle(color: t.textSec, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    style: TextStyle(color: t.text),
                    decoration: InputDecoration(
                      hintText: 'ornek@eposta.com',
                      prefixIcon: Icon(LucideIcons.mail, color: t.textTert, size: 18),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Hata sayfanin ICINDE gosteriliyor: SnackBar ekranin altina
                  // cizilir, modal alt sayfa ve klavye orayi kapatir.
                  if (hata != null) ...[
                    Container(
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
                            child: Text(hata!,
                                style: TextStyle(color: t.red, fontSize: 13.5, height: 1.35)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final email = emailCtrl.text.trim();
                              if (email.isEmpty || !email.contains('@')) {
                                setSheetState(() => hata = 'Geçerli bir e-posta adresi giriniz.');
                                return;
                              }
                              setSheetState(() {
                                isSubmitting = true;
                                hata = null;
                              });

                              final sonuc = await ApiService.forgotPassword(email);
                              if (!ctx.mounted) return;

                              setSheetState(() {
                                isSubmitting = false;
                                if (sonuc['success'] == true) {
                                  gonderildi = true;
                                } else {
                                  hata = sonuc['message']?.toString() ?? 'İstek gönderilemedi.';
                                }
                              });
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Sıfırlama Bağlantısı Gönder'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('E-posta ve şifre gerekli');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final result = await ApiService.login(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (result['success']) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        }
      } else {
        _showError(result['message']);
      }
    } catch (e) {
      _showError('Bağlantı hatası! Backend çalışıyor mu?');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    setState(() => _errorText = message);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo işareti + ad
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: t.brand,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(LucideIcons.wallet, color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Wallet Mark',
                    style: jakarta(fontSize: 24, fontWeight: FontWeight.w700, color: t.text, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 4),
                  Text('Paranızı akıllıca yönetin', style: TextStyle(color: t.textSec, fontSize: 14)),

                  const SizedBox(height: 36),

                  Text('E-posta', style: TextStyle(color: t.textSec, fontSize: 12.5, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: t.text, fontSize: 15),
                    decoration: const InputDecoration(hintText: 'ornek@eposta.com'),
                  ),

                  const SizedBox(height: 14),

                  Text('Şifre', style: TextStyle(color: t.textSec, fontSize: 12.5, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: TextStyle(color: t.text, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                          color: t.textSec,
                          size: 18,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: _showForgotPasswordSheet,
                      child: Text('Şifremi unuttum',
                          style: TextStyle(color: t.brand, fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Giriş Yap', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                    ),
                  ),

                  const SizedBox(height: 28),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Hesabın yok mu? ', style: TextStyle(color: t.textSec, fontSize: 13.5)),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const RegisterScreen()),
                          );
                        },
                        child: Text('Kayıt Ol',
                            style: TextStyle(color: t.brand, fontWeight: FontWeight.w600, fontSize: 13.5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Hata toast'ı — üstte sabit, tam genişlik banner değil
            if (_errorText != null)
              Positioned(
                top: 8,
                left: 16,
                right: 16,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: t.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: t.redSoft),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 8))],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.triangleAlert, color: t.red, size: 16),
                        const SizedBox(width: 8),
                        Flexible(child: Text(_errorText!, style: TextStyle(color: t.red, fontSize: 12.5))),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
