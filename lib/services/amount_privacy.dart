import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AmountPrivacy {
  static final gizli = ValueNotifier<bool>(false);
  static int _revision = 0;
  static Future<void> _saving = Future<void>.value();

  static Future<void> load() async {
    final revision = _revision;
    final prefs = await SharedPreferences.getInstance();
    if (revision == _revision) {
      gizli.value = prefs.getBool('amounts_hidden') ?? false;
    }
  }

  static Future<void> setHidden(bool hidden) {
    _revision++;
    gizli.value = hidden;
    return _saving = _saving.catchError((Object _) {}).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('amounts_hidden', hidden);
    });
  }

  static Future<void> toggle() => setHidden(!gizli.value);
}

/// Sayfa ve o sayfada oluşturulan para metinlerini birlikte yeniler.
mixin AmountPrivacyListener<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    AmountPrivacy.gizli.addListener(_privacyChanged);
  }

  void _privacyChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AmountPrivacy.gizli.removeListener(_privacyChanged);
    super.dispose();
  }
}
