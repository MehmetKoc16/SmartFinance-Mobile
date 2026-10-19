import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/formatters.dart';
import '../models/account.dart';
import '../services/account_service.dart';
import '../widgets/account_widgets.dart';

class AccountEditScreen extends StatefulWidget {
  const AccountEditScreen({super.key, this.account});
  final Account? account;
  @override
  State<AccountEditScreen> createState() => _AccountEditScreenState();
}

class _AccountEditScreenState extends State<AccountEditScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _opening, _limit;
  late int _type, _statementDay, _dueDay;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _name = TextEditingController(text: a?.name ?? '');
    _opening = TextEditingController(
      text: quantityForInput(a?.openingBalance ?? 0),
    );
    _limit = TextEditingController(
      text: a?.creditLimit == null ? '' : quantityForInput(a!.creditLimit!),
    );
    _type = a?.type ?? 1;
    _statementDay = a?.statementDay ?? 20;
    _dueDay = a?.dueDay ?? 25;
  }

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    _limit.dispose();
    super.dispose();
  }

  double? _number(String s) => double.tryParse(s.replaceAll(',', '.'));
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AccountService.save(
        id: widget.account?.id,
        name: _name.text.trim(),
        type: _type,
        openingBalance: _number(_opening.text),
        creditLimit: _type == 3 ? _number(_limit.text) : null,
        statementDay: _type == 3 ? _statementDay : null,
        dueDay: _type == 3 ? _dueDay : null,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      await showAccountError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account == null ? 'Hesap ekle' : 'Hesabı düzenle'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AccountPanel(
                  child: Column(
                    children: [
                      TextFormField(
                        key: const Key('account-name'),
                        controller: _name,
                        maxLength: 60,
                        decoration: const InputDecoration(
                          labelText: 'Hesap adı',
                        ),
                        validator: (s) => (s ?? '').trim().isEmpty
                            ? 'Hesap adı giriniz'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        key: const Key('account-type'),
                        initialValue: _type,
                        dropdownColor: t.card,
                        style: TextStyle(color: t.text),
                        decoration: InputDecoration(
                          labelText: 'Tür',
                          suffixIcon: widget.account == null
                              ? null
                              : Icon(LucideIcons.lock, color: t.textSec),
                        ),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Nakit')),
                          DropdownMenuItem(value: 2, child: Text('Banka')),
                          DropdownMenuItem(
                            value: 3,
                            child: Text('Kredi kartı'),
                          ),
                        ],
                        onChanged: widget.account != null || _saving
                            ? null
                            : (v) => setState(() => _type = v!),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('opening-balance'),
                        controller: _opening,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: InputDecoration(
                          labelText: _type == 3
                              ? 'Mevcut borç'
                              : 'Açılış bakiyesi',
                        ),
                        validator: (s) {
                          final n = _number(s ?? '');
                          return n == null ||
                                  !n.isFinite ||
                                  (_type == 3 && n < 0)
                              ? 'Geçerli bir tutar giriniz'
                              : null;
                        },
                      ),
                      if (_type == 3) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('credit-limit'),
                          controller: _limit,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(labelText: 'Limit'),
                          validator: (s) {
                            final n = _number(s ?? '');
                            return n == null || !n.isFinite || n <= 0
                                ? 'Pozitif limit giriniz'
                                : null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _day(
                          'Hesap kesim günü',
                          _statementDay,
                          (v) => setState(() => _statementDay = v),
                        ),
                        const SizedBox(height: 16),
                        _day(
                          'Son ödeme günü',
                          _dueDay,
                          (v) => setState(() => _dueDay = v),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: TextStyle(color: t.red)),
                  ),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _day(String label, int value, ValueChanged<int> changed) =>
      DropdownButtonFormField<int>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: List.generate(
          28,
          (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
        ),
        onChanged: _saving ? null : (v) => changed(v!),
      );
}
