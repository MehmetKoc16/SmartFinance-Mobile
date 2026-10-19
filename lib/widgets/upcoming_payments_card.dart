import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/formatters.dart';
import '../models/recurring_payment.dart';
import '../screens/recurring_payment_edit_screen.dart';
import '../screens/recurring_payments_screen.dart';
import '../services/amount_privacy.dart';
import '../services/recurring_payment_service.dart';
import '../services/transaction_trash.dart';
import 'account_widgets.dart';
import 'recurring_payment_widgets.dart';

class UpcomingPaymentsCard extends StatefulWidget {
  const UpcomingPaymentsCard({super.key});
  @override
  State<UpcomingPaymentsCard> createState() => UpcomingPaymentsCardState();
}

class UpcomingPaymentsCardState extends State<UpcomingPaymentsCard>
    with AmountPrivacyListener {
  Upcoming? _upcoming;
  bool _hasPlans = false;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    RecurringPaymentService.changes.addListener(reload);
    TransactionTrash.changes.addListener(reload);
    reload();
  }

  @override
  void dispose() {
    RecurringPaymentService.changes.removeListener(reload);
    TransactionTrash.changes.removeListener(reload);
    super.dispose();
  }

  Future<void> reload() async {
    final request = ++_request;
    try {
      final result = await Future.wait<dynamic>([
        RecurringPaymentService.upcoming(),
        RecurringPaymentService.list(),
      ]);
      if (!mounted || request != _request) return;
      setState(() {
        _upcoming = result[0] as Upcoming;
        _hasPlans = (result[1] as List<RecurringPayment>).isNotEmpty;
      });
    } catch (_) {
      if (mounted && request == _request) setState(() => _upcoming = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _upcoming;
    if (upcoming == null) return const SizedBox.shrink();
    final t = AppTokens.of(context);
    if (!_hasPlans && upcoming.items.isEmpty) {
      return AccountPanel(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(LucideIcons.calendar, color: t.brand),
          title: const Text(
            'Düzenli ödemelerini ekle, günü gelince hatırlatalım',
          ),
          onTap: () => Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const RecurringPaymentEditScreen(),
            ),
          ),
        ),
      );
    }
    final items = [...upcoming.items]
      ..sort((a, b) {
        final overdue = (a.status == 'overdue' ? 0 : 1).compareTo(
          b.status == 'overdue' ? 0 : 1,
        );
        if (overdue != 0) return overdue;
        final date = a.dueDate.compareTo(b.dueDate);
        return date != 0
            ? date
            : a.recurringPaymentId.compareTo(b.recurringPaymentId);
      });
    return AccountPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Yaklaşan ödemeler',
                  style: TextStyle(color: t.text, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RecurringPaymentsScreen(),
                  ),
                ),
                child: const Text('Tümünü gör'),
              ),
            ],
          ),
          Text(
            '30 günde ${formatTRY(upcoming.expenseTotal)}',
            style: TextStyle(color: t.textSec),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Önümüzdeki 30 günde ödeme yok.',
                style: TextStyle(color: t.textSec),
              ),
            ),
          for (final item in items.take(3))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                item.name,
                style: TextStyle(color: item.type == 1 ? t.green : t.text),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('dd.MM.yyyy').format(item.dueDate)),
                  if (item.status == 'overdue' || item.status == 'today')
                    RecurringStatusBadge(
                      status: item.status,
                      label: item.status == 'overdue' ? 'Gecikti' : 'Bugün',
                    ),
                ],
              ),
              trailing: Text(
                formatTRY(item.amount),
                style: TextStyle(color: item.type == 1 ? t.green : t.text),
              ),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => const RecurringPaymentsScreen(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
