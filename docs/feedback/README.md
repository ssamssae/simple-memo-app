# 메모요 외부 피드백 아카이브

## 2026-04-23 Testers Community Feedback Report

- 파일: `2026-04-23_testers-community-feedback-report.pdf`
- 원격 URL: https://storage.googleapis.com/testing-community-ec6g1l.appspot.com/reports/com.daejongkang.simple_memo_app_feedback.pdf
- 작성: Testers Community Team (유료 베타 모집 플랫폼)
- 다운로드: 2026-04-23 14:37 KST
- SHA256: `5c745fc78cb794102c54b5662466719431274a9d86dd70eb5dfaac34be926e72`
- 페이지: 7
- 사이즈: 262613 bytes

### Findings 요약
- 크래시·버그 없음, 모든 기능 의도대로 동작, 다양한 디바이스/SDK 호환 OK

### Opportunities for Enhancement (6건)
1. **ASO Optimization** — 키워드 강화, Feature Highlights bullet 강조, 타깃 데모그래픽 명시
2. **Improved Play Store Screenshots** — Dark Mode/instant launch/quick edit 강조, 컨텍스트 예시, 텍스트 오버레이
3. **User Walkthrough Introduction** — 첫 실행 onboarding 튜토리얼, Help/FAQ 섹션
4. **Language Settings** — 다국어 선택 메뉴 + 로컬라이제이션 (보고서가 "defaults to English" 오기 — 실제 한국어 디폴트)
5. **Privacy Policy and Terms of Service** — 앱/스토어 접근 가능한 PP/ToS 게재
6. **"Rate Your App" Button** — 설정 화면 별점 버튼 + 사용 후 prompt

### Additional Recommendations
- 정기 업데이트
- 인앱 피드백 채널
- 소셜미디어 링크
- 성능 모니터링
- 비주얼 브랜딩 강화

### 반영 상태 (2026-06-06 갱신)
| 항목 | 상태 | 비고 |
|------|------|------|
| (1) ASO | ✅ 반영 | 최신 SoT = `docs/store-assets/metadata.md`. Play/ASC 복붙용 설명·키워드·정책 URL 통합 |
| (2) Screenshots | ✅ 반영 | Android 정석 재캡처 4컷 업로드 완료. 베타 모집용 3컷은 `docs/beta-recruitment/screenshots/` 에 보존 |
| (3) Walkthrough | 1.1.0+ 이월 | 첫 실행 onboarding + Help/FAQ 로 묶음. 정리 문서: `docs/specs/1.1.0-plus-enhancements.md` |
| (4) Multi-lang | 1.1.0+ 이월 | `flutter_localizations` 미도입. 1.1.1 scaffold → 1.1.2 EN/JA 순서 권장 |
| (5) Privacy/Terms | ✅ 반영 | 인앱 정책 화면 + `docs/legal/privacy-policy.md`, `docs/legal/terms-of-service.md` 추가 |
| (6) Rate 버튼 | ✅ 반영 | 설정 화면 `앱 평가하기` + `in_app_review` 서비스/테스트 추가 |

잔여 장기 항목은 `1.1.0+ 사용자 안내/다국어 트랙`으로 분리한다. 동기화는 데이터 일관성 기능이므로 별도 1.2.x 트랙에서 다룬다.
