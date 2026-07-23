# 메모요 무료 초성 검색 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 검색창에 자음만(예 `ㅁㅁㅇ`) 쳐도 초성이 맞는 메모가 검색되게, 무료 `SearchService` 에 초성 모드를 추가한다.

**Architecture:** 순수함수 유틸 `hangul_chosung.dart`(쿼리가 전부 초성 자모인지 판정 `isChosungQuery`, 텍스트→초성 문자열 변환 `chosungOf`)를 새로 만들고, `SearchService.search` 가 쿼리 유형을 1회 판정해 `_titleHit`/`_bodyHit` 를 초성/substring 두 경로로 분기한다. 완성글자 쿼리는 기존 로직 무변경(상호배타). UI·`excerpt()` 무접촉 — 초성 매치는 리터럴 미발견이라 기존 no-highlight fallback 으로 자연 렌더.

**Tech Stack:** Dart / Flutter, `flutter_test`. 로컬 리눅스 Flutter 3.44.6 (`~/.local/flutter-sdks/`, desktop3060ti).

## Global Constraints

- 티어 = **무료**. 수정 대상은 `lib/services/search_service.dart` + 신규 `lib/utils/hangul_chosung.dart` 뿐. 프리미엄·semantic·AI 요약·과금 경로 무접촉 (spec §0).
- 상호배타 트리거: 정규화 쿼리의 공백 아닌 모든 문자가 초성 자모 19자면 초성 모드, 아니면 기존 substring (spec §2).
- 초성 자모 19자 = `ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ` (spec §3).
- 최소 길이 제한 없음, 랭킹(즐겨찾기 > 제목매치 > updatedAt desc) 불변, 초성 매치 하이라이트 미부착 (spec §2).
- TDD: 테스트 먼저. 기존 회귀 테스트 전부 green 유지 (단 옛 "자소 분리 X" contract 테스트는 §Task 2 에서 새 contract 로 교체).
- 산출 브랜치 `desktop3060ti/T-260723-052-chosung-search-spec` (spec 과 동일 브랜치에 이어 커밋). 최종 PR = **no-auto-merge**, 본진 머지 게이트.

---

### Task 1: 초성 유틸 (`hangul_chosung.dart`)

**Files:**
- Create: `lib/utils/hangul_chosung.dart`
- Test: `test/utils/hangul_chosung_test.dart`

**Interfaces:**
- Consumes: 없음 (순수함수, 의존성 0).
- Produces:
  - `bool isChosungQuery(String query)` — 공백 아닌 모든 문자가 초성 자모 19자이고 초성 자모가 ≥1자면 true, 아니면 false. 빈/공백-only → false.
  - `String chosungOf(String text)` — 완성 한글 음절(U+AC00~U+D7A3)은 초성 자모로, 이미 초성 자모/그 외 문자는 그대로 두고 이어붙인 문자열.

- [ ] **Step 1: Write the failing test**

Create `test/utils/hangul_chosung_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/utils/hangul_chosung.dart';

void main() {
  group('isChosungQuery', () {
    test('전부 초성 자모 → true', () {
      expect(isChosungQuery('ㅁㅁㅇ'), isTrue);
    });
    test('완성글자 포함 → false', () {
      expect(isChosungQuery('메모'), isFalse);
    });
    test('자음+완성글자 혼합 → false', () {
      expect(isChosungQuery('ㅁ모'), isFalse);
    });
    test('영문 → false', () {
      expect(isChosungQuery('abc'), isFalse);
    });
    test('빈 문자열 → false', () {
      expect(isChosungQuery(''), isFalse);
    });
    test('공백만 → false', () {
      expect(isChosungQuery('   '), isFalse);
    });
    test('초성 사이 공백 허용 → true', () {
      expect(isChosungQuery('ㅁ ㅇ'), isTrue);
    });
    test('컴파운드 자모(ㄳ) → false', () {
      expect(isChosungQuery('ㄳ'), isFalse);
    });
  });

  group('chosungOf', () {
    test('메모요 → ㅁㅁㅇ', () {
      expect(chosungOf('메모요'), 'ㅁㅁㅇ');
    });
    test('회의 → ㅎㅇ', () {
      expect(chosungOf('회의'), 'ㅎㅇ');
    });
    test('쌍자음 초성: 까치 → ㄲㅊ', () {
      expect(chosungOf('까치'), 'ㄲㅊ');
    });
    test('비한글은 그대로: hello → hello', () {
      expect(chosungOf('hello'), 'hello');
    });
    test('숫자 혼합: 메모2 → ㅁㅁ2', () {
      expect(chosungOf('메모2'), 'ㅁㅁ2');
    });
    test('공백 보존: 회의 메모 → ㅎㅇ ㅁㅁ', () {
      expect(chosungOf('회의 메모'), 'ㅎㅇ ㅁㅁ');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/utils/hangul_chosung_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'simple_memo_app/utils/hangul_chosung.dart'` (파일 없음).

- [ ] **Step 3: Write minimal implementation**

Create `lib/utils/hangul_chosung.dart`:

```dart
// 한글 초성 검색 유틸 (T-260723-052, spec docs/specs/memoyo-chosung-search.md).
// 순수함수·의존성 0. SearchService 무료 초성 모드에서만 사용.

// 초성 자모 19자 (Unicode compatibility jamo). 완성 음절 초성 인덱스와 순서 일치.
const String _choseong = 'ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ';
final Set<String> _choseongSet = _choseong.split('').toSet();

const int _syllableBase = 0xAC00; // '가'
const int _syllableLast = 0xD7A3; // '힣'
const int _choseongBlock = 588; // 중성 21 × 종성 28

/// 쿼리가 '초성 검색'인지 판정.
/// 공백 아닌 모든 문자가 초성 자모 19자이고 초성 자모가 최소 1자 이상이면 true.
/// 완성글자·컴파운드 자모(ㄳ 등)·영문/숫자가 하나라도 섞이면 false.
bool isChosungQuery(String query) {
  var hasJamo = false;
  for (final ch in query.split('')) {
    if (ch == ' ') continue;
    if (!_choseongSet.contains(ch)) return false;
    hasJamo = true;
  }
  return hasJamo;
}

/// 텍스트를 초성 문자열로 변환.
/// 완성 한글 음절 → 초성 자모, 이미 초성 자모/그 외(영문·숫자·기호·공백)는 그대로.
String chosungOf(String text) {
  final buf = StringBuffer();
  for (final ch in text.split('')) {
    final code = ch.codeUnitAt(0);
    if (code >= _syllableBase && code <= _syllableLast) {
      buf.write(_choseong[(code - _syllableBase) ~/ _choseongBlock]);
    } else {
      buf.write(ch);
    }
  }
  return buf.toString();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/utils/hangul_chosung_test.dart`
Expected: PASS (14 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/utils/hangul_chosung.dart test/utils/hangul_chosung_test.dart
git commit -m "feat(search): 한글 초성 변환 유틸 (T-260723-052)"
```

---

### Task 2: SearchService 초성 모드 배선

**Files:**
- Modify: `lib/services/search_service.dart` (import 추가, `search`/`_titleHit`/`_bodyHit` 분기, 상단 주석 갱신)
- Modify: `test/search_service_test.dart` (옛 "자소 분리 X" contract 테스트 교체 + 초성 그룹 추가)

**Interfaces:**
- Consumes: `isChosungQuery(String)`, `chosungOf(String)` (Task 1).
- Produces: `SearchService.search(List<Memo>, String)` 시그니처 **불변** — 동작만 확장.

- [ ] **Step 1: Write the failing tests**

`test/search_service_test.dart` 의 기존 옛 contract 테스트(현재 아래와 같음)를 찾아:

```dart
    test('한글 자소 분리 X (명시적 contract): ㄱ 검색 시 가 매치 X', () {
      final memos = [_memo('가나다')];
      expect(SearchService.search(memos, 'ㄱ'), isEmpty);
    });
```

**아래 초성 그룹으로 교체**한다(옛 테스트 삭제 + 신규 group 추가). `group('SearchService.search — 매칭', ...)` 닫힌 직후(랭킹 group 앞)에 삽입:

```dart
  group('SearchService.search — 초성 검색 (T-260723-052)', () {
    test('전체 자음 쿼리 → 초성 매칭 (ㅁㅁㅇ → 메모요)', () {
      final memos = [_memo('메모요 정리\n본문'), _memo('회의록\n내용')];
      final r = SearchService.search(memos, 'ㅁㅁㅇ');
      expect(r.length, 1);
      expect(r.first.firstLine, '메모요 정리');
    });

    test('초성 부분열도 매칭 (ㅁㅇ ⊂ 메모요=ㅁㅁㅇ)', () {
      final memos = [_memo('메모요')];
      expect(SearchService.search(memos, 'ㅁㅇ').length, 1);
    });

    test('새 contract: ㄱ 검색 시 가나다(ㄱㄴㄷ) 매치', () {
      final memos = [_memo('가나다')];
      expect(SearchService.search(memos, 'ㄱ').length, 1);
    });

    test('초성 불일치 → 무매치', () {
      final memos = [_memo('회의록')];
      expect(SearchService.search(memos, 'ㅁㅁㅇ'), isEmpty);
    });

    test('상호배타: 자음+완성글자 혼합(ㅁ모)은 substring → 무매치', () {
      final memos = [_memo('메모요')];
      expect(SearchService.search(memos, 'ㅁ모'), isEmpty);
    });

    test('공백은 초성 경계: ㅇㅁ 은 "회의 메모요"(ㅎㅇ ㅁㅁㅇ) 공백 넘어 무매치', () {
      final memos = [_memo('회의 메모요')];
      expect(SearchService.search(memos, 'ㅇㅁ'), isEmpty);
    });

    test('초성 쿼리에서도 랭킹 유지: 제목 초성매치 > 본문 초성매치', () {
      final body = _memo('딴제목\n메모요 본문'); // 본문 초성매치
      final title = _memo('메모요 제목\n내용'); // 제목 초성매치
      final r = SearchService.search([body, title], 'ㅁㅁㅇ');
      expect(r, [title, body]);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/search_service_test.dart`
Expected: 새 초성 group 이 FAIL (예: `ㅁㅁㅇ` 가 아직 초성 매칭 안 돼 `r.length` 0 ≠ 1; `ㄱ` 도 substring 이라 `가나다` 무매치). 랭킹·excerpt·기존 매칭 group 은 PASS.

- [ ] **Step 3: Implement the branch in SearchService**

`lib/services/search_service.dart` 를 다음 3곳 수정한다.

(a) import 추가 — 상단 `import '../models/memo.dart';` 아래에:

```dart
import '../utils/hangul_chosung.dart';
```

(b) 상단 클래스 doc 의 옛 자소 주석 2줄을 교체 —

```dart
///   - 한글 자소 분리 X — 'ㄱ' 검색 시 '가' 매치 X (명시적 contract, 1.0.9 후보).
```

를

```dart
///   - 초성 검색(T-260723-052): 쿼리가 전부 초성 자모면 초성 매칭, 아니면 substring
///     (상호배타). spec docs/specs/memoyo-chosung-search.md.
```

로 바꾼다.

(c) `search` + `_titleHit` + `_bodyHit` 를 아래로 교체:

```dart
  /// 활성 메모를 query 로 검색·랭킹해 반환.
  static List<Memo> search(List<Memo> memos, String query) {
    final q = _normalize(query);
    if (q.isEmpty) return memos;

    final chosung = isChosungQuery(q);
    final matched = memos
        .where((m) => _titleHit(m, q, chosung) || _bodyHit(m, q, chosung))
        .toList();

    matched.sort((a, b) {
      // 1) 즐겨찾기 우선
      final favA = a.isFavorite ? 0 : 1;
      final favB = b.isFavorite ? 0 : 1;
      if (favA != favB) return favA - favB;
      // 2) 제목 매치 우선
      final titleA = _titleHit(a, q, chosung) ? 0 : 1;
      final titleB = _titleHit(b, q, chosung) ? 0 : 1;
      if (titleA != titleB) return titleA - titleB;
      // 3) updatedAt 내림차순
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return matched;
  }
```

그리고 기존 `_titleHit`/`_bodyHit` 두 메서드를:

```dart
  static bool _titleHit(Memo m, String normQuery, bool chosung) => chosung
      ? chosungOf(_normalize(m.firstLine)).contains(normQuery)
      : _normalize(m.firstLine).contains(normQuery);

  static bool _bodyHit(Memo m, String normQuery, bool chosung) => chosung
      ? chosungOf(_normalize(m.content)).contains(normQuery)
      : _normalize(m.content).contains(normQuery);
```

로 교체한다. (`excerpt`·`_normalize`·나머지 helper 는 무변경.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/search_service_test.dart`
Expected: PASS (기존 매칭·랭킹·excerpt group + 새 초성 group 전부 green).

- [ ] **Step 5: Commit**

```bash
git add lib/services/search_service.dart test/search_service_test.dart
git commit -m "feat(search): 초성 모드 매칭 배선 + contract 갱신 (T-260723-052)"
```

---

### Task 3: 전체 회귀 검증

**Files:** (없음 — 검증만)

- [ ] **Step 1: 전체 테스트**

Run: `flutter test`
Expected: 전체 스위트 PASS (초성 2개 파일 포함, 기존 회귀 green).

- [ ] **Step 2: 정적 분석**

Run: `flutter analyze`
Expected: `No issues found!` (신규 파일 lint 0).

- [ ] **Step 3: 산출 브랜치 push + PR (본진 게이트)**

```bash
git push -u origin desktop3060ti/T-260723-052-chosung-search-spec
```

PR body 에 **`no-auto-merge`** 문자열 포함(수동 게이트), 머지는 본진 담당. 워커는 PR + mac-report + sot-mark 로 닫는다.

---

## Self-Review

**1. Spec coverage**
- §2 트리거/상호배타 → Task 2 (isChosungQuery 분기 + `ㅁ모` 무매치 테스트). ✓
- §2 최소길이 없음 → Task 2 `ㄱ`/`ㅁㅇ` 단·2자 테스트. ✓
- §2/§6 하이라이트 미부착 → 코드 무변경(excerpt 미접촉)으로 충족, 별도 task 불요. ✓
- §3 초성표/알고리즘 → Task 1 `chosungOf`(588 분할)·`isChosungQuery`(19자 집합). ✓
- §3 컴파운드 자모 배제 → Task 1 `ㄳ` 테스트. ✓
- §4 코드 변경 지점(신규 util·SearchService 2메서드·주석·UI 무변경) → Task 1·2 그대로. ✓
- §5 테스트 목록 → Task 1·2 테스트가 spec §5 케이스 전부 포함. ✓
- §2.4 공백 경계 → Task 2 `ㅇㅁ` 테스트. ✓

**2. Placeholder scan:** TBD/TODO/"적절히 처리" 없음. 모든 step 에 실제 코드/명령/기대출력 명시. ✓

**3. Type consistency:** `isChosungQuery(String)→bool`, `chosungOf(String)→String` 이 Task 1 정의와 Task 2 사용처에서 일치. `_titleHit`/`_bodyHit` 는 3-인자 `(Memo, String, bool)` 로 정의·호출부(2곳: where, sort) 모두 갱신. ✓
