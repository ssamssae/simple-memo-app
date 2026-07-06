import 'dart:convert';

import 'package:http/http.dart' as http;

typedef PremiumEntitlementTransport =
    Future<Map<String, Object?>> Function(
      Uri uri,
      Map<String, Object?> payload,
    );

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
      productId = PremiumEntitlementClient.premiumProductId,
      expiresAt = null,
      source = null,
      couponAlreadyGranted = false;

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
      productId:
          json['productId'] as String? ??
          PremiumEntitlementClient.premiumProductId,
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

class PremiumEntitlementClient {
  PremiumEntitlementClient({
    String? baseUrl,
    http.Client? httpClient,
    PremiumEntitlementTransport? transport,
  }) : _baseUrl = (baseUrl ?? const String.fromEnvironment('MEMOYO_API'))
           .trim()
           .replaceFirst(RegExp(r'/$'), ''),
       _httpClient = httpClient ?? http.Client(),
       _transport = transport;

  static const premiumProductId = 'premium_monthly';
  static const removeAdsProductId = 'remove_ads';

  final String _baseUrl;
  final http.Client _httpClient;
  final PremiumEntitlementTransport? _transport;

  bool get isConfigured => _baseUrl.isNotEmpty;

  Future<PremiumEntitlement> status(String userId) async {
    if (!isConfigured) return const PremiumEntitlement.inactive();
    final uri = Uri.parse(
      '$_baseUrl/api/memoyo/entitlement/status',
    ).replace(queryParameters: {'userId': userId});
    final response = await _httpClient.get(uri);
    return PremiumEntitlement.fromJson(_decode(response));
  }

  Future<PremiumEntitlement> verifySubscription({
    required String userId,
    required String platform,
    required String purchaseId,
    required String serverVerificationData,
  }) {
    return _postEntitlement(
      '/api/memoyo/entitlement/verify',
      userId: userId,
      platform: platform,
      productId: premiumProductId,
      purchaseId: purchaseId,
      serverVerificationData: serverVerificationData,
    );
  }

  Future<PremiumEntitlement> claimRemoveAdsCoupon({
    required String userId,
    required String platform,
    required String purchaseId,
    required String serverVerificationData,
  }) {
    return _postEntitlement(
      '/api/memoyo/entitlement/remove-ads-coupon',
      userId: userId,
      platform: platform,
      productId: removeAdsProductId,
      purchaseId: purchaseId,
      serverVerificationData: serverVerificationData,
    );
  }

  Future<PremiumEntitlement> _postEntitlement(
    String path, {
    required String userId,
    required String platform,
    required String productId,
    required String purchaseId,
    required String serverVerificationData,
  }) async {
    final payload = <String, Object?>{
      'userId': userId,
      'platform': platform,
      'productId': productId,
      'purchaseId': purchaseId,
      'serverVerificationData': serverVerificationData,
    };
    final uri = Uri.parse(
      '${_baseUrl.isEmpty ? 'https://memoyo.local' : _baseUrl}$path',
    );
    final transport = _transport;
    if (transport != null) {
      return PremiumEntitlement.fromJson(await transport(uri, payload));
    }
    if (!isConfigured) return const PremiumEntitlement.inactive();
    final response = await _httpClient.post(
      uri,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode(payload),
    );
    return PremiumEntitlement.fromJson(_decode(response));
  }

  Map<String, Object?> _decode(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Invalid entitlement response');
    }
    final body = Map<String, Object?>.from(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = body['error'] as String? ?? 'Premium entitlement failed';
      throw PremiumEntitlementException(response.statusCode, message);
    }
    return body;
  }
}

class PremiumEntitlementException implements Exception {
  const PremiumEntitlementException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'PremiumEntitlementException($statusCode, $message)';
}
