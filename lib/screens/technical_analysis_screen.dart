import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/constants/app_colors.dart';
import '../services/api_service.dart';

class TechnicalAnalysisScreen extends StatefulWidget {
  final int investmentId;
  final String name;

  const TechnicalAnalysisScreen({
    super.key,
    required this.investmentId,
    required this.name,
  });

  @override
  State<TechnicalAnalysisScreen> createState() => _TechnicalAnalysisScreenState();
}

class _TechnicalAnalysisScreenState extends State<TechnicalAnalysisScreen> {
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('${widget.name} — Teknik Analiz',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.purple))
            : _error != null
                ? _buildError()
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: AppColors.purple,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: _buildContent(),
                    ),
                  ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(_error ?? 'Bir hata oluştu',
                style: const TextStyle(color: AppColors.textMuted), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadData,
              child: const Text('Tekrar Dene', style: TextStyle(color: AppColors.purple)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final priceBars = (_data!['priceBars'] as List).cast<Map<String, dynamic>>();
    final rsiPoints = (_data!['rsi'] as List).cast<Map<String, dynamic>>();
    final macdPoints = ((_data!['macd'] as Map)['points'] as List).cast<Map<String, dynamic>>();
    final bbPoints = ((_data!['bollingerBands'] as Map)['points'] as List).cast<Map<String, dynamic>>();

    if (priceBars.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text('Bu yatırım için geçmiş fiyat verisi bulunamadı.',
              style: TextStyle(color: AppColors.textMuted)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Fiyat & Bollinger Bantları'),
        const SizedBox(height: 12),
        _buildPriceChart(priceBars, bbPoints),
        const SizedBox(height: 28),
        _sectionTitle('RSI (14)'),
        const SizedBox(height: 12),
        _buildRsiChart(rsiPoints),
        const SizedBox(height: 28),
        _sectionTitle('MACD (12, 26, 9)'),
        const SizedBox(height: 12),
        _buildMacdChart(macdPoints),
        const SizedBox(height: 16),
        _buildMacdHistogram(macdPoints),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
      );

  Widget _buildPriceChart(List<Map<String, dynamic>> priceBars, List<Map<String, dynamic>> bbPoints) {
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

    return _chartCard(
      height: 240,
      chart: LineChart(
        LineChartData(
          minX: 0,
          maxX: (priceBars.length - 1).toDouble(),
          minY: minY - padding,
          maxY: maxY + padding,
          gridData: _gridData(),
          titlesData: _priceTitlesData(priceBars),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: upperSpots,
              isCurved: false,
              color: AppColors.orange.withOpacity(0.5),
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
              dashArray: [6, 4],
            ),
            LineChartBarData(
              spots: lowerSpots,
              isCurved: false,
              color: AppColors.orange.withOpacity(0.5),
              barWidth: 1.5,
              dotData: const FlDotData(show: false),
              dashArray: [6, 4],
            ),
            LineChartBarData(
              spots: closeSpots,
              isCurved: false,
              color: AppColors.cyan,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRsiChart(List<Map<String, dynamic>> rsiPoints) {
    final spots = <FlSpot>[
      for (int i = 0; i < rsiPoints.length; i++)
        if (_asDouble(rsiPoints[i]['value']) != null) FlSpot(i.toDouble(), _asDouble(rsiPoints[i]['value'])!),
    ];

    return _chartCard(
      height: 180,
      chart: LineChart(
        LineChartData(
          minX: 0,
          maxX: (rsiPoints.length - 1).toDouble(),
          minY: 0,
          maxY: 100,
          gridData: _gridData(),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 25,
                getTitlesWidget: (v, meta) =>
                    Text(v.toInt().toString(), style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
              ),
            ),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          extraLinesData: ExtraLinesData(horizontalLines: [
            HorizontalLine(y: 70, color: AppColors.red.withOpacity(0.4), strokeWidth: 1, dashArray: [4, 4]),
            HorizontalLine(y: 30, color: AppColors.green.withOpacity(0.4), strokeWidth: 1, dashArray: [4, 4]),
          ]),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: AppColors.purple,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacdChart(List<Map<String, dynamic>> macdPoints) {
    final macdSpots = <FlSpot>[
      for (int i = 0; i < macdPoints.length; i++)
        if (_asDouble(macdPoints[i]['macd']) != null) FlSpot(i.toDouble(), _asDouble(macdPoints[i]['macd'])!),
    ];
    final signalSpots = <FlSpot>[
      for (int i = 0; i < macdPoints.length; i++)
        if (_asDouble(macdPoints[i]['signal']) != null) FlSpot(i.toDouble(), _asDouble(macdPoints[i]['signal'])!),
    ];

    return _chartCard(
      height: 180,
      chart: LineChart(
        LineChartData(
          minX: 0,
          maxX: (macdPoints.length - 1).toDouble(),
          gridData: _gridData(),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, meta) =>
                    Text(v.toStringAsFixed(1), style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
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
              color: AppColors.cyan,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
            LineChartBarData(
              spots: signalSpots,
              isCurved: false,
              color: AppColors.orange,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacdHistogram(List<Map<String, dynamic>> macdPoints) {
    final barGroups = <BarChartGroupData>[
      for (int i = 0; i < macdPoints.length; i++)
        if (_asDouble(macdPoints[i]['histogram']) != null)
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: _asDouble(macdPoints[i]['histogram'])!,
                color: _asDouble(macdPoints[i]['histogram'])! >= 0 ? AppColors.green : AppColors.red,
                width: 2,
              ),
            ],
          ),
    ];

    return _chartCard(
      height: 100,
      chart: BarChart(
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

  FlGridData _gridData() => FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => FlLine(color: AppColors.textMuted.withOpacity(0.1), strokeWidth: 1),
      );

  FlTitlesData _priceTitlesData(List<Map<String, dynamic>> priceBars) {
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 44,
          getTitlesWidget: (v, meta) =>
              Text(v.toStringAsFixed(0), style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
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
              child: Text('${date.day}/${date.month}', style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
            );
          },
        ),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  Widget _chartCard({required double height, required Widget chart}) {
    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: chart,
    );
  }
}
