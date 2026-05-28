# Changelog

## [1.0.7] - 2026-05-29

### Added
- Drive 1버튼 백업 — overflow 메뉴 "Drive 백업" 항목 추가. Google Drive `Memoyo` 폴더 자동 생성, JSON 파일 업로드 후 최근 7개 회전 보관. 성공 시 "Memoyo 폴더 열기" 액션 SnackBar.
- 삭제 실행 취소 — 단일 스와이프 삭제와 편집 모드 벌크 삭제 직후 SnackBar 의 "실행 취소" 액션 노출. 탭하면 원래 인덱스에 메모 재삽입 후 즐겨찾기/일반 그룹 순서 복원.
- 메모 공유 — 메모 편집 화면 AppBar 에 공유 IconButton 추가. 시스템 share sheet 로 본문 전달.

### Fixed
- Google OAuth 설정 정정 — Android `App signing key` SHA-1 교체, Drive 권한 동의 시트가 정상적으로 노출되도록 `drive.file` scope 명시.
- Drive 백업 실패 상태 분리 — 네트워크 끊김 / 권한 거부 / 용량 부족 / 기타 오류를 각각 다른 메시지 SnackBar 로 분기.

### Notes
- Drive 백업/가져오기 1버튼 흐름은 1.0.5 의 시스템 share sheet 기반 수동 백업/복원 위에 누적된 편의 레이어입니다. 가져오기 측 1버튼 (Drive 폴더 직접 탐색) 은 별도 트랙.
- 휴지통 30일 (1.0.7 4번째 트랙) 은 다음 사이클로 분리. 본 릴리즈는 실행 취소 SnackBar 까지.

## [1.0.5] - 2026-05-18

### Added
- 메모 백업/복원 — AppBar overflow 메뉴에 "메모 내보내기" / "메모 가져오기" 추가. 시스템 share sheet 를 통해 메일·AirDrop·iCloud Drive·Google Drive 등 자유 선택.
- 가져오기 되돌리기 — 직전 1단계 undo. 가져오기 직후 SnackBar 또는 overflow 메뉴에서 누름.
- 편집 모드 전체 선택 — "전체선택" / "선택해제" 토글 버튼.

### Removed
- 자동 동기화 (Firebase Firestore + Auth) 계획 폐기. 무료앱 + CS 부담 0 정책으로 수동 백업/복원 방식 채택. 상세: docs/superpowers/specs/2026-05-18-memo-export-import-design.md
