todos 도메인 규칙

- 할 일 저장 형식(`todos` 키, `Todo.toJson`)을 바꾸면 옛 값 읽기 시험과 백업 시험을 같이 고친다.
- 목록 계산은 `services/todo_ops.dart` 순수 함수에 두고 화면은 얇게 둔다.
- 기존 메모 체크 줄(`features/memos/services/checklist_*`)은 이 도메인에서 건드리지 않는다.
