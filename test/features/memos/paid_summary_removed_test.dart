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
//
// ■T-260804-078 추가 — 결제 판매 문구 축이 여기로 들어왔다.
//   062 시점에는 「결제화면 문구는 R3 별건」이라 대상이 아니었다. 아니키 ack(2026-08-04 23:20)로
//   문구 제거가 승인돼 이제 이 파일이 ★두 축을 지킨다: 호출 경로(아래 첫 test)와
//   판매 문구(둘째 test). 두 축을 한 파일에 둔 이유 = 갈라 두면 기능만 지우고 문구를 남기는
//   실패가 다시 난다. 실제로 062 가 그렇게 끝났다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/l10n/app_strings.dart';

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
  'premiumFeatureAiSummaries': '결제화면 AI 요약 혜택 라벨(없는 기능을 파는 문구)',
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

  // T-260804-078 — 손님이 읽는 판매 문구가 없어진 기능을 팔지 않는지.
  //   ★이 축이 없으면 062 의 재발을 못 막는다: 기능은 지웠는데 결제화면·설정화면이
  //   두 달간 「AI 요약」을 계속 팔고 있었고, 코드 검사는 전부 초록이었다.
  //   문자열 스캔이 아니라 ★getter 를 실제로 불러서 본다 — 문구가 어느 파일에 있든 잡힌다.
  // ★T-260805-076 로 검사 대상이 바뀌었다. 구독(premium_monthly)이 폐지되면서
  //   구독 판매 문구 getter 들이 사라졌으므로, 이 축은 ★지금 실제로 파는 상품인
  //   광고제거(remove_ads)의 문구를 본다. 축의 목적은 그대로다 —
  //   「손님이 읽는 판매 문구가 앱에 없는 기능을 팔지 않는다」.
  test('판매 문구가 AI 요약을 광고하지 않는다 (ko·en 양쪽)', () {
    for (final code in ['ko', 'en']) {
      final s = AppStrings.fromCode(code);
      final sales = <String, String>{
        'removeAds': s.removeAds,
        'removeAdsOneTime': s.removeAdsOneTime,
        'removeAdsPrepared': s.removeAdsPrepared,
        'thanksForUsing': s.thanksForUsing,
      };

      // ★양성 대조군 — 문구를 실제로 읽고 있음을 먼저 증명한다. 이게 없으면 빈 문자열
      //   4개를 검사하고도 초록이 나고, 그 초록은 아무것도 안 잰 초록이다.
      expect(
        sales.values.every((v) => v.trim().isNotEmpty),
        isTrue,
        reason: '판매 문구가 비었다 — 검사가 죽은 것이 먼저다 ($code)',
      );
      expect(
        sales['removeAdsOneTime']!.toLowerCase(),
        contains(code == 'en' ? 'ad' : '광고'),
        reason: '대조군 실패 — 실재하는 혜택 문구조차 못 읽었다 ($code)',
      );

      // 판정축. 「요약/summar」가 프리미엄 판매 문구에 있으면 그 기능이 앱에 있어야 한다.
      //   온디바이스 추출식 요약(레그 2, T-260803-038 계열)이 유료 혜택으로 되살아나면
      //   ★이 단언을 의도적으로 고쳐라 — 조용히 문구만 되살리는 길을 막는 것이 이 축의 목적이다.
      sales.forEach((name, value) {
        final v = value.toLowerCase();
        expect(
          v.contains('요약') || v.contains('summar'),
          isFalse,
          reason:
              '$code.$name 이 없어진 AI 요약을 여전히 광고한다 (T-260804-078): "$value"',
        );
      });
    }
  });
}
