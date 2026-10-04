import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'api_service.dart';

/// Yerel mağaza eklentisinin testte değiştirilebilen kısmı.
abstract class StoreGateway {
  Future<bool> isAvailable();
  Future<ProductDetailsResponse> queryProducts(Set<String> ids);
  Future<bool> buy(ProductDetails product, {String? accountToken});
  Future<void> restore();
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<void> completePurchase(PurchaseDetails purchase);
}

class InAppPurchaseGateway implements StoreGateway {
  InAppPurchase get _store => InAppPurchase.instance;

  @override
  Future<bool> isAvailable() => _store.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProducts(Set<String> ids) =>
      _store.queryProductDetails(ids);

  @override
  Future<bool> buy(ProductDetails product, {String? accountToken}) =>
      _store.buyNonConsumable(
        purchaseParam: product is GooglePlayProductDetails
            ? GooglePlayPurchaseParam(
                productDetails: product,
                applicationUserName: accountToken,
                offerToken: product.offerToken,
              )
            : PurchaseParam(
                productDetails: product,
                applicationUserName: accountToken,
              ),
      );

  @override
  Future<void> restore() => _store.restorePurchases();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _store.purchaseStream;

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _store.completePurchase(purchase);
}

/// Görünen fiyat ile satın alınan teklif aynı ProductDetails'e bağlıdır.
class PremiumPlan {
  const PremiumPlan({
    required this.product,
    required this.price,
    required this.rawPrice,
    required this.currencyCode,
    this.trialLabel,
    this.isBasePlan = true,
  });

  final ProductDetails product;
  final String price;
  final double rawPrice;
  final String currencyCode;
  final String? trialLabel;
  final bool isBasePlan;
  bool get yearly => product.id == BillingService.premiumYearly;
  String get priceLabel => '$price/${yearly ? 'yıl' : 'ay'}';
  String get description =>
      trialLabel == null ? priceLabel : '$trialLabel, sonra $priceLabel';

  static PremiumPlan? fromProduct(ProductDetails product) {
    if (product is! GooglePlayProductDetails) {
      return PremiumPlan(
        product: product,
        price: product.price,
        rawPrice: product.rawPrice,
        currencyCode: product.currencyCode,
      );
    }
    final offers = product.productDetails.subscriptionOfferDetails;
    final index = product.subscriptionIndex;
    if (offers == null || index == null || index >= offers.length) return null;
    final offer = offers[index];
    final phases = offer.pricingPhases;
    final period = product.id == BillingService.premiumYearly ? 'P1Y' : 'P1M';
    final recurring = phases.where((p) =>
        p.recurrenceMode == RecurrenceMode.infiniteRecurring &&
        p.priceAmountMicros > 0 && p.billingPeriod == period);
    if (recurring.isEmpty) return null;
    final price = recurring.last;
    // Ara indirimli ücretleri gizleyen bir deneme vaadi göstermeyelim.
    // Desteklenen teklif: doğrudan yenilenen fiyat veya ücretsiz + yenilenen fiyat.
    if (phases.length > 2 ||
        (phases.length == 2 && phases.first.priceAmountMicros != 0)) {
      return null;
    }
    String? trial;
    if (phases.length == 2 && phases.first.priceAmountMicros == 0) {
      final free = phases.first;
      final duration = RegExp(r'^P(\d+)([DW])$').firstMatch(free.billingPeriod);
      if (duration == null) return null;
      final days = int.parse(duration.group(1)!) *
          (duration.group(2) == 'W' ? 7 : 1) *
          (free.billingCycleCount > 0 ? free.billingCycleCount : 1);
      trial = '$days gün ücretsiz';
    }
    return PremiumPlan(
      product: product,
      price: price.formattedPrice,
      rawPrice: price.priceAmountMicros / 1000000,
      currencyCode: price.priceCurrencyCode,
      trialLabel: trial,
      isBasePlan: offer.offerId == null,
    );
  }
}

/// Açık premium ekranları mağaza akışını paylaşır; son ekran kapanınca abonelik
/// iptal edilir. Başlamış doğrulama devam eder. Premium kararı sunucudan alınır.
class BillingService {
  BillingService._();
  static BillingService _instance = BillingService._();
  factory BillingService() => _instance;

  static const premiumMonthly = 'premium_monthly';
  static const premiumYearly = 'premium_yearly';
  static const productIds = {premiumMonthly, premiumYearly};
  static StoreGateway gateway = InAppPurchaseGateway();

  late final _changes = StreamController<void>.broadcast(
    sync: true,
    onCancel: _stopListening,
  );
  Stream<void> get changes => _changes.stream;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Future<void>? _queue;
  Future<void>? _loading;
  final Map<String, PurchaseDetails> _unverified = {};
  Map<String, dynamic>? status;
  Map<String, PremiumPlan> plans = {};
  bool available = false;
  bool busy = false;
  bool pending = false;
  String? error;
  int _statusRevision = 0;

  bool get isPremium => status?['isPremium'] == true;
  bool get canRetryVerification => _unverified.isNotEmpty;

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void _stopListening() {
    final subscription = _subscription;
    _subscription = null;
    unawaited(subscription?.cancel());
  }

  Future<void> _enqueue(List<PurchaseDetails> purchases) =>
      _queue = (_queue ?? Future<void>.value())
          .then((_) => _handlePurchases(purchases));

  void _listen() {
    if (_subscription != null || !_changes.hasListener) return;
    _subscription = gateway.purchaseStream.listen(
      (purchases) {
        // Batch'ler de sırayla doğrulanır; eşzamanlı stream olayları çakışmaz.
        _enqueue(purchases);
      },
      onError: (Object _) {
        busy = false;
        error = 'Satın alma bilgileri alınamadı. Lütfen tekrar deneyin.';
        _notify();
      },
    );
  }

  Future<void> load() => _loading ??= _load().whenComplete(() => _loading = null);

  Future<void> _load() async {
    if (!canRetryVerification) error = null;
    final revision = _statusRevision;
    final response = await ApiService.authenticatedGet('/subscription/status');
    if (_statusRevision == revision) {
      if (response is Map && response['isPremium'] is bool &&
          !response.containsKey('error')) {
        status = Map<String, dynamic>.from(response);
        pending = response['purchasePending'] == true;
      } else {
        status = null;
        error = response is Map && response['error'] != null
            ? response['error'].toString()
            : 'Abonelik durumu alınamadı. Lütfen tekrar deneyin.';
      }
    }
    try {
      _listen();
      available = await gateway.isAvailable();
      plans = {};
      if (available && !isPremium) {
        final products = await gateway.queryProducts(productIds);
        if (products.error == null) {
          for (final product in products.productDetails) {
            if (!productIds.contains(product.id)) continue;
            final plan = PremiumPlan.fromProduct(product);
            if (plan == null) continue;
            final previous = plans[product.id];
            if (previous == null ||
                (previous.trialLabel == null && plan.trialLabel != null) ||
                (previous.trialLabel == null && plan.isBasePlan)) {
              plans[product.id] = plan;
            }
          }
        }
      }
    } catch (_) {
      available = false;
      plans = {};
    }
    _notify();
  }

  Future<void> buy(PremiumPlan plan) async {
    if (busy || pending || isPremium || canRetryVerification) return;
    final token = status?['accountToken'];
    if (token is! String || token.isEmpty) {
      error = 'Hesap bilgisi alınamadı. Lütfen tekrar deneyin.';
      _notify();
      return;
    }
    busy = true;
    error = null;
    _notify();
    try {
      if (!await gateway.buy(plan.product, accountToken: token)) {
        busy = false;
        error = 'Satın alma başlatılamadı. Lütfen tekrar deneyin.';
        _notify();
      }
    } catch (_) {
      busy = false;
      error = 'Satın alma başlatılamadı. Lütfen tekrar deneyin.';
      _notify();
    }
  }

  Future<void> restore() async {
    if (busy) return;
    busy = true;
    error = null;
    _notify();
    try {
      _listen();
      await gateway.restore();
      // restore() hiç olay üretmeyebilir; buton o durumda kilitli kalmaz.
      await _queue;
      if (!canRetryVerification) await load();
    } catch (_) {
      error = 'Satın alımlar geri yüklenemedi. Lütfen tekrar deneyin.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> retryVerification() {
    if (busy) return Future<void>.value();
    busy = true;
    _notify();
    return _enqueue(_unverified.values.toList());
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (!productIds.contains(purchase.productID)) continue;
      switch (purchase.status) {
        case PurchaseStatus.pending:
          pending = true;
          busy = false;
          error = null;
          _notify();
        case PurchaseStatus.error:
          pending = false;
          busy = false;
          error = 'Ödeme tamamlanamadı. Lütfen Google Play bilgilerinizi kontrol edip tekrar deneyin.';
          _notify();
        case PurchaseStatus.canceled:
          busy = false;
          pending = false;
          error = null;
          _notify();
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verify(purchase);
      }
    }
  }

  Future<void> _verify(PurchaseDetails purchase) async {
    final token = purchase.verificationData.serverVerificationData;
    final key = '${purchase.productID}:$token';
    busy = true;
    pending = false;
    error = null;
    _unverified[key] = purchase;
    _notify();
    try {
        if (token.isEmpty) {
          error = 'Satın alma doğrulama bilgisi eksik. Lütfen tekrar deneyin.';
          return;
        }
        final response = await ApiService.authenticatedPost('/subscription/verify', {
          'productId': purchase.productID,
          'purchaseToken': token,
        });
        if (response is! Map || response.containsKey('error') ||
            response['isPremium'] is! bool) {
          error = response is Map && response['error'] != null
              ? response['error'].toString()
              : 'Satın alma doğrulanamadı. Lütfen tekrar deneyin.';
          return;
        }
        status = Map<String, dynamic>.from(response);
        _statusRevision++;
        pending = response['purchasePending'] == true;
      if (purchase.pendingCompletePurchase) {
        await gateway.completePurchase(purchase);
      }
      _unverified.remove(key);
    } catch (_) {
      error = 'Satın alma işlemi tamamlanamadı. Lütfen tekrar deneyin.';
    } finally {
      busy = false;
      _notify();
    }
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    await _instance._subscription?.cancel();
    await _instance._queue;
    await _instance._changes.close();
    _instance = BillingService._();
    gateway = InAppPurchaseGateway();
  }
}
