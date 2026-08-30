import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'ads_service.dart';

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
        // ★광고를 끄는 축은 이 한 줄이다 — 로컬 저장이라 서버가 없어도 완결된다.
        //
        //   종전에는 바로 뒤에 `PremiumService.claimRemoveAdsCoupon(p)` 서버 왕복이
        //   붙어 있었고 try/catch 로 감싸여 있었다. 그 엔드포인트
        //   (`/api/memoyo/entitlement/remove-ads-coupon`)의 백엔드는 만들어진 적이
        //   없어 항상 실패했고, 실패가 삼켜졌으므로 ★관측 가능한 동작은 이 줄 하나가
        //   전부였다. T-260830-013 에서 그 죽은 왕복을 걷었다 — 구매 결과는 이전과
        //   동일하다(광고 즉시 꺼짐). 회귀축 = test/services/remove_ads_purchase_test.dart.
        await AdsService.instance.setRemoveAds(true);
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
