# Changelog

## [1.0.5] - 2026-05-18

### Added
- 메모 백업/복원 — AppBar overflow 메뉴에 "메모 내보내기" / "메모 가져오기" 추가. 시스템 share sheet 를 통해 메일·AirDrop·iCloud Drive·Google Drive 등 자유 선택.
- 가져오기 되돌리기 — 직전 1단계 undo. 가져오기 직후 SnackBar 또는 overflow 메뉴에서 누름.
- 편집 모드 전체 선택 — "전체선택" / "선택해제" 토글 버튼.

### Removed
- 자동 동기화 (Firebase Firestore + Auth) 계획 폐기. 무료앱 + CS 부담 0 정책으로 수동 백업/복원 방식 채택. 상세: docs/superpowers/specs/2026-05-18-memo-export-import-design.md
