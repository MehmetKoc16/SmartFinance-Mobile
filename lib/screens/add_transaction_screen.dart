import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/app_tokens.dart';
import '../services/api_service.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _selectedType = 2; // 1=Gelir, 2=Gider (varsayılan gider)
  DateTime _selectedDate = DateTime.now();
  int? _selectedCategoryId;
  List<dynamic> _categories = [];
  bool _isLoading = false;
  bool _isCategoriesLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await ApiService.authenticatedGet('/category');
      if (!mounted) return;

      if (response is List) {
        setState(() {
          _categories = response;
          _isCategoriesLoading = false;
        });
      } else if (response is Map && response.containsKey('items')) {
        setState(() {
          _categories = response['items'];
          _isCategoriesLoading = false;
        });
      } else {
        setState(() => _isCategoriesLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isCategoriesLoading = false);
    }
  }

  // Seçilen işlem tipine uygun olmayan kategori seçiliyse temizle (ör. Gelir'e
  // geçince önceden seçili bir gider kategorisi kalmasın).
  List<dynamic> get _filteredCategories =>
      _categories.where((c) => c['type'] == _selectedType).toList();

  Future<void> _selectDate() async {
    final t = AppTokens.of(context);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(colorScheme: ColorScheme.dark(primary: t.brand, surface: t.card)),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveTransaction() async {
    if (_amountController.text.isEmpty) {
      _showError('Tutar giriniz!');
      return;
    }

    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      _showError('Geçerli bir tutar giriniz!');
      return;
    }

    if (_descriptionController.text.isEmpty) {
      _showError('Açıklama giriniz!');
      return;
    }

    if (_selectedCategoryId == null) {
      _showError('Kategori seçiniz!');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.authenticatedPost('/transaction', {
        'amount': amount,
        'description': _descriptionController.text,
        'transactionDate': _selectedDate.toIso8601String(),
        'type': _selectedType,
        'categoryId': _selectedCategoryId,
      });

      if (response.containsKey('error')) {
        _showError(response['error']);
      } else {
        if (mounted) {
          final t = AppTokens.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('İşlem başarıyla eklendi!'),
              backgroundColor: t.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          Navigator.pop(context, true); // true = yeni işlem eklendi
        }
      }
    } catch (e) {
      _showError('Bağlantı hatası!');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    final t = AppTokens.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: t.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('İşlem Ekle')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: t.inputBg, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedType = 1;
                        _selectedCategoryId = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _selectedType == 1 ? t.greenSoft : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: _selectedType == 1 ? Border.all(color: t.green, width: 1.5) : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.arrowDownLeft, color: _selectedType == 1 ? t.green : t.textTert, size: 18),
                            const SizedBox(width: 8),
                            Text('Gelir',
                                style: TextStyle(
                                    color: _selectedType == 1 ? t.green : t.textTert, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedType = 2;
                        _selectedCategoryId = null;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _selectedType == 2 ? t.redSoft : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: _selectedType == 2 ? Border.all(color: t.red, width: 1.5) : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.arrowUpRight, color: _selectedType == 2 ? t.red : t.textTert, size: 18),
                            const SizedBox(width: 8),
                            Text('Gider',
                                style: TextStyle(
                                    color: _selectedType == 2 ? t.red : t.textTert, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text('Tutar', style: TextStyle(color: t.textSec, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: t.text, fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '0.00',
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 16, top: 12, bottom: 12),
                  child: Text('₺', style: TextStyle(color: t.brand, fontSize: 24, fontWeight: FontWeight.bold)),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text('Açıklama', style: TextStyle(color: t.textSec, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              style: TextStyle(color: t.text),
              decoration: InputDecoration(
                hintText: 'Örn: Market alışverişi',
                prefixIcon: Icon(LucideIcons.fileText, color: t.textTert, size: 18),
              ),
            ),

            const SizedBox(height: 20),

            Text('Tarih', style: TextStyle(color: t.textSec, fontSize: 13)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(color: t.inputBg, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(LucideIcons.calendar, color: t.textTert, size: 18),
                    const SizedBox(width: 12),
                    Text(DateFormat('dd MMMM yyyy', 'tr_TR').format(_selectedDate), style: TextStyle(color: t.text, fontSize: 15)),
                    const Spacer(),
                    Icon(LucideIcons.chevronRight, color: t.textTert),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text('Kategori', style: TextStyle(color: t.textSec, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: t.inputBg, borderRadius: BorderRadius.circular(12)),
              child: _isCategoriesLoading
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(color: t.brand)),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: _filteredCategories.any((c) => c['id'] == _selectedCategoryId) ? _selectedCategoryId : null,
                        hint: Text('Kategori seçin', style: TextStyle(color: t.textTert)),
                        dropdownColor: t.card,
                        icon: Icon(LucideIcons.chevronDown, color: t.textTert),
                        items: _filteredCategories.map<DropdownMenuItem<int>>((cat) {
                          return DropdownMenuItem<int>(
                            value: cat['id'],
                            child: Text(cat['name'] ?? 'Kategori', style: TextStyle(color: t.text)),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _selectedCategoryId = value),
                      ),
                    ),
            ),

            const SizedBox(height: 36),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveTransaction,
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
