import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/memoyo_embedding_client.dart';

Map<String, dynamic> _fixture(String name) {
  return jsonDecode(File('test/fixtures/gemini/$name.json').readAsStringSync())
      as Map<String, dynamic>;
}

void main() {
  test('official embedContent fixture uses singular embedding contract', () {
    final request = _fixture('embed_content_request');
    final response = _fixture('embed_content_response');

    expect(request['model'], 'models/gemini-embedding-001');
    expect(request['content'], isA<Map<String, dynamic>>());
    expect(request, isNot(contains('requests')));
    expect(response['embedding'], isA<Map<String, dynamic>>());
    expect(response, isNot(contains('embeddings')));
  });

  test('official batchEmbedContents fixture uses requests and embeddings', () {
    final request = _fixture('batch_embed_contents_request');
    final response = _fixture('batch_embed_contents_response');
    final requests = (request['requests'] as List).cast<Map<String, dynamic>>();
    final embeddings = (response['embeddings'] as List)
        .cast<Map<String, dynamic>>();

    expect(requests, hasLength(2));
    expect(
      requests.map((entry) => entry['model']),
      everyElement('models/gemini-embedding-001'),
    );
    expect(embeddings, hasLength(requests.length));
    expect(response, isNot(contains('embedding')));
  });

  test(
    'app keeps the Worker batch boundary distinct from Gemini REST',
    () async {
      late Uri calledUri;
      late Map<String, Object?> calledPayload;
      final client = MemoyoEmbeddingClient(
        transport: (uri, payload) async {
          calledUri = uri;
          calledPayload = payload;
          return {
            'model': 'gemini-embedding-001',
            'dimensions': 3,
            'embeddings':
                (_fixture('batch_embed_contents_response')['embeddings']
                        as List)
                    .map(
                      (entry) =>
                          (entry as Map<String, dynamic>)['values'] as List,
                    )
                    .toList(),
          };
        },
      );

      final result = await client.embedTexts(
        userId: 'fixture-user',
        texts: const ['치과 예약', '카레 레시피'],
      );

      expect(calledUri.path, '/api/memoyo/ai/embed');
      expect(calledPayload['texts'], ['치과 예약', '카레 레시피']);
      expect(result.embeddings, hasLength(2));
      expect(result.dimensions, 3);
    },
  );
}
