import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/constants/app_colors.dart';

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  int _selectedPeriod = 1; // 0=1H, 1=1A, 2=3A, 3=1Y

  // Mock portföy verisi
  final double _totalPortfolio = 127450.00;
  final double _dailyChange = 1250.00;
  final double _dailyChangePercent = 0.99;

  // Mock 7 günlük performans verisi
  final List<double> _weeklyData = [
    124200, 125800, 124900, 126100, 127300, 126200, 127450
  ];

  // Mock yatırım listesi
  final List<Map<String, dynamic>> _investments = [
    {
      'name': 'THYAO',
      'fullName': 'Türk Hava Yolları',
      'price': 312.40,
      'change': 2.15,
      'icon': Icons.flight_rounded,
      'color': AppColors.cyan,
      'sparkline': [295.0, 300.0, 305.0, 298.0, 308.0, 310.0, 312.4],
    },
    {
      'name': 'Altın (gr)',
      'fullName': 'Gram Altın',
      'price': 3285.00,
      'change': -0.42,
      'icon': Icons.diamond_rounded,
      'color': AppColors.orange,
      'sparkline': [3310.0, 3295.0, 3300.0, 3280.0, 3275.0, 3290.0, 3285.0],
    },
    {
      'name': 'SASA',
      'fullName': 'SASA Polyester',
      'price': 58.70,
      'change': 4.32,
      'icon': Icons.factory_rounded,
      'color': AppColors.green,
      'sparkline': [54.0, 55.5, 56.0, 55.8, 57.2, 58.0, 58.7],
    },
    {
      'name': 'USD/TRY',
      'fullName': 'Amerikan Doları',
      'price': 38.42,
      'change': 0.18,
      'icon': Icons.attach_money_rounded,
      'color': AppColors.purple,
      'sparkline': [38.10, 38.20, 38.15, 38.30, 38.35, 38.38, 38.42],
    },
    {
      'name': 'EUR/TRY',
      'fullName': 'Euro',
      'price': 41.85,
      'change': -0.25,
      'icon': Icons.euro_rounded,
      'color': const Color(0xFF3B82F6),
      'sparkline': [42.10, 42.00, 41.95, 41.90, 41.88, 41.80, 41.85],
    },
    {
      'name': 'BTC',
      'fullName': 'Bitcoin',
      'price': 96520.00,
      'change': 1.87,
      'icon': Icons.currency_bitcoin_rounded,
      'color': const Color(0xFFF7931A),
      'sparkline': [94000.0, 94500.0, 95200.0, 95800.0, 96000.0, 96300.0, 96520.0],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              const Text(
                'Yatırımlar',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              // Portföy değeri kartı
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.gradientPurpleCyan,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Toplam Portföy',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₺${_totalPortfolio.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _dailyChange >= 0
                                ? Colors.white.withOpacity(0.2)
                                : AppColors.red.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _dailyChange >= 0
                                    ? Icons.trending_up_rounded
                                    : Icons.trending_down_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_dailyChange >= 0 ? '+' : ''}₺${_dailyChange.toStringAsFixed(0)} (${_dailyChangePercent.toStringAsFixed(2)}%)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Bugün', style: TextStyle(color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Periyod seçici
              Row(
                children: [
                  _buildPeriodChip('1H', 0),
                  const SizedBox(width: 8),
                  _buildPeriodChip('1A', 1),
                  const SizedBox(width: 8),
                  _buildPeriodChip('3A', 2),
                  const SizedBox(width: 8),
                  _buildPeriodChip('1Y', 3),
                ],
              ),

              const SizedBox(height: 16),

              // Çizgi grafik
              Container(
                height: 200,
                padding: const EdgeInsets.fromLTRB(0, 16, 16, 8),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) => spots.map((spot) =>
                          LineTooltipItem(
                            '₺${spot.y.toStringAsFixed(0)}',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ).toList(),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _weeklyData.asMap().entries.map((e) =>
                          FlSpot(e.key.toDouble(), e.value),
                        ).toList(),
                        isCurved: true,
                        color: AppColors.purple,
                        barWidth: 3,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.purple.withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Yatırımlarım başlığı
              const Text(
                'Yatırımlarım',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 14),

              // Yatırım listesi
              ..._investments.map((inv) => _buildInvestmentCard(inv)),

              const SizedBox(height: 20),

              // Uyarı notu
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.orange, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Veriler örnek amaçlıdır. Gerçek piyasa verileri yakında eklenecektir.',
                        style: TextStyle(color: AppColors.orange.withOpacity(0.8), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String label, int value) {
    final isActive = _selectedPeriod == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive ? AppColors.gradientPurple : null,
          color: isActive ? null : AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.textSecondary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildInvestmentCard(Map<String, dynamic> inv) {
    final change = inv['change'] as double;
    final isPositive = change >= 0;
    final sparkline = inv['sparkline'] as List<double>;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // İkon
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: (inv['color'] as Color).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(inv['icon'] as IconData, color: inv['color'] as Color, size: 22),
          ),
          const SizedBox(width: 14),

          // İsim
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inv['name'],
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  inv['fullName'],
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),

          // Mini sparkline
          SizedBox(
            width: 60,
            height: 30,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: sparkline.asMap().entries.map((e) =>
                      FlSpot(e.key.toDouble(), e.value),
                    ).toList(),
                    isCurved: true,
                    color: isPositive ? AppColors.green : AppColors.red,
                    barWidth: 1.5,
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Fiyat + değişim
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₺${(inv['price'] as double).toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${isPositive ? '+' : ''}${change.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: isPositive ? AppColors.green : AppColors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
