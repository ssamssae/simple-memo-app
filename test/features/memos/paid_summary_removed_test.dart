// T-260804-062 — 유료 AI 요약 호출 경로가 lib/ 에서 사라진 상태를 단언한다.
//
// ■왜 문자열 스캔인가
//   아니키 결정 2026-08-04: 「내 api 로 비용은 못 내겠어」 — 유료 요약은 제거 대상이다.
//   그런데 이 경로는 ★없어진 것을 확인하는 검사라, 평범한 단위 테스트로는 못 잡는다.
//   호출부를 지워도 클라이언트 클래스가 살아 있으면 다음 화면에서 다시 배선된다.
//   그래서 배선 여부가 아니라 ★소스에 그 심볼·엔드포인트가 존재하는지를 직접 센다.
//
// ■계기가 살아있음을 어떻게 아나 (mutation probe)
//   금지 문자열을 lib/ 아무 파일에 한 줄 되살리면 이 테스트는 ★RED 가 되어야 한다.
//   되살렸는데 초록이면 이 테스트는 0회 도는 장식이다. 착수 시 실측으로 RED→복원→GREEN
//   3단을 확인했다(보고 첨부). 이 파일을 고칠 사람은 같은 절차를 다시 밟아라.
//
// ■범위 주의
//   lib/ 만 센다. test/ 를 포함하면 ★이 파일 자신의 금지 문자열이 잡혀 항상 RED 가 된다.
//   또한 결제화면(paywall_screen.dart)의 프리미엄 혜택 문구는 이 검사 대상이 아니다 —
//   스토어 문구 수정은 R3 별건이라 이 티켓에서 손대지 않았다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 되살아나면 안 되는 것들. 조각으로 쪼개 두지 않는다 — 쪼개면 이 파일이 스스로를
/// 못 지키고, 무엇을 막는 중인지도 안 읽힌다.
const _forbidden = <String, String>{
  '/api/memoyo/ai/summarize': '유료 AI 요약 엔드포인트',
  'MemoyoSummaryClient': '유료 요약 클라이언트 클래스',
  'MemoyoSummaryResult': '유료 요약 응답 모델',
  'MemoyoSummaryException': '유료 요약 예외 타입',
  'memoyo_summary_client': '유료 요약 클라이언트 파일 import',
  'MemoSummarySheet': '유료 요약 결과 시트',
  'memo-summary-button': '유료 요약 진입 버튼(죽은 버튼도 남기지 않는다)',
};

void main() {
  test('lib/ 에 유료 AI 요약 호출 경로가 0건이다', () {
    final libDir = Directory('lib');
    // ★대조군 — 스캐너가 실제로 파일을 읽고 있는지 먼저 증명한다. 0건 초록이
    //   「깨끗하다」가 아니라 「아무것도 안 읽었다」일 수 있다.
    expect(libDir.existsSync(), isTrue, reason: 'lib/ 를 못 찾았다 — cwd 가 패키지 루트가 아니다');

    final dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    expect(
      dartFiles.length,
      greaterThan(20),
      reason: '스캔 대상이 비정상적으로 적다 — 스캐너가 죽었을 가능성이 먼저다',
    );

    final hits = <String>[];
    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      for (final entry in _forbidden.entries) {
        if (source.contains(entry.key)) {
          hits.add('${file.path}: ${entry.key} (${entry.value})');
        }
      }
    }

    expect(
      hits,
      isEmpty,
      reason:
          '유료 AI 요약 경로가 lib/ 에 되살아났다 (T-260804-062 로 제거된 경로):\n'
          '${hits.join('\n')}',
    );
  });
}
