# Simple Memo App

간단하고 직관적인 메모 앱입니다. Flutter로 제작되었으며, 메모 작성/수정/삭제와 즐겨찾기 기능을 지원합니다.

## 주요 기능

- 메모 작성, 수정, 삭제
- 즐겨찾기 기능 (스와이프로 토글)
- 즐겨찾기 메모가 항상 상단에 표시
- 드래그 앤 드롭으로 메모 순서 변경
- 스와이프로 삭제/즐겨찾기 조작
- 로컬 저장 (SharedPreferences)
- 메모 백업/복원 — Google Drive 1버튼 백업 (`Memoyo` 폴더 자동 생성, 최신 7개 회전 보관) + 시스템 share sheet 가져오기/내보내기
- 삭제 실행 취소 — 삭제 직후 SnackBar 의 "실행 취소" 액션 탭으로 직전 상태 복원
- 메모 공유 — 편집 화면 AppBar 의 공유 버튼으로 시스템 share sheet 호출

## 1.0.7 트랙 (데이터 안전망 + UX 단순화)

1.0.7 은 데이터 안전망과 UX 단순화를 목표로 한 4 항목 메이저 묶음입니다.

- **(1) Drive 1버튼 백업** — overflow 메뉴의 "Drive 백업" 한 번으로 Google Drive `Memoyo` 폴더에 JSON 백업. OAuth + `drive.file` scope, 최근 7개 유지 자동 회전, 네트워크/권한/용량 실패 상태 SnackBar 분기.
- **(2) 삭제 실행 취소** — 단일·벌크 삭제 즉시 "실행 취소" SnackBar. 탭하면 원래 위치 + 즐겨찾기 그룹 순서 복원.
- **(3) 메모 공유** — 메모 편집 화면 AppBar 의 공유 IconButton 으로 본문을 시스템 share sheet 에 전달.
- **(4) 휴지통 30일** — 예정 (별도 트랙).

## 실행 방법

### 사전 준비

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 설치

### 의존성 설치

```bash
flutter pub get
```

### 앱 실행

```bash
# macOS
flutter run -d macos

# Chrome
flutter run -d chrome

# iOS 시뮬레이터
flutter run -d ios

# Android 에뮬레이터
flutter run -d android
```

## 프로젝트 구조

```
lib/
  main.dart                # 앱 진입점 (MemoApp + 글로벌 에러 핸들러)
  models/memo.dart         # Memo 데이터 모델 (copyWith / JSON 직렬화)
  screens/
    splash_screen.dart       # 스플래시 → 목록 화면 전환
    memo_list_screen.dart    # 메모 목록 화면 (스와이프/리오더)
    memo_edit_screen.dart    # 메모 작성/수정 화면
  services/
    memo_storage.dart        # SharedPreferences 기반 영속 저장
  widgets/
    paste_button.dart        # 클립보드 붙여넣기 버튼
test/
  widget_test.dart         # Memo 모델 단위 테스트
```
