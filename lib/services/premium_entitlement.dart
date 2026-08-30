/// 구독 권한 모델 — T-260830-013 에서 서버 배선을 걷어내고 모델만 남겼다.
///
/// ■서버 축이 왜 사라졌나
///   구독(premium_monthly)은 2026-08-03 Play·ASC 양쪽에서 판매 종료됐고
///   (T-260803-038), 권한을 조회하던 백엔드는 ★만들어진 적이 없다. 그래서 종전
///   `PremiumEntitlementClient` 가 `MEMOYO_API` 로 부르던 3개 경로
///   (entitlement/status · verify · remove-ads-coupon)는 전부 도달 불가능한 죽은
///   배선이었다. 그 선언 하나 때문에 업로드 관문(`artifact-endpoint-gate.py`)이
///   「기대 host 를 모른다」로 계속 막혔다 — 채울 값이 세상에 없는데도.
///
/// ■그럼 권한은 어디서 오나
///   `PremiumService` 가 SharedPreferences 캐시에서 복원한다. 이미 결제한 사람의
///   광고 제거 ★유예(grandfather)는 그 캐시가 지킨다 — `ad_banner` 의
///   `|| PremiumService.instance.isPremium`. 판매가 끝났으므로 새 권한은 더 생기지
///   않고, 그래서 쓰기 경로가 없어도 맞다. 회귀축 =
///   test/screens/subscription_sales_ended_test.dart (판매종료 + 유예보존 양방향).
///
/// ■되살릴 때
///   백엔드가 실제로 생기면 클라이언트를 다시 붙여라. 단 그때는 관문의
///   `KNOWN_ENDPOINT_HOSTS` 에 ★진짜 host 를 등록해서 초록을 받아라. 스텁 주소로
///   관문을 통과시키는 우회는 금지다 — `memoyo.local` 은 소스 폴백 상수와 같아
///   주입 여부와 무관하게 통과해 버린다(그 구멍의 기록 = T-260806-024).
library;

enum PremiumEntitlementSource { subscription, removeAdsCoupon }

class PremiumEntitlement {
  const PremiumEntitlement({
    required this.premium,
    required this.productId,
    required this.expiresAt,
    required this.source,
    this.couponAlreadyGranted = false,
  });

  const PremiumEntitlement.inactive()
    : premium = false,
      productId = premiumProductId,
      expiresAt = null,
      source = null,
      couponAlreadyGranted = false;

  static const premiumProductId = 'premium_monthly';
  static const removeAdsProductId = 'remove_ads';

  final bool premium;
  final String productId;
  final DateTime? expiresAt;
  final PremiumEntitlementSource? source;
  final bool couponAlreadyGranted;

  bool get active {
    final expires = expiresAt;
    return premium && (expires == null || expires.isAfter(DateTime.now()));
  }

  Map<String, Object?> toJson() => {
    'premium': premium,
    'productId': productId,
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
    'source': switch (source) {
      PremiumEntitlementSource.subscription => 'subscription',
      PremiumEntitlementSource.removeAdsCoupon => 'remove_ads_coupon',
      null => null,
    },
    'couponAlreadyGranted': couponAlreadyGranted,
  };

  factory PremiumEntitlement.fromJson(Map<String, Object?> json) {
    final sourceText = json['source'];
    final expiresText = json['expiresAt'];
    return PremiumEntitlement(
      premium: json['premium'] == true,
      productId: json['productId'] as String? ?? premiumProductId,
      expiresAt: expiresText is String ? DateTime.tryParse(expiresText) : null,
      source: sourceText == 'subscription'
          ? PremiumEntitlementSource.subscription
          : sourceText == 'remove_ads_coupon'
          ? PremiumEntitlementSource.removeAdsCoupon
          : null,
      couponAlreadyGranted: json['couponAlreadyGranted'] == true,
    );
  }
}
