import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/formatters.dart';
import '../models/account.dart';
import '../models/recurring_payment.dart';
import '../services/account_service.dart';
import '../services/amount_privacy.dart';
import '../services/recurring_payment_service.dart';
import '../widgets/account_widgets.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/recurring_payment_widgets.dart';
import 'recurring_payment_edit_screen.dart';

class RecurringPaymentsScreen extends StatefulWidget {
  const RecurringPaymentsScreen({super.key});
  @override
  State<RecurringPaymentsScreen> createState() =>
      _RecurringPaymentsScreenState();
}

class _RecurringPaymentsScreenState extends State<RecurringPaymentsScreen>
    with AmountPrivacyListener {
  List<RecurringPayment>? _plans;
  Upcoming? _upcoming;
  String? _error;
  int _request = 0;
  bool _processing = false;
  @override
  void initState() {
    super.initState();
    RecurringPaymentService.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    RecurringPaymentService.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    try {
      final result = await Future.wait<dynamic>([
        RecurringPaymentService.list(),
        RecurringPaymentService.upcoming(),
      ]);
      if (!mounted || request != _request) return;
      setState(() {
        _plans = result[0] as List<RecurringPayment>;
        _upcoming = result[1] as Upcoming;
        _error = null;
      });
    } catch (e) {
      if (mounted && request == _request) setState(() => _error = e.toString());
    }
  }

  void _edit([RecurringPayment? p]) => Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => RecurringPaymentEditScreen(payment: p)),
  );
  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _actions(RecurringPayment p) async {
    final action = await showAppBottomSheet<String>(
      context: context,
      builder: (ctx) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                p.name,
                style: TextStyle(
                  color: AppTokens.of(ctx).text,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (p.status != 'ended') ...[
                ListTile(
                  leading: const Icon(LucideIcons.check),
                  title: Text(
                    p.type == 1
                        ? 'Alındı olarak işaretle'
                        : 'Ödendi olarak işaretle',
                  ),
                  onTap: () => Navigator.pop(ctx, 'pay'),
                ),
                ListTile(
                  leading: const Icon(LucideIcons.skipForward),
                  title: const Text('Bu vadeyi atla'),
                  onTap: () => Navigator.pop(ctx, 'skip'),
                ),
              ],
              ListTile(
                leading: const Icon(LucideIcons.squarePen),
                title: const Text('Düzenle'),
                onTap: () => Navigator.pop(ctx, 'edit'),
              ),
              ListTile(
                leading: Icon(LucideIcons.trash2, color: AppTokens.of(ctx).red),
                title: const Text('Sil'),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      _edit(p);
      return;
    }
    if (action == 'pay') {
      final result = await showAppBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _PayForm(payment: p),
      );
      if (!mounted || result == null) return;
      _message(
        result == 'conflict' ? 'Bu vade zaten işlendi.' : 'İşlem eklendi',
      );
      await _load();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action == 'skip' ? 'Vadeyi atla' : 'Planlı ödemeyi sil'),
        content: Text(
          action == 'skip'
              ? '${DateFormat('dd.MM.yyyy').format(p.nextDueDate)} vadesi atlansın mı? İşlem eklenmez.'
              : '${p.name} silinsin mi? Geçmiş işlemler korunur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action == 'skip' ? 'Atla' : 'Sil'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _processing = true);
    try {
      if (action == 'skip') {
        await RecurringPaymentService.skip(p.id, dueDate: p.nextDueDate);
      } else {
        await RecurringPaymentService.delete(p.id);
      }
      if (!mounted) return;
      _message(action == 'skip' ? 'Vade atlandı' : 'Planlı ödeme silindi');
    } catch (e) {
      if (!mounted) return;
      _message(
        e is RecurringPaymentException && e.conflict
            ? 'Bu vade zaten işlendi.'
            : e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _processing = false);
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final upcoming = _upcoming;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planlı ödemeler'),
        actions: [
          IconButton(
            tooltip: 'Planlı ödeme ekle',
            onPressed: _processing ? null : () => _edit(),
            icon: const Icon(LucideIcons.plus),
          ),
        ],
      ),
      body: SafeArea(
        child: _plans == null && _error == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_error != null)
                      AccountPanel(
                        child: Column(
                          children: [
                            Text(_error!, style: TextStyle(color: t.red)),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Tekrar dene'),
                            ),
                          ],
                        ),
                      ),
                    if (upcoming != null)
                      AccountPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Önümüzdeki 30 gün',
                              style: TextStyle(
                                color: t.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Gider ${formatTRY(upcoming.expenseTotal)}',
                              style: TextStyle(color: t.red, fontSize: 20),
                            ),
                            if (upcoming.incomeTotal > 0)
                              Text(
                                'Gelir ${formatTRY(upcoming.incomeTotal)}',
                                style: TextStyle(color: t.green),
                              ),
                          ],
                        ),
                      ),
                    if (_plans != null && _plans!.isEmpty)
                      AccountPanel(
                        child: Column(
                          children: [
                            Icon(
                              LucideIcons.calendar,
                              color: t.brand,
                              size: 36,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Abonelik, kira, fatura gibi düzenli ödemelerini ekle — günü gelince hatırlatalım.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () => _edit(),
                              child: const Text('Planlı ödeme ekle'),
                            ),
                          ],
                        ),
                      ),
                    for (final p in _plans ?? <RecurringPayment>[])
                      AccountPanel(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: _processing ? null : () => _actions(p),
                          title: Text(
                            p.name,
                            style: TextStyle(
                              color: p.type == 1 ? t.green : t.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _frequency(p),
                                style: TextStyle(color: t.textSec),
                              ),
                              Text(
                                DateFormat('dd.MM.yyyy').format(p.nextDueDate),
                                style: TextStyle(color: t.textSec),
                              ),
                              RecurringStatusBadge(
                                status: p.status,
                                label: p.statusLabel,
                              ),
                            ],
                          ),
                          trailing: Text(
                            formatTRY(p.amount),
                            style: TextStyle(
                              color: p.type == 1 ? t.green : t.text,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  String _frequency(RecurringPayment p) => switch (p.frequency) {
    1 => 'Her hafta ${DateFormat('EEEE', 'tr_TR').format(p.startDate)}',
    2 => "Her ay ${p.anchorDay}'inde",
    3 =>
      'Her yıl ${p.anchorDay} ${DateFormat('MMMM', 'tr_TR').format(p.startDate)}',
    _ => '',
  };
}

class _PayForm extends StatefulWidget {
  const _PayForm({required this.payment});
  final RecurringPayment payment;
  @override
  State<_PayForm> createState() => _PayFormState();
}

class _PayFormState extends State<_PayForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount;
  List<Account> _accounts = [];
  int? _accountId;
  DateTime _date = DateTime.now();
  bool _loading = true, _saving = false;
  String? _error, _loadError;
  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: quantityForInput(widget.payment.amount),
    );
    _accountId = widget.payment.accountId;
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final accounts = await AccountService.list();
      if (!mounted) return;
      setState(() {
        _accounts = accounts.where((a) => !a.isArchived).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (!mounted || date == null) return;
    setState(() => _date = date);
  }

  Future<void> _pay() async {
    if (!_form.currentState!.validate()) return;
    if ((_accountId != null && !_accounts.any((a) => a.id == _accountId)) ||
        (_accountId == null && widget.payment.accountId != null)) {
      setState(
        () => _error =
            'Aktif bir hesap seçin veya planın hesabını Düzenle ekranından kaldırın.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await RecurringPaymentService.pay(
        widget.payment.id,
        dueDate: widget.payment.nextDueDate,
        amount: double.parse(_amount.text.replaceAll(',', '.')),
        accountId: _accountId,
        transactionDate: _date,
      );
      if (!mounted) return;
      Navigator.pop(context, 'paid');
    } catch (e) {
      if (!mounted) return;
      if (e is RecurringPaymentException && e.conflict) {
        Navigator.pop(context, 'conflict');
        return;
      }
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.payment.type == 1
                    ? 'Alındı olarak işaretle'
                    : 'Ödendi olarak işaretle',
                style: TextStyle(
                  color: t.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              if (_loading) const Center(child: CircularProgressIndicator()),
              if (_loadError != null) ...[
                Text(_loadError!, style: TextStyle(color: t.red)),
                TextButton(onPressed: _load, child: const Text('Tekrar dene')),
              ],
              AccountPanel(
                child: Column(
                  children: [
                    TextFormField(
                      key: const Key('recurring-pay-amount'),
                      controller: _amount,
                      enabled: !_saving,
                      decoration: const InputDecoration(labelText: 'Tutar'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: recurringAmountError,
                    ),
                    if (_accounts.isNotEmpty || _accountId != null) ...[
                      const SizedBox(height: 16),
                      AccountPicker(
                        accounts: _accounts,
                        value: _accountId,
                        emptyLabel: widget.payment.accountId == null
                            ? 'Hesap seçilmedi'
                            : 'Planın hesabını düzenleyin',
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _accountId = v),
                      ),
                    ],
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tarih'),
                      subtitle: Text(DateFormat('dd.MM.yyyy').format(_date)),
                      onTap: _saving ? null : _pickDate,
                    ),
                  ],
                ),
              ),
              if (_error != null) Text(_error!, style: TextStyle(color: t.red)),
              ElevatedButton(
                onPressed: _loading || _saving || _loadError != null
                    ? null
                    : _pay,
                child: Text(_saving ? 'İşleniyor…' : 'Onayla'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
