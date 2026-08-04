# Memoyo premium_monthly store setup

Task: T-260703-39

## Product

- Product ID: `premium_monthly`
- Type: auto-renewing subscription
- Price target: KRW 1,900 / month
- App copy: "메모요 프리미엄", "월 ₩1,900"
- Worker entitlement product ID: `premium_monthly`
- App build config: **스토어 산출은 `scripts/build-store.sh <ios|android>` 로만 한다.**
  `MEMOYO_API` 를 env 로 주고, 스크립트가 ①미주입이면 빌드를 거부하고 ②산출물에 값이
  실제로 박혔는지 검증한다. `flutter build` 직접 호출은 금지 — 이 값이 빠져도 예외가
  안 나고 유료 기능만 조용히 죽은 채 심사까지 통과한다 (T-260803-038 실사고).
  ```
  MEMOYO_API=https://<worker-endpoint> scripts/build-store.sh android
  ```

## remove_ads thank-you coupon

- Existing non-consumable product `remove_ads` remains a permanent ad removal purchase.
- A verified `remove_ads` receipt grants Premium access for 30 days once per store transaction.
- The app copy calls this a "감사 쿠폰", not an App Store / Google Play free trial.
- Reinstall/restore does not mint a new 30-day window. The Worker reuses the original coupon expiration keyed by the verified store transaction.

## Policy check

- Apple App Review Guidelines 3.1.2 allow auto-renewable subscriptions and say existing paid primary functionality should not be removed when moving to subscriptions. This implementation keeps `remove_ads` intact.
- Apple subscription free trials are configured in App Store Connect. This implementation does not present the thank-you coupon as a store free trial.
- Google Play subscription policy requires clear disclosure of offer terms, billing frequency, auto-renewal, and cancellation. The paywall shows monthly renewal and App Store / Google Play management text.
- Google Play purchase security guidance says subscription entitlement should be granted after backend verification with `Purchases.subscriptionsv2:get`. The Worker uses a server-side subscription verification path and stores the entitlement in D1.

## Not done in this PR

- App Store Connect / Play Console product creation and activation.
- Store review submission.
- Worker deployment or D1 production migration.
- AI summary / semantic search endpoints. Those are P2/P3.
