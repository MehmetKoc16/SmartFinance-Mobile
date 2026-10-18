import 'package:flutter/foundation.dart';
import 'api_service.dart';

class TransactionTrash {
  static final changes = ValueNotifier<int>(0);

  /// null başarıdır; hata durumunda kullanıcıya gösterilecek mesaj döner.
  static Future<String?> restore(Object id) async {
    final result = await ApiService.authenticatedPost(
      '/transaction/$id/restore',
      {},
    );
    if (result is Map && result['statusCode'] == 404) {
      return 'Bu işlem artık geri alınamıyor.';
    }
    if (result is! Map || result.containsKey('error') || result['id'] == null) {
      return 'İşlem geri alınamadı. Bağlantınızı kontrol edip tekrar deneyin.';
    }
    changes.value++;
    return null;
  }
}
