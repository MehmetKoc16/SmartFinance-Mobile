import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_tokens.dart';
import 'core/theme/theme_controller.dart';
import 'screens/biometric_lock_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/api_service.dart';
import 'services/biometric_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeController(),
      child: const SmartFinanceApp(),
    ),
  );
}

class SmartFinanceApp extends StatelessWidget {
  const SmartFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    return MaterialApp(
      title: 'SmartFinance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeController.mode,
      navigatorKey: ApiService.navigatorKey,
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
      },
    );
  }
}

// Uygulama açılışında token kontrolü
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2)); // Splash göster
    final isLogged = await ApiService.isLoggedIn();

    Widget next;
    if (!isLogged) {
      next = const LoginScreen();
    } else {
      // Biyometrik donanimi/kaydi olmayan cihazlarda kapi hic gosterilmez —
      // yoksa o cihazdaki hicbir kullanici uygulamaya giremezdi.
      final biometricAvailable = await BiometricService.isAvailable();
      next = biometricAvailable ? const BiometricLockScreen() : const MainScreen();
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => next),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'SmartFinance',
              style: jakarta(fontSize: 40, fontWeight: FontWeight.w800, color: t.brand),
            ),
            const SizedBox(height: 16),
            Text(
              'Finansal özgürlüğün başlangıcı',
              style: TextStyle(color: t.textSec, fontSize: 16),
            ),
            const SizedBox(height: 40),
            CircularProgressIndicator(color: t.brand),
          ],
        ),
      ),
    );
  }
}
