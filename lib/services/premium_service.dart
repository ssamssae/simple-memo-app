import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'premium_entitlement_client.dart';

class PremiumService {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  static const _userIdKey = 'premium_user_id';
  static const _entitlementKey = 'premium_entitlement_json';

  final ValueNotifier<PremiumEntitlement> entitlement =
      ValueNotifier<PremiumEntitlement>(const PremiumEntitlement.inactive());

  PremiumEntitlementClient _client = PremiumEntitlementClient();
  String? _userId;
  bool _initialized = false;

  bool get isPremium => entitlement.value.active;

  Future<void> init({PremiumEntitlementClient? client}) async {
    if (client != null) _client = client;
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
    if (_client.isConfigured) {
      unawaited(refreshStatus().catchError((Object _) => entitlement.value));
    }
  }

  Future<String> userId() async {
    if (!_initialized) await init();
    return _userId!;
  }

  Future<PremiumEntitlement> refreshStatus() async {
    final status = await _client.status(await userId());
    return _store(status);
  }

  Future<PremiumEntitlement> verifyPremiumPurchase(PurchaseDetails purchase) {
    return _verifyPurchase(purchase, _client.verifySubscription);
  }

  Future<PremiumEntitlement> claimRemoveAdsCoupon(PurchaseDetails purchase) {
    return _verifyPurchase(purchase, _client.claimRemoveAdsCoupon);
  }

  Future<PremiumEntitlement> _verifyPurchase(
    PurchaseDetails purchase,
    Future<PremiumEntitlement> Function({
      required String userId,
      required String platform,
      required String purchaseId,
      required String serverVerificationData,
    })
    verify,
  ) async {
    final platform = _storePlatform();
    if (platform == null) return const PremiumEntitlement.inactive();
    final purchaseId =
        purchase.purchaseID ??
        purchase.verificationData.localVerificationData.trim();
    if (purchaseId.isEmpty) return const PremiumEntitlement.inactive();
    final status = await verify(
      userId: await userId(),
      platform: platform,
      purchaseId: purchaseId,
      serverVerificationData: purchase.verificationData.serverVerificationData,
    );
    return _store(status);
  }

  Future<PremiumEntitlement> _store(PremiumEntitlement status) async {
    entitlement.value = status.active
        ? status
        : const PremiumEntitlement.inactive();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _entitlementKey,
      jsonEncode(entitlement.value.toJson()),
    );
    return entitlement.value;
  }

  String? _storePlatform() {
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    return null;
  }
}
