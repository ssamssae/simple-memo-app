import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:simple_memo_app/features/memos/services/memoyo_summary_client.dart';

void main() {
  test('summarize posts userId/memoText and parses Haiku usage', () async {
    late http.Request seen;
    final client = MemoyoSummaryClient(
      baseUrl: 'https://worker.test',
      httpClient: MockClient((request) async {
        seen = request;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'model': 'claude-haiku-4-5-20251001',
              'summary': '• 치과 예약\n• 오후 3시 방문',
              'usage': {
                'date': '2026-07-15',
                'used': 1,
                'limit': 30,
                'remaining': 29,
              },
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final result = await client.summarize(
      userId: 'memoyo-user-1',
      memoText: '치과 예약\n오후 3시 방문',
    );
    final payload = jsonDecode(seen.body) as Map<String, Object?>;

    expect(seen.url.path, '/api/memoyo/ai/summarize');
    expect(payload['userId'], 'memoyo-user-1');
    expect(payload['memoText'], '치과 예약\n오후 3시 방문');
    expect(result.model, 'claude-haiku-4-5-20251001');
    expect(result.summary, contains('오후 3시'));
    expect(result.usage.remaining, 29);
    expect(result.usage.limit, 30);
  });

  test('daily limit response throws typed exception with usage', () async {
    final client = MemoyoSummaryClient(
      baseUrl: 'https://worker.test',
      httpClient: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'error': '오늘 AI 요약 30회 한도에 도달했습니다.',
              'code': 'MEMOYO_SUMMARY_DAILY_LIMIT',
              'usage': {
                'date': '2026-07-15',
                'used': 30,
                'limit': 30,
                'remaining': 0,
              },
            }),
          ),
          429,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await expectLater(
      client.summarize(userId: 'memoyo-user-1', memoText: '요약할 메모'),
      throwsA(
        isA<MemoyoSummaryException>()
            .having((error) => error.statusCode, 'statusCode', 429)
            .having((error) => error.code, 'code', 'MEMOYO_SUMMARY_DAILY_LIMIT')
            .having((error) => error.usage?.remaining, 'remaining', 0),
      ),
    );
  });
}
