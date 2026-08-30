// T-260830-013 — 서버 클라이언트를 걷어낸 뒤 남은 ★모델 계약을 지킨다.
//
// ■왜 이 파일이 client 테스트를 대체하나
//   종전 premium_entitlement_client_test.dart 는 transport 를 가짜로 끼워
//   /api/memoyo/entitlement/verify · remove-ads-coupon 왕복을 검증했다. 그 백엔드는
//   만들어진 적이 없고(T-260803-038), 클라이언트를 철거하면서 그 검증은 대상 자체가
//   사라졌다. 대신 ★남은 것을 지킨다 — 권한은 이제 SharedPreferences 캐시에서만
//   복원되므로, 그 캐시의 직렬화 계약(toJson/fromJson)이 깨지면 ★이미 결제한 사람의
//   광고 제거 유예가 조용히 풀린다. 그게 지금 이 모델의 유일한 실사용 경로다.
//
// ■같이 보는 축
//   유예의 UI 쪽 끝단 = test/screens/subscription_sales_ended_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/services/premium_entitlement.dart';

void main() {
  test('구독 권한이 캐시 왕복(toJson→fromJson)을 넘어 살아남는다', () {
    const original = PremiumEntitlement(
      premium: true,
      productId: PremiumEntitlement.premiumProductId,
      expiresAt: null,
      source: PremiumEntitlementSource.subscription,
    );

    final restored = PremiumEntitlement.fromJson(original.toJson());

    expect(restored.premium, true);
    expect(restored.productId, 'premium_monthly');
    expect(restored.source, PremiumEntitlementSource.subscription);
    expect(restored.active, true, reason: '만료 없음 = 유예 유지');
  });

  test('광고제거 쿠폰 권한도 메타데이터째 캐시 왕복을 넘는다', () {
    final original = PremiumEntitlement(
      premium: true,
      productId: PremiumEntitlement.removeAdsProductId,
      expiresAt: DateTime.utc(2099, 1, 1),
      source: PremiumEntitlementSource.removeAdsCoupon,
      couponAlreadyGranted: true,
    );

    final restored = PremiumEntitlement.fromJson(original.toJson());

    expect(restored.source, PremiumEntitlementSource.removeAdsCoupon);
    expect(restored.couponAlreadyGranted, true);
    expect(restored.active, true);
  });

  test('만료가 지난 권한은 active 가 아니다', () {
    final expired = PremiumEntitlement(
      premium: true,
      productId: PremiumEntitlement.premiumProductId,
      expiresAt: DateTime.utc(2020, 1, 1),
      source: PremiumEntitlementSource.subscription,
    );

    expect(expired.active, false);
  });

  test('inactive 는 어떤 경우에도 권한을 주지 않는다', () {
    const inactive = PremiumEntitlement.inactive();

    expect(inactive.premium, false);
    expect(inactive.active, false);
    expect(inactive.source, isNull);
  });
}
