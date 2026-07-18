import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/constants/category_style.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/formatters.dart';

class TransactionCard extends StatelessWidget {
  final String description;
  final String? merchantName;
  final double amount;
  final int type; // 1 = Gelir, 2 = Gider
  final String categoryName;
  final String date;
  final VoidCallback? onTap;
  final bool showDivider;

  const TransactionCard({
    super.key,
    required this.description,
    this.merchantName,
    required this.amount,
    required this.type,
    required this.categoryName,
    required this.date,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = type == 1;
    final hasCategory = categoryName.isNotEmpty;
    final style = hasCategory ? CategoryStyles.of(categoryName) : null;
    final badgeColor = style?.color ?? t.textTert;
    final badgeBg = style != null
        ? style.color.withValues(alpha: isDark ? 0.22 : 0.13)
        : t.inputBg;
    final title = (merchantName != null && merchantName!.trim().isNotEmpty)
        ? merchantName!.trim()
        : description;
    final amountColor = isIncome ? t.green : t.red;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: showDivider ? Border(bottom: BorderSide(color: t.divider)) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(11)),
              child: Icon(style?.icon ?? LucideIcons.helpCircle, color: badgeColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? 'İsimsiz İşlem' : title,
                    style: TextStyle(color: t.text, fontSize: 14.5, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  if (hasCategory)
                    Text(
                      date.isEmpty ? categoryName : '$categoryName · $date',
                      style: TextStyle(color: t.textSec, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: t.inputBg, borderRadius: BorderRadius.circular(100)),
                        child: Text('Kategori seç', style: TextStyle(color: t.textTert, fontSize: 11.5)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isIncome ? LucideIcons.arrowDownLeft : LucideIcons.arrowUpRight,
                  color: amountColor,
                  size: 13,
                ),
                const SizedBox(width: 3),
                Text(
                  formatTRY(amount),
                  style: TextStyle(color: amountColor, fontWeight: FontWeight.w600, fontSize: 14.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
