import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_type_colors.dart';
import '../core/constants/indicator_catalog.dart';
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

class _LineSpec {
  final String valueKey;
  final String label;
  final Color color;
  final bool dashed;
  const _LineSpec(this.valueKey, this.label, this.color, {this.dashed = false});
}

class _TechnicalAnalysisScreenState extends State<TechnicalAnalysisScreen> {
  static const _prefsKey = 'selected_indicators';

  // Osilator turundeki gostergelerden sinir degeri (asiri alim/satim) olanlarin
  // sabit Y ekseni araligi ve referans cizgileri.
  static const Map<String, (double, double)> _fixedYRange = {
    'rsi': (0, 100), 'stoch': (0, 100), 'stochrsi': (0, 100), 'mfi': (0, 100),
    'williamsr': (-100, 0),
  };
  static const Map<String, (double, double)> _refLines = {
    'rsi': (70, 30), 'stoch': (80, 20), 'stochrsi': (80, 20), 'mfi': (80, 20),
    'williamsr': (-20, -80),
  };

  static const List<(String, String)> _allRanges = [
    ('1d', '1G'), ('1w', '1H'), ('1m', '1A'), ('6m', '6A'),
    ('ytd', 'YBB'), ('1y', '1Y'), ('5y', '5Y'),
  ];

  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  Set<String> _selectedIndicators = {};
  final Set<String> _openSections = {'_price'};
  String _selectedRange = '6m';

  bool get _isFund => widget.investment?['investmentType'] == 'fund';

  // "1 Gun" gercek gun-ici (saatlik) veri gerektiriyor — sadece hisse/kripto
  // saglayicilarinda mumkun. Doviz/altin resmi olarak gunde bir (altin ayda
  // bir) yayinlaniyor, fon gunde bir NAV — gun-ici veri hicbir sekilde yok.
  // TEFAS ayrica kendi hiz siniri korumasi yuzunden uzun araliklarda cok
  // yavas (1Yil ~2.5dk, 5Yil ~12dk), o yuzden fon 6 Ay'a kadar sinirli.
  List<(String, String)> _availableRanges() {
    final type = widget.investment?['investmentType'];
    if (type == 'fund') return _allRanges.where((r) => ['1w', '1m', '6m'].contains(r.$1)).toList();
    if (type == 'currency' || type == 'gold') return _allRanges.where((r) => r.$1 != '1d').toList();
    return _allRanges;
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!_isFund) {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_prefsKey);
      _selectedIndicators = (saved != null && saved.isNotEmpty)
          ? saved.toSet()
          : Set.from(IndicatorCatalog.defaultSelected);
    }
    await _loadData();
  }

  Future<void> _saveIndicatorPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _selectedIndicators.toList());
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final indicatorsParam = _selectedIndicators.isEmpty ? '' : '&indicators=${_selectedIndicators.join(',')}';
    final result = await ApiService.authenticatedGet(
      '/investment/${widget.investmentId}/technical-analysis?range=$_selectedRange$indicatorsParam',
      // TEFAS (fon) saglayicisi kendi hiz siniri korumasi icin parcalar
      // arasi bilerek 11sn bekliyor (180 gunluk sorgu ~80sn surebilir) —
      // genel 15sn varsayilanindan cok daha uzun bir sure gerekiyor.
      timeout: const Duration(seconds: 100),
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
    final indicatorSeries = (_data!['indicators'] as List).cast<Map<String, dynamic>>();
    final statistics = _data!['statistics'] as Map<String, dynamic>?;

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

    final overlaySeries = indicatorSeries.where((s) => IndicatorCatalog.byKey(s['key'])?.category == 'trend').toList();
    final oscillatorSeries =
        indicatorSeries.where((s) => IndicatorCatalog.byKey(s['key'])?.category != 'trend').toList();

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
        const SizedBox(height: 12),
        _buildRangeSelector(t),
        const SizedBox(height: 12),

        _indicatorSection(
          t,
          sectionKey: '_price',
          title: 'Fiyat Grafiği',
          chart: _buildPriceChart(t, priceBars, overlaySeries),
        ),

        for (final series in oscillatorSeries)
          if (series['key'] == 'macd')
            _indicatorSection(
              t,
              sectionKey: 'macd',
              title: 'MACD (12,26,9)',
              chart: Column(children: [
                _buildMacdChart(t, (series['points'] as List).cast<Map<String, dynamic>>()),
                const SizedBox(height: 10),
                _buildMacdHistogram(t, (series['points'] as List).cast<Map<String, dynamic>>()),
              ]),
            )
          else
            _indicatorSection(
              t,
              sectionKey: series['key'] as String,
              title: IndicatorCatalog.byKey(series['key'] as String)?.name ?? series['key'] as String,
              chart: _buildOscillatorChart(t, series),
            ),

        if (!_isFund) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showIndicatorPicker,
              icon: Icon(LucideIcons.slidersHorizontal, size: 16, color: t.brand),
              label: Text('Gösterge Ekle/Çıkar', style: TextStyle(color: t.brand, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: t.border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],

        if (statistics != null) _buildStatsGrid(t, statistics),

        const SizedBox(height: 6),
        if (widget.investment != null) _buildPositionSummary(t, widget.investment!),
      ],
    );
  }

  void _showIndicatorPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTokens.of(context).card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final t = AppTokens.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: t.textTert, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Göstergeler', style: jakarta(fontSize: 18, fontWeight: FontWeight.w700, color: t.text)),
                    const SizedBox(height: 16),
                    for (final cat in IndicatorCatalog.categoryOrder) ...[
                      Text(IndicatorCatalog.categoryLabel[cat]!,
                          style: TextStyle(color: t.textSec, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: IndicatorCatalog.all.where((d) => d.category == cat).map((def) {
                          final isSelected = _selectedIndicators.contains(def.key);
                          return GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                if (isSelected) {
                                  _selectedIndicators.remove(def.key);
                                } else {
                                  _selectedIndicators.add(def.key);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? t.brandSoft : t.card,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isSelected ? t.brand : t.border, width: isSelected ? 2 : 1),
                              ),
                              child: Text(def.name,
                                  style: TextStyle(
                                      color: t.text,
                                      fontSize: 12.5,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _saveIndicatorPreferences();
      _loadData();
    });
  }

  Widget _buildStatsGrid(AppTokens t, Map<String, dynamic> stats) {
    final rows = <(String, String)>[];
    void addRow(String label, String key, String Function(num) fmt) {
      final v = stats[key] as num?;
      if (v == null) return;
      rows.add((label, fmt(v)));
    }

    addRow('Açılış', 'open', (v) => formatTRY(v));
    addRow('Önceki kapanış', 'previousClose', (v) => formatTRY(v));
    addRow('En yüksek', 'dayHigh', (v) => formatTRY(v));
    addRow('En düşük', 'dayLow', (v) => formatTRY(v));
    addRow('52 hafta en yüksek', 'fiftyTwoWeekHigh', (v) => formatTRY(v));
    addRow('52 hafta en düşük', 'fiftyTwoWeekLow', (v) => formatTRY(v));
    addRow('Ortalama hacim', 'averageVolume', (v) => formatCompactNumber(v));
    addRow('Piyasa değeri', 'marketCap', (v) => '₺${formatCompactNumber(v)}');
    addRow('F/K', 'trailingPE', (v) => v.toStringAsFixed(2));
    addRow('PD/DD', 'priceToBook', (v) => v.toStringAsFixed(2));
    addRow('Özsermaye değeri', 'equityValue', (v) => '₺${formatCompactNumber(v)}');
    addRow('Özsermaye karlılık', 'returnOnEquity', (v) => formatPercent(v));
    addRow('FAVÖK', 'ebitda', (v) => '₺${formatCompactNumber(v)}');
    addRow('Net kar marj', 'profitMargin', (v) => formatPercent(v));
    addRow('Brüt kar marj', 'grossMargin', (v) => formatPercent(v));

    if (rows.isEmpty) return const SizedBox.shrink();

    final pairedRows = <List<(String, String)>>[];
    for (int i = 0; i < rows.length; i += 2) {
      pairedRows.add(rows.sublist(i, (i + 2 > rows.length) ? rows.length : i + 2));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.card, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('İstatistikler', style: TextStyle(color: t.text, fontSize: 13.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          for (final pair in pairedRows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _statCell(t, pair[0].$1, pair[0].$2)),
                  const SizedBox(width: 12),
                  Expanded(child: pair.length > 1 ? _statCell(t, pair[1].$1, pair[1].$2) : const SizedBox()),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _statCell(AppTokens t, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: t.textSec, fontSize: 11.5)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(color: t.text, fontSize: 13, fontWeight: FontWeight.w600)),
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

  Widget _buildRangeSelector(AppTokens t) {
    final ranges = _availableRanges();
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ranges.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (key, label) = ranges[i];
          final isSelected = _selectedRange == key;
          return GestureDetector(
            onTap: isSelected
                ? null
                : () {
                    setState(() => _selectedRange = key);
                    _loadData();
                  },
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected ? t.brand : t.inputBg,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Text(label,
                  style: TextStyle(
                      color: isSelected ? Colors.white : t.textSec,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ),
          );
        },
      ),
    );
  }

  Widget _indicatorSection(
    AppTokens t, {
    required String sectionKey,
    required String title,
    required Widget chart,
  }) {
    final open = _openSections.contains(sectionKey);
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
            onTap: () => setState(() {
              if (open) {
                _openSections.remove(sectionKey);
              } else {
                _openSections.add(sectionKey);
              }
            }),
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

  // Trend kategorisindeki gostergeler fiyat grafigine bindirilecek cizgi
  // tanimlari — anahtar/renk eslesmesi burada tek yerden yonetiliyor.
  Map<String, List<_LineSpec>> _overlayLineSpecs(AppTokens t) => {
        'sma20': [_LineSpec('value', 'SMA20', t.purple)],
        'sma50': [_LineSpec('value', 'SMA50', t.indigo)],
        'ema20': [_LineSpec('value', 'EMA20', t.teal)],
        'ema50': [_LineSpec('value', 'EMA50', t.cyan)],
        'bollinger': [
          _LineSpec('upper', 'BB Üst', t.amber, dashed: true),
          _LineSpec('lower', 'BB Alt', t.amber, dashed: true),
        ],
        'keltner': [
          _LineSpec('upper', 'Keltner Üst', t.pink, dashed: true),
          _LineSpec('lower', 'Keltner Alt', t.pink, dashed: true),
        ],
        'donchian': [
          _LineSpec('upper', 'Donchian Üst', t.teal, dashed: true),
          _LineSpec('lower', 'Donchian Alt', t.teal, dashed: true),
        ],
        'supertrend': [_LineSpec('value', 'SuperTrend', t.green)],
        'psar': [_LineSpec('value', 'PSAR', t.red)],
        'vwap': [_LineSpec('value', 'VWAP', t.indigo)],
      };

  // Osilator paneli olarak ayrı gösterilen gostergelerin cizgi tanimlari.
  Map<String, List<_LineSpec>> _oscillatorLineSpecs(AppTokens t) => {
        'rsi': [_LineSpec('value', 'RSI', t.brand)],
        'stoch': [_LineSpec('k', '%K', t.brand), _LineSpec('d', '%D', t.amber)],
        'stochrsi': [_LineSpec('value', 'StochRSI', t.brand), _LineSpec('signal', 'Sinyal', t.amber)],
        'cci': [_LineSpec('value', 'CCI', t.brand)],
        'williamsr': [_LineSpec('value', 'Williams %R', t.brand)],
        'roc': [_LineSpec('value', 'ROC', t.brand)],
        'ultimate': [_LineSpec('value', 'Ultimate', t.brand)],
        'awesome': [_LineSpec('value', 'Awesome', t.brand)],
        'trix': [_LineSpec('value', 'TRIX', t.brand)],
        'fisher': [_LineSpec('value', 'Fisher', t.brand)],
        'tsi': [_LineSpec('value', 'TSI', t.brand), _LineSpec('signal', 'Sinyal', t.amber)],
        'adx': [_LineSpec('adx', 'ADX', t.brand), _LineSpec('pdi', '+DI', t.green), _LineSpec('mdi', '-DI', t.red)],
        'aroon': [_LineSpec('up', 'Aroon Up', t.green), _LineSpec('down', 'Aroon Down', t.red)],
        'vortex': [_LineSpec('viplus', 'VI+', t.green), _LineSpec('viminus', 'VI-', t.red)],
        'atr': [_LineSpec('value', 'ATR', t.brand)],
        'stddev': [_LineSpec('value', 'Std Sapma', t.brand)],
        'obv': [_LineSpec('value', 'OBV', t.brand)],
        'mfi': [_LineSpec('value', 'MFI', t.brand)],
        'cmf': [_LineSpec('value', 'CMF', t.brand)],
        'adl': [_LineSpec('value', 'ADL', t.brand)],
        'chaikinosc': [_LineSpec('value', 'Chaikin Osc', t.brand)],
        'forceindex': [_LineSpec('value', 'Force Index', t.brand)],
      };

  Widget _buildPriceChart(AppTokens t, List<Map<String, dynamic>> priceBars, List<Map<String, dynamic>> overlaySeries) {
    final closeSpots = <FlSpot>[
      for (int i = 0; i < priceBars.length; i++)
        FlSpot(i.toDouble(), (priceBars[i]['close'] as num).toDouble()),
    ];

    final overlayLines = <LineChartBarData>[];
    final allValues = <double>[...closeSpots.map((s) => s.y)];
    final specs = _overlayLineSpecs(t);

    for (final series in overlaySeries) {
      final key = series['key'] as String;
      final points = (series['points'] as List).cast<Map<String, dynamic>>();
      for (final spec in specs[key] ?? const <_LineSpec>[]) {
        final spots = <FlSpot>[
          for (int i = 0; i < points.length; i++)
            if (_asDouble((points[i]['values'] as Map)[spec.valueKey]) != null)
              FlSpot(i.toDouble(), _asDouble((points[i]['values'] as Map)[spec.valueKey])!),
        ];
        if (spots.isEmpty) continue;
        allValues.addAll(spots.map((s) => s.y));
        overlayLines.add(LineChartBarData(
          spots: spots,
          isCurved: false,
          color: spec.color.withValues(alpha: 0.8),
          barWidth: 1.5,
          dotData: const FlDotData(show: false),
          dashArray: spec.dashed ? [6, 4] : null,
        ));
      }
    }

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
          titlesData: _priceTitlesData(t, priceBars, isIntraday: _selectedRange == '1d'),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            ...overlayLines,
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

  Widget _buildOscillatorChart(AppTokens t, Map<String, dynamic> series) {
    final key = series['key'] as String;
    final points = (series['points'] as List).cast<Map<String, dynamic>>();
    final specs = _oscillatorLineSpecs(t)[key] ??
        [_LineSpec('value', IndicatorCatalog.byKey(key)?.name ?? key, t.brand)];

    final allValues = <double>[];
    final lines = <LineChartBarData>[];
    for (final spec in specs) {
      final spots = <FlSpot>[
        for (int i = 0; i < points.length; i++)
          if (_asDouble((points[i]['values'] as Map)[spec.valueKey]) != null)
            FlSpot(i.toDouble(), _asDouble((points[i]['values'] as Map)[spec.valueKey])!),
      ];
      if (spots.isEmpty) continue;
      allValues.addAll(spots.map((s) => s.y));
      lines.add(LineChartBarData(
        spots: spots,
        isCurved: false,
        color: spec.color,
        barWidth: 2,
        dotData: const FlDotData(show: false),
      ));
    }

    double minY, maxY;
    final fixedRange = _fixedYRange[key];
    if (fixedRange != null) {
      minY = fixedRange.$1;
      maxY = fixedRange.$2;
    } else if (allValues.isNotEmpty) {
      final rawMin = allValues.reduce((a, b) => a < b ? a : b);
      final rawMax = allValues.reduce((a, b) => a > b ? a : b);
      final pad = (rawMax - rawMin).abs() * 0.1 + 0.0001;
      minY = rawMin - pad;
      maxY = rawMax + pad;
    } else {
      minY = 0;
      maxY = 1;
    }

    final refLine = _refLines[key];

    return SizedBox(
      height: 170,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (points.length - 1).clamp(0, double.infinity).toDouble(),
          minY: minY,
          maxY: maxY,
          gridData: _gridData(t),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (v, meta) => Text(v.abs() >= 1000 ? v.toStringAsFixed(0) : v.toStringAsFixed(1),
                    style: TextStyle(color: t.textTert, fontSize: 10)),
              ),
            ),
            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          extraLinesData: refLine != null
              ? ExtraLinesData(horizontalLines: [
                  HorizontalLine(y: refLine.$1, color: t.red.withValues(alpha: 0.4), strokeWidth: 1, dashArray: [4, 4]),
                  HorizontalLine(y: refLine.$2, color: t.green.withValues(alpha: 0.4), strokeWidth: 1, dashArray: [4, 4]),
                ])
              : const ExtraLinesData(),
          lineBarsData: lines,
        ),
      ),
    );
  }

  Widget _buildMacdChart(AppTokens t, List<Map<String, dynamic>> macdPoints) {
    final macdSpots = <FlSpot>[
      for (int i = 0; i < macdPoints.length; i++)
        if (_asDouble((macdPoints[i]['values'] as Map)['macd']) != null)
          FlSpot(i.toDouble(), _asDouble((macdPoints[i]['values'] as Map)['macd'])!),
    ];
    final signalSpots = <FlSpot>[
      for (int i = 0; i < macdPoints.length; i++)
        if (_asDouble((macdPoints[i]['values'] as Map)['signal']) != null)
          FlSpot(i.toDouble(), _asDouble((macdPoints[i]['values'] as Map)['signal'])!),
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
        if (_asDouble((macdPoints[i]['values'] as Map)['histogram']) != null)
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: _asDouble((macdPoints[i]['values'] as Map)['histogram'])!,
                color: _asDouble((macdPoints[i]['values'] as Map)['histogram'])! >= 0 ? t.green : t.red,
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

  FlTitlesData _priceTitlesData(AppTokens t, List<Map<String, dynamic>> priceBars, {bool isIntraday = false}) {
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
            final label = isIntraday
                ? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
                : '${date.day}/${date.month}';
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(label, style: TextStyle(color: t.textTert, fontSize: 9)),
            );
          },
        ),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }
}
