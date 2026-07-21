import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import 'login_screen.dart';
import 'main_screen.dart';

// Kayıtlı oturumu olan kullanıcı uygulamayı her açtığında bu ekrandan geçer.
// Biyometrik dogrulama basarisiz olursa kullanici "Cikis Yap" ile sifreyle
// giris yapmaya donebilir — sensor arizali/erisilemez olsa bile kilitte kalmaz.
class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  bool _authenticating = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _attemptAuth();
  }

  Future<void> _attemptAuth() async {
    setState(() {
      _authenticating = true;
      _failed = false;
    });

    final success = await BiometricService.authenticate();

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else {
      setState(() {
        _authenticating = false;
        _failed = true;
      });
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: t.brandSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.fingerprint, color: t.brand, size: 44),
                ),
                const SizedBox(height: 24),
                Text(
                  _authenticating ? 'Doğrulanıyor...' : 'Kimlik doğrulama başarısız',
                  style: jakarta(fontSize: 18, fontWeight: FontWeight.w700, color: t.text),
                ),
                const SizedBox(height: 8),
                Text(
                  'Devam etmek için parmak izi veya yüz taraması gerekiyor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.textSec, fontSize: 14),
                ),
                const SizedBox(height: 32),
                if (_failed) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _attemptAuth,
                      style: ElevatedButton.styleFrom(backgroundColor: t.brand),
                      child: const Text('Tekrar Dene'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _logout,
                    child: Text('Şifre ile giriş yap', style: TextStyle(color: t.textSec)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
