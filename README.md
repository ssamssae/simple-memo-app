# Simple Memo App

간단하고 직관적인 메모 앱입니다. Flutter로 제작되었으며, 메모 작성/수정/삭제와 즐겨찾기 기능을 지원합니다.

## 주요 기능

- 메모 작성, 수정, 삭제
- 즐겨찾기 기능 (스와이프로 토글)
- 즐겨찾기 메모가 항상 상단에 표시
- 드래그 앤 드롭으로 메모 순서 변경
- 스와이프로 삭제/즐겨찾기 조작
- 로컬 저장 (SharedPreferences)

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
