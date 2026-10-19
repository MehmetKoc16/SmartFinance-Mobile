import 'package:flutter/foundation.dart';
import '../models/account.dart';
import 'api_service.dart';

class AccountException implements Exception {
  const AccountException(this.message, {this.premiumRequired = false});
  final String message;
  final bool premiumRequired;
  @override
  String toString() => message;
}

class AccountService {
  static final changes = ValueNotifier<int>(0);
  static void notifyChanged() => changes.value++;

  static dynamic _checked(dynamic result) {
    if (result is Map && result.containsKey('error')) {
      throw AccountException(
        result['error'].toString(),
        premiumRequired: result['premiumRequired'] == true,
      );
    }
    return result;
  }

  static Map<String, dynamic> _map(dynamic result) =>
      Map<String, dynamic>.from(_checked(result) as Map);

  static Future<List<Account>> list({bool includeArchived = false}) async {
    final result = _checked(
      await ApiService.authenticatedGet(
        '/account${includeArchived ? '?includeArchived=true' : ''}',
      ),
    );
    return (result as List)
        .map((e) => Account.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<Account> save({
    int? id,
    required String name,
    required int type,
    double? openingBalance,
    double? creditLimit,
    int? statementDay,
    int? dueDay,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'type': type,
      'openingBalance': openingBalance,
      if (type == 3) ...{
        'creditLimit': creditLimit,
        'statementDay': statementDay,
        'dueDay': dueDay,
      },
    };
    final result = id == null
        ? await ApiService.authenticatedPost('/account', body)
        : await ApiService.authenticatedPut('/account/$id', body);
    final account = Account.fromJson(_map(result));
    notifyChanged();
    return account;
  }

  /// true: arşivlendi (200), false: silindi (gövdesiz 204).
  static Future<bool> delete(int id) async {
    final result = _map(await ApiService.authenticatedDelete('/account/$id'));
    notifyChanged();
    return result['archived'] == true;
  }

  static Future<Account> unarchive(int id) async {
    final result = Account.fromJson(
      _map(await ApiService.authenticatedPost('/account/$id/unarchive', null)),
    );
    notifyChanged();
    return result;
  }

  static Future<Transfer> createTransfer({
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    required DateTime transferDate,
    String? description,
  }) async {
    final result = Transfer.fromJson(
      _map(
        await ApiService.authenticatedPost('/account/transfer', {
          'fromAccountId': fromAccountId,
          'toAccountId': toAccountId,
          'amount': amount,
          'transferDate': transferDate.toUtc().toIso8601String(),
          'description': description,
        }),
      ),
    );
    notifyChanged();
    return result;
  }

  static Future<TransferPage> transfers(
    int id, {
    int page = 1,
    int pageSize = 50,
  }) async => TransferPage.fromJson(
    _map(
      await ApiService.authenticatedGet(
        '/account/$id/transfers?page=$page&pageSize=$pageSize',
      ),
    ),
  );
  static Future<void> deleteTransfer(int id) async {
    _checked(await ApiService.authenticatedDelete('/account/transfer/$id'));
    notifyChanged();
  }

  static Future<Statements> statements(int id, {int count = 3}) async =>
      Statements.fromJson(
        _map(
          await ApiService.authenticatedGet(
            '/account/$id/statements?count=$count',
          ),
        ),
      );
}
