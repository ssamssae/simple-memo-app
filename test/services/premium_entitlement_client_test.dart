import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/services/premium_entitlement_client.dart';

void main() {
  test(
    'verifySubscription sends premium_monthly receipt and parses entitlement',
    () async {
      late Uri seenUri;
      late Map<String, Object?> seenPayload;
      final client = PremiumEntitlementClient(
        transport: (uri, payload) async {
          seenUri = uri;
          seenPayload = payload;
          return {
            'premium': true,
            'productId': 'premium_monthly',
            'expiresAt': '2026-08-07T00:00:00.000Z',
            'source': 'subscription',
          };
        },
      );

      final entitlement = await client.verifySubscription(
        userId: 'memoyo-user-1',
        platform: 'ios',
        purchaseId: 'tx-1',
        serverVerificationData: 'receipt',
      );

      expect(seenUri.path, '/api/memoyo/entitlement/verify');
      expect(seenPayload['productId'], 'premium_monthly');
      expect(entitlement.premium, true);
      expect(entitlement.source, PremiumEntitlementSource.subscription);
    },
  );

  test(
    'claimRemoveAdsCoupon sends remove_ads proof and preserves one-time coupon metadata',
    () async {
      final client = PremiumEntitlementClient(
        transport: (_, payload) async {
          expect(payload['productId'], 'remove_ads');
          return {
            'premium': true,
            'productId': 'premium_monthly',
            'expiresAt': '2026-08-07T00:00:00.000Z',
            'source': 'remove_ads_coupon',
            'couponAlreadyGranted': true,
          };
        },
      );

      final entitlement = await client.claimRemoveAdsCoupon(
        userId: 'memoyo-user-1',
        platform: 'android',
        purchaseId: 'remove-ads-token',
        serverVerificationData: 'token',
      );

      expect(entitlement.premium, true);
      expect(entitlement.source, PremiumEntitlementSource.removeAdsCoupon);
      expect(entitlement.couponAlreadyGranted, true);
    },
  );
}
