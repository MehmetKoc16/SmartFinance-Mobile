import 'package:flutter/material.dart';
import '../screens/biometric_lock_screen.dart';
import 'api_service.dart';
import 'biometric_service.dart';

const appLockTimeout = Duration(seconds: 60);

/// Navigator'ın üstünde yaşar; açık modal ve sayfaları doğrulamaya kadar örter.
class AppLock extends StatefulWidget {
  const AppLock({
    super.key,
    required this.child,
    this.now = DateTime.now,
    this.navigatorKey,
    this.hasSession = ApiService.isLoggedIn,
    this.available = BiometricService.isAvailable,
    this.authenticate = BiometricService.authenticate,
  });

  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;
  final DateTime Function() now;
  final Future<bool> Function() hasSession;
  final Future<bool> Function() available;
  final Future<bool> Function() authenticate;
  static int _suppression = 0;
  static int _suppressionRevision = 0;

  static Future<T> suppress<T>(Future<T> operation) async {
    _suppression++;
    _suppressionRevision++;
    try {
      return await operation;
    } finally {
      _suppression--;
    }
  }

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  DateTime? _backgroundAt;
  int _revisionAtBackground = 0;
  bool _backgroundSuppressed = false;
  bool _inactiveSuppressed = false;
  bool _locked = false;
  bool _checking = false;
  Route<void>? _lockRoute;
  NavigatorState? get _navigator =>
      (widget.navigatorKey ?? ApiService.navigatorKey).currentState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // inactive tek başına sistem diyaloğu olabilir; gerçek arka planı say.
    if (state == AppLifecycleState.inactive) {
      _inactiveSuppressed = AppLock._suppression > 0;
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_backgroundAt == null) {
        _backgroundAt = widget.now();
        _revisionAtBackground = AppLock._suppressionRevision;
        _backgroundSuppressed = _inactiveSuppressed || AppLock._suppression > 0;
      }
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundAt;
      _backgroundAt = null;
      _inactiveSuppressed = false;
      if (since == null ||
          _locked ||
          _checking ||
          _backgroundSuppressed ||
          AppLock._suppression > 0 ||
          _revisionAtBackground != AppLock._suppressionRevision ||
          widget.now().difference(since) <= appLockTimeout) {
        return;
      }
      _check();
    }
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final suppressionRevision = AppLock._suppressionRevision;
    try {
      if (!await widget.hasSession() || !mounted) return;
      if (!await widget.available() || !mounted) return;
      if (AppLock._suppression > 0 ||
          suppressionRevision != AppLock._suppressionRevision) {
        return;
      }
      // Çıkış, donanım kontrolü sürerken tamamlanmış olabilir.
      if (!await widget.hasSession() || !mounted) return;
      if (AppLock._suppression > 0 ||
          suppressionRevision != AppLock._suppressionRevision) {
        return;
      }
      if (_navigator == null) return;
      _locked = true;
      final route = PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, animation, secondaryAnimation) => PopScope(
          canPop: false,
          child: BiometricLockScreen(
            authenticate: widget.authenticate,
            onUnlocked: _unlock,
            onLoggedOut: () {
              _lockRoute = null;
              _navigator?.pushNamedAndRemoveUntil('/login', (_) => false);
              _unlock();
            },
          ),
        ),
      );
      _lockRoute = route;
      _navigator!.push(route).whenComplete(() {
        // Oturum süresi dolduğunda kök Navigator kilidi kaldırıp girişe dönebilir.
        if (mounted && identical(_lockRoute, route)) _unlock();
      });
    } finally {
      _checking = false;
      if (mounted) setState(() {});
    }
  }

  void _unlock() {
    if (!mounted) return;
    final route = _lockRoute;
    _lockRoute = null;
    if (route != null && route.isActive) _navigator?.removeRoute(route);
    _backgroundAt = null;
    setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      if (_checking)
        const Positioned.fill(
          child: ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
    ],
  );
}
