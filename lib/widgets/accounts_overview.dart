import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/formatters.dart';
import '../models/account.dart';
import '../screens/account_detail_screen.dart';
import '../screens/account_edit_screen.dart';
import '../services/account_service.dart';
import '../services/amount_privacy.dart';
import '../services/transaction_trash.dart';
import 'account_widgets.dart';

class AccountsOverview extends StatefulWidget {
  const AccountsOverview({super.key});
  @override
  State<AccountsOverview> createState() => AccountsOverviewState();
}

class AccountsOverviewState extends State<AccountsOverview>
    with AmountPrivacyListener {
  List<Account>? _accounts;
  Map<int, Statements> _statements = {};
  int _request = 0;
  @override
  void initState() {
    super.initState();
    AccountService.changes.addListener(reload);
    TransactionTrash.changes.addListener(reload);
    reload();
  }

  @override
  void dispose() {
    AccountService.changes.removeListener(reload);
    TransactionTrash.changes.removeListener(reload);
    super.dispose();
  }

  Future<void> reload() async {
    final request = ++_request;
    try {
      final accounts = await AccountService.list();
      final statements = <int, Statements>{};
      await Future.wait(
        accounts.where((a) => a.isCard).map((a) async {
          statements[a.id] = await AccountService.statements(a.id, count: 12);
        }),
      );
      if (!mounted || request != _request) return;
      setState(() {
        _accounts = accounts;
        _statements = statements;
      });
    } catch (_) {
      if (mounted && request == _request) setState(() => _accounts = null);
    }
  }

  void _add() => Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => const AccountEditScreen()),
  );
  @override
  Widget build(BuildContext context) {
    final accounts = _accounts;
    if (accounts == null) return const SizedBox.shrink();
    final t = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hesaplarım',
            style: TextStyle(color: t.text, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          if (accounts.isEmpty)
            InkWell(
              onTap: _add,
              borderRadius: BorderRadius.circular(16),
              child: AccountPanel(
                child: Row(
                  children: [
                    Icon(LucideIcons.wallet, color: t.brand),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Kartlarını ve hesaplarını ekle — bakiyeni ve kart borcunu takip et',
                        style: TextStyle(color: t.text, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final a in accounts)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: InkWell(
                          onTap: () => Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AccountDetailScreen(account: a),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            width: 222,
                            child: AccountPanel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    a.isCard
                                        ? LucideIcons.creditCard
                                        : LucideIcons.wallet,
                                    color: t.brand,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    a.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: t.text,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    a.isCard
                                        ? 'Borç ${formatTRY(a.debt ?? 0)}'
                                        : formatTRY(a.balance ?? 0),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: t.text,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (a.isCard) ...[
                                    Text(
                                      'Kalan limit ${formatTRY(a.availableLimit ?? 0)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: t.textSec),
                                    ),
                                    if (_statements[a.id]?.oldestRemaining !=
                                        null)
                                      Text(
                                        'Son ödeme ${DateFormat('dd.MM.yyyy').format(_statements[a.id]!.oldestRemaining!.dueDate)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: t.textSec,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    InkWell(
                      onTap: _add,
                      borderRadius: BorderRadius.circular(16),
                      child: const SizedBox(
                        width: 160,
                        child: AccountPanel(
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              '+ Hesap ekle',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
