import 'dart:convert';

import 'package:http/http.dart' as http;

typedef MemoyoSummaryTransport =
    Future<Map<String, Object?>> Function(
      Uri uri,
      Map<String, Object?> payload,
    );

class MemoyoSummaryUsage {
  const MemoyoSummaryUsage({
    required this.date,
    required this.used,
    required this.limit,
    required this.remaining,
  });

  final String date;
  final int used;
  final int limit;
  final int remaining;

  factory MemoyoSummaryUsage.fromJson(Map<String, Object?> json) {
    final used = json['used'];
    final limit = json['limit'];
    final remaining = json['remaining'];
    if (used is! num || limit is! num || remaining is! num) {
      throw const FormatException('Invalid summary usage response');
    }
    return MemoyoSummaryUsage(
      date: json['date'] as String? ?? '',
      used: used.toInt(),
      limit: limit.toInt(),
      remaining: remaining.toInt(),
    );
  }
}

class MemoyoSummaryResult {
  const MemoyoSummaryResult({
    required this.model,
    required this.summary,
    required this.usage,
  });

  final String model;
  final String summary;
  final MemoyoSummaryUsage usage;

  factory MemoyoSummaryResult.fromJson(Map<String, Object?> json) {
    final summary = (json['summary'] as String? ?? '').trim();
    final rawUsage = json['usage'];
    if (summary.isEmpty || rawUsage is! Map) {
      throw const FormatException('Invalid summary response');
    }
    return MemoyoSummaryResult(
      model: json['model'] as String? ?? 'claude-haiku-4-5-20251001',
      summary: summary,
      usage: MemoyoSummaryUsage.fromJson(Map<String, Object?>.from(rawUsage)),
    );
  }
}

class MemoyoSummaryClient {
  MemoyoSummaryClient({
    String? baseUrl,
    http.Client? httpClient,
    MemoyoSummaryTransport? transport,
  }) : _baseUrl = (baseUrl ?? const String.fromEnvironment('MEMOYO_API'))
           .trim()
           .replaceFirst(RegExp(r'/$'), ''),
       _httpClient = httpClient ?? http.Client(),
       _transport = transport;

  final String _baseUrl;
  final http.Client _httpClient;
  final MemoyoSummaryTransport? _transport;

  bool get isConfigured => _baseUrl.isNotEmpty || _transport != null;

  Future<MemoyoSummaryResult> summarize({
    required String userId,
    required String memoText,
  }) async {
    final payload = <String, Object?>{'userId': userId, 'memoText': memoText};
    final uri = Uri.parse(
      '${_baseUrl.isEmpty ? 'https://memoyo.local' : _baseUrl}/api/memoyo/ai/summarize',
    );
    final transport = _transport;
    if (transport != null) {
      return MemoyoSummaryResult.fromJson(await transport(uri, payload));
    }
    if (_baseUrl.isEmpty) {
      throw const MemoyoSummaryException(
        statusCode: 503,
        code: 'MEMOYO_SUMMARY_UNCONFIGURED',
        message: 'AI summary endpoint is not configured',
      );
    }
    final response = await _httpClient.post(
      uri,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode(payload),
    );
    return MemoyoSummaryResult.fromJson(_decode(response));
  }

  Map<String, Object?> _decode(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Invalid summary response');
    }
    final body = Map<String, Object?>.from(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final rawUsage = body['usage'];
      throw MemoyoSummaryException(
        statusCode: response.statusCode,
        code: body['code'] as String? ?? 'MEMOYO_SUMMARY_FAILED',
        message: body['error'] as String? ?? 'AI summary failed',
        usage: rawUsage is Map
            ? MemoyoSummaryUsage.fromJson(Map<String, Object?>.from(rawUsage))
            : null,
      );
    }
    return body;
  }
}

class MemoyoSummaryException implements Exception {
  const MemoyoSummaryException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.usage,
  });

  final int statusCode;
  final String code;
  final String message;
  final MemoyoSummaryUsage? usage;

  @override
  String toString() => 'MemoyoSummaryException($statusCode, $code, $message)';
}
