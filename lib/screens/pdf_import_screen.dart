import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../core/constants/app_colors.dart';
import '../services/api_service.dart';

class PdfImportScreen extends StatefulWidget {
  const PdfImportScreen({super.key});

  @override
  State<PdfImportScreen> createState() => _PdfImportScreenState();
}

class _PdfImportScreenState extends State<PdfImportScreen> {
  // Aşama: 0=dosya seç, 1=önizleme, 2=sonuç
  int _step = 0;
  bool _isLoading = false;
  String? _selectedFilePath;
  String? _selectedFileName;

  // Parse sonucu
  Map<String, dynamic>? _parseResult;
  List<Map<String, dynamic>> _transactions = [];
  List<bool> _selectedItems = [];

  // Kullanıcının kategorileri
  List<Map<String, dynamic>> _categories = [];
  int _savedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final result = await ApiService.authenticatedGet('/category');
    debugPrint('[PdfImport] Categories result type: ${result.runtimeType}, value: $result');
    if (!mounted) return;
    if (result is List) {
      setState(() {
        _categories = List<Map<String, dynamic>>.from(result);
      });
    }
    debugPrint('[PdfImport] Loaded ${_categories.length} categories');
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
        _selectedFileName = result.files.single.name;
      });
    }
  }

  Future<void> _parseFile() async {
    if (_selectedFilePath == null) return;
    setState(() => _isLoading = true);

    debugPrint('[PdfImport] Uploading: $_selectedFilePath');

    final result = await ApiService.authenticatedUpload(
      '/pdfimport/parse',
      _selectedFilePath!,
    );

    debugPrint('[PdfImport] Result: $result');
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _parseResult = result is Map<String, dynamic> ? result : null;

      if (_parseResult != null && _parseResult!['transactions'] != null) {
        _transactions = List<Map<String, dynamic>>.from(
          _parseResult!['transactions'],
        );
        // Duplicate olmayanları varsayılan seçili yap
        _selectedItems = _transactions.map((t) => !(t['isDuplicate'] ?? false)).toList();
        _step = 1;
      }
    });

    if (_transactions.isEmpty && mounted) {
      final errorMsg = _parseResult?['error'] ?? _parseResult?['message'] ?? 'PDF\'den işlem çıkarılamadı. Dosya metin tabanlı olmayabilir.';
      debugPrint('[PdfImport] Error: $errorMsg');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: AppColors.orange,
        ),
      );
    }
  }

  Future<void> _confirmImport() async {
    final selectedTransactions = <Map<String, dynamic>>[];
    for (int i = 0; i < _transactions.length; i++) {
      if (_selectedItems[i]) {
        final t = _transactions[i];
        selectedTransactions.add({
          'amount': t['amount'],
          'description': t['description'] ?? '',
          'transactionDate': t['transactionDate'],
          'type': t['type'],
          'categoryId': t['categoryId'],
          'merchantName': t['merchantName'],
        });
      }
    }

    debugPrint('[PdfImport] Confirm: ${selectedTransactions.length} items selected');

    if (selectedTransactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('En az bir işlem seçmelisiniz.'),
          backgroundColor: AppColors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    debugPrint('[PdfImport] Sending confirm request...');
    final result = await ApiService.authenticatedPost('/pdfimport/confirm', {
      'transactions': selectedTransactions,
    });
    debugPrint('[PdfImport] Confirm result: $result');
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result is Map && result.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${result['error']}'), backgroundColor: AppColors.red),
        );
      } else {
        _savedCount = result['count'] ?? 0;
        _step = 2;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('PDF İçe Aktar'),
        backgroundColor: AppColors.cardBg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: _step == 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() { _step = 0; _transactions = []; }),
              )
            : null,
      ),
      body: _isLoading
          ? _buildLoading()
          : _step == 0
              ? _buildFileSelection()
              : _step == 1
                  ? _buildPreview()
                  : _buildResult(),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              children: [
                CircularProgressIndicator(color: AppColors.purple),
                SizedBox(height: 20),
                Text('PDF analiz ediliyor...', style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                SizedBox(height: 8),
                Text('İşlemler çıkarılıyor', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── AŞAMA 0: DOSYA SEÇİMİ ──────────────────────────────

  Widget _buildFileSelection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // PDF ikonu
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              gradient: AppColors.gradientPurpleCyan,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.picture_as_pdf, size: 50, color: Colors.white),
          ),
          const SizedBox(height: 24),
          const Text(
            'Banka Ekstresi Yükle',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Banka ekstresi PDF dosyanızı seçin.\nİşlemler otomatik olarak algılanacak.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          // Dosya seç kutusu
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedFilePath != null ? AppColors.green : AppColors.textMuted,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _selectedFilePath != null ? Icons.check_circle : Icons.cloud_upload_outlined,
                    size: 40,
                    color: _selectedFilePath != null ? AppColors.green : AppColors.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedFileName ?? 'PDF dosyası seçin',
                    style: TextStyle(
                      color: _selectedFilePath != null ? AppColors.green : AppColors.textSecondary,
                      fontSize: 15, fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_selectedFilePath != null) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Değiştirmek için tekrar dokunun',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Spacer(),

          // Desteklenen bankalar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardBgLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.textSecondary, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Halkbank, Ziraat ve diğer metin tabanlı PDF ekstreleri desteklenir.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Analiz Et butonu
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _selectedFilePath != null ? _parseFile : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                disabledBackgroundColor: AppColors.textMuted,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Analiz Et', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── AŞAMA 1: ÖNİZLEME ──────────────────────────────────

  Widget _buildPreview() {
    final bankName = _parseResult?['bankName'] ?? 'Bilinmeyen';
    final period = _parseResult?['period'] ?? '';
    final dupCount = _parseResult?['duplicateCount'] ?? 0;
    final selectedCount = _selectedItems.where((s) => s).length;

    double totalIncome = 0, totalExpense = 0;
    for (int i = 0; i < _transactions.length; i++) {
      if (_selectedItems[i]) {
        final t = _transactions[i];
        if (t['type'] == 1) {
          totalIncome += (t['amount'] as num).toDouble();
        } else {
          totalExpense += (t['amount'] as num).toDouble();
        }
      }
    }

    return Column(
      children: [
        // Üst bilgi kartı
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.gradientPurpleCyan,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(bankName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (period.isNotEmpty)
                    Text(period, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _summaryChip('Gelir', '+₺${totalIncome.toStringAsFixed(2)}', AppColors.green),
                  const SizedBox(width: 10),
                  _summaryChip('Gider', '-₺${totalExpense.toStringAsFixed(2)}', AppColors.red),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('$selectedCount/${_transactions.length} seçili', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  if (dupCount > 0) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('$dupCount tekrar', style: const TextStyle(color: AppColors.orange, fontSize: 11)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        // İşlem listesi
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _transactions.length,
            itemBuilder: (ctx, i) => _buildTransactionTile(i),
          ),
        ),

        // Onay butonu
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.cardBg,
            border: Border(top: BorderSide(color: AppColors.textMuted, width: 0.5)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: selectedCount > 0 ? _confirmImport : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                disabledBackgroundColor: AppColors.textMuted,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.check, color: Colors.white),
              label: Text(
                '$selectedCount İşlemi İçe Aktar',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(int index) {
    final t = _transactions[index];
    final isIncome = t['type'] == 1;
    final isDuplicate = t['isDuplicate'] ?? false;
    final amount = (t['amount'] as num).toDouble();
    final desc = t['description'] ?? '';
    final merchant = t['merchantName'] ?? '';
    final dateStr = t['transactionDate'] ?? '';
    final catName = t['categoryName'];

    // Tarih parse
    String formattedDate = '';
    try {
      final dt = DateTime.parse(dateStr);
      formattedDate = '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      formattedDate = dateStr;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDuplicate ? AppColors.cardBg.withValues(alpha: 0.5) : AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: isDuplicate ? Border.all(color: AppColors.orange.withValues(alpha: 0.4)) : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Checkbox(
          value: _selectedItems[index],
          onChanged: (v) => setState(() => _selectedItems[index] = v ?? false),
          activeColor: AppColors.purple,
          side: const BorderSide(color: AppColors.textSecondary),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                merchant.isNotEmpty ? merchant : desc,
                style: TextStyle(
                  color: isDuplicate ? AppColors.textMuted : AppColors.textPrimary,
                  fontSize: 14, fontWeight: FontWeight.w500,
                  decoration: isDuplicate ? TextDecoration.lineThrough : null,
                ),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${isIncome ? '+' : '-'}₺${amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: isDuplicate ? AppColors.textMuted : (isIncome ? AppColors.green : AppColors.red),
                fontWeight: FontWeight.bold, fontSize: 14,
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Text(formattedDate, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            if (isDuplicate) ...[
              const SizedBox(width: 8),
              const Text('⚠️ Zaten kayıtlı', style: TextStyle(color: AppColors.orange, fontSize: 10)),
            ],
            const Spacer(),
            // Kategori seçici
            _buildCategoryDropdown(index, catName),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown(int index, String? currentCatName) {
    final currentCatId = _transactions[index]['categoryId'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: currentCatId != null
            ? AppColors.purple.withValues(alpha: 0.2)
            : AppColors.textMuted.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: currentCatId,
          isDense: true,
          dropdownColor: AppColors.cardBg,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 11),
          hint: const Text('Kategori', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Kategorisiz', style: TextStyle(fontSize: 11))),
            ..._categories.map((c) => DropdownMenuItem<int?>(
              value: c['id'],
              child: Text('${c['icon'] ?? ''} ${c['name']}', style: const TextStyle(fontSize: 11)),
            )),
          ],
          onChanged: (v) {
            setState(() {
              _transactions[index]['categoryId'] = v;
              _transactions[index]['categoryName'] = v != null
                  ? _categories.firstWhere((c) => c['id'] == v, orElse: () => {})['name']
                  : null;
            });
          },
        ),
      ),
    );
  }

  // ─── AŞAMA 2: SONUÇ ─────────────────────────────────────

  Widget _buildResult() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: AppColors.green, size: 50),
            ),
            const SizedBox(height: 24),
            Text(
              '$_savedCount İşlem Kaydedildi!',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'İşlemler başarıyla içe aktarıldı.\nDashboard\'da görüntüleyebilirsiniz.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Tamam', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
