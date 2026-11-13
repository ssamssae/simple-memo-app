# todos 도메인 (T-261112-052 → T-261113-024 옛 저장값만)

옛 「할 일」 탭(Things 3식 목록 하나)은 T-261113-024 에서 걷었다. 대종님 2026-11-13:
메모와 할 일을 나누지 않는다 — 메모 왼쪽에 체크 칸, 체크한 메모는 「완료」 탭.
그 기능은 `features/memos/` 에 있다(`Memo.doneAt`, 완료 탭).

여기 남은 것은 옛 데이터를 읽는 코드뿐이다.
- `models/todo.dart` · `services/todo_storage.dart`: SharedPreferences `todos`(JSON 배열) 읽기.
- 읽는 곳: `features/memos/services/todo_memo_migration.dart` 가 처음 한 번 할 일을 메모로
  옮긴다(깃발 `todos_migrated_to_memos_v1`). `todos` 키는 지우지 않는다(되돌릴 수 있게).
- 1.0.29~1.0.30 백업 zip 의 `todos.json` 도 `MemoBackupArchive.decode` 가 메모로 바꾼다.
  새 백업은 `todos.json` 을 넣지 않는다.
