# 메모요 — 무료 초성 검색 spec

**Status**: 🟡 draft · 아니키 GO(무료 확정 · A안 확정) / 본진 review 펜딩
**Author**: 🖥 desktop3060ti / 2026-07-23 KST
**Repo**: ssamssae/simple-memo-app · branch `desktop3060ti/T-260723-052-chosung-search-spec`
**Task**: T-260723-052
**Origin**: 아니키 데스크탑 DM 2026-07-23 — "메모요 검색 초성으로 찾게 가능?" → 무료·A안 GO. 기존 [[1.0.8-search.md]] `SearchService` §2.3 주석("한글 자소 분리 X — 'ㄱ' 검색 시 '가' 매치 X, 1.0.9 후보")로 예약돼 있던 항목의 실현.

---

## §0 의도 / 범위

- **목표(1줄)**: 사용자가 검색창에 자음만(예: `ㅁㅁㅇ`) 쳐도 초성이 맞는 메모가 검색되게 한다.
- **티어**: **무료**. 무료 일반검색 `SearchService`(lib/services/search_service.dart)에만 얹는다. 프리미엄(AI 요약·말로검색/semantic)·유료 API·과금 경로 **무접촉**.
- **비범위(YAGNI)**: 자음+완성글자 혼합쿼리(`ㅁ모`), 초성 매치 하이라이트, IME 조합 중간상태 처리, semantic/embedding 경로의 초성화.

## §1 동기

현재 `SearchService` 는 정규화(소문자·트림·공백단일화) 후 **완성글자 substring** 만 매칭한다(`_titleHit`/`_bodyHit`). 한국 사용자는 카톡 연락처·아이폰 스포트라이트처럼 초성 검색을 기본 UX로 기대하고, 메모 N건이 쌓이면 "그 메모 어디"를 초성으로 빠르게 좁힌다. 초성 매칭은 AI가 아니라 순수 자모 비교라 무료 일반검색에 두는 게 자연스럽다(프리미엄 값어치는 semantic "말로검색"이 담당).

## §2 동작 정의 (A안 — 상호배타 트리거)

1. 쿼리 정규화는 기존 `_normalize`(소문자·트림·다중공백 단일화) **그대로** 사용.
2. **트리거**: 정규화된 쿼리의 공백 아닌 모든 문자가 **초성 자모 19자**이고 최소 1자 이상이면 → **초성 모드**. 하나라도 아니면 → **기존 substring 모드**(로직 무변경).
3. **상호배타**: 완성글자가 하나라도 섞이면 초성 모드 아님. 즉 `ㅁ모` 는 리터럴 `ㅁ모` substring 검색이 되어 대개 무매치 — 이것은 문서화된 한계이며 혼합쿼리는 향후(§6).
4. **초성 모드 매칭**: 소스(firstLine·content)를 초성 문자열로 변환한 뒤 `.contains(정규화쿼리)`.
   - `chosungOf`: 완성 한글 음절(U+AC00~U+D7A3) → 초성 자모로, 이미 초성 자모면 그대로, 그 외(영문·숫자·기호) 그대로 둔다.
   - **공백은 경계로 유지** — 단어 사이 초성이 이어붙지 않는다(예: "회의 메모요" 초성 = `ㅎㅇ ㅁㅁㅇ`, 쿼리 `ㅇㅁ`은 공백에 막혀 무매치).
5. **최소 길이 제한 없음** — `ㅁ` 한 글자도 검색된다. 결과가 많아도 **기존 랭킹**(즐겨찾기 > 제목매치 > updatedAt desc)이 그대로 적용돼 제목 초성매치가 위로 뜬다.
6. **하이라이트**: 초성 매치는 노란 강조 **미부착**. `excerpt()` 는 리터럴 `ㅁㅁㅇ` 을 원문에서 못 찾으므로 자연히 `start = -1`(강조 없음)을 반환 → 결과카드가 제목 평문 + 본문 평문 미리보기로 렌더된다. 이는 기존 "본문 미매치 fallback"(search_screen.dart `bodyExc.start >= 0 ? ... : plainPreview`) 재사용이라 **UI 코드 변경 0**.

## §3 매칭 알고리즘 상세 / 초성표

- `CHOSEONG = "ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ"` (index 0~18, Unicode compat jamo)
- 음절 S(0xAC00~0xD7A3): `idx = (S - 0xAC00) ~/ 588` → `CHOSEONG[idx]`
- `isChosungQuery(q)`: q 비어있지 않고, 각 문자 c 가 `c == ' '` 또는 `c ∈ CHOSEONG 집합`. 단 전부 공백이면 false.
- `chosungOf(text)`: 문자별 매핑 결과를 이어붙임(상위 `_normalize` 가 공백을 이미 단일화).
- **컴파운드 자모**(ㄳㄵㄶㄺ… U+3133,3135,3136,313A~3140)는 CHOSEONG 집합 밖 → `isChosungQuery` false. 표준 한글 키보드에서 단독 입력이 불가하므로 실사용 영향 0.

## §4 코드 변경 지점 (국소)

- **신규** `lib/utils/hangul_chosung.dart`: `bool isChosungQuery(String)`, `String chosungOf(String)` — 순수함수, 외부 의존성 0.
- **수정** `lib/services/search_service.dart`:
  - `search()`: `q` 정규화 후 `final chosung = isChosungQuery(q)` 1회 계산.
  - `_titleHit`/`_bodyHit`: chosung 여부를 인자로 받아 분기 — chosung 이면 `chosungOf(source).contains(q)`, 아니면 기존 `_normalize(source).contains(q)`.
  - `excerpt()`: **변경 없음**(초성쿼리는 리터럴 미발견 → 기존 no-highlight 경로).
- **UI** `lib/screens/search_screen.dart`: **변경 없음**.

## §5 테스트 (TDD — 구현 전 작성)

- `test/utils/hangul_chosung_test.dart`:
  - `isChosungQuery`: `ㅁㅁㅇ`→true, `메모`→false, `ㅁ모`→false, `abc`→false, ``→false, `ㅁ ㅇ`→true, `ㄳ`→false.
  - `chosungOf`: `메모요`→`ㅁㅁㅇ`, `회의`→`ㅎㅇ`, `까치`→`ㄲㅊ`, `hello`→`hello`, `메모2`→`ㅁㅁ2`.
- `test/services/search_service_test.dart` 확장:
  - 제목 "메모요 정리" + 쿼리 `ㅁㅁㅇ` → 매치 / 쿼리 `ㅁㅁㅇ` 는 "회의록" 무매치.
  - 상호배타: `메모` substring 매치 유지, `ㅁ모` 무매치.
  - 랭킹: 즐겨찾기·제목매치 우선 초성쿼리에서도 유지.
- **회귀**: 기존 substring/excerpt/랭킹 테스트 전부 green 유지.

## §6 한계 / 향후

- 혼합쿼리(`ㅁ모`), 초성 매치 하이라이트, semantic 경로 초성화 = 후속(별도 결정).
- l10n: 영어 UI 사용자는 초성 자모를 입력하지 않아 초성모드 비발동 → 문자열/현지화 변경 불필요.

## §7 마감 / 리스크

- 산출: 본 spec → `writing-plans` 구현계획 → 구현 PR(**no-auto-merge**, 본진 머지 게이트).
- **R티어 = R0**: 무료 로컬 로직, 과금·대외발신·스토어 제출·계정인증 무접촉. 실제 스토어 릴리스는 별건(submit-app 흐름).
