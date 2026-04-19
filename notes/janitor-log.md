# Janitor 작업 로그

야간 자동 러너(`night-runner`) 가 `repo-janitor` 에이전트를 통해 처리한
잡일 기록. 각 세션은 `janitor/YYYY-MM-DD` 브랜치에 commit 만 하고 push 는
별도. 큰 작업/breaking change 는 여기 적지 말고 BACKLOG 로.

---
## 2026-04-19 (janitor/2026-04-19)

처리한 작업 3개:
1. `test/widget_test.dart` — `flutter create` 가 만든 카운터 스모크
   테스트(MyApp + Icons.add)를 삭제하고 Memo 모델 단위 테스트
   (firstLine / copyWith / encode↔decode 라운드트립)로 교체. 기존 테스트는
   현재 `MemoApp` 구조와 맞지 않아 컴파일조차 안 되던 상태.
   → commit `77f9cfa`
2. `lib/screens/memo_list_screen.dart` — flutter analyze 가 가리키던
   `curly_braces_in_flow_control_structures` 두 건 (즐겨찾기/일반 reorder
   가드 if) 정리. 동작 변경 없음.
   → commit `64b99c6`
3. `README.md` — 프로젝트 구조 섹션에 `splash_screen.dart`,
   `widgets/paste_button.dart`, `test/widget_test.dart` 누락분 추가하고
   설명을 현재 코드에 맞게 갱신.
   → commit `9c49947`

검증:
- `flutter analyze` 결과 9 → 5 issues (lint 2 + 위 단일행 if 2 → 1 단순화).
  남은 5건은 Flutter 6.x deprecated_member_use 2건(`Matrix4.translate` →
  Matrix3/4 전용 API), unused_field 2건(splash 의 `_fadeAnimation`,
  paste_button 의 `_viewId`), unnecessary_underscores 1건. 모두 동작과
  무관하지만 다음 라운드에서 정리 가능.
- `flutter test` 는 Windows Developer Mode 미활성으로 symlink 실패하여
  실행 불가 (코드 검증은 `flutter analyze` 통과로 갈음). Mac 본진에서
  `flutter test` 한 번 돌려봐 주면 좋음.

다음 권장 작업:
- splash_screen.dart 의 unused `_fadeAnimation` 필드 — 사용처 복원하거나
  삭제. (페이드 인 애니메이션이 의도된 거면 build 에 연결 필요.)
- paste_button.dart 의 unused `_viewId` 필드 — 동일 방향.
- `Matrix4.translate` 두 건 → `translateByDouble(...)` 로 교체 (Flutter
  6.x 권고 API).
- 윈도우 Developer Mode 켜서 러너 환경에서도 `flutter test` 가 돌게
  만들기 (관리자 권한 필요해서 사람이 한 번 켜줘야 함).
