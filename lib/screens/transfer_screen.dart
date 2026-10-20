import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/formatters.dart';
import '../models/account.dart';
import '../services/account_service.dart';
import '../widgets/account_widgets.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key, this.toAccountId, this.amount});
  final int? toAccountId;
  final double? amount;
  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount;
  final _description = TextEditingController();
  List<Account> _accounts = [];
  int? _from, _to;
  DateTime _date = DateTime.now();
  bool _loading = true, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _to = widget.toAccountId;
    _amount = TextEditingController(
      text: widget.amount == null ? '' : amountForInput(widget.amount!),
    );
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final accounts = await AccountService.list();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        if (!accounts.any((a) => a.id == _to)) _to = null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_from == null || _to == null || _from == _to) {
      setState(() => _error = 'Farklı kaynak ve hedef hesap seçiniz');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AccountService.createTransfer(
        fromAccountId: _from!,
        toAccountId: _to!,
        amount: double.parse(_amount.text.replaceAll(',', '.')),
        transferDate: _date,
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (!mounted || picked == null) return;
    setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Transfer / Kart ödemesi')),
      body: SafeArea(
        child: _loading
            ? Center(child: CircularProgressIndicator(color: t.brand))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_accounts.length < 2)
                        const Text(
                          'Transfer için en az iki aktif hesap gerekir.',
                        ),
                      AccountPanel(
                        child: Column(
                          children: [
                            KeyedSubtree(
                              key: const Key('transfer-from'),
                              child: AccountPicker(
                                accounts: _accounts
                                    .where((a) => a.id != _to)
                                    .toList(),
                                value: _from,
                                label: 'Kaynak hesap',
                                emptyLabel: 'Kaynak seçiniz',
                                onChanged: _saving
                                    ? null
                                    : (v) => setState(() => _from = v),
                              ),
                            ),
                            const SizedBox(height: 16),
                            KeyedSubtree(
                              key: const Key('transfer-to'),
                              child: AccountPicker(
                                accounts: _accounts
                                    .where((a) => a.id != _from)
                                    .toList(),
                                value: _to,
                                label: 'Hedef hesap',
                                emptyLabel: 'Hedef seçiniz',
                                onChanged: _saving
                                    ? null
                                    : (v) => setState(() => _to = v),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const Key('transfer-amount'),
                              controller: _amount,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Tutar',
                              ),
                              validator: (s) {
                                final n = double.tryParse(
                                  (s ?? '').replaceAll(',', '.'),
                                );
                                return n == null || !n.isFinite || n <= 0
                                    ? 'Pozitif tutar giriniz'
                                    : null;
                              },
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Tarih'),
                              subtitle: Text(
                                DateFormat('dd.MM.yyyy').format(_date),
                              ),
                              onTap: _saving ? null : _pickDate,
                            ),
                            TextFormField(
                              controller: _description,
                              maxLength: 200,
                              decoration: const InputDecoration(
                                labelText: 'Açıklama (isteğe bağlı)',
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_error != null)
                        Text(_error!, style: TextStyle(color: t.red)),
                      if (_accounts.isEmpty && _error != null)
                        TextButton(
                          onPressed: _load,
                          child: const Text('Tekrar dene'),
                        ),
                      ElevatedButton(
                        onPressed: _saving || _accounts.length < 2
                            ? null
                            : _save,
                        child: Text(_saving ? 'Gönderiliyor…' : 'Transfer yap'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
