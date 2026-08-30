import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'premium_entitlement.dart';

/// 구독 권한 보관소 — T-260830-013 에서 서버 조회축을 걷어냈다.
///
/// ■지금 하는 일은 ★캐시 복원 하나다
///   구독은 2026-08-03 판매 종료(T-260803-038)라 새 권한이 생길 길이 없고, 권한을
///   조회하던 백엔드는 만들어진 적이 없다. 그래서 종전의 status/verify 왕복은 전부
///   도달 불가능한 죽은 배선이었다 — `MEMOYO_API` 가 비어 `isConfigured` 가 거짓이라
///   `refreshStatus` 는 호출조차 안 됐다. 남은 실효 경로는 SharedPreferences 에
///   저장된 권한을 읽어 오는 것뿐이고, 그것이 ★이미 결제한 사람의 광고 제거
///   유예(grandfather)를 지탱한다.
///
/// ■지우면 안 되는 것
///   `isPremium` 은 죽은 코드가 아니다. `ad_banner` 가 `AdsService.removeAds.value ||
///   PremiumService.instance.isPremium` 로 배너를 끄며, 뒤쪽 항이 유예다. 환불
///   (T-260804-082 4페이즈)이 끝나기 전에 이걸 정리하면 ★돈 낸 사람에게 광고가
///   되살아난다. 회귀축 = test/screens/subscription_sales_ended_test.dart.
class PremiumService {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  static const _userIdKey = 'premium_user_id';
  static const _entitlementKey = 'premium_entitlement_json';

  final ValueNotifier<PremiumEntitlement> entitlement =
      ValueNotifier<PremiumEntitlement>(const PremiumEntitlement.inactive());

  String? _userId;
  bool _initialized = false;

  bool get isPremium => entitlement.value.active;

  @visibleForTesting
  void resetForTest() {
    _initialized = false;
    _userId = null;
    entitlement.value = const PremiumEntitlement.inactive();
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString(_userIdKey);
    if (_userId == null) {
      _userId = const Uuid().v4();
      await prefs.setString(_userIdKey, _userId!);
    }

    final cached = prefs.getString(_entitlementKey);
    if (cached != null) {
      try {
        final entitlementJson = PremiumEntitlement.fromJson(
          Map<String, Object?>.from(jsonDecode(cached) as Map),
        );
        entitlement.value = entitlementJson.active
            ? entitlementJson
            : const PremiumEntitlement.inactive();
      } catch (_) {
        await prefs.remove(_entitlementKey);
      }
    }
  }

  Future<String> userId() async {
    if (!_initialized) await init();
    return _userId!;
  }
}
