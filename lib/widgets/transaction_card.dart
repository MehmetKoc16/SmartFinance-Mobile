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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Kategori ikonu
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(displayIcon, color: color, size: 22),
          ),
          const SizedBox(width: 14),

          // Açıklama + kategori
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  categoryName,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
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
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
