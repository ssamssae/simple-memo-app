# 메모요 — tombstone + 휴지통(1.0.7-4) 통합 스키마 설계 (read-only)

- 작성일: 2026-05-21 (KST)
- 작성자: 💻 노트북3060 (autopilot 낮 사이클)
- 상태: **read-only 설계 노트** — 결정 아님. 1.0.7(4) 휴지통 / 1.1.x 동기화 정식 spec 의 입력자료.
- 입력 문서:
  - `docs/specs/1.0.7-data-safety-ux.md` (🖥 데스크탑, 휴지통 30일 + `deletedAt` 설계 — **이미 있음**)
  - `docs/research/2026-05-21-memoyo-1.1.x-multidevice-sync-research.md` (💻 노트북, 동기화 사전 리서치)
- ⚠️ 코드 변경 0.

---

## 0. 한 줄 결론

**휴지통 spec 이 이미 도입하는 `Memo.deletedAt` 필드가 곧 sync tombstone 이다 — 새 필드/테이블 불필요.** 단, 휴지통 설계를 그대로 두면 동기화에서 **메모 부활(resurrection)** 이 두 군데서 터진다: (1) 30일 자동 purge 가 레코드를 통째 지움, (2) "즉시 영구삭제 / 휴지통 비우기" hard-delete 가 흔적 없이 지움. 둘 다 "다른 기기엔 아직 있음 → union 으로 되살아남"을 유발한다. 해결책은 **"삭제됨" 상태를 두 단계로 분리** — `deletedAt`(휴지통, 30일, content 보존, 사용자 복구 가능) → `purgedAt`(tombstone, 더 긴 TTL, content 비움, sync 전용) — 이고, 이를 **한 모델 안 두 필드**로 통합한다. LWW 비교축은 `updatedAt` 단일.

---

## 1. 출발점 — 휴지통 spec 이 이미 만든 것

`docs/specs/1.0.7-data-safety-ux.md` §2.2 가 도입:

```dart
class Memo {
  // ... 기존 ...
  DateTime? deletedAt; // null = 일반 메모, 값 있음 = 휴지통
}
bool get isInTrash => deletedAt != null;
```

- 삭제 = 리스트에서 `removeWhere` 가 아니라 `copyWith(deletedAt: now)` 마킹 → soft-delete.
- 30일 후 `purgeExpiredTrash()` 가 `deletedAt < now-30d` 레코드를 **리스트에서 완전 제거**.
- "즉시 영구삭제" / "휴지통 비우기" = 즉시 완전 제거.

→ soft-delete 자체는 sync tombstone 의 80%를 공짜로 깔아준다. **문제는 "완전 제거"가 일어나는 두 지점.**

---

## 2. 부활(resurrection) 함정 — 휴지통 설계만으로는 sync 깨짐

동기화의 기본 병합 = 같은 `id` 는 LWW, 다른 `id` 는 union(합집합). 합집합이 부활을 만든다:

### 2.1 30일 auto-purge 부활

```
T0  : A기기·B기기 모두 메모 X 보유 (동기화됨)
T1  : A에서 X 삭제 → 휴지통 (deletedAt=T1)
...  : B기기 31일+ 오프라인 (여행/예비폰)
T1+31d: A에서 purgeExpiredTrash → X 레코드 A에서 완전 소멸
T1+40d: B 온라인 → 동기화. A엔 X 없음, B엔 X 있음 → union "B에만 있네, 추가하자" → X 부활 💥
```

### 2.2 hard-delete 부활

```
T0 : A·B 모두 X 보유
T1 : A에서 X 휴지통 → "즉시 영구삭제" → A에서 X 완전 소멸 (흔적 0)
T2 : 동기화 → B엔 X 있음 → union 으로 X 부활 💥
```

두 경우 모두 **"삭제했다"는 사실의 흔적이 사라져서** 동기화가 "한쪽에만 있는 새 메모"로 오인한다. tombstone = 이 흔적을 남기는 것.

---

## 3. 통합 스키마 — `deletedAt` + `purgedAt` 2상태, 한 모델

휴지통 = "복구 가능한 삭제", tombstone = "복구 불가하지만 부활 방지용 흔적". 두 단계로 분리하되 **한 레코드 안 두 필드**로 표현 (별 테이블/별 저장소 X — 메모요는 단일 SharedPreferences blob).

```dart
class Memo {
  final String id;
  String content;            // purged 단계에서는 "" 로 비움
  bool isFavorite;
  final DateTime createdAt;
  DateTime updatedAt;        // ★ 단일 LWW 비교축 — 모든 변이가 bump
  DateTime? deletedAt;       // 휴지통 진입 시각 (휴지통 spec 그대로)
  DateTime? purgedAt;        // ★ 신규: tombstone 확정 시각 (content 비워진 시점)
}
```

레코드의 3가지 생애 상태:

| 상태 | 조건 | content | 사용자 가시성 | sync 취급 |
|------|------|---------|----------------|-----------|
| **active** | `deletedAt == null` | 있음 | 일반 리스트 | 정상 메모 |
| **trashed** | `deletedAt != null && purgedAt == null` | **보존** | 휴지통 화면 (X일 후 영구삭제) | 메모 + 휴지통 상태 동기화 |
| **tombstone** | `purgedAt != null` | **""** (비움) | 안 보임 | "삭제됨" 흔적, 부활 차단 |

- 30일 휴지통 만료 또는 hard-delete → **레코드 제거 대신** `purgedAt=now` + `content=""` 마킹.
- tombstone 은 일정 TTL(§5) 후에야 레코드에서 완전 제거.

> 핵심: 휴지통 spec 의 `purgeExpiredTrash()` 가 하던 "리스트에서 제거"를 "tombstone 으로 강등"으로 바꾸는 1줄 변경이 통합의 전부.

---

## 4. LWW 와 "편집이 삭제를 이긴다" 정합성

동기화 사전 리서치 §6 의 두 규칙을 한 축으로 묶는다.

### 4.1 단일 비교축: `updatedAt` 을 모든 변이가 bump

휴지통 spec 의 `deletedAt` 는 **별도 시각 필드**라 그대로 두면 LWW 비교축이 둘(`updatedAt` / `deletedAt`)이 되어 충돌 판정이 모호해진다. → **모든 상태 전이가 `updatedAt` 를 bump** 하게 통일:

| 동작 | 필드 변화 |
|------|-----------|
| 내용 편집 | `updatedAt=now` |
| 즐겨찾기 토글 | `updatedAt=now` |
| 휴지통 이동 | `deletedAt=now`, **`updatedAt=now`** |
| 휴지통 복구 | `deletedAt=null`, **`updatedAt=now`** |
| purge(만료/hard) | `purgedAt=now`, `content=""`, **`updatedAt=now`** |

→ 병합은 **같은 id 끼리 `updatedAt` 큰 쪽 통째 채택**. 단순 LWW, 비교축 1개.

### 4.2 "편집이 삭제를 이긴다" = tie-break / 안전규칙으로 격하

순수 LWW 면 "나중 동작이 이긴다" — 늦은 삭제가 이른 편집을 이긴다. 이는 "사용자가 마지막에 삭제를 의도"한 흔한 케이스엔 맞다. 진짜 위험은 **두 기기가 서로 못 본 채(concurrent) 한쪽은 편집, 한쪽은 삭제**한 경우인데, 이를 정확히 구분하려면 vector clock 이 필요하고 **메모요엔 과함**(단일 사용자 다기기, 동시 충돌 빈도 극저).

타협안:
- **기본**: `updatedAt` 순수 LWW (마지막 동작 승).
- **tie-break / 안전망**: `updatedAt` 차이가 시계오차 허용범위(예: ±2초) 이내로 사실상 동시이면, **content 보유 상태(active/trashed) 가 tombstone 을 이긴다** = "삭제보다 보존 우선". → "메모 안 사라짐" 박제(1.0.7 §2) 를 동률 상황에서 보장.
- 잔여 한계(수용): 시계 정상 + 명백히 늦은 삭제가 이른 편집을 덮는 경우는 LWW 대로 삭제 승. 데이터 보존을 절대화하려면 "삭제는 항상 짐 + 충돌 시 분기 메모 생성"까지 가야 하나, 단일 사용자엔 과해 채택 X. 정식 spec 에서 형님 정책 확정.

---

## 5. 30일 휴지통 vs tombstone 보존기간

두 기간은 **목적이 달라 분리**해야 한다.

| 기간 | 상수(안) | 목적 | content |
|------|----------|------|---------|
| 휴지통 보존 | 30일 (`Duration(days:30)`, 휴지통 spec 그대로) | 사용자 실수 복구 윈도우 | 보존 |
| tombstone 보존(TTL) | **≥ 최대 현실 오프라인 기간** (제안: 90일) | 부활 차단 | 비움("") |

- 휴지통(30일) 만료 → tombstone 으로 강등(content 비움), **삭제 흔적은 추가로 TTL 만큼 더 유지**.
- tombstone TTL 경과 → 레코드 완전 제거.
- **잔여 부활 위험**: 기기가 tombstone TTL(90일) 보다 오래 오프라인 → 부활 가능. TTL 을 늘리면 위험 감소하지만 빈 레코드가 더 오래 쌓임(메모요는 양 작아 부담 0에 가까움). 90일이면 "한 학기 예비폰 방치" 정도까지 커버. **정식 spec 에서 TTL 확정 + release note 1줄("아주 오래 미사용 기기에서 삭제한 메모가 드물게 다시 나타날 수 있음").**

### purge 로직 변경(설계, 코드 X)

휴지통 spec §2.4 `purgeExpiredTrash()` 를 2단계로:

```text
sweep(now):
  for m in all:
    if m.purgedAt == null and m.deletedAt != null
                          and m.deletedAt < now - 30d:
        # 휴지통 만료 → tombstone 강등 (제거 아님)
        m.purgedAt = now; m.content = ""; m.updatedAt = now
    elif m.purgedAt != null and m.purgedAt < now - TTL:
        # tombstone TTL 만료 → 레코드 완전 제거
        drop m
  save survivors
```

호출 위치는 휴지통 spec 그대로(cold start + app resume).

---

## 6. 오프라인 / 병합 흐름 (사전 리서치 §7 과 정합)

- 로컬(SharedPreferences) = SoT. 오프라인 100% 동작 불변.
- 병합은 `merge(localList, remoteList) -> mergedList` **순수 함수**:
  1. id 로 양쪽 인덱싱.
  2. 양쪽에 있는 id: `updatedAt` LWW(+ §4.2 tie-break).
  3. 한쪽에만 있는 id: **tombstone 이면 그 상태 채택(부활 차단), 아니면 채택(신규/미동기)**. ← 부활 함정의 실제 차단 지점.
  4. 결과를 로컬에 쓰고 원격에 push.
- tombstone 덕에 "한쪽에만 있음 = 무조건 추가"가 아니라 "한쪽에만 있는데 그게 tombstone? → 다른 쪽도 지워야 할 흔적"으로 해석됨.

---

## 7. 마이그레이션 / 하위호환

- 휴지통 spec §2.8 그대로 + `purgedAt` 추가. `fromJson` 누락 필드 기본값 패턴(현재 코드)이라 구버전 데이터 무손실.
- `toJson` 은 `if (purgedAt != null)` 조건부 키 — active/trashed 메모엔 키 없음(용량 0 증가).
- tombstone(content="") 은 1.0.6 다운그레이드 시 빈 메모로 보일 수 있음 → 휴지통 spec 의 다운그레이드 한계 note 에 1줄 추가.
- backup/restore JSON: tombstone 포함 여부 = **포함 권장**(다른 기기 복구 시에도 부활 차단 일관). 단 사용자가 "백업엔 빈 흔적 빼고 싶다"면 export 시 tombstone 제외 옵션은 별도 — 기본은 포함.

---

## 8. 통합으로 절약되는 것 (왜 한 번에 설계하나)

- 휴지통(1.0.7-4) 을 sync 무관하게 먼저 만들고 나중에 tombstone 을 별 필드로 또 도입하면 **삭제 경로를 두 번 건드림**(중복 작업 + 회귀 위험).
- `deletedAt` 한 필드에 `purgedAt` 만 얹으면 휴지통과 tombstone 이 같은 soft-delete 파이프라인을 공유 — 삭제 UI/UNDO/purge 코드가 1세트.
- 휴지통은 sync 없이도 단독 출시 가능(1.0.7-4). `purgedAt` 강등 로직만 미리 박아두면 1.1.x 동기화는 `merge()` 순수함수 + pull/push 만 얹으면 됨.

---

## 9. 정식 spec 진입 전 형님 결정사항 (열린 질문)

1. tombstone TTL 상수 — 90일? 더 길게/짧게? (오프라인 부활 위험 vs 빈 레코드 누적)
2. §4.2 충돌 정책 — 순수 LWW + "동률 시 보존 우선" 으로 확정? 아니면 "삭제는 항상 짐" 강한 보존?
3. 휴지통(1.0.7-4) 을 sync 없이 먼저 출시하되 `purgedAt`/단일 `updatedAt` bump 를 **선반영**할지(권장), 아니면 휴지통은 `deletedAt` 만으로 내고 sync 때 다시 손댈지.
4. backup JSON 에 tombstone 포함(권장) vs 제외.
5. hard-delete("즉시 영구삭제")도 tombstone 강등으로 바꾸면 사용자 기대("지금 완전히 지웠다")와 어긋남 — UI 문구 조정 필요? (실제론 흔적만 남고 content 는 즉시 비워짐)

---

## 부록 — 변경 요약(설계, 코드 X)

휴지통 spec(`1.0.7-data-safety-ux.md`) 대비 델타:
- `Memo` 에 `purgedAt` 1필드 추가 + 모든 변이가 `updatedAt` bump (휴지통 이동/복구 포함).
- `purgeExpiredTrash()` → 2단계 sweep(만료 시 제거 대신 tombstone 강등 → TTL 후 제거).
- (1.1.x) `merge(local, remote)` 순수함수 신규 — tombstone 인지 union.
- 나머지(휴지통 UI / UNDO / 30일 / 마이그레이션)는 휴지통 spec 그대로.
