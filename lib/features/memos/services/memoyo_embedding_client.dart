import 'dart:convert';

import 'package:http/http.dart' as http;

typedef MemoyoEmbeddingTransport =
    Future<Map<String, Object?>> Function(
      Uri uri,
      Map<String, Object?> payload,
    );

class MemoyoEmbeddingResult {
  const MemoyoEmbeddingResult({
    required this.model,
    required this.dimensions,
    required this.embeddings,
  });

  final String model;
  final int dimensions;
  final List<List<double>> embeddings;

  factory MemoyoEmbeddingResult.fromJson(Map<String, Object?> json) {
    final rawEmbeddings = json['embeddings'];
    if (rawEmbeddings is! List) {
      throw const FormatException('Invalid embedding response');
    }
    final embeddings = rawEmbeddings
        .map((raw) {
          if (raw is! List) {
            throw const FormatException('Invalid embedding vector');
          }
          return raw
              .map((value) {
                if (value is! num || !value.isFinite) {
                  throw const FormatException('Invalid embedding value');
                }
                return value.toDouble();
              })
              .toList(growable: false);
        })
        .toList(growable: false);
    return MemoyoEmbeddingResult(
      model: json['model'] as String? ?? 'gemini-embedding-001',
      dimensions:
          json['dimensions'] as int? ??
          (embeddings.isEmpty ? 0 : embeddings.first.length),
      embeddings: embeddings,
    );
  }
}

class MemoyoEmbeddingClient {
  MemoyoEmbeddingClient({
    String? baseUrl,
    http.Client? httpClient,
    MemoyoEmbeddingTransport? transport,
  }) : _baseUrl = (baseUrl ?? const String.fromEnvironment('MEMOYO_API'))
           .trim()
           .replaceFirst(RegExp(r'/$'), ''),
       _httpClient = httpClient ?? http.Client(),
       _transport = transport;

  final String _baseUrl;
  final http.Client _httpClient;
  final MemoyoEmbeddingTransport? _transport;

  bool get isConfigured => _baseUrl.isNotEmpty || _transport != null;

  Future<MemoyoEmbeddingResult> embedTexts({
    required String userId,
    required List<String> texts,
  }) async {
    final payload = <String, Object?>{'userId': userId, 'texts': texts};
    final uri = Uri.parse(
      '${_baseUrl.isEmpty ? 'https://memoyo.local' : _baseUrl}/api/memoyo/ai/embed',
    );
    final transport = _transport;
    if (transport != null) {
      return MemoyoEmbeddingResult.fromJson(await transport(uri, payload));
    }
    if (_baseUrl.isEmpty) {
      throw const MemoyoEmbeddingFallbackException(
        statusCode: 503,
        code: 'MEMOYO_EMBEDDING_UNCONFIGURED',
        message: 'Embedding endpoint is not configured',
      );
    }
    final response = await _httpClient.post(
      uri,
      headers: const {'content-type': 'application/json'},
      body: jsonEncode(payload),
    );
    return MemoyoEmbeddingResult.fromJson(_decode(response));
  }

  Map<String, Object?> _decode(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Invalid embedding response');
    }
    final body = Map<String, Object?>.from(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MemoyoEmbeddingFallbackException(
        statusCode: response.statusCode,
        code: body['code'] as String? ?? 'MEMOYO_EMBEDDING_FAILED',
        message: body['error'] as String? ?? 'Semantic search fallback',
      );
    }
    return body;
  }
}

class MemoyoEmbeddingFallbackException implements Exception {
  const MemoyoEmbeddingFallbackException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() =>
      'MemoyoEmbeddingFallbackException($statusCode, $code, $message)';
}
