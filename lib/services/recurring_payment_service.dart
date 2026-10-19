import 'package:flutter/foundation.dart';
import '../models/recurring_payment.dart';
import 'account_service.dart';
import 'api_service.dart';
import 'transaction_trash.dart';

class RecurringPaymentException implements Exception {
  const RecurringPaymentException(
    this.message, {
    this.premiumRequired = false,
    this.conflict = false,
  });
  final String message;
  final bool premiumRequired, conflict;
  @override
  String toString() => message;
}

class RecurringPaymentService {
  static final changes = ValueNotifier<int>(0);
  static void notifyChanged() => changes.value++;
  static dynamic _checked(dynamic result) {
    if (result is Map && result.containsKey('error')) {
      throw RecurringPaymentException(
        result['error'].toString(),
        premiumRequired: result['premiumRequired'] == true,
        conflict: result['statusCode'] == 409,
      );
    }
    return result;
  }

  static Map<String, dynamic> _map(dynamic result) =>
      Map<String, dynamic>.from(_checked(result) as Map);
  static Future<List<RecurringPayment>> list() async {
    final result = _checked(await ApiService.authenticatedGet('/recurring'));
    return (result as List)
        .map(
          (e) => RecurringPayment.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  static Future<Upcoming> upcoming({int days = 30}) async => Upcoming.fromJson(
    _map(await ApiService.authenticatedGet('/recurring/upcoming?days=$days')),
  );
  static Future<RecurringPayment> save({
    int? id,
    required String name,
    required double amount,
    required int type,
    int? categoryId,
    int? accountId,
    required int frequency,
    required DateTime startDate,
    DateTime? endDate,
    int remindDaysBefore = 1,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'amount': amount,
      'type': type,
      'categoryId': categoryId,
      'accountId': accountId,
      'frequency': frequency,
      'startDate': recurringDate(startDate),
      'endDate': endDate == null ? null : recurringDate(endDate),
      'remindDaysBefore': remindDaysBefore,
    };
    final result = RecurringPayment.fromJson(
      _map(
        id == null
            ? await ApiService.authenticatedPost('/recurring', body)
            : await ApiService.authenticatedPut('/recurring/$id', body),
      ),
    );
    notifyChanged();
    return result;
  }

  static Future<void> delete(int id) async {
    _checked(await ApiService.authenticatedDelete('/recurring/$id'));
    notifyChanged();
  }

  static Future<RecurringPayment> skip(
    int id, {
    required DateTime dueDate,
  }) async {
    final result = RecurringPayment.fromJson(
      _map(
        await ApiService.authenticatedPost('/recurring/$id/skip', {
          'dueDate': recurringDate(dueDate),
        }),
      ),
    );
    notifyChanged();
    return result;
  }

  static Future<RecurringPaymentPayResult> pay(
    int id, {
    required DateTime dueDate,
    double? amount,
    int? accountId,
    DateTime? transactionDate,
    String? description,
  }) async {
    final result = RecurringPaymentPayResult.fromJson(
      _map(
        await ApiService.authenticatedPost('/recurring/$id/pay', {
          'dueDate': recurringDate(dueDate),
          'amount': amount,
          'accountId': accountId,
          'transactionDate': transactionDate?.toUtc().toIso8601String(),
          'description': description,
        }),
      ),
    );
    notifyChanged();
    AccountService.notifyChanged();
    // Ana sayfa ve işlem listesi bu ortak işlem değişikliği sinyalini dinler.
    TransactionTrash.changes.value++;
    return result;
  }
}
