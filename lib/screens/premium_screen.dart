import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../services/api_service.dart';
import '../services/billing_service.dart';
import '../services/links.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen>
    with WidgetsBindingObserver {
  final _billing = BillingService();
  StreamSubscription<void>? _subscription;
  bool _loading = true;
  String _selected = BillingService.premiumYearly;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = _billing.changes.listen((_) {
      if (mounted) setState(() {});
    });
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _billing.load();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!_billing.plans.containsKey(_selected) && _billing.plans.isNotEmpty) {
        _selected = _billing.plans.keys.first;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_billing.busy) {
      _load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  String get _savings {
    final monthly = _billing.plans[BillingService.premiumMonthly];
    final yearly = _billing.plans[BillingService.premiumYearly];
    if (monthly == null || yearly == null || monthly.rawPrice <= 0 ||
        monthly.currencyCode != yearly.currencyCode) {
      return 'En avantajlı';
    }
    final percent = ((1 - yearly.rawPrice / (monthly.rawPrice * 12)) * 100).round();
    return percent > 0 ? '%$percent tasarruf' : 'En avantajlı';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final plan = _billing.plans[_selected];
    final locked = _billing.busy || _billing.pending;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        foregroundColor: t.text,
        title: Text('Wallet Mark Premium',
            style: jakarta(fontSize: 19, fontWeight: FontWeight.w700, color: t.text)),
      ),
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: t.brand))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(LucideIcons.crown, size: 40, color: t.brand),
                    const SizedBox(height: 12),
                    if (_billing.isPremium)
                      _membership(t)
                    else ...[
                      Text('Finansınızı özgürce yönetin',
                          style: jakarta(fontSize: 22, fontWeight: FontWeight.w700, color: t.text)),
                      const SizedBox(height: 16),
                      _benefit(t, 'Sınırsız yatırım takibi', 'investments', 'yatırım'),
                      _benefit(t, 'Sınırsız bütçe', 'budgets', 'bütçe'),
                      _benefit(t, 'Sınırsız ekstre içe aktarma', 'monthlyImports', 'ekstre/ay'),
                      _benefit(t, 'Tüm teknik göstergeler', null, null),
                      const SizedBox(height: 16),
                      if (!_billing.available || _billing.plans.isEmpty) ...[
                        Text('Satın alma şu an kullanılamıyor',
                            style: TextStyle(color: t.text, fontWeight: FontWeight.w600)),
                        TextButton(onPressed: locked ? null : _load, child: const Text('Tekrar dene')),
                      ] else ...[
                        for (final id in [BillingService.premiumMonthly, BillingService.premiumYearly])
                          if (_billing.plans[id] != null) _planCard(t, _billing.plans[id]!, locked),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          key: const Key('premium-buy'),
                          onPressed: locked || plan == null ||
                                  _billing.status?['accountToken'] is! String ||
                                  (_billing.status?['accountToken'] as String).isEmpty ||
                                  _billing.canRetryVerification
                              ? null
                              : () => _billing.buy(plan),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: t.brandSoft,
                            foregroundColor: t.brand,
                            disabledBackgroundColor: t.elevated,
                            disabledForegroundColor: t.textSec,
                            minimumSize: const Size.fromHeight(50),
                          ),
                          child: _billing.busy
                              ? SizedBox(width: 22, height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: t.brand))
                              : const Text("Premium'a geç"),
                        ),
                      ],
                    ],
                    if (_billing.pending) ...[
                      const SizedBox(height: 12),
                      Text('Ödeme bekleniyor', style: TextStyle(color: t.amber, fontWeight: FontWeight.w600)),
                    ],
                    if (_billing.error != null) ...[
                      const SizedBox(height: 12),
                      Text(_billing.error!, style: TextStyle(color: t.red)),
                      TextButton(
                        onPressed: _billing.busy ? null : () async {
                          if (_billing.canRetryVerification) {
                            await _billing.retryVerification();
                          } else {
                            await _load();
                          }
                        },
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      'Abonelik, deneme bitince seçtiğiniz plana göre otomatik yenilenir. '
                      "İstediğiniz zaman Google Play'den iptal edebilirsiniz.",
                      style: TextStyle(color: t.textSec, fontSize: 12, height: 1.5),
                    ),
                    TextButton(onPressed: () => baglantiAc(context, gizlilikUrl),
                      child: const Text('Gizlilik Politikası')),
                    TextButton(onPressed: () => baglantiAc(context, abonelikYonetimUrl),
                      child: const Text('Abonelikleri yönet')),
                    TextButton(
                      onPressed: _billing.busy ? null : _billing.restore,
                      child: const Text('Satın alımları geri yükle'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _benefit(AppTokens t, String title, String? key, String? unit) {
    final usage = key == null ? null : _billing.status?[key];
    final limit = usage is Map ? usage['limit'] : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.check, color: t.green, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: t.text, fontWeight: FontWeight.w500)),
            if (limit != null)
              Text('Ücretsiz: $limit $unit', style: TextStyle(color: t.textSec, fontSize: 12)),
          ])),
        ],
      ),
    );
  }

  Widget _planCard(AppTokens t, PremiumPlan plan, bool locked) {
    final selected = _selected == plan.product.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? t.brandSoft : t.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: Key('plan-${plan.product.id}'),
          borderRadius: BorderRadius.circular(16),
          onTap: locked ? null : () => setState(() => _selected = plan.product.id),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: selected ? t.brand : t.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(selected ? LucideIcons.circleCheck : LucideIcons.circle, color: t.brand, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(plan.yearly ? 'Yıllık · Önerilen' : 'Aylık',
                    style: jakarta(fontSize: 16, fontWeight: FontWeight.w700, color: t.text))),
              ]),
              if (plan.yearly) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: t.greenSoft, borderRadius: BorderRadius.circular(8)),
                  child: Text(_savings, style: TextStyle(color: t.green, fontSize: 12)),
                ),
              ],
              const SizedBox(height: 8),
              Text(plan.description, style: TextStyle(color: t.text, fontSize: 14, height: 1.4)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _membership(AppTokens t) {
    final status = _billing.status!;
    final date = DateTime.tryParse(status['expiresAt']?.toString() ?? '');
    final renewal = status['autoRenewing'] == true;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Premium üyesiniz',
          style: jakarta(fontSize: 24, fontWeight: FontWeight.w700, color: t.text)),
      const SizedBox(height: 12),
      if (date != null)
        Text('${renewal ? 'Yenileme tarihi' : 'Bitiş tarihi'}: ${DateFormat('dd.MM.yyyy').format(date.toLocal())}',
            style: TextStyle(color: t.textSec)),
      const SizedBox(height: 16),
      OutlinedButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: t.card,
            title: Text('Aboneliği yönet', style: TextStyle(color: t.text)),
            content: Text(
              'Aboneliğinizi Play Store > Ödemeler ve abonelikler bölümünden yönetebilirsiniz.',
              style: TextStyle(color: t.textSec),
            ),
            actions: [
              TextButton(onPressed: () => baglantiAc(context, abonelikYonetimUrl),
                child: const Text('Abonelikleri yönet')),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam')),
            ],
          ),
        ),
        child: const Text('Aboneliği yönet'),
      ),
    ]);
  }
}

/// Profildeki tek satırın status yükleme ve dönüşte yenileme davranışı.
/// Profil ekranının mevcut veri yükleme akışını değiştirmez.
class PremiumProfileEntry extends StatefulWidget {
  const PremiumProfileEntry({super.key, required this.builder});
  final Widget Function(bool isPremium, VoidCallback open) builder;

  @override
  State<PremiumProfileEntry> createState() => _PremiumProfileEntryState();
}

class _PremiumProfileEntryState extends State<PremiumProfileEntry> {
  bool _premium = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final status = await ApiService.authenticatedGet('/subscription/status');
    if (mounted) setState(() => _premium = status is Map && status['isPremium'] == true);
  }

  Future<void> _open() async {
    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_premium, _open);
}
