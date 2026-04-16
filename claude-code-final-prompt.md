# Claude Code 프롬프트 (복사해서 붙여넣기)

---

```
이 Flutter 프로젝트의 iOS 앱이 아이폰에서 스와이프 종료 후 재실행하면 바로 크래시가 나는 버그를 수정해줘.
Flutter 3.38부터 iOS UIScene 라이프사이클 마이그레이션이 필수인데, 이 프로젝트에 적용이 안 되어 있어서 생기는 문제야.

아래 3개 파일을 수정해줘:

---

## 1. ios/Runner/AppDelegate.swift

- didFinishLaunchingWithOptions 안에 있는 `GeneratedPluginRegistrant.register(with: self)` 줄을 제거해
- 대신 `didInitializeImplicitFlutterEngine` 메서드를 새로 추가하고, 그 안에서 `GeneratedPluginRegistrant.register(with: engine)` 호출해
- import 순서는 Flutter를 UIKit보다 먼저 유지해

---

## 2. ios/Runner/Info.plist

- `</dict></plist>` 바로 앞에 아래 XML 블록을 추가해:

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

---

## 3. lib/screens/memo_list_screen.dart

- `Colors.amber.withValues(alpha: 0.4)` 를 `Colors.amber.withOpacity(0.4)` 로 변경해

---

## 수정 완료 후

아래 명령어를 순서대로 실행해:
1. flutter clean
2. flutter pub get  
3. cd ios && pod install --repo-update && cd ..

그리고 변경된 3개 파일의 전체 내용을 보여줘.
```
