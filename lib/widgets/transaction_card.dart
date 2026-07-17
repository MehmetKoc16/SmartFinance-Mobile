import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class TransactionCard extends StatelessWidget {
  final String description;
  final double amount;
  final int type; // 1 = Gelir, 2 = Gider
  final String categoryName;
  final String date;
  final IconData? icon;

  const TransactionCard({
    super.key,
    required this.description,
    required this.amount,
    required this.type,
    required this.categoryName,
    required this.date,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = type == 1;
    final color = isIncome ? AppColors.green : AppColors.red;
    final prefix = isIncome ? '+' : '-';
    final displayIcon = icon ?? (isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          // Kategori ikonu
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(displayIcon, color: color, size: 19),
          ),
          const SizedBox(width: 12),

          // Açıklama + kategori
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  categoryName,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Tutar + tarih
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$prefix₺${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                date,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
