import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/utils/formatters.dart';
import '../services/amount_privacy.dart';
import '../services/api_service.dart';
import '../services/transaction_trash.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});
  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<Map<String, dynamic>> _items = [];
  final Set<Object> _restoring = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ApiService.authenticatedGet('/transaction/deleted');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result is List &&
          result.every(
            (e) =>
                e is Map &&
                e['id'] != null &&
                e['amount'] is num &&
                e['deletedAt'] is String &&
                e['transactionDate'] is String &&
                DateTime.tryParse(e['deletedAt'] as String) != null &&
                DateTime.tryParse(e['transactionDate'] as String) != null,
          )) {
        _items = result
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        _error = 'Çöp kutusu yüklenemedi. Lütfen tekrar deneyin.';
      }
    });
  }

  Future<void> _restore(Map<String, dynamic> item) async {
    final id = item['id'] as Object;
    if (_restoring.contains(id)) return;
    setState(() => _restoring.add(id));
    final error = await TransactionTrash.restore(id);
    if (!mounted) return;
    setState(() {
      _restoring.remove(id);
      if (error == null) _items.removeWhere((e) => e['id'] == id);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'İşlem geri alındı')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Çöp kutusu')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                TextButton(onPressed: _load, child: const Text('Tekrar dene')),
              ],
            ),
          )
        : ValueListenableBuilder<bool>(
            valueListenable: AmountPrivacy.gizli,
            builder: (context, hidden, _) => _items.isEmpty
                ? const Center(child: Text('Son 30 günde silinen işlem yok.'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final deleted = DateTime.parse(
                          item['deletedAt'],
                        ).toUtc();
                        final days = DateTime.now()
                            .toUtc()
                            .difference(deleted)
                            .inDays
                            .clamp(0, 30);
                        final date = DateTime.parse(
                          item['transactionDate'],
                        ).toLocal();
                        return ListTile(
                          title: Text(
                            item['description']?.toString() ?? 'İşlem',
                          ),
                          subtitle: Text(
                            '${formatTRY(item['amount'] as num)} · ${DateFormat('dd.MM.yyyy').format(date)}\n$days gün önce silindi',
                          ),
                          isThreeLine: true,
                          trailing: TextButton(
                            onPressed: _restoring.contains(item['id'])
                                ? null
                                : () => _restore(item),
                            child: const Text('Geri al'),
                          ),
                        );
                      },
                    ),
                  ),
          ),
  );
}
