import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'premium_entitlement_client.dart';
import 'premium_service.dart';

/// 메모요 프리미엄 자동갱신 구독 래퍼.
///
/// 스토어 상품 ID: `premium_monthly` (월 ₩1,900). 실제 상품 생성/활성화는
/// App Store Connect / Play Console 게이트 이후 수행한다.
class PremiumPurchase {
  PremiumPurchase._();
  static final PremiumPurchase instance = PremiumPurchase._();

  static const String productId = PremiumEntitlementClient.premiumProductId;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? _product;

  String? get price => _product?.price;
  bool get available => _product != null;

  Future<void> init() async {
    final isAvailable = await _iap.isAvailable();
    if (!isAvailable) return;
    _sub ??= _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onDone: () => _sub?.cancel(),
      onError: (Object _) {},
    );
    final resp = await _iap.queryProductDetails({productId});
    if (resp.productDetails.isNotEmpty) {
      _product = resp.productDetails.first;
    }
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != productId) continue;
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await PremiumService.instance.verifyPremiumPurchase(purchase);
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<bool> buy() async {
    final product = _product;
    if (product == null) return false;
    return _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  Future<void> restore() => _iap.restorePurchases();

  void dispose() => _sub?.cancel();
}
