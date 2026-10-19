import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/formatters.dart';
import '../models/account.dart';
import '../models/recurring_payment.dart';
import '../services/account_service.dart';
import '../services/api_service.dart';
import '../services/recurring_payment_service.dart';
import '../widgets/account_widgets.dart';
import 'premium_screen.dart';

class RecurringPaymentEditScreen extends StatefulWidget {
  const RecurringPaymentEditScreen({super.key, this.payment});
  final RecurringPayment? payment;
  @override
  State<RecurringPaymentEditScreen> createState() =>
      _RecurringPaymentEditScreenState();
}

class _RecurringPaymentEditScreenState
    extends State<RecurringPaymentEditScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _amount;
  late int _type, _frequency, _remind;
  int? _categoryId, _accountId;
  late DateTime _start;
  DateTime? _end;
  List<Account> _accounts = [];
  List<dynamic> _categories = [];
  bool _loading = true, _saving = false;
  String? _error, _loadError;
  @override
  void initState() {
    super.initState();
    final p = widget.payment;
    _name = TextEditingController(text: p?.name ?? '');
    _amount = TextEditingController(
      text: p == null ? '' : quantityForInput(p.amount),
    );
    _type = p?.type ?? 2;
    _frequency = p?.frequency ?? 2;
    _remind = p?.remindDaysBefore ?? 1;
    _categoryId = p?.categoryId;
    _accountId = p?.accountId;
    _start = p?.startDate ?? DateUtils.dateOnly(DateTime.now());
    _end = p?.endDate;
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final result = await Future.wait<dynamic>([
        AccountService.list(),
        ApiService.authenticatedGet('/category'),
      ]);
      if (!mounted) return;
      final categories = result[1];
      if (categories is Map && categories.containsKey('error')) {
        throw Exception(categories['error']);
      }
      setState(() {
        _accounts = (result[0] as List<Account>)
            .where((a) => !a.isArchived)
            .toList();
        _categories = categories is List
            ? categories
            : (categories['items'] as List);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e.toString();
        });
      }
    }
  }

  Future<void> _pickDate(bool end) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: end ? (_end ?? _start) : _start,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (!mounted || picked == null) return;
    setState(() {
      if (end) {
        _end = picked;
      } else {
        _start = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_end != null && _end!.isBefore(_start)) {
      setState(() => _error = 'Bitiş tarihi başlangıçtan önce olamaz.');
      return;
    }
    // Arşivli plan hesabı kullanıcı tarafından temizlenebilir, ancak tekrar gönderilemez.
    if (_accountId != null && !_accounts.any((a) => a.id == _accountId)) {
      setState(
        () => _error =
            'Kullanılamayan hesabı kaldırın veya aktif bir hesap seçin.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await RecurringPaymentService.save(
        id: widget.payment?.id,
        name: _name.text.trim(),
        amount: double.parse(_amount.text.replaceAll(',', '.')),
        type: _type,
        categoryId: _categoryId,
        accountId: _accountId,
        frequency: _frequency,
        startDate: _start,
        endDate: _end,
        remindDaysBefore: _remind,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      if (e is RecurringPaymentException && e.premiumRequired) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => const PremiumScreen()),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final filtered = _categories.where((c) => c['type'] == _type).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.payment == null
              ? 'Planlı ödeme ekle'
              : 'Planlı ödemeyi düzenle',
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_loadError != null) ...[
                        Text(_loadError!, style: TextStyle(color: t.red)),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Tekrar dene'),
                        ),
                      ],
                      AccountPanel(
                        child: Column(
                          children: [
                            TextFormField(
                              key: const Key('recurring-name'),
                              controller: _name,
                              maxLength: 100,
                              enabled: !_saving,
                              decoration: const InputDecoration(
                                labelText: 'Ad',
                              ),
                              validator: (s) => (s ?? '').trim().isEmpty
                                  ? 'Ad giriniz'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            SegmentedButton<int>(
                              segments: const [
                                ButtonSegment(value: 2, label: Text('Gider')),
                                ButtonSegment(value: 1, label: Text('Gelir')),
                              ],
                              selected: {_type},
                              onSelectionChanged: _saving
                                  ? null
                                  : (v) => setState(() {
                                      _type = v.first;
                                      _categoryId = null;
                                    }),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const Key('recurring-amount'),
                              controller: _amount,
                              enabled: !_saving,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Tutar',
                              ),
                              validator: recurringAmountError,
                            ),
                            const SizedBox(height: 16),
                            KeyedSubtree(
                              key: const Key('recurring-category'),
                              child: DropdownButtonFormField<int>(
                                key: ValueKey(
                                  'recurring-category-$_type-$_categoryId',
                                ),
                                isExpanded: true,
                                initialValue:
                                    filtered.any((c) => c['id'] == _categoryId)
                                    ? _categoryId
                                    : null,
                                dropdownColor: t.card,
                                style: TextStyle(color: t.text),
                                decoration: const InputDecoration(
                                  labelText: 'Kategori (isteğe bağlı)',
                                ),
                                items: [
                                  const DropdownMenuItem<int>(
                                    child: Text(
                                      'Kategori seçilmedi',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  ...filtered.map(
                                    (c) => DropdownMenuItem<int>(
                                      value: c['id'] as int,
                                      child: Text(
                                        c['name'] as String,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: _saving
                                    ? null
                                    : (v) => setState(() => _categoryId = v),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_accounts.isNotEmpty || _accountId != null)
                              AccountPicker(
                                accounts: _accounts,
                                value: _accountId,
                                onChanged: _saving
                                    ? null
                                    : (v) => setState(() => _accountId = v),
                              ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              isExpanded: true,
                              initialValue: _frequency,
                              dropdownColor: t.card,
                              decoration: const InputDecoration(
                                labelText: 'Sıklık',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 1,
                                  child: Text('Haftalık'),
                                ),
                                DropdownMenuItem(
                                  value: 2,
                                  child: Text('Aylık'),
                                ),
                                DropdownMenuItem(
                                  value: 3,
                                  child: Text('Yıllık'),
                                ),
                              ],
                              onChanged: _saving
                                  ? null
                                  : (v) => setState(() => _frequency = v!),
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Başlangıç tarihi'),
                              subtitle: Text(
                                DateFormat('dd.MM.yyyy').format(_start),
                              ),
                              onTap: _saving ? null : () => _pickDate(false),
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Bitiş tarihi (isteğe bağlı)'),
                              subtitle: Text(
                                _end == null
                                    ? 'Bitiş yok'
                                    : DateFormat('dd.MM.yyyy').format(_end!),
                              ),
                              onTap: _saving ? null : () => _pickDate(true),
                              trailing: _end == null
                                  ? null
                                  : IconButton(
                                      tooltip: 'Bitiş yok',
                                      onPressed: _saving
                                          ? null
                                          : () => setState(() => _end = null),
                                      icon: const Icon(LucideIcons.x),
                                    ),
                            ),
                            DropdownButtonFormField<int>(
                              isExpanded: true,
                              initialValue: _remind,
                              dropdownColor: t.card,
                              decoration: const InputDecoration(
                                labelText: 'Hatırlatma',
                              ),
                              items: [
                                for (final entry in const {
                                  0: 'Günü gelince',
                                  1: '1 gün önce',
                                  2: '2 gün önce',
                                  3: '3 gün önce',
                                  7: '1 hafta önce',
                                }.entries)
                                  DropdownMenuItem(
                                    value: entry.key,
                                    child: Text(entry.value),
                                  ),
                                // API 0–7 aralığını kabul eder; mevcut 4/5/6 değeri de kaybolmaz.
                                if (_remind > 3 && _remind < 7)
                                  DropdownMenuItem(
                                    value: _remind,
                                    child: Text('$_remind gün önce'),
                                  ),
                              ],
                              onChanged: _saving
                                  ? null
                                  : (v) => setState(() => _remind = v!),
                            ),
                          ],
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(_error!, style: TextStyle(color: t.red)),
                        ),
                      ElevatedButton(
                        onPressed: _saving || _loadError != null ? null : _save,
                        child: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

String? recurringAmountError(String? s) {
  final value = (s ?? '').trim().replaceAll(',', '.');
  final n = double.tryParse(value);
  return n == null ||
          !n.isFinite ||
          n <= 0 ||
          n >= 1e16 ||
          !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)
      ? 'En fazla iki ondalıklı pozitif tutar giriniz'
      : null;
}
