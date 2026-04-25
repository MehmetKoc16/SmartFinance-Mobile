import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'main_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_fullNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      _showError('Tüm alanları doldurunuz!');
      return;
    }

    if (_passwordController.text.length < 6) {
      _showError('Şifre en az 6 karakter olmalıdır!');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Şifreler eşleşmiyor!');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.register(
        fullName: _fullNameController.text,
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 60),

              // Logo
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppColors.gradientPurpleCyan.createShader(bounds),
                child: const Text(
                  'SmartFinance',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hesap Oluştur',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),

              const SizedBox(height: 40),

              // Ad Soyad
              TextField(
                controller: _fullNameController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Ad Soyad',
                  prefixIcon: Icon(Icons.person_outline, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 16),

              // Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Email adresiniz',
                  prefixIcon: Icon(Icons.mail_outline, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 16),

              // Şifre
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Şifreniz (min 6 karakter)',
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Şifre Tekrar
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Şifre tekrar',
                  prefixIcon: Icon(Icons.lock_outline, color: AppColors.textMuted),
                ),
              ),

              const SizedBox(height: 32),

              // Kayıt butonu (gradient)
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppColors.gradientPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Kayıt Ol',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Login linki
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Zaten hesabın var mı? ',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    child: const Text(
                      'Giriş Yap',
                      style: TextStyle(
                        color: AppColors.cyan,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
