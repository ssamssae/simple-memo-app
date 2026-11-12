# todos 도메인 (T-261112-052)

메모요 「할 일」 탭. Things 3 Inbox 처럼 쓰는 목록 하나.
- 저장: SharedPreferences `todos`(JSON 배열, 배열 순서 = 화면 순서). 메모 `memos` 와 따로.
- 백업: `MemoBackupArchive` 의 `todos.json`(할 일이 있을 때만).
- 공용 의존: `l10n/app_strings.dart`, `utils/app_palette.dart`, `services/export_import_service.dart`(백업 연결만). 공용으로 둔다.
