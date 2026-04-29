import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/constants/app_colors.dart';

class DonutChart extends StatelessWidget {
  final double totalIncome;
  final double totalExpense;
  final double balance;

  const DonutChart({
    super.key,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final total = totalIncome + totalExpense;

    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Donut chart
          PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 70,
              startDegreeOffset: -90,
              sections: [
                // Gelir dilimi
                PieChartSectionData(
                  value: total > 0 ? totalIncome : 1,
                  color: AppColors.green,
                  radius: 28,
                  showTitle: false,
                ),
                // Gider dilimi
                PieChartSectionData(
                  value: total > 0 ? totalExpense : 1,
                  color: AppColors.red,
                  radius: 28,
                  showTitle: false,
                ),
              ],
            ),
          ),

          // Ortadaki bakiye yazısı
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Bakiye',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₺${balance.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
