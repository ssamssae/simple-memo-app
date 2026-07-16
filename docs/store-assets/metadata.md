# 메모요 스토어 메타데이터 SoT

최종 갱신: 2026-07-16

대상 버전: `1.0.13+35`

대상 앱: 메모요 (`com.daejongkang.simpleMemoApp` / `com.daejongkang.simple_memo_app`)

## 기본 정보

- 앱 이름: 메모요
- iOS 부제: AI로 요약하고 말로 찾는 메모장
- 카테고리: 생산성
- 연령 등급: 4+ / 전체 이용가
- 계정 가입: 없음
- 광고: Google Mobile Ads 배너 사용. 유효한 `remove_ads` 구매자와 프리미엄 이용 기간에는 숨김
- 인앱결제: 비소모성 `remove_ads`, 월간 자동 갱신 구독 `premium_monthly`
- 개인정보처리방침: https://github.com/ssamssae/simple-memo-app/blob/main/docs/legal/privacy-policy.md
- 이용약관: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

## Google Play 짧은 설명

```text
빠르게 기록하고 AI로 요약하세요. 자연스러운 말로 관련 메모를 찾는 다크 메모장
```

## Google Play 긴 설명

```text
메모요 - 빠르게 기록하고 AI로 정리하는 다크 메모장

메모요는 생각난 내용을 바로 적고, 자주 보는 메모를 쉽게 정리하는 심플 메모 앱입니다. 제목 없이 본문만 기록할 수 있어 짧은 메모, 아이디어, 할 일, 일기처럼 매일 남기는 기록에 잘 맞습니다.

■ 기본 기능
· 제목 없는 빠른 메모와 기기 내 로컬 저장
· 스와이프 즐겨찾기와 드래그 순서 변경
· 삭제한 메모를 되돌릴 수 있는 휴지통
· 선택형 Google Drive 백업·복원
· 계정 가입 없이 바로 사용

■ 메모요 프리미엄
· AI 요약 - 선택한 메모의 핵심을 간결하게 정리
· 말로 검색 - 자연스러운 문장으로 관련 메모 찾기
· 프리미엄 이용 기간 배너 광고 숨김

메모요 프리미엄은 월간 자동 갱신 구독입니다. 결제 금액은 구매 화면에 표시되며, 해지하지 않으면 매월 자동으로 갱신됩니다. Google Play 구독 설정에서 언제든 관리하거나 해지할 수 있고, 앱에서 구매를 복원할 수 있습니다.

기존 광고 제거 상품을 구매한 사용자의 평생 광고 제거 권리는 그대로 유지됩니다. 검증된 기존 구매에는 최초 1회 프리미엄 30일 감사 쿠폰이 제공됩니다.

AI 기능은 사용자가 직접 실행할 때 선택한 메모 또는 검색어를 서버 중계와 AI 처리업체로 전송합니다. 자세한 내용은 개인정보처리방침에서 확인할 수 있습니다.

문의: minusbetastudio@gmail.com
개인정보처리방침: https://github.com/ssamssae/simple-memo-app/blob/main/docs/legal/privacy-policy.md
```

## iOS 프로모션 텍스트

```text
빠르게 기록하고 AI로 요약하세요. 자연스러운 문장으로 관련 메모를 찾고, 프리미엄 기간에는 배너 광고 없이 집중할 수 있습니다.
```

## iOS 키워드

```text
메모,메모장,노트,다크모드,심플,즐겨찾기,빠른메모,메모정리,일기,할일,AI요약,말로검색
```

## iOS 설명 한국어

`fastlane/metadata/ko/description.txt`를 정본으로 사용한다.

## 무엇이 새로운가

```text
메모요 프리미엄을 추가했습니다.
- AI 요약과 말로 검색을 이용할 수 있습니다.
- 프리미엄 이용 기간에는 배너 광고가 숨겨집니다.
- 기존 광고 제거 구매자의 평생 광고 제거 권리는 그대로 유지됩니다.
- 구독 구매 복원과 안정성을 개선했습니다.
```

## 지원 및 연락처

- 지원 URL: https://ssamssae.github.io/daejong-page
- 마케팅 URL: https://ssamssae.github.io/daejong-page
- 연락처 이메일: minusbetastudio@gmail.com
- 개인정보처리방침: https://github.com/ssamssae/simple-memo-app/blob/main/docs/legal/privacy-policy.md

## App Privacy 선언 - App Store Connect

보수적으로 다음 항목을 선언한다. AI 요청 원문은 앱과 Worker 데이터베이스에 저장하지 않지만, 이용자가 기능을 실행하면 기기 밖으로 전송되어 제3자 AI 처리업체가 처리한다.

| 데이터 유형 | 수집 | 사용자 연결 | 추적 | 목적 |
| --- | --- | --- | --- | --- |
| 사용자 콘텐츠 > 기타 사용자 콘텐츠(메모·검색어) | 예 | 예(앱 임의 식별자와 함께 요청) | 아니요 | 앱 기능 |
| 식별자 > 사용자 ID(앱 임의 UUID) | 예 | 예 | 아니요 | 앱 기능, 부정 이용 방지 |
| 구매 내역 | 예 | 예 | 아니요 | 앱 기능, 권한·쿠폰 검증 |
| 위치 > 대략적 위치(IP 기반, Google Mobile Ads) | 예 | 예 | 예 | 제3자 광고, 분석 |
| 식별자 > 기기 ID(Google Mobile Ads) | 예 | 예 | 예 | 제3자 광고, 분석, 부정 이용 방지 |
| 사용 데이터 > 제품 상호작용·광고 데이터(Google Mobile Ads) | 예 | 예 | 예 | 제3자 광고, 분석 |
| 진단 > 충돌·성능·기타 진단 데이터(Google Mobile Ads) | 예 | 예 | 아니요 | 분석, 앱 기능 |

Google Drive 백업 파일은 이용자가 직접 요청할 때 본인의 Drive에 저장되며 개발자 서버에 저장하지 않는다. 최종 콘솔 응답은 현재 포함된 Google Mobile Ads SDK의 데이터 공개 문서와 실제 앱 동작을 다시 대조한다.

## 데이터 안전 섹션 - Google Play Console

- 데이터 수집: 예
- 데이터 공유: 예(Google Mobile Ads의 광고·분석 처리)
- 전송 중 암호화: 예(HTTPS)
- 계정 생성: 없음
- 삭제 요청 경로: 개인정보처리방침의 이메일 문의

| 데이터 유형 | 처리 | 필수 여부 | 목적 | 비고 |
| --- | --- | --- | --- | --- |
| 기타 사용자 제작 콘텐츠(메모·검색어) | 수집 | 선택 | 앱 기능 | AI 기능 실행 시 일시 처리, 앱·Worker DB에 원문 미보관 |
| 사용자 ID(앱 임의 UUID) | 수집 | 프리미엄 기능 사용 시 필수 | 앱 기능, 부정 이용 방지 | 계정 정보 아님 |
| 구매 내역 | 수집 | 결제 기능 사용 시 필수 | 앱 기능, 부정 이용 방지 | 거래 참조·권한 상태 |
| 대략적 위치(IP 기반) | 수집·공유 | SDK 동작에 따름 | 광고, 분석, 부정 이용 방지 | Google Mobile Ads |
| 기기 또는 기타 ID | 수집·공유 | SDK 동작에 따름 | 광고, 분석, 부정 이용 방지 | Google Mobile Ads |
| 앱 상호작용·광고 데이터 | 수집·공유 | SDK 동작에 따름 | 광고, 분석 | Google Mobile Ads |
| 충돌 로그·진단·성능 | 수집·공유 | SDK 동작에 따름 | 분석, 앱 기능 | Google Mobile Ads |

AI 처리업체와 Cloudflare는 서비스 제공자로 사용한다. Google Play 정의상 서비스 제공자 전송은 데이터 공유에서 제외할 수 있으나, Google Mobile Ads 항목은 SDK 공개 문서에 맞춰 공유로 선언한다.

## 구독 심사 정보

- 상품 ID: `premium_monthly`
- 표시 이름: 메모요 프리미엄
- 설명: AI 요약과 말로 검색, 프리미엄 기간 광고 숨김을 이용하는 월간 구독입니다.
- 결제 주기: 1개월
- 대한민국 기준 가격: ₩1,900
- 구매 위치: 설정 > 메모요 프리미엄
- 복원 위치: 메모요 프리미엄 화면 > 구매 복원
- 해지 안내: App Store 또는 Google Play 계정의 구독 설정
- 검토 메모: 기존 `remove_ads` 비소모성 구매의 평생 광고 제거 권리는 유지되며, 검증된 기존 거래에는 최초 1회 30일 감사 쿠폰을 지급한다.

## 스크린샷 기준

- iOS: 현재 빌드에서 캡처한 App Store Connect 지원 크기
- Android: 1080×1920 세로 스크린샷 3~8장
- 필수 컷: 메모 목록, AI 요약 진입·결과, 말로 검색, 프리미엄 구매·복원 화면
- 구독 심사 스크린샷: 가격·월간 자동 갱신·구매 복원·약관/개인정보 링크가 보이는 프리미엄 화면

## 제출 전 체크리스트

- 버전 `1.0.13+35`, 번들 ID, 패키지명 확인
- 개인정보처리방침 공개 URL 응답 확인
- `premium_monthly` 월 ₩1,900 및 월간 자동 갱신 상태 확인
- 기존 `remove_ads` 판매·권한 불변 확인
- iOS App Privacy와 Play 데이터 안전 응답 실측
- 현행 빌드 스크린샷과 메타데이터 일치 확인
- iOS release type `AFTER_APPROVAL` 확인
