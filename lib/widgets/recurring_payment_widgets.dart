import 'package:flutter/material.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/formatters.dart';

/// İşlem kartıyla aynı ad/tutar hiyerarşisi; tutar adın satırında kalır.
class RecurringPaymentTitle extends StatelessWidget {
  const RecurringPaymentTitle({
    super.key,
    required this.name,
    required this.amount,
    required this.type,
  });
  final String name;
  final double amount;
  final int type;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final color = type == 1 ? t.green : t.text;
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          formatTRY(amount),
          style: TextStyle(
            color: color,
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class RecurringStatusBadge extends StatelessWidget {
  const RecurringStatusBadge({
    super.key,
    required this.status,
    required this.label,
  });
  final String status, label;
  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final color = switch (status) {
      'overdue' => t.red,
      'today' => t.brand,
      'ended' => t.textTert,
      _ => t.textSec,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
