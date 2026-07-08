메모요 Codex/agent 작업 규칙

- 기존 `lib/screens`, `lib/services`, `lib/models`, `lib/widgets` 파일은 별도 재구조화 task 없이 이동하지 않는다.
- 신규 기능은 우선 `lib/features/<domain>/` 아래에 둔다.
- 도메인 폴더를 새로 만들거나 기능을 추가할 때는 해당 폴더의 `README.md`와 `AGENTS.md`를 먼저 확인하고, 없으면 함께 만든다.
- 도메인 내부는 필요할 때 `screens/`, `widgets/`, `services/`, `models/` 하위 폴더로 나누되, 앱 전역 재사용 코드만 기존 공용 폴더로 둔다.
- store 제출, 버전 변경, 앱 아이콘/스크린샷/서명 파일 변경은 별도 명시 지시 없이는 하지 않는다.
