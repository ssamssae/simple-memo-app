# 기능 확인 경로

## 백업 완료 알림과 뜻 검색 설정 (T-261016-042)

- 사전 조건: 활성 메모가 있는 기기. 실제 Drive 백업에는 Google 로그인이 필요하다. 아래 위젯 검사는 업로드와 모델 관리자를 주입하며 운영 메모·모델 파일을 사용하지 않는다.
- 백업 경로: 설정 → 백업 & 복원 → 지금 백업 → 성공 알림. `Memoyo 폴더 열기`를 누르지 않아도 일반 모드에서는 4초 뒤 알림이 닫혀야 한다. 닫기 아이콘으로 즉시 닫을 수 있어야 한다. 설정으로 돌아와도 알림이 계속 남으면 실패다.
- 접근성: 화면 읽기 기능이 켜진 상태에서 표시한 성공 알림은 자동으로 닫히지 않는다. 폴더 버튼과 닫기 아이콘으로 사용자가 처리할 시간을 보장한다.
- 뜻 검색 경로: 설정 → 뜻 검색. 설치된 경우 요약에는 오프라인 검색 상태와 용량이 표시된다. 행을 누르면 모델명·라이선스·저장소·파일 정보를 확인할 수 있다. 상세의 모델 삭제 → 확인창에서 취소하면 설치 상태가 유지된다. 최종 삭제를 누른 경우에만 모델 삭제를 요청한다. 기존 메모는 삭제 대상이 아니다.
- 확인창이 열린 동안 설정 화면이 제거되거나 모델 관리자가 교체되면 이전 설치·삭제 확인으로 실행하지 않는다. 320×568 화면·글자 배율 2배에서도 한국어·영어 확인창 내용은 스크롤할 수 있어야 한다. 취소·확인 버튼이 화면 안에 있어야 한다.
- 자동 검사: `flutter test test/screens/backup_restore_screen_test.dart test/widgets/mini_lm_model_settings_tile_test.dart test/features/memos/semantic_search_exposure_test.dart test/l10n/english_locale_smoke_test.dart`. 노출 보호 검사에 대한 반례는 `flutter test --dart-define=MEMOYO_SEMANTIC_SEARCH=false test/features/memos/semantic_search_exposure_test.dart`로 확인한다. 잠금 상태에서도 기존 모델의 삭제 확인 경로는 남아야 한다.
- 근거: 2026-10-16, Linux의 Flutter 3.44.0 / Dart 3.12.0 위젯 검사. 알림 자동 닫힘·수동 닫기, 상세 이동, 이전 확인 대상 보호, 영어 큰 글씨 넘침을 재현한 뒤 수정했다. 변경 검증 결과는 해당 PR의 CI와 연결한다.
- 미확인: iPhone 실기기 조작, 실제 Google Drive 업로드, 실제 모델 설치·삭제는 이 검사의 대상이 아니다. 앱 버전 변경·스토어 업로드는 별도 작업이다.
- 머지 효과: 저장소의 유일한 GitHub workflow는 PR의 analyze/test를 실행한다. 머지는 스토어 배포를 실행하지 않는다. workflow가 바뀌면 다시 확인한다.

## 1.0.20 이름과 스크린샷 (T-261011-058)

- 앱 UI는 한국어·영어를 지원한다. 스토어 이름은 ko=메모요, ja·en-US=Memoyo다. 일본어 페이지는 영어 UI에 일본어 예시 메모를 넣은 화면을 사용한다. 설명에 지원 언어와 스크린샷 언어를 명시한다.
- 캡처: macOS에서 `flutter test test/store_capture_test.dart --dart-define=STORE_CAPTURE=true --dart-define=STORE_CAPTURE_LOCALE=en-US`를 실행한다. `ja`로 한 번 더 실행한다. 기본 테스트에서는 캡처를 건너뛴다.
- 산출물: `fastlane/screenshots/<locale>/iPhone 6.9 Display/`의 3장. 1320×2868 크기로 실제 MemoApp의 메모 목록·새 메모·백업을 렌더링한다. 앱 화면을 별도로 재작성하거나 운영 메모를 읽지 않는다. 예시 메모와 광고 제거 구매자 상태를 사용한다.
- 범위: iOS 시뮬레이터 런타임 부재로 Flutter 위젯 렌더러와 로컬 시스템 글꼴을 사용했다. 실기기 캡처·키보드·광고·결제·Google 로그인 검증은 아니다. PNG 인코딩에서 불투명 픽셀을 유지하며 알파 채널만 제거한다. 글자 누락·잘림·언어·화면 내용을 6장 모두 육안 검수한다.
- 업로드: 승인된 build-lease에서 asc-deliver.py의 `--locale <locale> --screenshots`를 실행한다. 이름·설명·스크린샷 개수·해시와 ASC `assetDeliveryState=COMPLETE`를 재조회한다.
- 빌드: 기존 TestFlight 1.0.20(46), source 8302a173c, IPA SHA-256 22403f877238537c53d94f22df4c46f41953b2db3311b13cc4ceb6df6a88638f를 재사용한다. 해당 소스부터 현재 main까지 변경은 스토어 메타데이터뿐이다. pubspec을 이미 업로드된 1.0.20+46으로 맞췄다.
- 제출: 사용자 현재 대화의 진행 승인을 적용한다. 기존 AFTER_APPROVAL 정책을 유지한다. 제출 완료와 Apple 승인·실제 출시는 구분한다. API 재조회·이미지·검사 근거는 `/Users/user/reports/T-261011-058/`에 기록한다.
- 저장소 머지는 ASC 업로드·심사 제출을 자동 실행하지 않는다.
