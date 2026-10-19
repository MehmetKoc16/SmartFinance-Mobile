import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/app_tokens.dart';
import '../models/account.dart';
import '../screens/premium_screen.dart';
import '../services/account_service.dart';

Future<void> showAccountError(BuildContext context, Object error) async {
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(error.toString())));
  if (error is AccountException && error.premiumRequired) {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const PremiumScreen()),
    );
  }
}

class AccountPanel extends StatelessWidget {
  const AccountPanel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: t.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: t.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

class AccountPicker extends StatelessWidget {
  const AccountPicker({
    super.key,
    required this.accounts,
    required this.value,
    required this.onChanged,
    this.label = 'Hesap',
    this.emptyLabel = 'Hesap seçilmedi',
  });
  final List<Account> accounts;
  final int? value;
  final ValueChanged<int?>? onChanged;
  final String label, emptyLabel;
  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return DropdownButtonFormField<int>(
      key: ValueKey('$label-$value-${accounts.map((a) => a.id).join(',')}'),
      initialValue: value,
      isExpanded: true,
      dropdownColor: t.card,
      style: TextStyle(color: t.text),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(LucideIcons.wallet, color: t.brand),
      ),
      hint: Text(emptyLabel, style: TextStyle(color: t.textSec)),
      items: [
        DropdownMenuItem<int>(child: Text(emptyLabel)),
        if (value != null && !accounts.any((a) => a.id == value))
          DropdownMenuItem<int>(
            value: value,
            enabled: false,
            child: const Text('Kullanılamayan hesap'),
          ),
        for (final a in accounts)
          DropdownMenuItem(
            value: a.id,
            child: Text('${a.name}${a.isArchived ? ' · Arşivlendi' : ''}'),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
