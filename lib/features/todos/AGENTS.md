todos 도메인 규칙

- 할 일 화면·목록 연산은 없앴다(T-261113-024). 새 할 일 기능을 여기 만들지 않는다 — 체크·완료는 메모(`Memo.doneAt`)다.
- `Todo.fromJson`·`TodoStorage` 는 옛 `todos` 키와 옛 백업 `todos.json` 을 읽는 데만 쓴다. 바꾸면 옮기기 시험(`test/features/memos/todo_memo_migration_test.dart`)과 옛 백업 시험(`test/services/todo_backup_test.dart`)을 같이 고친다.
- 기존 메모 체크 줄(`features/memos/services/checklist_*`)은 이 도메인에서 건드리지 않는다.
