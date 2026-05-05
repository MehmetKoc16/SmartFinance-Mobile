import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/constants/app_colors.dart';
import '../services/api_service.dart';

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  List<Map<String, dynamic>> _investments = [];
  Map<String, dynamic>? _summary;
  bool _isLoading = true;

  // İkon ve renk eşleştirmeleri
  final Map<String, IconData> _typeIcons = {
    'stock': Icons.show_chart_rounded,
    'gold': Icons.diamond_rounded,
    'currency': Icons.attach_money_rounded,
    'crypto': Icons.currency_bitcoin_rounded,
  };

  final Map<String, Color> _typeColors = {
    'stock': AppColors.cyan,
    'gold': AppColors.orange,
    'currency': AppColors.purple,
    'crypto': const Color(0xFFF7931A),
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
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
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddInvestmentDialog() {
    final nameCtrl = TextEditingController();
    final fullNameCtrl = TextEditingController();
    final purchasePriceCtrl = TextEditingController();
    final currentPriceCtrl = TextEditingController();
    final quantityCtrl = TextEditingController();
    String selectedType = 'stock';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          title: const Text('Yatırım Ekle', style: TextStyle(color: AppColors.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(nameCtrl, 'Sembol (örn: THYAO)'),
                const SizedBox(height: 10),
                _buildTextField(fullNameCtrl, 'Tam Ad (örn: Türk Hava Yolları)'),
                const SizedBox(height: 10),
                _buildTextField(purchasePriceCtrl, 'Alış Fiyatı', isNumber: true),
                const SizedBox(height: 10),
                _buildTextField(currentPriceCtrl, 'Güncel Fiyat', isNumber: true),
                const SizedBox(height: 10),
                _buildTextField(quantityCtrl, 'Miktar', isNumber: true),
                const SizedBox(height: 14),
                // Tip seçici
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButton<String>(
                    value: selectedType,
                    isExpanded: true,
                    dropdownColor: AppColors.cardBg,
                    style: const TextStyle(color: AppColors.textPrimary),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'stock', child: Text('Hisse Senedi')),
                      DropdownMenuItem(value: 'gold', child: Text('Altın')),
                      DropdownMenuItem(value: 'currency', child: Text('Döviz')),
                      DropdownMenuItem(value: 'crypto', child: Text('Kripto')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedType = v!),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.purple),
              onPressed: () async {
                if (nameCtrl.text.isEmpty || purchasePriceCtrl.text.isEmpty) return;
                final result = await ApiService.authenticatedPost('/investment', {
                  'name': nameCtrl.text,
                  'fullName': fullNameCtrl.text,
                  'purchasePrice': double.tryParse(purchasePriceCtrl.text) ?? 0,
                  'currentPrice': double.tryParse(currentPriceCtrl.text) ?? 0,
                  'quantity': double.tryParse(quantityCtrl.text) ?? 0,
                  'investmentType': selectedType,
                });
                if (mounted) Navigator.pop(context);
                _loadData();
              },
              child: const Text('Ekle', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(int id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Yatırımı Sil', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('$name yatırımını silmek istediğinize emin misiniz?',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () async {
              await ApiService.authenticatedDelete('/investment/$id');
              if (mounted) Navigator.pop(context);
              _loadData();
            },
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.purple))
            : RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.purple,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Başlık + Ekle butonu
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Yatırımlar',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: _showAddInvestmentDialog,
                            icon: const Icon(Icons.add_circle_rounded, color: AppColors.purple, size: 30),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Portföy değeri kartı
                      _buildPortfolioCard(),

                      const SizedBox(height: 24),

                      // Tür bazlı dağılım
                      if (_summary != null && _summary!['byType'] != null && (_summary!['byType'] as List).isNotEmpty) ...[
                        const Text(
                          'Tür Dağılımı',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 14),
                        ...((_summary!['byType'] as List).map((t) => _buildTypeCard(t))),
                        const SizedBox(height: 20),
                      ],

                      // Yatırımlarım başlığı
                      const Text(
                        'Yatırımlarım',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
                      ),

                      const SizedBox(height: 14),

                      if (_investments.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.show_chart_rounded, size: 48, color: AppColors.textMuted),
                              const SizedBox(height: 12),
                              const Text('Henüz yatırım yok', style: TextStyle(color: AppColors.textMuted)),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _showAddInvestmentDialog,
                                child: const Text('İlk yatırımını ekle', style: TextStyle(color: AppColors.purple)),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._investments.map((inv) => _buildInvestmentCard(inv)),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildPortfolioCard() {
    final totalCurrent = (_summary?['totalCurrentValue'] ?? 0).toDouble();
    final totalProfitLoss = (_summary?['totalProfitLoss'] ?? 0).toDouble();
    final profitPercent = (_summary?['totalProfitLossPercentage'] ?? 0).toDouble();
    final isPositive = totalProfitLoss >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.gradientPurpleCyan,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Toplam Portföy', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            '₺${totalCurrent.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isPositive ? Colors.white.withOpacity(0.2) : AppColors.red.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: Colors.white, size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${isPositive ? '+' : ''}₺${totalProfitLoss.toStringAsFixed(2)} (${profitPercent.toStringAsFixed(2)}%)',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeCard(dynamic typeData) {
    final type = typeData['investmentType'] ?? '';
    final currentValue = (typeData['totalCurrentValue'] ?? 0).toDouble();
    final profitLoss = (typeData['profitLoss'] ?? 0).toDouble();
    final count = typeData['count'] ?? 0;
    final isPositive = profitLoss >= 0;

    final labels = {'stock': 'Hisse', 'gold': 'Altın', 'currency': 'Döviz', 'crypto': 'Kripto'};

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: (_typeColors[type] ?? AppColors.purple).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_typeIcons[type] ?? Icons.help, color: _typeColors[type] ?? AppColors.purple, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(labels[type] ?? type, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                Text('$count adet', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₺${currentValue.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
              Text(
                '${isPositive ? '+' : ''}₺${profitLoss.toStringAsFixed(2)}',
                style: TextStyle(color: isPositive ? AppColors.green : AppColors.red, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentCard(Map<String, dynamic> inv) {
    final purchasePrice = (inv['purchasePrice'] ?? 0).toDouble();
    final currentPrice = (inv['currentPrice'] ?? 0).toDouble();
    final quantity = (inv['quantity'] ?? 0).toDouble();
    final profitLoss = (currentPrice - purchasePrice) * quantity;
    final profitPercent = purchasePrice == 0 ? 0.0 : ((currentPrice - purchasePrice) / purchasePrice) * 100;
    final isPositive = profitLoss >= 0;
    final type = inv['investmentType'] ?? '';

    return GestureDetector(
      onLongPress: () => _showDeleteConfirmation(inv['id'], inv['name'] ?? ''),
      child: Container(
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
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: (_typeColors[type] ?? AppColors.purple).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_typeIcons[type] ?? Icons.show_chart, color: _typeColors[type] ?? AppColors.purple, size: 22),
            ),
            const SizedBox(width: 14),

            // İsim
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(inv['name'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(inv['fullName'] ?? '', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text('${quantity.toStringAsFixed(2)} adet × ₺${purchasePrice.toStringAsFixed(2)}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                ],
              ),
            ),

            // Fiyat + kar/zarar
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₺${currentPrice.toStringAsFixed(2)}',
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text('${isPositive ? '+' : ''}${profitPercent.toStringAsFixed(2)}%',
                    style: TextStyle(color: isPositive ? AppColors.green : AppColors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                Text('${isPositive ? '+' : ''}₺${profitLoss.toStringAsFixed(2)}',
                    style: TextStyle(color: isPositive ? AppColors.green : AppColors.red, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
