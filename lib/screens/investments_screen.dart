import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/constants/app_type_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/formatters.dart';
import '../services/api_service.dart';
import 'technical_analysis_screen.dart';

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  List<Map<String, dynamic>> _investments = [];
  Map<String, dynamic>? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Ekran her açıldığında/yenilendiğinde fiyatlar önce sağlayıcılardan tazelenir
      final refreshResult = await ApiService.authenticatedPost('/investment/refresh-prices', {});

      if (refreshResult is Map && refreshResult.containsKey('error')) {
        // Yenileme başarısız oldu — eski akışa düş (mevcut listeyi olduğu gibi göster)
        final investmentsData = await ApiService.authenticatedGet('/investment');
        final summaryData = await ApiService.authenticatedGet('/investment/summary');
        if (mounted) {
          setState(() {
            if (investmentsData is List) {
              _investments = investmentsData.cast<Map<String, dynamic>>();
            }
            if (summaryData is Map) {
              _summary = summaryData.cast<String, dynamic>();
            }
            _isLoading = false;
          });
          final t = AppTokens.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Fiyatlar güncellenemedi, önceki değerler gösteriliyor.'),
              backgroundColor: t.amber,
              behavior: SnackBarBehavior.floating,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
            ),
          );
        }
        return;
      }

      final summaryData = await ApiService.authenticatedGet('/investment/summary');

      if (mounted) {
        setState(() {
          if (refreshResult is Map && refreshResult['investments'] is List) {
            _investments = (refreshResult['investments'] as List).cast<Map<String, dynamic>>();
          }
          if (summaryData is Map) {
            _summary = summaryData.cast<String, dynamic>();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showInvestmentDialog({Map<String, dynamic>? investment}) {
    final t = AppTokens.of(context);
    final isEdit = investment != null;
    final nameCtrl = TextEditingController(text: investment?['name'] ?? '');
    final fullNameCtrl = TextEditingController(text: investment?['fullName'] ?? '');
    final purchasePriceCtrl = TextEditingController(
        text: investment != null ? '${investment['purchasePrice'] ?? ''}' : '');
    final quantityCtrl = TextEditingController(
        text: investment != null ? '${investment['quantity'] ?? ''}' : '');
    String selectedType = investment?['investmentType'] ?? 'stock';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: t.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(isEdit ? 'Yatırımı Düzenle' : 'Yatırım Ekle', style: TextStyle(color: t.text)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(t, nameCtrl, 'Sembol (örn: THYAO)'),
                const SizedBox(height: 10),
                _buildTextField(t, fullNameCtrl, 'Tam Ad (örn: Türk Hava Yolları)'),
                const SizedBox(height: 10),
                _buildTextField(t, purchasePriceCtrl, 'Alış Fiyatı', isNumber: true),
                const SizedBox(height: 10),
                _buildTextField(t, quantityCtrl, 'Miktar', isNumber: true),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: t.inputBg, borderRadius: BorderRadius.circular(10)),
                  child: DropdownButton<String>(
                    value: selectedType,
                    isExpanded: true,
                    dropdownColor: t.card,
                    style: TextStyle(color: t.text),
                    underline: const SizedBox(),
                    items: AppTypeColors.investmentLabel.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedType = v!),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('İptal', style: TextStyle(color: t.textTert)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || purchasePriceCtrl.text.isEmpty) return;
                final body = {
                  'name': nameCtrl.text,
                  'fullName': fullNameCtrl.text,
                  'purchasePrice': double.tryParse(purchasePriceCtrl.text.replaceAll(',', '.')) ?? 0,
                  'quantity': double.tryParse(quantityCtrl.text.replaceAll(',', '.')) ?? 0,
                  'investmentType': selectedType,
                };
                final result = isEdit
                    ? await ApiService.authenticatedPut('/investment/${investment['id']}', body)
                    : await ApiService.authenticatedPost('/investment', body);
                if (result is Map && result.containsKey('error')) {
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(result['error']),
                        backgroundColor: t.red,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                  return;
                }
                if (mounted) Navigator.pop(this.context);
                _loadData();
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(isEdit ? 'Yatırım güncellendi.' : 'Yatırım eklendi.'),
                      backgroundColor: t.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              },
              child: Text(isEdit ? 'Güncelle' : 'Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(int id, String name) {
    final t = AppTokens.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: t.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Yatırımı Sil', style: TextStyle(color: t.text)),
        content: Text('$name yatırımını silmek istediğinize emin misiniz?', style: TextStyle(color: t.textSec)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal', style: TextStyle(color: t.textTert)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: t.red),
            onPressed: () async {
              final result = await ApiService.authenticatedDelete('/investment/$id');
              if (result is Map && result.containsKey('error')) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(result['error']),
                      backgroundColor: t.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
                return;
              }
              if (mounted) Navigator.pop(this.context);
              _loadData();
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: const Text('Yatırım silindi.'),
                    backgroundColor: t.red,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(AppTokens t, TextEditingController ctrl, String hint, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: t.text),
      decoration: InputDecoration(hintText: hint),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: t.brand))
            : RefreshIndicator(
                onRefresh: _loadData,
                color: t.brand,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Yatırımlar', style: jakarta(fontSize: 20, fontWeight: FontWeight.w700, color: t.text)),
                          GestureDetector(
                            onTap: () => _showInvestmentDialog(),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(color: t.brand, borderRadius: BorderRadius.circular(11)),
                              child: const Icon(LucideIcons.plus, color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildPortfolioCard(t),

                      if (_summary != null && _summary!['byType'] != null && (_summary!['byType'] as List).isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildAllocationCard(t, (_summary!['byType'] as List)),
                      ],

                      const SizedBox(height: 20),
                      Text('Yatırımlarım', style: jakarta(fontSize: 15, fontWeight: FontWeight.w600, color: t.text)),
                      const SizedBox(height: 10),

                      if (_investments.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: t.card,
                            border: Border.all(color: t.border),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Icon(LucideIcons.trendingUp, size: 44, color: t.textTert),
                              const SizedBox(height: 12),
                              Text('Henüz yatırım yok', style: TextStyle(color: t.textSec)),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => _showInvestmentDialog(),
                                child: Text('İlk yatırımını ekle', style: TextStyle(color: t.brand)),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: t.card,
                            border: Border.all(color: t.border),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (var i = 0; i < _investments.length; i++)
                                _buildInvestmentRow(t, _investments[i], i != _investments.length - 1),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildPortfolioCard(AppTokens t) {
    final totalCurrent = (_summary?['totalCurrentValue'] ?? 0).toDouble();
    final totalProfitLoss = (_summary?['totalProfitLoss'] ?? 0).toDouble();
    final profitPercent = (_summary?['totalProfitLossPercentage'] ?? 0).toDouble();
    final isPositive = totalProfitLoss >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Toplam Portföy', style: TextStyle(color: t.textSec, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            formatTRY(totalCurrent),
            style: jakarta(fontSize: 30, fontWeight: FontWeight.w600, color: t.text),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPositive ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight,
                color: isPositive ? t.green : t.red,
                size: 15,
              ),
              const SizedBox(width: 4),
              Text(
                '${isPositive ? '+' : ''}${formatTRY(totalProfitLoss)} (${profitPercent.toStringAsFixed(2)}%)',
                style: TextStyle(color: isPositive ? t.green : t.red, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllocationCard(AppTokens t, List byType) {
    final total = byType.fold<double>(0, (s, e) => s + (e['totalCurrentValue'] ?? 0).toDouble());
    final segments = byType.map((e) {
      final type = e['investmentType'] ?? '';
      final double value = (e['totalCurrentValue'] ?? 0).toDouble();
      final color = AppTypeColors.investmentType[type] ?? t.brand;
      final double fraction = total == 0 ? 0.0 : value / total;
      return MapEntry<Color, double>(color, fraction);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tür Dağılımı', style: TextStyle(color: t.text, fontSize: 13.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 104,
                height: 104,
                child: CustomPaint(painter: _DonutPainter(segments: segments, holeColor: t.card)),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: byType.map((e) {
                    final type = e['investmentType'] ?? '';
                    final value = (e['totalCurrentValue'] ?? 0).toDouble();
                    final pct = total == 0 ? 0 : (value / total * 100);
                    final color = AppTypeColors.investmentType[type] ?? t.brand;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppTypeColors.investmentLabel[type] ?? type,
                              style: TextStyle(color: t.text, fontSize: 12.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text('${pct.toStringAsFixed(0)}%', style: TextStyle(color: t.textSec, fontSize: 12)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentRow(AppTokens t, Map<String, dynamic> inv, bool showDivider) {
    final purchasePrice = (inv['purchasePrice'] ?? 0).toDouble();
    final currentPrice = (inv['currentPrice'] ?? 0).toDouble();
    final quantity = (inv['quantity'] ?? 0).toDouble();
    final value = currentPrice * quantity;
    final profitLoss = (currentPrice - purchasePrice) * quantity;
    final profitPercent = purchasePrice == 0 ? 0.0 : ((currentPrice - purchasePrice) / purchasePrice) * 100;
    final isPositive = profitLoss >= 0;
    final type = inv['investmentType'] ?? '';
    final color = AppTypeColors.investmentType[type] ?? t.brand;
    final icon = AppTypeColors.investmentIcon[type] ?? LucideIcons.circleDollarSign;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TechnicalAnalysisScreen(investmentId: inv['id'], name: inv['name'] ?? '', investment: inv),
        ),
      ).then((_) => _loadData()),
      onLongPress: () => _showInvestmentActions(inv),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(border: showDivider ? Border(bottom: BorderSide(color: t.divider)) : null),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
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
                  Text(inv['name'] ?? '', style: TextStyle(color: t.text, fontWeight: FontWeight.w600, fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(
                    '${quantity.toStringAsFixed(2)} adet × ${formatTRY(purchasePrice)}',
                    style: TextStyle(color: t.textSec, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatTRY(value), style: TextStyle(color: t.text, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  '${isPositive ? '+' : ''}${formatTRY(profitLoss)} (${profitPercent.toStringAsFixed(1)}%)',
                  style: TextStyle(color: isPositive ? t.green : t.red, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showInvestmentActions(Map<String, dynamic> inv) {
    final t = AppTokens.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(LucideIcons.pencil, color: t.text),
              title: Text('Düzenle', style: TextStyle(color: t.text)),
              onTap: () {
                Navigator.pop(ctx);
                _showInvestmentDialog(investment: inv);
              },
            ),
            ListTile(
              leading: Icon(LucideIcons.trash2, color: t.red),
              title: Text('Sil', style: TextStyle(color: t.red)),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirmation(inv['id'], inv['name'] ?? '');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<MapEntry<Color, double>> segments;
  final Color holeColor;
  static const _strokeWidth = 16.0;

  _DonutPainter({required this.segments, required this.holeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - _strokeWidth) / 2;
    var startAngle = -pi / 2;
    for (final seg in segments) {
      if (seg.value <= 0) continue;
      final sweep = seg.value * 2 * pi;
      final paint = Paint()
        ..color = seg.key
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.segments != segments || oldDelegate.holeColor != holeColor;
}
