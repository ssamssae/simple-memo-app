# UIScene 마이그레이션 수정 프롬프트

터미널에서 먼저 자동 마이그레이션을 시도하세요:
```bash
flutter config --enable-uiscene-migration
flutter run
```

자동이 안 되면 아래 프롬프트를 Claude Code에 복사해서 붙여넣으세요.

---

```
Flutter 3.38의 UIScene 라이프사이클 마이그레이션을 수동으로 적용해줘.
현재 앱이 iOS에서 스와이프 종료 후 재실행하면 크래시가 나는데, UIScene 마이그레이션이 안 되어 있어서 그래.

## 수정 1: ios/Runner/AppDelegate.swift

현재 코드:
```swift
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

아래처럼 수정해줘:
```swift
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func didInitializeImplicitFlutterEngine(_ engine: FlutterEngine) {
    GeneratedPluginRegistrant.register(with: engine)
  }
}
```

핵심 변경:
- didFinishLaunchingWithOptions에서 GeneratedPluginRegistrant.register(with: self) 제거
- didInitializeImplicitFlutterEngine 메서드 추가하고 그 안에서 플러그인 등록

## 수정 2: ios/Runner/Info.plist

Info.plist의 </dict> 바로 위에 UIApplicationSceneManifest 설정을 추가해줘:

```xml
	<key>UIApplicationSceneManifest</key>
	<dict>
		<key>UIApplicationSupportsMultipleScenes</key>
		<false/>
		<key>UISceneConfigurations</key>
		<dict>
			<key>UIWindowSceneSessionRoleApplication</key>
			<array>
				<dict>
					<key>UISceneConfigurationName</key>
					<string>Default Configuration</string>
					<key>UISceneDelegateClassName</key>
					<string>FlutterSceneDelegate</string>
					<key>UISceneStoryboardFile</key>
					<string>Main</string>
				</dict>
			</array>
		</dict>
	</dict>
```

이 XML을 </dict></plist> 바로 앞에 넣어줘.

## 수정 3: withValues → withOpacity 호환성 수정

lib/screens/memo_list_screen.dart에서:
Colors.amber.withValues(alpha: 0.4)
를
Colors.amber.withOpacity(0.4)
로 변경해줘.

## 수정 후 빌드

수정 완료 후 아래 명령어를 순서대로 실행해줘:
1. flutter clean
2. flutter pub get
3. cd ios && pod install --repo-update && cd ..

변경된 파일 내용을 모두 보여줘.
```
