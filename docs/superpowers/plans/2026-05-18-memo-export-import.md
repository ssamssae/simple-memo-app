# 메모요 — 수동 백업/복원 (자동 동기화 폐기) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 메모요 (simple_memo_app) 에서 자동 동기화 (Firebase Firestore + Auth) 를 전면 폐기하고 수동 export/import + 1단계 undo + 편집 모드 전체 선택을 구현해 1.0.5 출하 후보를 만든다.

**Architecture:** 기존 `MemoStorage` (SharedPreferences `memos` 키) 위에 (1) JSON 직렬화·역직렬화는 이미 있는 `Memo.encodeList/decodeList` 재사용, (2) 신규 `SnapshotStore` (`memos_pre_import` 키) 로 1단계 undo, (3) 신규 `ExportImportService` 가 share_plus / file_picker 와 storage 사이를 연결. UI 는 `memo_list_screen` AppBar 의 비편집 모드 overflow menu 와 편집 모드 actions 만 손댄다.

**Tech Stack:** Flutter 3.10+, SharedPreferences, uuid, share_plus, file_picker, flutter_test.

**Reference spec:** `docs/superpowers/specs/2026-05-18-memo-export-import-design.md`

**노드 분배 (execute 단계):**

- 🍎 본진 `mac/memo-export-import-cleanup-2026-05-18` — Task 1~5 (폐기) → PR1 본인 머지
- 🏭 맥미니 `macmini/memo-export-import-feature-2026-05-18` — Task 6~13 (신규 코드+TDD+빌드) → PR2 본진 머지
- 💻 노트북 `notebook/memo-export-import-tests-2026-05-18` — Task 14~17 (통합 검증+edge case+CHANGELOG) → PR3 본진 머지

순차 의존성: PR1 머지 → 맥미니 fetch → PR2 작성 → PR2 머지 → 노트북 fetch → PR3 작성.

---

## File Structure

### Create
- `lib/services/snapshot_store.dart` — 가져오기 직전 스냅샷 저장/복원/유무 확인 단일 책임
- `lib/services/export_import_service.dart` — JSON export + import (silent merge) + undo 진입점
- `test/services/snapshot_store_test.dart` — 스냅샷 store TDD
- `test/services/export_import_service_test.dart` — export/import silent merge TDD
- `docs/_archived/sync-2026-05/README.md` — 아카이브 사유 한 줄

### Modify
- `pubspec.yaml` — Firebase 3개 제거, share_plus / file_picker 추가, 38행 sync 코멘트 삭제
- `lib/main.dart` — `_bootstrapSync()` 함수 + Firebase import + sync_state import 제거
- `lib/screens/memo_list_screen.dart` — AppBar `actions:` 에 overflow PopupMenuButton (비편집 모드) + "전체 선택" 버튼 (편집 모드) 추가, sync 관련 import / 호출 정리 (해당되는 경우)

### Delete
- `lib/services/auth_service.dart`
- `lib/services/sync_service.dart`
- `lib/services/sync_state.dart`
- `lib/widgets/sync_enable_card.dart`
- `lib/widgets/sync_status_dot.dart`
- `test/sync_enable_card_test.dart`
- `test/sync_state_test.dart`

### Move (archive)
- `docs/sync-design.md` → `docs/_archived/sync-2026-05/sync-design.md`
- `docs/sync-spec.md` → `docs/_archived/sync-2026-05/sync-spec.md`
- `docs/sync-privacy-policy-draft.md` → `docs/_archived/sync-2026-05/sync-privacy-policy-draft.md`
- `docs/sync-test-scenarios.md` → `docs/_archived/sync-2026-05/sync-test-scenarios.md`

---

## 🍎 본진 트랙 (Tasks 1~5) — PR1: 폐기

### Task 1: 베이스라인 + 브랜치 생성

**Files:** N/A (git 상태만)

- [ ] **Step 1: 현재 상태 확인 + main 최신화**

```bash
cd ~/simple_memo_app
git status
git fetch origin
git checkout main
git pull --ff-only origin main
```

Expected: clean working tree, main = origin/main.

- [ ] **Step 2: 작업 브랜치 생성**

```bash
git checkout -b mac/memo-export-import-cleanup-2026-05-18
```

- [ ] **Step 3: 베이스라인 테스트 PASS 확인**

```bash
flutter pub get
flutter analyze
flutter test
```

Expected: analyze clean, 기존 테스트 PASS.

### Task 2: pubspec.yaml 의존성 정리

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Firebase 3개 제거 + share_plus / file_picker 추가**

`pubspec.yaml` 의 33~41행 (현재 의존성 블록) 을 아래로 교체:

```yaml
dependencies:
  flutter:
    sdk: flutter

  uuid: ^4.5.1
  shared_preferences: ^2.3.4
  sensors_plus: ^6.1.1
  share_plus: ^10.1.4
  file_picker: ^8.1.7
```

기존 38~41행 (Firebase 코멘트 + firebase_core / firebase_auth / cloud_firestore 3개) 삭제.

- [ ] **Step 2: pub get 으로 의존성 적용**

```bash
flutter pub get
```

Expected: 의존성 다운로드 + lockfile 갱신. share_plus / file_picker 가 resolved 상태.

- [ ] **Step 3: 커밋**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(memoyo): drop firebase deps, add share_plus + file_picker"
```

### Task 3: 폐기 코드 파일 5개 + 테스트 2개 삭제

**Files:**
- Delete: `lib/services/auth_service.dart`, `lib/services/sync_service.dart`, `lib/services/sync_state.dart`, `lib/widgets/sync_enable_card.dart`, `lib/widgets/sync_status_dot.dart`, `test/sync_enable_card_test.dart`, `test/sync_state_test.dart`

- [ ] **Step 1: 파일 일괄 삭제**

```bash
git rm lib/services/auth_service.dart lib/services/sync_service.dart lib/services/sync_state.dart
git rm lib/widgets/sync_enable_card.dart lib/widgets/sync_status_dot.dart
git rm test/sync_enable_card_test.dart test/sync_state_test.dart
```

- [ ] **Step 2: 잔존 import 검색**

```bash
grep -rn "auth_service\|sync_service\|sync_state\|sync_enable_card\|sync_status_dot\|firebase\|Firebase" lib test
```

Expected: `lib/main.dart` 에만 잔존 (Task 4 에서 처리). 그 외 0건.

- [ ] **Step 3: 커밋**

```bash
git commit -m "chore(memoyo): remove sync code (auth/sync services + widgets + tests)"
```

### Task 4: lib/main.dart 의 Firebase init 제거

**Files:**
- Modify: `lib/main.dart` (1~52행)

- [ ] **Step 1: import 와 _bootstrapSync 호출 + 함수 제거**

`lib/main.dart` 전체를 아래로 교체:

```dart
import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

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

class MemoApp extends StatelessWidget {
  const MemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '메모요',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF1C1C1E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1C1C1E),
          foregroundColor: Colors.amber,
          iconTheme: IconThemeData(color: Colors.amber),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF2C2C2E),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.amber.shade700,
          foregroundColor: const Color(0xFF1A1A2E),
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colors.amber,
          selectionColor: Colors.amber.withValues(alpha: 0.35),
          selectionHandleColor: Colors.amber,
        ),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const SplashScreen(),
    );
  }
}
```

- [ ] **Step 2: analyze 로 잔존 reference 0 확인**

```bash
flutter analyze
```

Expected: 0 issues.

- [ ] **Step 3: 커밋**

```bash
git add lib/main.dart
git commit -m "chore(memoyo): drop Firebase bootstrap from main.dart"
```

### Task 5: sync 문서 4개 archive + iOS Podfile / Android build.gradle 정리 + PR1 푸시

**Files:**
- Create: `docs/_archived/sync-2026-05/README.md`
- Move: `docs/sync-design.md`, `sync-spec.md`, `sync-privacy-policy-draft.md`, `sync-test-scenarios.md` → `docs/_archived/sync-2026-05/`
- Verify: `ios/Podfile`, `android/app/build.gradle` 의 Firebase 잔존 여부

- [ ] **Step 1: archive 디렉토리 생성 + 문서 이동**

```bash
mkdir -p docs/_archived/sync-2026-05
git mv docs/sync-design.md docs/_archived/sync-2026-05/
git mv docs/sync-spec.md docs/_archived/sync-2026-05/
git mv docs/sync-privacy-policy-draft.md docs/_archived/sync-2026-05/
git mv docs/sync-test-scenarios.md docs/_archived/sync-2026-05/
```

- [ ] **Step 2: README 한 줄 추가**

`docs/_archived/sync-2026-05/README.md`:

```markdown
# 자동 동기화 추진 (2026-05 폐기)

2026-05-18 자동 동기화 전면 폐기 결정 (`docs/superpowers/specs/2026-05-18-memo-export-import-design.md`) 후 아카이브. 메모요는 무료앱 + CS 부담 0 우선 정책으로 수동 export/import 방식으로 전환됨.
```

- [ ] **Step 3: iOS Podfile / Android Firebase 잔존 확인**

```bash
grep -nE "firebase|Firebase|google-services|GoogleService-Info" ios/Podfile android/app/build.gradle android/build.gradle android/app/google-services.json 2>/dev/null
ls ios/Runner/GoogleService-Info.plist android/app/google-services.json 2>/dev/null
```

발견된 항목이 있으면 제거 (Firebase 가 추가된 적 없으면 정상이라 0 건). 발견 시 해당 줄/파일 삭제 + 별도 커밋.

- [ ] **Step 4: analyze + test 재확인**

```bash
flutter analyze
flutter test
```

Expected: 0 issues, 기존 테스트 PASS.

- [ ] **Step 5: 커밋 + PR1 생성**

```bash
git add docs/_archived
git commit -m "docs(memoyo): archive sync-* design docs after 2026-05-18 deprecation"
git push -u origin mac/memo-export-import-cleanup-2026-05-18
gh pr create --title "chore(memoyo): drop Firebase sync infra (PR1: cleanup)" --body "$(cat <<'EOF'
## Summary
- Drop firebase_core / firebase_auth / cloud_firestore deps
- Add share_plus + file_picker (for upcoming export/import in PR2)
- Delete lib/services/{auth,sync_service,sync_state}.dart + lib/widgets/sync_*.dart + their tests
- Strip Firebase init from main.dart
- Archive 4 sync design docs to docs/_archived/sync-2026-05/

Spec: docs/superpowers/specs/2026-05-18-memo-export-import-design.md
Plan: docs/superpowers/plans/2026-05-18-memo-export-import.md

## Test plan
- [x] flutter analyze (0 issues)
- [x] flutter test (existing PASS)
- [ ] PR2 (macmini) 가 신규 export/import 코드 박을 베이스로 사용

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 6: 본진 머지 (squash 또는 merge)**

```bash
gh pr merge --merge --auto
```

머지 후 main 동기화:

```bash
git checkout main
git pull --ff-only origin main
```

---

## 🏭 맥미니 트랙 (Tasks 6~13) — PR2: 신규 기능 + 빌드 검증

**전제:** 본진 PR1 머지 완료 후 시작. 시작 전 origin/main 최신화 필수.

### Task 6: 베이스라인 + 브랜치 생성

**Files:** N/A

- [ ] **Step 1: PR1 머지 반영**

```bash
cd ~/simple_memo_app
git fetch origin
git checkout main
git pull --ff-only origin main
```

PR1 의 8 commit 이 main 에 들어와 있어야 함 (`git log --oneline -10`).

- [ ] **Step 2: 작업 브랜치 생성**

```bash
git checkout -b macmini/memo-export-import-feature-2026-05-18
flutter pub get
```

### Task 7: SnapshotStore — 테스트 작성 (TDD red)

**Files:**
- Create: `test/services/snapshot_store_test.dart`

- [ ] **Step 1: 테스트 파일 작성**

`test/services/snapshot_store_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/services/snapshot_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('SnapshotStore', () {
    test('초기엔 hasSnapshot=false, load=null', () async {
      expect(await SnapshotStore.hasSnapshot(), isFalse);
      expect(await SnapshotStore.load(), isNull);
    });

    test('save 후 hasSnapshot=true, load=동일 문자열', () async {
      await SnapshotStore.save('[{"id":"a","content":"hi"}]');
      expect(await SnapshotStore.hasSnapshot(), isTrue);
      expect(await SnapshotStore.load(), '[{"id":"a","content":"hi"}]');
    });

    test('clear 후 hasSnapshot=false', () async {
      await SnapshotStore.save('[{"id":"a"}]');
      await SnapshotStore.clear();
      expect(await SnapshotStore.hasSnapshot(), isFalse);
      expect(await SnapshotStore.load(), isNull);
    });

    test('save 중복 호출 시 마지막 값으로 덮어씀', () async {
      await SnapshotStore.save('first');
      await SnapshotStore.save('second');
      expect(await SnapshotStore.load(), 'second');
    });
  });
}
```

- [ ] **Step 2: 테스트 실행해 RED 확인**

```bash
flutter test test/services/snapshot_store_test.dart
```

Expected: FAIL (SnapshotStore 미존재).

### Task 8: SnapshotStore — 구현 (GREEN)

**Files:**
- Create: `lib/services/snapshot_store.dart`

- [ ] **Step 1: 구현**

`lib/services/snapshot_store.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

class SnapshotStore {
  static const _key = 'memos_pre_import';

  static Future<void> save(String memosJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, memosJson);
  }

  static Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  static Future<bool> hasSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
```

- [ ] **Step 2: 테스트 PASS 확인**

```bash
flutter test test/services/snapshot_store_test.dart
```

Expected: 4 tests PASS.

- [ ] **Step 3: 커밋**

```bash
git add lib/services/snapshot_store.dart test/services/snapshot_store_test.dart
git commit -m "feat(memoyo): add SnapshotStore for 1-step import undo"
```

### Task 9: ExportImportService — 테스트 작성 (TDD red)

**Files:**
- Create: `test/services/export_import_service_test.dart`

- [ ] **Step 1: 테스트 파일 작성**

`test/services/export_import_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/services/export_import_service.dart';
import 'package:simple_memo_app/services/snapshot_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  Memo memo(String id, String content, DateTime updatedAt) => Memo(
        id: id,
        content: content,
        createdAt: updatedAt.subtract(const Duration(minutes: 1)),
        updatedAt: updatedAt,
      );

  group('ExportImportService.mergeSilently', () {
    test('빈 기존 + 가져온 list → 가져온 그대로', () {
      final existing = <Memo>[];
      final incoming = [memo('a', 'hello', DateTime(2026, 1, 1))];
      final merged = ExportImportService.mergeSilently(existing, incoming);
      expect(merged.length, 1);
      expect(merged.first.id, 'a');
    });

    test('기존 + 새 id 가져옴 → 둘 다 보존', () {
      final existing = [memo('a', 'hi', DateTime(2026, 1, 1))];
      final incoming = [memo('b', 'new', DateTime(2026, 1, 2))];
      final merged = ExportImportService.mergeSilently(existing, incoming);
      expect(merged.map((m) => m.id).toSet(), {'a', 'b'});
    });

    test('같은 id 충돌 시 updatedAt 최신 우선', () {
      final existing = [memo('a', 'old', DateTime(2026, 1, 1))];
      final incoming = [memo('a', 'new', DateTime(2026, 1, 5))];
      final merged = ExportImportService.mergeSilently(existing, incoming);
      expect(merged.length, 1);
      expect(merged.first.content, 'new');
    });

    test('같은 id 충돌 시 기존이 더 최신이면 기존 유지', () {
      final existing = [memo('a', 'keep', DateTime(2026, 1, 5))];
      final incoming = [memo('a', 'stale', DateTime(2026, 1, 1))];
      final merged = ExportImportService.mergeSilently(existing, incoming);
      expect(merged.length, 1);
      expect(merged.first.content, 'keep');
    });

    test('silent merge 는 기존 메모를 결코 삭제하지 않음 (gold path)', () {
      final existing = [
        memo('a', 'A', DateTime(2026, 1, 1)),
        memo('b', 'B', DateTime(2026, 1, 1)),
        memo('c', 'C', DateTime(2026, 1, 1)),
      ];
      final incoming = [memo('d', 'D', DateTime(2026, 1, 2))];
      final merged = ExportImportService.mergeSilently(existing, incoming);
      expect(merged.map((m) => m.id).toSet().containsAll({'a', 'b', 'c'}), isTrue);
      expect(merged.length, 4);
    });
  });

  group('ExportImportService.parseImport', () {
    test('잘못된 JSON → null', () {
      expect(ExportImportService.parseImport('not json {{{'), isNull);
    });

    test('빈 list JSON → 빈 list', () {
      final parsed = ExportImportService.parseImport('[]');
      expect(parsed, isNotNull);
      expect(parsed!.isEmpty, isTrue);
    });

    test('정상 JSON → Memo list', () {
      final source = Memo.encodeList([memo('a', 'hi', DateTime(2026, 1, 1))]);
      final parsed = ExportImportService.parseImport(source);
      expect(parsed, isNotNull);
      expect(parsed!.length, 1);
      expect(parsed.first.id, 'a');
    });
  });

  group('ExportImportService.undoImport', () {
    test('스냅샷 없으면 null 반환', () async {
      expect(await ExportImportService.undoImport(), isNull);
    });

    test('스냅샷 있으면 그 list 반환 + 스냅샷 비움', () async {
      final snapshot = Memo.encodeList([memo('x', 'snap', DateTime(2026, 1, 1))]);
      await SnapshotStore.save(snapshot);
      final restored = await ExportImportService.undoImport();
      expect(restored, isNotNull);
      expect(restored!.length, 1);
      expect(restored.first.id, 'x');
      expect(await SnapshotStore.hasSnapshot(), isFalse);
    });
  });
}
```

- [ ] **Step 2: 테스트 실행해 RED 확인**

```bash
flutter test test/services/export_import_service_test.dart
```

Expected: FAIL (ExportImportService 미존재).

### Task 10: ExportImportService — 구현 (GREEN)

**Files:**
- Create: `lib/services/export_import_service.dart`

- [ ] **Step 1: 구현 — 순수 함수 + storage 게이트웨이 분리**

`lib/services/export_import_service.dart`:

```dart
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/memo.dart';
import 'memo_storage.dart';
import 'snapshot_store.dart';

class ExportImportService {
  static List<Memo> mergeSilently(List<Memo> existing, List<Memo> incoming) {
    final byId = {for (final m in existing) m.id: m};
    for (final m in incoming) {
      final prev = byId[m.id];
      if (prev == null || m.updatedAt.isAfter(prev.updatedAt)) {
        byId[m.id] = m;
      }
    }
    return byId.values.toList();
  }

  static List<Memo>? parseImport(String source) {
    try {
      return Memo.decodeList(source);
    } catch (_) {
      return null;
    }
  }

  static Future<File> writeExportFile(List<Memo> memos) async {
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '')
        .substring(0, 15);
    final file = File('${dir.path}/memoyo-export-$ts.json');
    await file.writeAsString(Memo.encodeList(memos));
    return file;
  }

  static Future<void> shareExport(List<Memo> memos) async {
    final file = await writeExportFile(memos);
    await Share.shareXFiles([XFile(file.path)], text: '메모요 백업');
  }

  /// Returns: (importedCount, mergedCount) on success, null on user cancel,
  /// throws FormatException on invalid JSON (caller shows toast).
  static Future<(int, int)?> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null) return null;

    final source = await File(path).readAsString();
    final incoming = parseImport(source);
    if (incoming == null) {
      throw const FormatException('not a memoyo backup');
    }
    if (incoming.isEmpty) {
      return (0, 0);
    }

    final existing = await MemoStorage.loadMemos();
    await SnapshotStore.save(Memo.encodeList(existing));
    final merged = mergeSilently(existing, incoming);
    await MemoStorage.saveMemos(merged);
    return (incoming.length, merged.length);
  }

  static Future<List<Memo>?> undoImport() async {
    final snapshot = await SnapshotStore.load();
    if (snapshot == null) return null;
    final restored = Memo.decodeList(snapshot);
    await MemoStorage.saveMemos(restored);
    await SnapshotStore.clear();
    return restored;
  }
}
```

- [ ] **Step 2: pubspec 에 path_provider 가 transitive 로만 있다면 명시 추가**

```bash
grep "path_provider" pubspec.yaml pubspec.lock | head -5
```

share_plus 의 transitive 이지만 직접 import 하므로 명시:

```yaml
  path_provider: ^2.1.5
```

`pubspec.yaml` 의 file_picker 다음 줄에 추가, `flutter pub get` 실행.

- [ ] **Step 3: 테스트 PASS 확인**

```bash
flutter test test/services/export_import_service_test.dart
```

Expected: 모든 그룹 PASS. (FilePicker / Share / path_provider 를 호출하는 `pickAndImport` / `shareExport` 는 테스트하지 않음 — 순수 함수와 `undoImport` 만 검증.)

- [ ] **Step 4: 커밋**

```bash
git add lib/services/export_import_service.dart test/services/export_import_service_test.dart pubspec.yaml pubspec.lock
git commit -m "feat(memoyo): add ExportImportService (silent merge + 1-step undo)"
```

### Task 11: memo_list_screen — 비편집 모드 overflow PopupMenu 추가

**Files:**
- Modify: `lib/screens/memo_list_screen.dart` (AppBar `actions:` 블록 388~409 행 부근)

- [ ] **Step 1: import 추가 + state 필드 추가**

파일 상단 import 블록에 추가:

```dart
import '../services/export_import_service.dart';
import '../services/snapshot_store.dart';
```

State 클래스에 필드 추가 (현재 `_selectedIds` 근처):

```dart
bool _hasImportSnapshot = false;
```

`initState` 또는 `_loadMemos()` 끝부분에 스냅샷 상태 갱신:

```dart
final hasSnapshot = await SnapshotStore.hasSnapshot();
if (mounted) setState(() => _hasImportSnapshot = hasSnapshot);
```

- [ ] **Step 2: AppBar actions 의 비편집 모드에 PopupMenuButton 추가**

현재 `actions: [if (_isEditMode) Padding(...)]` 블록을 아래로 교체:

```dart
actions: [
  if (_isEditMode)
    Padding(
      padding: const EdgeInsets.only(right: 20),
      child: TextButton(
        onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
        style: TextButton.styleFrom(
          foregroundColor: Colors.orange,
          disabledForegroundColor: Colors.orange.withValues(alpha: 0.3),
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          _selectedIds.isEmpty
              ? '삭제'
              : '삭제 (${_selectedIds.length})',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    ),
  if (!_isEditMode)
    PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.amber),
      onSelected: _onOverflowSelected,
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'export', child: Text('메모 내보내기')),
        const PopupMenuItem(value: 'import', child: Text('메모 가져오기')),
        if (_hasImportSnapshot)
          const PopupMenuItem(value: 'undo', child: Text('가져오기 되돌리기')),
      ],
    ),
],
```

- [ ] **Step 3: `_onOverflowSelected` 핸들러 추가**

State 클래스 (예: `_deleteSelected` 메서드 부근) 에 추가:

```dart
Future<void> _onOverflowSelected(String value) async {
  if (value == 'export') {
    await ExportImportService.shareExport(_memos);
    return;
  }
  if (value == 'import') {
    try {
      final result = await ExportImportService.pickAndImport();
      if (result == null) return;
      final (incoming, total) = result;
      if (incoming == 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('가져올 메모가 없습니다')),
        );
        return;
      }
      await _loadMemos();
      if (!mounted) return;
      setState(() => _hasImportSnapshot = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('메모 $incoming개 가져왔습니다 (전체 $total개)'),
          action: SnackBarAction(
            label: '되돌리기',
            onPressed: () => _handleUndoImport(),
          ),
        ),
      );
    } on FormatException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('올바른 메모요 백업 파일이 아닙니다')),
      );
    }
    return;
  }
  if (value == 'undo') {
    await _handleUndoImport();
  }
}

Future<void> _handleUndoImport() async {
  final restored = await ExportImportService.undoImport();
  if (restored == null) return;
  await _loadMemos();
  if (!mounted) return;
  setState(() => _hasImportSnapshot = false);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('이전 메모 ${restored.length}개로 되돌렸습니다')),
  );
}
```

`_loadMemos()` 는 이미 `memo_list_screen.dart:94` 에 있음. 동일 메서드 재사용.

- [ ] **Step 4: 빌드 + 한 번 실행해 메뉴 진입 확인**

```bash
flutter analyze
flutter run -d <device>  # 또는 빌드만
```

수동 확인: 비편집 모드 AppBar 우측 3-dot 탭 → "메모 내보내기" / "메모 가져오기" 노출. 가져오기 후 "가져오기 되돌리기" 메뉴 활성화.

- [ ] **Step 5: 커밋**

```bash
git add lib/screens/memo_list_screen.dart
git commit -m "feat(memoyo): add overflow menu for export/import/undo"
```

### Task 12: memo_list_screen — 편집 모드 "전체 선택" 버튼

**Files:**
- Modify: `lib/screens/memo_list_screen.dart` (AppBar `actions:` 의 편집 모드 블록)

- [ ] **Step 1: "전체 선택" 메서드 추가**

State 클래스에 추가:

```dart
void _selectAll() {
  setState(() {
    _selectedIds
      ..clear()
      ..addAll(_memos.map((m) => m.id));
  });
}
```

- [ ] **Step 2: AppBar actions 의 편집 모드 분기에 버튼 추가**

`if (_isEditMode)` 블록 안 (삭제 버튼 좌측) 에 추가:

```dart
if (_isEditMode)
  Padding(
    padding: const EdgeInsets.only(right: 12),
    child: TextButton(
      onPressed: _memos.isEmpty
          ? null
          : (_selectedIds.length == _memos.length
              ? () => setState(_selectedIds.clear)
              : _selectAll),
      style: TextButton.styleFrom(
        foregroundColor: Colors.amber.shade300,
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        _selectedIds.length == _memos.length && _memos.isNotEmpty
            ? '선택해제'
            : '전체선택',
        style: const TextStyle(fontSize: 16),
      ),
    ),
  ),
```

(기존 "삭제 (N)" 버튼은 그대로 유지, 이 버튼이 좌측에 추가)

- [ ] **Step 3: analyze + 수동 확인**

```bash
flutter analyze
```

수동: 편집 모드 진입 → "전체선택" 보임 → 탭 → 모두 체크 + 라벨이 "선택해제" 로 바뀜 → 탭 → 모두 해제.

- [ ] **Step 4: 커밋**

```bash
git add lib/screens/memo_list_screen.dart
git commit -m "feat(memoyo): add Select All toggle in edit mode AppBar"
```

### Task 13: iOS + Android 빌드 검증 + PR2 푸시

**Files:** N/A (빌드 산출물)

- [ ] **Step 1: iOS debug 빌드 (no codesign)**

```bash
flutter build ios --debug --no-codesign
```

Expected: 성공. Firebase 관련 link error 0.

- [ ] **Step 2: Android aab debug 빌드**

```bash
flutter build appbundle --debug
```

Expected: 성공. firebase plugin 잔존 경고 0.

- [ ] **Step 3: flutter analyze + test 최종**

```bash
flutter analyze
flutter test
```

Expected: 0 issues, 모든 테스트 PASS.

- [ ] **Step 4: PR2 푸시 + 생성**

```bash
git push -u origin macmini/memo-export-import-feature-2026-05-18
gh pr create --title "feat(memoyo): export/import + 1-step undo + select-all (PR2)" --body "$(cat <<'EOF'
## Summary
- Add SnapshotStore (`memos_pre_import` SharedPreferences key)
- Add ExportImportService (silent merge, parseImport, shareExport, pickAndImport, undoImport)
- Add `path_provider` dep
- memo_list_screen: 비편집모드 overflow PopupMenu (내보내기/가져오기/되돌리기 조건부) + 편집모드 전체선택 토글
- iOS debug build PASS + Android aab debug build PASS

Spec: docs/superpowers/specs/2026-05-18-memo-export-import-design.md
Depends on: #PR1 (cleanup, already merged)

## Test plan
- [x] SnapshotStore unit tests (4 cases)
- [x] ExportImportService.mergeSilently unit tests (5 cases, includes gold path "existing never disappears")
- [x] ExportImportService.parseImport / undoImport tests
- [x] flutter analyze (0 issues)
- [x] flutter build ios --debug --no-codesign
- [x] flutter build appbundle --debug
- [ ] (manual) overflow menu 진입 → export 시 share sheet 노출
- [ ] (manual) import → silent merge + SnackBar undo action

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 5: 본진 머지 결정 대기**

본진이 review 후 `gh pr merge --merge` 로 처리.

---

## 💻 노트북 트랙 (Tasks 14~17) — PR3: 통합 검증 + edge case + CHANGELOG

**전제:** 맥미니 PR2 머지 완료 후 시작. iOS 빌드는 노트북에서 못함 — Android + analyze + test 만.

### Task 14: 베이스라인 + 브랜치 생성

**Files:** N/A

- [ ] **Step 1: PR2 머지 반영**

```bash
cd ~/simple_memo_app
git fetch origin
git checkout main
git pull --ff-only origin main
```

- [ ] **Step 2: 작업 브랜치 생성**

```bash
git checkout -b notebook/memo-export-import-tests-2026-05-18
flutter pub get
```

- [ ] **Step 3: 베이스라인 검증**

```bash
flutter analyze
flutter test
```

Expected: 0 issues, 모든 테스트 PASS.

### Task 15: edge case 테스트 추가

**Files:**
- Modify: `test/services/export_import_service_test.dart` (그룹 추가)

- [ ] **Step 1: edge case 그룹 추가**

`main()` 의 마지막 group 다음에 추가:

```dart
  group('ExportImportService — edge cases', () {
    test('동일 updatedAt 충돌 시 기존 우선 (안전 디폴트)', () {
      final t = DateTime(2026, 1, 1);
      final existing = [memo('a', 'existing', t)];
      final incoming = [memo('a', 'incoming', t)];
      final merged = ExportImportService.mergeSilently(existing, incoming);
      expect(merged.first.content, 'existing');
    });

    test('가져온 list 가 중복 id 를 갖고 있으면 마지막 항목 기준', () {
      final existing = <Memo>[];
      final incoming = [
        memo('a', 'first', DateTime(2026, 1, 1)),
        memo('a', 'second', DateTime(2026, 1, 2)),
      ];
      final merged = ExportImportService.mergeSilently(existing, incoming);
      expect(merged.length, 1);
      expect(merged.first.content, 'second');
    });

    test('parseImport: JSON 이긴 한데 메모 객체가 아닌 형태도 비파괴', () {
      final parsed = ExportImportService.parseImport('"just a string"');
      expect(parsed, isNotNull); // Memo.decodeList 가 List 가 아니면 [] 반환
      expect(parsed!.isEmpty, isTrue);
    });

    test('parseImport: 일부 필드 누락 메모 — Memo.fromJson default 적용', () {
      final parsed = ExportImportService.parseImport(
        '[{"id":"x"}]',
      );
      expect(parsed, isNotNull);
      expect(parsed!.length, 1);
      expect(parsed.first.id, 'x');
      expect(parsed.first.content, '');
    });
  });
```

- [ ] **Step 2: 테스트 PASS 확인**

```bash
flutter test test/services/export_import_service_test.dart
```

Expected: 신규 4 case 포함 모두 PASS.

- [ ] **Step 3: 커밋**

```bash
git add test/services/export_import_service_test.dart
git commit -m "test(memoyo): add edge cases for ExportImportService"
```

### Task 16: 통합 검증 + (옵션) Android APK 빌드

**Files:** N/A

- [ ] **Step 1: 전체 analyze + test**

```bash
flutter analyze
flutter test --coverage
```

Expected: 0 issues, 모든 테스트 PASS. coverage 파일은 commit 안 함.

- [ ] **Step 2: (옵션) Android APK debug 빌드 — WSL flutter 가능 시**

```bash
flutter build apk --debug
```

성공 시: build/app/outputs/flutter-apk/app-debug.apk 생성. 실패 시 (Android SDK 미설정 등) skip 가능.

- [ ] **Step 3: 잔존 Firebase 참조 0 확인 (regression guard)**

```bash
grep -rn "firebase\|Firebase\|cloud_firestore\|auth_service\|sync_service\|sync_state\|sync_enable_card\|sync_status_dot" lib test pubspec.yaml ios/Podfile android/app/build.gradle 2>/dev/null
```

Expected: 0 매치. 매치 있으면 PR3 에서 추가 정리.

### Task 17: CHANGELOG + PR3 푸시

**Files:**
- Create or Modify: `CHANGELOG.md` (없으면 생성)

- [ ] **Step 1: CHANGELOG 작성**

`CHANGELOG.md` 상단에 추가 (파일 없으면 새로 생성):

```markdown
# Changelog

## [1.0.5] - 2026-05-18

### Added
- 메모 백업/복원 — AppBar overflow 메뉴에 "메모 내보내기" / "메모 가져오기" 추가. 시스템 share sheet 를 통해 메일·AirDrop·iCloud Drive·Google Drive 등 자유 선택.
- 가져오기 되돌리기 — 직전 1단계 undo. 가져오기 직후 SnackBar 또는 overflow 메뉴에서 누름.
- 편집 모드 전체 선택 — "전체선택" / "선택해제" 토글 버튼.

### Removed
- 자동 동기화 (Firebase Firestore + Auth) 계획 폐기. 무료앱 + CS 부담 0 정책으로 수동 백업/복원 방식 채택. 상세: docs/superpowers/specs/2026-05-18-memo-export-import-design.md

### Internal
- firebase_core / firebase_auth / cloud_firestore 의존성 제거
- lib/services/{auth,sync_service,sync_state}.dart + lib/widgets/sync_*.dart 폐기
- docs/sync-*.md 4개 문서 docs/_archived/sync-2026-05/ 아카이브
```

- [ ] **Step 2: pubspec 버전 bump (선택)**

`pubspec.yaml` 19행:

```yaml
version: 1.0.5+22
```

(맥미니 PR2 에서 이미 했으면 skip)

- [ ] **Step 3: 커밋 + PR3 푸시**

```bash
git add CHANGELOG.md pubspec.yaml
git commit -m "docs(memoyo): CHANGELOG for 1.0.5 (export/import) + version bump"
git push -u origin notebook/memo-export-import-tests-2026-05-18
gh pr create --title "test+docs(memoyo): edge cases + CHANGELOG (PR3)" --body "$(cat <<'EOF'
## Summary
- 4 추가 edge case 테스트 (동일 updatedAt 충돌, 중복 id incoming, non-list JSON, 일부 필드 누락 메모)
- 잔존 Firebase 참조 0 regression 확인
- CHANGELOG 1.0.5 entry + version bump

Spec: docs/superpowers/specs/2026-05-18-memo-export-import-design.md
Depends on: #PR2 (feature, already merged)

## Test plan
- [x] flutter analyze (0 issues)
- [x] flutter test (모든 case PASS)
- [x] grep 으로 sync/firebase 잔존 reference 0 확인
- [ ] (옵션) Android APK debug 빌드 — WSL flutter 가능 시 첨부

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 4: 본진 머지 결정 대기**

본진이 review 후 `gh pr merge --merge` 로 처리.

---

## 완료 후 후속 (별도 사이클)

- 맥미니에서 1.0.5+22 release 빌드 (`/submit-app` 스킬) + Play Console / App Store 업로드
- 스토어 설명 (privacy policy 페이지) 의 자동 동기화 언급 (있다면) 제거
- `daejong-page` 의 메모요 페이지에 "1.0.5 = 수동 백업/복원, 자동 동기화 계획 폐기" 한 줄 박제
