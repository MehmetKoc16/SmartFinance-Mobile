import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/constants/app_type_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/formatters.dart';
import '../services/api_service.dart';

class TechnicalAnalysisScreen extends StatefulWidget {
  final int investmentId;
  final String name;
  final Map<String, dynamic>? investment;

  const TechnicalAnalysisScreen({
    super.key,
    required this.investmentId,
    required this.name,
    this.investment,
  });

  @override
  State<TechnicalAnalysisScreen> createState() => _TechnicalAnalysisScreenState();
}

class _TechnicalAnalysisScreenState extends State<TechnicalAnalysisScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  bool _priceOpen = true;
  bool _rsiOpen = false;
  bool _macdOpen = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final result = await ApiService.authenticatedGet(
      '/investment/${widget.investmentId}/technical-analysis?days=180',
    );
    if (!mounted) return;
    if (result is Map && result.containsKey('error')) {
      setState(() {
        _error = result['error'];
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _data = (result as Map).cast<String, dynamic>();
      _isLoading = false;
    });
  }

  double? _asDouble(dynamic v) => v == null ? null : (v as num).toDouble();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final inv = widget.investment;
    final type = inv?['investmentType'] ?? '';
    final color = AppTypeColors.investmentType[type] ?? t.brand;
    final icon = AppTypeColors.investmentIcon[type] ?? LucideIcons.circleDollarSign;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: t.brand))
            : Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: t.card,
                              border: Border.all(color: t.border),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(LucideIcons.chevronLeft, color: t.text, size: 18),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: isDark ? 0.22 : 0.13),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(icon, color: color, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.name, style: jakarta(fontSize: 16, fontWeight: FontWeight.w700, color: t.text)),
                              if (inv?['fullName'] != null && (inv!['fullName'] as String).isNotEmpty)
                                Text(inv['fullName'], style: TextStyle(color: t.textSec, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _error != null
                          ? _buildError(t)
                          : RefreshIndicator(
                              onRefresh: _loadData,
                              color: t.brand,
                              child: SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.only(bottom: 20),
                                child: _buildContent(t),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildError(AppTokens t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.circleAlert, size: 44, color: t.textTert),
            const SizedBox(height: 12),
            Text(_error ?? 'Bir hata oluştu', style: TextStyle(color: t.textSec), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton(onPressed: _loadData, child: Text('Tekrar Dene', style: TextStyle(color: t.brand))),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AppTokens t) {
    final priceBars = (_data!['priceBars'] as List).cast<Map<String, dynamic>>();
    final rsiPoints = (_data!['rsi'] as List).cast<Map<String, dynamic>>();
    final macdPoints = ((_data!['macd'] as Map)['points'] as List).cast<Map<String, dynamic>>();
    final bbPoints = ((_data!['bollingerBands'] as Map)['points'] as List).cast<Map<String, dynamic>>();

    if (priceBars.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text('Bu yatırım için geçmiş fiyat verisi bulunamadı.',
              style: TextStyle(color: t.textSec), textAlign: TextAlign.center),
        ),
      );
    }

    final lastClose = (priceBars.last['close'] as num).toDouble();
    final prevClose = priceBars.length > 1 ? (priceBars[priceBars.length - 2]['close'] as num).toDouble() : lastClose;
    final dayChange = prevClose == 0 ? 0.0 : (lastClose - prevClose) / prevClose * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(formatTRY(lastClose), style: jakarta(fontSize: 26, fontWeight: FontWeight.w600, color: t.text)),
            const SizedBox(width: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(dayChange >= 0 ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight,
                    color: dayChange >= 0 ? t.green : t.red, size: 14),
                const SizedBox(width: 2),
                Text('${dayChange >= 0 ? '+' : ''}${dayChange.toStringAsFixed(2)}%',
                    style: TextStyle(color: dayChange >= 0 ? t.green : t.red, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        _indicatorSection(
          t,
          title: 'Fiyat & Bollinger Bantları',
          open: _priceOpen,
          onToggle: () => setState(() => _priceOpen = !_priceOpen),
          chart: _buildPriceChart(t, priceBars, bbPoints),
        ),
        _indicatorSection(
          t,
          title: 'RSI (14)',
          open: _rsiOpen,
          onToggle: () => setState(() => _rsiOpen = !_rsiOpen),
          chart: _buildRsiChart(t, rsiPoints),
        ),
        _indicatorSection(
          t,
          title: 'MACD (12, 26, 9)',
          open: _macdOpen,
          onToggle: () => setState(() => _macdOpen = !_macdOpen),
          chart: Column(children: [
            _buildMacdChart(t, macdPoints),
            const SizedBox(height: 10),
            _buildMacdHistogram(t, macdPoints),
          ]),
        ),

        const SizedBox(height: 6),
        if (widget.investment != null) _buildPositionSummary(t, widget.investment!),
      ],
    );
  }

  Widget _buildPositionSummary(AppTokens t, Map<String, dynamic> inv) {
    final purchasePrice = (inv['purchasePrice'] ?? 0).toDouble();
    final currentPrice = (inv['currentPrice'] ?? 0).toDouble();
    final quantity = (inv['quantity'] ?? 0).toDouble();
    final profitLoss = (currentPrice - purchasePrice) * quantity;
    final isPositive = profitLoss >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pozisyon Özeti', style: TextStyle(color: t.text, fontSize: 13.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _summaryRow(t, 'Adet', quantity.toStringAsFixed(2)),
          _summaryRow(t, 'Ortalama Maliyet', formatTRY(purchasePrice)),
          _summaryRow(t, 'Güncel Fiyat', formatTRY(currentPrice)),
          _summaryRow(
            t,
            'Toplam Kâr/Zarar',
            '${isPositive ? '+' : ''}${formatTRY(profitLoss)}',
            valueColor: isPositive ? t.green : t.red,
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(AppTokens t, String label, String value, {Color? valueColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: t.textSec, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? t.text, fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _indicatorSection(
    AppTokens t, {
    required String title,
    required bool open,
    required VoidCallback onToggle,
    required Widget chart,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: TextStyle(color: t.text, fontSize: 13.5, fontWeight: FontWeight.w600)),
                  Icon(open ? LucideIcons.chevronUp : LucideIcons.chevronDown, color: t.textSec, size: 18),
                ],
              ),
            ),
          ),
          if (open) Padding(padding: const EdgeInsets.fromLTRB(8, 0, 16, 16), child: chart),
        ],
      ),
    );
  }

  Widget _buildPriceChart(AppTokens t, List<Map<String, dynamic>> priceBars, List<Map<String, dynamic>> bbPoints) {
    final closeSpots = <FlSpot>[
      for (int i = 0; i < priceBars.length; i++)
        FlSpot(i.toDouble(), (priceBars[i]['close'] as num).toDouble()),
    ];
    final upperSpots = <FlSpot>[
      for (int i = 0; i < bbPoints.length; i++)
        if (_asDouble(bbPoints[i]['upperBand']) != null)
          FlSpot(i.toDouble(), _asDouble(bbPoints[i]['upperBand'])!),
    ];
    final lowerSpots = <FlSpot>[
      for (int i = 0; i < bbPoints.length; i++)
        if (_asDouble(bbPoints[i]['lowerBand']) != null)
          FlSpot(i.toDouble(), _asDouble(bbPoints[i]['lowerBand'])!),
    ];

    final allValues = [
      ...closeSpots.map((s) => s.y),
      ...upperSpots.map((s) => s.y),
      ...lowerSpots.map((s) => s.y),
    ];
    final minY = allValues.reduce((a, b) => a < b ? a : b);
    final maxY = allValues.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.05;

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (priceBars.length - 1).toDouble(),
          minY: minY - padding,
          maxY: maxY + padding,
          gridData: _gridData(t),
          titlesData: _priceTitlesData(t, priceBars),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: upperSpots,
              isCurved: false,
              color: t.amber.withValues(alpha: 0.5),
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
              dashArray: [6, 4],
            ),
            LineChartBarData(
              spots: lowerSpots,
              isCurved: false,
              color: t.amber.withValues(alpha: 0.5),
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
              dashArray: [6, 4],
            ),
            LineChartBarData(
              spots: closeSpots,
              isCurved: false,
              color: t.brand,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRsiChart(AppTokens t, List<Map<String, dynamic>> rsiPoints) {
    final spots = <FlSpot>[
      for (int i = 0; i < rsiPoints.length; i++)
        if (_asDouble(rsiPoints[i]['value']) != null) FlSpot(i.toDouble(), _asDouble(rsiPoints[i]['value'])!),
    ];

    return SizedBox(
      height: 170,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (rsiPoints.length - 1).toDouble(),
          minY: 0,
          maxY: 100,
          gridData: _gridData(t),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 25,
                getTitlesWidget: (v, meta) =>
                    Text(v.toInt().toString(), style: TextStyle(color: t.textTert, fontSize: 10)),
              ),
            ),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          extraLinesData: ExtraLinesData(horizontalLines: [
            HorizontalLine(y: 70, color: t.red.withValues(alpha: 0.4), strokeWidth: 1, dashArray: [4, 4]),
            HorizontalLine(y: 30, color: t.green.withValues(alpha: 0.4), strokeWidth: 1, dashArray: [4, 4]),
          ]),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: t.brand,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacdChart(AppTokens t, List<Map<String, dynamic>> macdPoints) {
    final macdSpots = <FlSpot>[
      for (int i = 0; i < macdPoints.length; i++)
        if (_asDouble(macdPoints[i]['macd']) != null) FlSpot(i.toDouble(), _asDouble(macdPoints[i]['macd'])!),
    ];
    final signalSpots = <FlSpot>[
      for (int i = 0; i < macdPoints.length; i++)
        if (_asDouble(macdPoints[i]['signal']) != null) FlSpot(i.toDouble(), _asDouble(macdPoints[i]['signal'])!),
    ];

    return SizedBox(
      height: 170,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (macdPoints.length - 1).toDouble(),
          gridData: _gridData(t),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, meta) => Text(v.toStringAsFixed(1), style: TextStyle(color: t.textTert, fontSize: 10)),
              ),
            ),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: macdSpots,
              isCurved: false,
              color: t.brand,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
            LineChartBarData(
              spots: signalSpots,
              isCurved: false,
              color: t.amber,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacdHistogram(AppTokens t, List<Map<String, dynamic>> macdPoints) {
    final barGroups = <BarChartGroupData>[
      for (int i = 0; i < macdPoints.length; i++)
        if (_asDouble(macdPoints[i]['histogram']) != null)
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: _asDouble(macdPoints[i]['histogram'])!,
                color: _asDouble(macdPoints[i]['histogram'])! >= 0 ? t.green : t.red,
                width: 2,
              ),
            ],
          ),
    ];

    return SizedBox(
      height: 90,
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          barGroups: barGroups,
        ),
      ),
    );
  }

  FlGridData _gridData(AppTokens t) => FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => FlLine(color: t.textTert.withValues(alpha: 0.15), strokeWidth: 1),
      );

  FlTitlesData _priceTitlesData(AppTokens t, List<Map<String, dynamic>> priceBars) {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 44,
          getTitlesWidget: (v, meta) => Text(v.toStringAsFixed(0), style: TextStyle(color: t.textTert, fontSize: 10)),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 24,
          interval: (priceBars.length / 4).clamp(1, priceBars.length).toDouble(),
          getTitlesWidget: (v, meta) {
            final idx = v.toInt();
            if (idx < 0 || idx >= priceBars.length) return const SizedBox();
            final date = DateTime.tryParse(priceBars[idx]['date'] as String);
            if (date == null) return const SizedBox();
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('${date.day}/${date.month}', style: TextStyle(color: t.textTert, fontSize: 9)),
            );
          },
        ),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }
}
