import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'ads_service.dart';
import 'premium_service.dart';

/// '광고 제거' 비소모성 인앱결제 래퍼.
///
/// ⚠️ 출시 전 스토어 등록 필요 (아니키):
///  App Store Connect / Play Console 에 비소모성 상품 ID `remove_ads` 등록.
///  등록 전에는 queryProductDetails 가 빈 결과라 [available] 이 false 라서
///  설정의 구매 버튼이 "상품 준비중" 으로 비활성화된다.
class RemoveAdsPurchase {
  RemoveAdsPurchase._();
  static final RemoveAdsPurchase instance = RemoveAdsPurchase._();

  static const String productId = 'remove_ads';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? _product;

  /// 스토어에서 받은 정가 (미등록·미가용이면 null).
  String? get price => _product?.price;

  /// 구매 가능 여부 — 스토어에 상품이 등록돼 조회됐을 때만 true.
  bool get available => _product != null;

  Future<void> init() async {
    final isAvailable = await _iap.isAvailable();
    if (!isAvailable) return;
    _sub = _iap.purchaseStream.listen(
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
    for (final p in purchases) {
      if (p.productID != productId) continue;
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        await AdsService.instance.setRemoveAds(true);
        try {
          await PremiumService.instance.claimRemoveAdsCoupon(p);
        } catch (_) {
          // 광고 제거 엔티틀먼트는 기존 권리라 유지한다. 쿠폰 검증은 복원 시 재시도 가능.
        }
      }
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
  }

  /// 구매 시도. 상품 미등록(미가용)이면 false 를 반환.
  Future<bool> buy() async {
    final product = _product;
    if (product == null) return false;
    return _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
  }

  /// 이전 구매 복원 (기기 변경·재설치 시).
  Future<void> restore() => _iap.restorePurchases();

  void dispose() => _sub?.cancel();
}
