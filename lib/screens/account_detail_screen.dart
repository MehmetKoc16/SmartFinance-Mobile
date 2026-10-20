import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/formatters.dart';
import '../models/account.dart';
import '../services/account_service.dart';
import '../services/api_service.dart';
import '../services/amount_privacy.dart';
import '../services/transaction_trash.dart';
import '../widgets/account_widgets.dart';
import 'account_edit_screen.dart';
import 'transfer_screen.dart';

class AccountDetailScreen extends StatefulWidget {
  const AccountDetailScreen({super.key, required this.account});
  final Account account;
  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen>
    with AmountPrivacyListener {
  late Account _account;
  List<Account> _accounts = [];
  Statements? _statements;
  List<_Movement> _movements = [];
  bool _loading = true, _busy = false;
  bool _showAllStatements = false;
  String? _error;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _account = widget.account;
    TransactionTrash.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    TransactionTrash.changes.removeListener(_load);
    super.dispose();
  }

  Future<List<_Movement>> _transactions() async {
    final rows = <_Movement>[];
    var page = 1;
    while (true) {
      final result = await ApiService.authenticatedGet(
        '/transaction/filter?accountId=${_account.id}&page=$page&pageSize=50',
      );
      if (result is! Map ||
          result['error'] != null ||
          result['items'] is! List) {
        throw AccountException(
          result is Map
              ? (result['error'] ?? 'Hareketler yüklenemedi').toString()
              : 'Hareketler yüklenemedi',
        );
      }
      final items = result['items'] as List;
      rows.addAll(
        items.map(
          (e) => _Movement.transaction(Map<String, dynamic>.from(e as Map)),
        ),
      );
      if (items.isEmpty || page >= (result['totalPages'] as int)) break;
      page++;
    }
    return rows;
  }

  Future<List<_Movement>> _transfers() async {
    final rows = <_Movement>[];
    var page = 1;
    while (true) {
      final result = await AccountService.transfers(_account.id, page: page);
      rows.addAll(result.items.map(_Movement.fromTransfer));
      if (result.items.isEmpty || rows.length >= result.totalCount) break;
      page++;
    }
    return rows;
  }

  Future<void> _load() async {
    final request = ++_request;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Future.wait<Object?>([
        AccountService.list(includeArchived: true),
        _account.isCard
            ? AccountService.statements(_account.id, count: 12)
            : Future<Statements?>.value(),
        _transactions(),
        _transfers(),
      ]);
      if (!mounted || request != _request) return;
      final accounts = result[0] as List<Account>;
      final rows =
          [...result[2] as List<_Movement>, ...result[3] as List<_Movement>]
            ..sort((a, b) {
              final date = b.date.compareTo(a.date);
              return date != 0 ? date : b.id.compareTo(a.id);
            });
      setState(() {
        _accounts = accounts;
        _account = accounts.firstWhere(
          (a) => a.id == _account.id,
          orElse: () => _account,
        );
        _statements = result[1] as Statements?;
        _movements = rows;
        _loading = false;
      });
    } catch (e) {
      if (mounted && request == _request) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _edit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AccountEditScreen(account: _account)),
    );
    if (!mounted) return;
    if (changed == true) await _load();
  }

  Future<void> _pay() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransferScreen(
          toAccountId: _account.id,
          amount: _statements?.oldestRemaining?.remaining,
        ),
      ),
    );
    if (!mounted) return;
    if (changed == true) await _load();
  }

  Future<bool> _confirm(String title) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: const Text('Bu işlemi onaylıyor musunuz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Onayla'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _delete() async {
    final confirm = await _confirm('Hesabı arşivle/sil');
    if (!mounted || !confirm) return;
    setState(() => _busy = true);
    try {
      final archived = await AccountService.delete(_account.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(archived ? 'Hesap arşivlendi' : 'Hesap silindi'),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) await showAccountError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteTransfer(Transfer transfer) async {
    final confirm = await _confirm('Transferi sil');
    if (!mounted || !confirm) return;
    setState(() => _busy = true);
    try {
      await AccountService.deleteTransfer(transfer.id);
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (mounted) await showAccountError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _date(DateTime date) => DateFormat('dd.MM.yyyy').format(date);
  String _name(int id) =>
      _accounts.where((a) => a.id == id).firstOrNull?.name ?? 'Hesap #$id';
  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final a = _account;
    return Scaffold(
      appBar: AppBar(
        title: Text(a.name),
        actions: [
          PopupMenuButton<String>(
            key: const Key('account-menu'),
            enabled: !_busy,
            onSelected: (value) {
              if (value == 'edit') {
                _edit();
              } else {
                _delete();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Düzenle')),
              PopupMenuItem(value: 'delete', child: Text('Arşivle/Sil')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: t.brand))
            : RefreshIndicator(
                onRefresh: _load,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: _error != null
                      ? Column(
                          children: [
                            Text(_error!, style: TextStyle(color: t.red)),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Tekrar dene'),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AccountPanel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.isCard
                                        ? 'Borç ${formatTRY(a.debt!)}'
                                        : 'Bakiye ${formatTRY(a.balance!)}',
                                    style: TextStyle(
                                      color: t.text,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (a.isCard) ...[
                                    Text(
                                      'Limit ${formatTRY(a.creditLimit!)}',
                                      style: TextStyle(color: t.textSec),
                                    ),
                                    Text(
                                      'Kalan limit ${formatTRY(a.availableLimit!)}',
                                      style: TextStyle(color: t.textSec),
                                    ),
                                    const SizedBox(height: 12),
                                    if (!AmountPrivacy.gizli.value)
                                      LinearProgressIndicator(
                                        value: (a.debt! / a.creditLimit!).clamp(
                                          0.0,
                                          1.0,
                                        ),
                                        color: t.brand,
                                        backgroundColor: t.inputBg,
                                      ),
                                  ],
                                  if (a.isArchived)
                                    Text(
                                      'Arşivlendi',
                                      style: TextStyle(color: t.textSec),
                                    ),
                                ],
                              ),
                            ),
                            if (a.isCard && !a.isArchived)
                              ElevatedButton(
                                onPressed: _busy ? null : _pay,
                                child: const Text('Borç öde'),
                              ),
                            if (_statements != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Ekstreler',
                                style: TextStyle(
                                  color: t.text,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _statement(_statements!.current),
                              for (final s
                                  in _showAllStatements
                                      ? _statements!.past
                                      : _statements!.past.take(3))
                                _statement(s),
                              if (_statements!.past.length > 3)
                                TextButton(
                                  onPressed: () => setState(() {
                                    _showAllStatements = !_showAllStatements;
                                  }),
                                  child: Text(
                                    _showAllStatements
                                        ? 'Daha az ekstre göster'
                                        : 'Tüm ekstreleri göster (${_statements!.past.length})',
                                  ),
                                ),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              'Hareketler',
                              style: TextStyle(
                                color: t.text,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_movements.isEmpty)
                              const Text('Henüz hareket yok.'),
                            for (final m in _movements)
                              AccountPanel(
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    m.transfer != null
                                        ? LucideIcons.arrowRightLeft
                                        : LucideIcons.receipt,
                                    color: t.brand,
                                  ),
                                  title: Text(
                                    m.transfer == null
                                        ? m.description
                                        : m.transfer!.fromAccountId == a.id
                                        ? '→ ${_name(m.transfer!.toAccountId)}'
                                        : '← ${_name(m.transfer!.fromAccountId)}',
                                  ),
                                  subtitle: Text(
                                    '${_date(m.date.toLocal())}${m.transfer == null || m.description.isEmpty ? '' : '\n${m.description}'}',
                                  ),
                                  trailing: Text(
                                    '${m.transfer != null ? (m.transfer!.fromAccountId == a.id ? '−' : '+') : (m.type == 1 ? '+' : '−')}${formatTRY(m.amount)}',
                                  ),
                                  onLongPress: m.transfer == null || _busy
                                      ? null
                                      : () => _deleteTransfer(m.transfer!),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
      ),
    );
  }

  Widget _statement(Statement s) {
    final t = AppTokens.of(context);
    final color = switch (s.status) {
      'empty' => t.textTert,
      'paid' => t.green,
      'overdue' => t.red,
      _ => t.brand,
    };
    return AccountPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s.status == 'open')
            Text(
              'Bu dönem harcama',
              style: TextStyle(color: t.text, fontWeight: FontWeight.w600),
            ),
          Text(
            '${_date(s.periodStart)} – ${_date(s.periodEnd)}',
            style: TextStyle(color: t.textSec),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              s.statusLabel,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          Text('Tutar ${formatTRY(s.amount)}', style: TextStyle(color: t.text)),
          Text(
            'Ödenen ${formatTRY(s.paid)}',
            style: TextStyle(color: t.textSec),
          ),
          Text(
            'Kalan ${formatTRY(s.remaining)}',
            style: TextStyle(color: t.text),
          ),
          Text(
            'Son ödeme ${_date(s.dueDate)}',
            style: TextStyle(color: t.textSec),
          ),
        ],
      ),
    );
  }
}

class _Movement {
  _Movement({
    required this.id,
    required this.date,
    required this.amount,
    required this.description,
    this.transfer,
    this.type,
  });
  final int id;
  final DateTime date;
  final double amount;
  final String description;
  final Transfer? transfer;
  final int? type;
  factory _Movement.transaction(Map<String, dynamic> json) => _Movement(
    id: json['id'] as int,
    date: DateTime.parse(json['transactionDate'] as String),
    amount: (json['amount'] as num).toDouble(),
    description: json['description'] as String? ?? '',
    type: json['type'] as int,
  );
  factory _Movement.fromTransfer(Transfer transfer) => _Movement(
    id: transfer.id,
    date: transfer.transferDate,
    amount: transfer.amount,
    description: transfer.description ?? '',
    transfer: transfer,
  );
}
