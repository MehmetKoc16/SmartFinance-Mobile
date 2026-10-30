import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/app_tokens.dart';
import '../services/api_service.dart';

/// Bildirim türü tercihleri uç noktası. Yol backend'de farklı çıkarsa
/// yalnız burası değişir; GET ve PUT aynı yolu kullanır.
const String notificationPreferencesPath = '/notification/preferences';

/// Kullanıcının bildirimleri türüne göre seçebilmesi için (KVKK, 14.01.2026
/// duyurusu). Değerler YALNIZ sunucudan gelir: hiçbir tür önceden açık
/// varsayılmaz, özellikle tanıtım duyuruları için ayrı ve önceden
/// işaretlenmemiş onay gerekir.
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _PreferenceItem {
  final String key;
  final String title;
  final String subtitle;
  const _PreferenceItem(this.key, this.title, this.subtitle);
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  static const _items = [
    _PreferenceItem('budgetAlerts', 'Bütçe uyarıları', 'Bütçe limitine yaklaşınca veya aşınca'),
    _PreferenceItem('recurringReminders', 'Planlı ödeme hatırlatmaları', 'Vadesi yaklaşan ödeme ve gelirler'),
    _PreferenceItem('announcements', 'Duyurular ve kampanyalar',
        'Yeni özellikler ve kampanyalar hakkında bilgilendirme. İstediğin zaman kapatabilirsin.'),
  ];

  /// Sunucudan gelen değerler; null iken (yükleniyor ya da hata) anahtarlar
  /// devre dışıdır ve kapalı görünür.
  Map<String, bool>? _values;
  bool _loading = true;
  bool _loadFailed = false;
  // İsteği süren anahtarlar: aynı anahtar için ikinci istek gitmesin.
  final Set<String> _pending = {};
  int _loadRequest = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Üç alanın hepsi bool değilse yanıt geçersiz sayılır; eksik alan
  /// "açık" ya da "kapalı" diye tahmin edilmez.
  static Map<String, bool>? _parse(dynamic result) {
    if (result is! Map || result.containsKey('error')) return null;
    final parsed = <String, bool>{};
    for (final item in _items) {
      final value = result[item.key];
      if (value is! bool) return null;
      parsed[item.key] = value;
    }
    return parsed;
  }

  Future<void> _load() async {
    final request = ++_loadRequest;
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    final result = await ApiService.authenticatedGet(notificationPreferencesPath);
    if (!mounted || request != _loadRequest) return;
    final parsed = _parse(result);
    setState(() {
      _loading = false;
      _values = parsed;
      _loadFailed = parsed == null;
    });
  }

  Future<void> _toggle(String key, bool newValue) async {
    final values = _values;
    if (values == null || _pending.contains(key)) return;
    final oldValue = values[key]!;
    setState(() {
      _pending.add(key);
      values[key] = newValue;
    });

    // Yalnız değişen alan gönderilir: başka bir anahtarın isteği sürüyorsa
    // onun değeri bu istekle ezilmesin.
    final result = await ApiService.authenticatedPut(notificationPreferencesPath, {key: newValue});
    if (!mounted) return;

    final error = result is Map && result.containsKey('error')
        ? (result['error']?.toString() ?? 'Tercih kaydedilemedi.')
        : null;
    setState(() {
      _pending.remove(key);
      final current = _values;
      if (current == null) return;
      if (error != null) {
        current[key] = oldValue;
        return;
      }
      final server = _parse(result);
      if (server != null) {
        // Sunucunun güncel değerleri esas alınır; isteği hâlâ süren diğer
        // anahtarların iyimser değerine dokunulmaz.
        for (final entry in server.entries) {
          if (!_pending.contains(entry.key)) current[entry.key] = entry.value;
        }
      }
    });
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final values = _values;
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirim tercihleri')),
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: t.brand))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  if (_loadFailed) ...[
                    Container(
                      key: const Key('bildirim-tercih-hata'),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: t.redSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.circleAlert, color: t.red, size: 17),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Tercihler yüklenemedi',
                                style: TextStyle(color: t.red, fontSize: 13.5)),
                          ),
                          TextButton(onPressed: _load, child: const Text('Tekrar dene')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    decoration: BoxDecoration(
                      color: t.card,
                      border: Border.all(color: t.border),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(
                        children: [
                          for (final item in _items)
                            Container(
                              decoration: BoxDecoration(
                                border: identical(item, _items.last)
                                    ? null
                                    : Border(bottom: BorderSide(color: t.divider)),
                              ),
                              child: SwitchListTile(
                                key: Key('bildirim-tercih-${item.key}'),
                                value: values?[item.key] ?? false,
                                onChanged: values == null || _pending.contains(item.key)
                                    ? null
                                    : (v) => _toggle(item.key, v),
                                activeTrackColor: t.brand,
                                title: Text(item.title, style: TextStyle(color: t.text, fontSize: 14)),
                                subtitle: Text(item.subtitle,
                                    style: TextStyle(color: t.textSec, fontSize: 12.5, height: 1.35)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Kapattığın türler telefonuna bildirim olarak gelmez; bütçe ve ödeme uyarıları '
                    'uygulama içindeki bildirim listesinde görünmeye devam eder. Güvenlik ve hesabınla '
                    'ilgili zorunlu bildirimler tercihlerden bağımsız gönderilir.',
                    style: TextStyle(color: t.textTert, fontSize: 12, height: 1.45),
                  ),
                ],
              ),
      ),
    );
  }
}
