import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/constants/category_style.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/formatters.dart';
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
  // Zaten kayitli oldugu icin eklenmeyen islem sayisi. Ayni ekstreyi ikinci
  // kez yukleyen kullanici "hicbir sey olmadi" sanmasin diye sonuc
  // ekraninda ayrica gosteriliyor.
  int _skippedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final result = await ApiService.authenticatedGet('/category');
    if (!mounted) return;
    if (result is List) {
      setState(() {
        _categories = List<Map<String, dynamic>>.from(result);
      });
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'xlsx'],
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

    final result = await ApiService.authenticatedUpload('/pdfimport/parse', _selectedFilePath!);
    if (!mounted) return;

    final t = AppTokens.of(context);
    setState(() {
      _isLoading = false;
      _parseResult = result is Map<String, dynamic> ? result : null;

      if (_parseResult != null && _parseResult!['transactions'] != null) {
        _transactions = List<Map<String, dynamic>>.from(_parseResult!['transactions']);
        // Duplicate olmayanları varsayılan seçili yap
        _selectedItems = _transactions.map((tx) => !(tx['isDuplicate'] ?? false)).toList();
        _step = 1;
      }
    });

    if (_transactions.isEmpty && mounted) {
      final errorMsg = _parseResult?['error'] ?? _parseResult?['message'] ?? 'Dosyadan işlem çıkarılamadı.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: t.amber),
      );
    }
  }

  Future<void> _confirmImport() async {
    final t = AppTokens.of(context);
    final selectedTransactions = <Map<String, dynamic>>[];
    for (int i = 0; i < _transactions.length; i++) {
      if (_selectedItems[i]) {
        final tx = _transactions[i];
        selectedTransactions.add({
          'amount': tx['amount'],
          'description': tx['description'] ?? '',
          'transactionDate': tx['transactionDate'],
          'type': tx['type'],
          'categoryId': tx['categoryId'],
          'merchantName': tx['merchantName'],
        });
      }
    }

    if (selectedTransactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('En az bir işlem seçmelisiniz.'), backgroundColor: t.amber),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.authenticatedPost('/pdfimport/confirm', {
      'transactions': selectedTransactions,
    });
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result is Map && result.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${result['error']}'), backgroundColor: t.red),
        );
      } else {
        _savedCount = result['count'] ?? 0;
        _skippedCount = result['skipped'] ?? 0;
        _step = 2;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: const Text('Ekstre İçe Aktar'),
        leading: _step == 1
            ? IconButton(
                icon: Icon(LucideIcons.arrowLeft, color: t.text),
                onPressed: () => setState(() {
                  _step = 0;
                  _transactions = [];
                }),
              )
            : null,
      ),
      body: _isLoading
          ? _buildLoading(t)
          : _step == 0
              ? _buildFileSelection(t)
              : _step == 1
                  ? _buildPreview(t)
                  : _buildResult(t),
    );
  }

  Widget _buildLoading(AppTokens t) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: t.card,
              border: Border.all(color: t.border),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                CircularProgressIndicator(color: t.brand),
                const SizedBox(height: 20),
                Text('Dosya analiz ediliyor...', style: TextStyle(color: t.text, fontSize: 16)),
                const SizedBox(height: 8),
                Text('İşlemler çıkarılıyor', style: TextStyle(color: t.textSec, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── AŞAMA 0: DOSYA SEÇİMİ ──────────────────────────────

  Widget _buildFileSelection(AppTokens t) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: t.brandSoft, borderRadius: BorderRadius.circular(22)),
            child: Icon(LucideIcons.upload, size: 40, color: t.brand),
          ),
          const SizedBox(height: 22),
          Text('Banka Ekstresi Yükle', style: TextStyle(color: t.text, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Banka ekstresi dosyanızı seçin (PDF veya Excel).\nİşlemler otomatik olarak algılanacak.',
            style: TextStyle(color: t.textSec, fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          GestureDetector(
            onTap: _pickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _selectedFilePath != null ? t.green : t.border, width: 1.5),
              ),
              child: Column(
                children: [
                  Icon(
                    _selectedFilePath != null ? LucideIcons.circleCheck : LucideIcons.cloudUpload,
                    size: 36,
                    color: _selectedFilePath != null ? t.green : t.textSec,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _selectedFileName ?? 'PDF veya Excel dosyası seçin',
                    style: TextStyle(
                      color: _selectedFilePath != null ? t.green : t.textSec,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_selectedFilePath != null) ...[
                    const SizedBox(height: 4),
                    Text('Değiştirmek için tekrar dokunun', style: TextStyle(color: t.textTert, fontSize: 12)),
                  ],
                ],
              ),
            ),
          ),
          const Spacer(),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: t.inputBg, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(LucideIcons.info, color: t.textSec, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Halkbank, Ziraat ve diğer metin tabanlı PDF ekstreleri; Ziraat için ayrıca Excel (.xlsx) ekstre çıktısı desteklenir.',
                    style: TextStyle(color: t.textSec, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _selectedFilePath != null ? _parseFile : null,
              child: const Text('Analiz Et', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── AŞAMA 1: ÖNİZLEME ──────────────────────────────────

  Widget _buildPreview(AppTokens t) {
    final bankName = _parseResult?['bankName'] ?? 'Bilinmeyen';
    final period = _parseResult?['period'] ?? '';
    final dupCount = _parseResult?['duplicateCount'] ?? 0;
    final selectedCount = _selectedItems.where((s) => s).length;

    double totalIncome = 0, totalExpense = 0;
    for (int i = 0; i < _transactions.length; i++) {
      if (_selectedItems[i]) {
        final tx = _transactions[i];
        if (tx['type'] == 1) {
          totalIncome += (tx['amount'] as num).toDouble();
        } else {
          totalExpense += (tx['amount'] as num).toDouble();
        }
      }
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [t.brand, t.brandDeep], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.landmark, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(bankName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (period.isNotEmpty) Text(period, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _summaryChip('Gelir', '+${formatTRY(totalIncome)}', Colors.white),
                  const SizedBox(width: 10),
                  _summaryChip('Gider', '-${formatTRY(totalExpense)}', Colors.white),
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
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(8)),
                      child: Text('$dupCount tekrar', style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _transactions.length,
            itemBuilder: (ctx, i) => _buildTransactionTile(t, i),
          ),
        ),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: t.card, border: Border(top: BorderSide(color: t.border))),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: selectedCount > 0 ? _confirmImport : null,
              style: ElevatedButton.styleFrom(backgroundColor: t.green, foregroundColor: Colors.white),
              icon: const Icon(LucideIcons.check, color: Colors.white, size: 18),
              label: Text('$selectedCount İşlemi İçe Aktar', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryChip(String label, String value, Color valueColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(AppTokens t, int index) {
    final tx = _transactions[index];
    final isIncome = tx['type'] == 1;
    final isDuplicate = tx['isDuplicate'] ?? false;
    final amount = (tx['amount'] as num).toDouble();
    final desc = tx['description'] ?? '';
    final merchant = tx['merchantName'] ?? '';
    final dateStr = tx['transactionDate'] ?? '';

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
        color: isDuplicate ? t.card.withValues(alpha: 0.5) : t.card,
        border: Border.all(color: isDuplicate ? t.amber.withValues(alpha: 0.4) : t.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Checkbox(
          value: _selectedItems[index],
          onChanged: (v) => setState(() => _selectedItems[index] = v ?? false),
          activeColor: t.brand,
          side: BorderSide(color: t.textSec),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                merchant.isNotEmpty ? merchant : desc,
                style: TextStyle(
                  color: isDuplicate ? t.textTert : t.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  decoration: isDuplicate ? TextDecoration.lineThrough : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${isIncome ? '+' : '-'}${formatTRY(amount)}',
              style: TextStyle(color: isDuplicate ? t.textTert : (isIncome ? t.green : t.red), fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Text(formattedDate, style: TextStyle(color: t.textSec, fontSize: 11)),
            if (isDuplicate) ...[
              const SizedBox(width: 8),
              Text('Zaten kayıtlı', style: TextStyle(color: t.amber, fontSize: 10)),
            ],
            const Spacer(),
            _buildCategoryDropdown(t, index),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown(AppTokens t, int index) {
    final currentCatId = _transactions[index]['categoryId'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: currentCatId != null ? t.brandSoft : t.inputBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: currentCatId,
          isDense: true,
          dropdownColor: t.card,
          style: TextStyle(color: t.text, fontSize: 11),
          hint: Text('Kategori', style: TextStyle(color: t.textTert, fontSize: 11)),
          items: [
            DropdownMenuItem<int?>(value: null, child: Text('Kategorisiz', style: TextStyle(fontSize: 11, color: t.textSec))),
            ..._categories.map((c) {
              final style = CategoryStyles.resolve(c['name'] ?? '', icon: c['icon'], color: c['color']);
              return DropdownMenuItem<int?>(
                value: c['id'],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 7, height: 7, decoration: BoxDecoration(color: style.color, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(c['name'] ?? '', style: TextStyle(fontSize: 11, color: t.text)),
                  ],
                ),
              );
            }),
          ],
          onChanged: (v) {
            setState(() {
              _transactions[index]['categoryId'] = v;
              _transactions[index]['categoryName'] =
                  v != null ? _categories.firstWhere((c) => c['id'] == v, orElse: () => {})['name'] : null;
            });
          },
        ),
      ),
    );
  }

  // ─── AŞAMA 2: SONUÇ ─────────────────────────────────────

  Widget _buildResult(AppTokens t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: t.greenSoft, shape: BoxShape.circle),
              child: Icon(LucideIcons.circleCheck, color: t.green, size: 44),
            ),
            const SizedBox(height: 24),
            Text(
              _savedCount > 0 ? '$_savedCount İşlem Kaydedildi!' : 'İşlemler Zaten Kayıtlı',
              style: TextStyle(color: t.text, fontSize: 20, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _skippedCount == 0
                  ? 'İşlemler başarıyla içe aktarıldı.\nAna Sayfa\'da görüntüleyebilirsiniz.'
                  : _savedCount == 0
                      ? 'Bu ekstredeki $_skippedCount işlem daha önce eklenmişti,\ntekrar kaydedilmedi.'
                      : '$_skippedCount işlem daha önce eklendiği için atlandı.\nAna Sayfa\'da görüntüleyebilirsiniz.',
              style: TextStyle(color: t.textSec, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tamam', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
