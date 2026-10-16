import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:smartfinance_mobile/services/billing_service.dart';

/// Ana ekran testleri yerel Google Play eklentisini başlatmamalı.
/// Satın alma olaylarını sınayan testlerin kendi denetlenebilir mağazası var.
class TestStoreGateway implements StoreGateway {
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<ProductDetailsResponse> queryProducts(Set<String> ids) async =>
      ProductDetailsResponse(productDetails: [], notFoundIDs: ids.toList());
  @override
  Future<bool> buy(ProductDetails product, {String? accountToken}) async => false;
  @override
  Future<void> restore() async {}
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => const Stream.empty();
  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}
}
