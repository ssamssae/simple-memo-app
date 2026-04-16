# Flutter 메모앱 iOS 크래시 수정 프롬프트

아래 프롬프트를 Claude Code에 복사해서 붙여넣으세요.

---

```
이 Flutter 프로젝트에서 iPhone 앱이 첫 실행은 정상이지만 스와이프 종료 후 재실행하면 바로 크래시되는 버그를 수정해줘.

분석 결과 아래 2가지가 원인으로 확인됐어:

## 수정 1: lib/main.dart - runZonedGuarded 패턴 수정

현재 WidgetsFlutterBinding.ensureInitialized()가 runZonedGuarded 내부에서 호출되고 있어.
이렇게 하면 Flutter 바인딩이 특정 Zone에 묶여서 iOS에서 앱 재시작 시 네이티브 콜백과 Zone 충돌로 크래시가 발생할 수 있어.

현재 코드:
```dart
void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('[FlutterError] ${details.exception}');
      debugPrint('[FlutterError] ${details.stack}');
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      debugPrint('[PlatformError] $error');
      debugPrint('[PlatformError] $stack');
      return true;
    };
    runApp(const MemoApp());
  }, (Object error, StackTrace stack) {
    debugPrint('[ZoneError] $error');
    debugPrint('[ZoneError] $stack');
  });
}
```

아래처럼 수정해줘:
- WidgetsFlutterBinding.ensureInitialized()를 runZonedGuarded 바깥(최상단)으로 이동
- FlutterError.onError와 PlatformDispatcher.instance.onError도 바깥으로 이동
- runZonedGuarded는 runApp()만 감싸도록 변경
- dart:ui import는 유지 (PlatformDispatcher 때문에 필요)

수정 후 코드:
```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exception}');
    debugPrint('[FlutterError] ${details.stack}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[PlatformError] $error');
    debugPrint('[PlatformError] $stack');
    return true;
  };

  runZonedGuarded(() {
    runApp(const MemoApp());
  }, (Object error, StackTrace stack) {
    debugPrint('[ZoneError] $error');
    debugPrint('[ZoneError] $stack');
  });
}
```

## 수정 2: pubspec.yaml - 미사용 intl 패키지 제거

pubspec.yaml의 dependencies에서 `intl: ^0.20.2` 줄을 삭제해줘.
코드 어디에서도 import하지 않는 미사용 의존성이야.

## 수정 후 할 일

두 파일 수정 후 아래 명령어를 순서대로 실행해줘:
1. flutter clean
2. flutter pub get
3. cd ios && pod install --repo-update && cd ..

수정 완료 후 변경된 파일 내용을 보여줘.
```
