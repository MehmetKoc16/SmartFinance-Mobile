import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/formatters.dart';
import '../models/account.dart';
import '../services/account_service.dart';
import '../services/amount_privacy.dart';
import '../widgets/account_widgets.dart';
import 'account_detail_screen.dart';
import 'account_edit_screen.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});
  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen>
    with AmountPrivacyListener {
  List<Account>? _accounts;
  String? _error;
  bool _busy = false;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    AccountService.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    AccountService.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    try {
      final accounts = await AccountService.list(includeArchived: true);
      if (!mounted || request != _request) return;
      setState(() {
        _accounts = accounts;
        _error = null;
      });
    } catch (e) {
      if (mounted && request == _request) setState(() => _error = e.toString());
    }
  }

  Future<void> _unarchive(Account a) async {
    setState(() => _busy = true);
    try {
      await AccountService.unarchive(a.id);
    } catch (e) {
      if (mounted) await showAccountError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hesaplarım'),
        actions: [
          IconButton(
            tooltip: 'Hesap ekle',
            icon: const Icon(LucideIcons.plus),
            onPressed: () => Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => const AccountEditScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: t.red)),
                TextButton(onPressed: _load, child: const Text('Tekrar dene')),
              ] else if (_accounts == null)
                Center(child: CircularProgressIndicator(color: t.brand))
              else if (_accounts!.isEmpty)
                const Text('Henüz hesap eklenmedi.')
              else
                for (final a in _accounts!)
                  AccountPanel(
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            a.isCard
                                ? LucideIcons.creditCard
                                : LucideIcons.wallet,
                            color: t.brand,
                          ),
                          title: Text(a.name),
                          subtitle: Text(
                            '${a.typeLabel}${a.isArchived ? ' · Arşivlendi' : ''}',
                          ),
                          trailing: Text(
                            formatTRY(a.isCard ? a.debt! : a.balance!),
                          ),
                          onTap: () => Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AccountDetailScreen(account: a),
                            ),
                          ),
                        ),
                        if (a.isArchived)
                          TextButton(
                            onPressed: _busy ? null : () => _unarchive(a),
                            child: const Text('Arşivden çıkar'),
                          ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
