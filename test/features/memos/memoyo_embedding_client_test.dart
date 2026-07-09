import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simple_memo_app/features/memos/services/memoyo_embedding_client.dart';

void main() {
  test('embedTexts posts userId/texts to Worker semantic endpoint', () async {
    late http.Request seen;
    final client = MemoyoEmbeddingClient(
      baseUrl: 'https://worker.test',
      httpClient: MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'model': 'gemini-embedding-001',
            'dimensions': 2,
            'embeddings': [
              [1, 0],
              [0, 1],
            ],
          }),
          200,
        );
      }),
    );

    final result = await client.embedTexts(
      userId: 'memoyo-user-1',
      texts: const ['첫 메모', '두 번째 메모'],
    );
    final payload = jsonDecode(seen.body) as Map<String, Object?>;

    expect(seen.url.path, '/api/memoyo/ai/embed');
    expect(payload['userId'], 'memoyo-user-1');
    expect(payload['texts'], ['첫 메모', '두 번째 메모']);
    expect(result.model, 'gemini-embedding-001');
    expect(result.embeddings, [
      [1.0, 0.0],
      [0.0, 1.0],
    ]);
  });

  test(
    'quota fallback response throws typed lexical fallback exception',
    () async {
      final client = MemoyoEmbeddingClient(
        baseUrl: 'https://worker.test',
        httpClient: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'error': 'Gemini 무료티어 embedding 한도를 초과했습니다.',
                'code': 'GEMINI_QUOTA_EXHAUSTED',
                'fallback': 'lexical',
              }),
            ),
            429,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      await expectLater(
        client.embedTexts(userId: 'memoyo-user-1', texts: const ['검색어']),
        throwsA(
          isA<MemoyoEmbeddingFallbackException>()
              .having((e) => e.statusCode, 'statusCode', 429)
              .having((e) => e.code, 'code', 'GEMINI_QUOTA_EXHAUSTED'),
        ),
      );
    },
  );
}
