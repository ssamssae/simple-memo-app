# 스토어 현지화 확인 경로

## 1.0.20 이름과 스크린샷 (T-261011-058)

- 앱 UI는 한국어·영어를 지원한다. 스토어 이름은 ko=메모요, ja·en-US=Memoyo다. 일본어 페이지는 영어 UI에 일본어 예시 메모를 넣은 화면을 사용한다. 설명에 지원 언어와 스크린샷 언어를 명시한다.
- 캡처: macOS에서 `flutter test test/store_capture_test.dart --dart-define=STORE_CAPTURE=true --dart-define=STORE_CAPTURE_LOCALE=en-US`를 실행한다. `ja`로 한 번 더 실행한다. 기본 테스트에서는 캡처를 건너뛴다.
- 산출물: `fastlane/screenshots/<locale>/iPhone 6.9 Display/`의 3장. 1320×2868 크기로 실제 MemoApp의 메모 목록·새 메모·백업을 렌더링한다. 앱 화면을 별도로 재작성하거나 운영 메모를 읽지 않는다. 예시 메모와 광고 제거 구매자 상태를 사용한다.
- 범위: iOS 시뮬레이터 런타임 부재로 Flutter 위젯 렌더러와 로컬 시스템 글꼴을 사용했다. 실기기 캡처·키보드·광고·결제·Google 로그인 검증은 아니다. PNG 인코딩에서 불투명 픽셀을 유지하며 알파 채널만 제거한다. 글자 누락·잘림·언어·화면 내용을 6장 모두 육안 검수한다.
- 업로드: 승인된 build-lease에서 asc-deliver.py의 `--locale <locale> --screenshots`를 실행한다. 이름·설명·스크린샷 개수·해시와 ASC `assetDeliveryState=COMPLETE`를 재조회한다.
- 빌드: 기존 TestFlight 1.0.20(46), source 8302a173c, IPA SHA-256 22403f877238537c53d94f22df4c46f41953b2db3311b13cc4ceb6df6a88638f를 재사용한다. 해당 소스부터 현재 main까지 변경은 스토어 메타데이터뿐이다. pubspec을 이미 업로드된 1.0.20+46으로 맞췄다.
- 제출: 사용자 현재 대화의 진행 승인을 적용한다. 기존 AFTER_APPROVAL 정책을 유지한다. 제출 완료와 Apple 승인·실제 출시는 구분한다. API 재조회·이미지·검사 근거는 `/Users/user/reports/T-261011-058/`에 기록한다.
- 저장소 머지는 ASC 업로드·심사 제출을 자동 실행하지 않는다.
