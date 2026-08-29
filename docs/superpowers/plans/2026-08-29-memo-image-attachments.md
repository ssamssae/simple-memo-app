# 메모 이미지 첨부 (1단계) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 메모요 메모에 사진(사진첩·카메라·클립보드) 최대 10장을 붙여 기기 안에 저장하고, 편집·목록·뷰어·공유에서 보이게 한다. 백업은 글만(안내 문구).

**Architecture:** 사진 파일은 `<앱문서>/attachments/<uuid>.jpg` 평면 디렉토리에 두고 `Memo.imageFiles`(파일명 목록)만 JSON 에 싣는다. 가져오기 파이프라인(`ImageSourcePort` → `ImageCompressor` → `AttachmentStore`)은 전부 생성자 주입이라 CI(Linux, 기기 없음)에서 fake 로 테스트한다. 편집 화면은 「대기 추가/대기 삭제」 목록으로 저장·취소 시점에만 파일 상태를 확정한다. 영구삭제 경로(`MemoStorage.deleteForever`·`emptyTrash`·`purgeExpiredTrash`)가 파일도 지우고, cold start 1회 고아 파일을 청소한다.

**Tech Stack:** Flutter 3.41.9(볼칸)/3.44.0(CI), Dart SDK ^3.10.7, `image_picker ^1.2.3`, `pasteboard ^0.5.0`, `flutter_image_compress ^2.5.1`, 기존 `path_provider`·`share_plus`·`uuid`·`shared_preferences`, 테스트 = `flutter_test` + 임시 디렉토리.

**Spec:** `docs/superpowers/specs/2026-08-29-memo-image-attachments-design.md` (T-260829-022). 스펙 §3.2 의 `lib/features/attachments/` 는 repo 관례(`lib/features/memos/README.md` — 메모 흐름에 보이는 기능은 memos 도메인)에 맞춰 **`lib/features/memos/`** 로 둔다.

**Repo root:** `/Users/user/wt/T-260829-022-memoyo` (브랜치 `macmini/T-260829-022-image-attachments`). 아래 명령은 전부 이 디렉토리에서 실행. 커밋 형식 `type(memoyo): 한글 설명 (T-260829-022)`, 커밋 시 `git -c user.email=gayoremix@gmail.com -c user.name=vulcan commit …`.

**두 가드 테스트 (모든 태스크가 통과해야 한다):**
- `test/l10n/no_hardcoded_korean_test.dart` — `lib/` 코드(주석 제외)에 한글 리터럴 금지 → UI 문구는 전부 `AppStrings`.
- `test/l10n/english_locale_smoke_test.dart` — en 로케일에서 `MemoListScreen`·`MemoEditScreen`·`TrashScreen` 에 한글 `Text` 0.

---

## File Structure

| 파일 | 책임 |
|---|---|
| Modify `lib/models/memo.dart` | `imageFiles` 필드, JSON `images` 키, 파일명 검증 |
| Modify `pubspec.yaml`, `ios/Runner/Info.plist` | 의존성 3개, 사진첩·카메라 문구 |
| Create `lib/features/memos/services/attachment_store.dart` | 파일 디렉토리·저장·삭제·고아 정리, 프로세스 단일 인스턴스 |
| Create `lib/features/memos/services/image_ingest.dart` | `fitLongEdge` 순수 계산 + `ImageCompressor` 추상화 + `flutter_image_compress` 구현 |
| Create `lib/features/memos/services/attachment_service.dart` | 가져오기 3경로 + 결과 타입 + `ImageSourcePort` 추상화/플러그인 구현 |
| Modify `lib/l10n/app_strings.dart` | 신규 문구 12개 |
| Create `lib/features/memos/widgets/attachment_thumbnail.dart` | 썸네일 + 플레이스홀더 (목록 36px / 스트립 72px 공용) |
| Create `lib/features/memos/widgets/attachment_strip.dart` | 편집 화면 하단 가로 스크롤 |
| Create `lib/features/memos/widgets/attachment_viewer.dart` | 전체화면 PageView + InteractiveViewer + 삭제 |
| Modify `lib/screens/memo_edit_screen.dart` | 버튼·시트·스트립·수명·공유 배선 |
| Modify `lib/services/memo_storage.dart` | `deleteForever`·`emptyTrash` 신설, `purgeExpiredTrash` 파일 삭제 |
| Modify `lib/screens/trash_screen.dart` | 영구삭제 2경로를 `MemoStorage` 펀넬로, 썸네일 |
| Modify `lib/screens/memo_list_screen.dart` | 썸네일, cold start 고아 정리 |
| Modify `lib/screens/search_screen.dart` | 썸네일 |
| Modify `lib/main.dart` | `AttachmentStore.init()` |
| Modify `lib/screens/backup_restore_screen.dart` | 「사진은 백업에 포함되지 않습니다」 |
| Create `test/features/memos/support/attachment_test_support.dart` | 임시 스토어·1px PNG·fake 포트/압축기 |
| Tests | `test/models/memo_images_test.dart`, `test/features/memos/attachment_store_test.dart`, `test/features/memos/image_ingest_test.dart`, `test/features/memos/attachment_service_test.dart`, `test/features/memos/attachment_widgets_test.dart`, `test/features/memos/attachment_viewer_test.dart`, `test/screens/memo_edit_image_test.dart`, `test/services/memo_storage_images_test.dart`, `test/screens/memo_list_thumbnail_test.dart`, `test/screens/backup_restore_photos_notice_test.dart` |
| Docs | `lib/features/memos/README.md`(의존 노트), `README.md`, `CHANGELOG.md`, spec §3.2 경로 정정 |

---

### Task 1: `Memo.imageFiles` 모델 필드

**Files:**
- Modify: `lib/models/memo.dart`
- Test: `test/models/memo_images_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/models/memo_images_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/models/memo.dart';

void main() {
  final t = DateTime(2026, 8, 29, 12);

  Map<String, dynamic> baseJson() => {
        'id': 'a',
        'content': '본문',
        'isFavorite': false,
        'createdAt': '2026-08-29T12:00:00.000',
        'updatedAt': '2026-08-29T12:00:00.000',
      };

  group('Memo.imageFiles — JSON 호환', () {
    test('images 키 없는 1.0.18 이하 JSON → 빈 목록 (손실 0)', () {
      final memo = Memo.fromJson(baseJson());
      expect(memo.imageFiles, isEmpty);
      expect(memo.hasImages, isFalse);
    });

    test('images 있는 JSON → 순서 보존 파싱', () {
      final memo = Memo.fromJson({...baseJson(), 'images': ['b.jpg', 'a.jpg']});
      expect(memo.imageFiles, ['b.jpg', 'a.jpg']);
      expect(memo.hasImages, isTrue);
    });

    test('images 가 List 가 아니거나 원소가 문자열이 아니면 관대하게 걸러낸다', () {
      expect(Memo.fromJson({...baseJson(), 'images': 'x.jpg'}).imageFiles, isEmpty);
      expect(Memo.fromJson({...baseJson(), 'images': null}).imageFiles, isEmpty);
      expect(
        Memo.fromJson({...baseJson(), 'images': ['ok.jpg', 3, null, true]}).imageFiles,
        ['ok.jpg'],
      );
    });

    test('경로 조작 가능한 파일명은 파싱 단계에서 버린다', () {
      final memo = Memo.fromJson({
        ...baseJson(),
        'images': ['../etc.jpg', 'a/b.jpg', 'c\\d.jpg', '', 'fine-1.jpg'],
      });
      expect(memo.imageFiles, ['fine-1.jpg']);
    });

    test('toJson: 비어 있으면 images 키 생략, 있으면 그대로', () {
      final none = Memo(id: 'a', content: 'x', createdAt: t, updatedAt: t);
      expect(none.toJson().containsKey('images'), isFalse);

      final some = Memo(id: 'a', content: 'x', createdAt: t, updatedAt: t, imageFiles: ['p.jpg']);
      expect(some.toJson()['images'], ['p.jpg']);
    });

    test('encodeList/decodeList 라운드트립', () {
      final memo = Memo(id: 'a', content: 'x', createdAt: t, updatedAt: t, imageFiles: ['p.jpg', 'q.jpg']);
      final back = Memo.decodeList(Memo.encodeList([memo])).single;
      expect(back.imageFiles, ['p.jpg', 'q.jpg']);
    });
  });

  group('Memo.imageFiles — copyWith / create / 불변', () {
    test('copyWith(imageFiles: null) 은 기존 유지, 값 주면 교체', () {
      final memo = Memo(id: 'a', content: 'x', createdAt: t, updatedAt: t, imageFiles: ['p.jpg']);
      expect(memo.copyWith(content: 'y').imageFiles, ['p.jpg']);
      expect(memo.copyWith(imageFiles: const []).imageFiles, isEmpty);
      expect(memo.copyWith(imageFiles: ['z.jpg']).imageFiles, ['z.jpg']);
    });

    test('Memo.create 기본 빈 목록, 인자로 넣으면 실림', () {
      expect(Memo.create(content: 'x').imageFiles, isEmpty);
      expect(Memo.create(content: 'x', imageFiles: ['p.jpg']).imageFiles, ['p.jpg']);
    });

    test('imageFiles 는 수정 불가 목록', () {
      final memo = Memo(id: 'a', content: 'x', createdAt: t, updatedAt: t, imageFiles: ['p.jpg']);
      expect(() => memo.imageFiles.add('q.jpg'), throwsUnsupportedError);
    });

    test('isValidImageFileName', () {
      expect(Memo.isValidImageFileName('3f2a-1.jpg'), isTrue);
      expect(Memo.isValidImageFileName('.hidden'), isFalse);
      expect(Memo.isValidImageFileName('a..b.jpg'), isFalse);
      expect(Memo.isValidImageFileName('a/b.jpg'), isFalse);
      expect(Memo.isValidImageFileName(''), isFalse);
    });
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/models/memo_images_test.dart`
Expected: 컴파일 실패 — `imageFiles`, `hasImages`, `isValidImageFileName` 미정의.

- [ ] **Step 3: 모델 구현**

`lib/models/memo.dart` 를 다음과 같이 고친다 (필드·생성자·getter·copyWith·create·toJson·fromJson·파서).

필드 블록 (기존 `final String? semanticEmbeddingSource;` 바로 아래에 추가):

```dart
  // 첨부 사진 파일명 목록 (경로 없음, <앱문서>/attachments/ 아래). 순서 = 표시 순서.
  // 1.0.18 이하 JSON 엔 키가 없고 → 빈 목록. 상한(10장)은 모델이 아니라
  // AttachmentService 가 강제한다 — 백업 복원 등 외부 유입 값은 자르지 않는다.
  final List<String> imageFiles;
```

생성자 (기존 `Memo({...})` 를 통째로 교체):

```dart
  Memo({
    required this.id,
    required this.content,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    List<double>? semanticEmbedding,
    this.semanticEmbeddingModel,
    this.semanticEmbeddingSource,
    List<String>? imageFiles,
  }) : semanticEmbedding = semanticEmbedding == null
           ? null
           : List<double>.unmodifiable(semanticEmbedding),
       imageFiles = List<String>.unmodifiable(imageFiles ?? const <String>[]);
```

getter (기존 `bool get isInTrash` 바로 아래에 추가):

```dart
  bool get hasImages => imageFiles.isNotEmpty;

  // 파일명 = uuid.jpg 형태만. 경로 구분자·`..`·선행 점을 막아 JSON(백업 복원 포함)에서
  // 들어온 값이 attachments/ 밖을 가리킬 수 없게 한다.
  static final _imageFileNamePattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$');
  static bool isValidImageFileName(String name) =>
      !name.contains('..') && _imageFileNamePattern.hasMatch(name);
```

`copyWith` 시그니처에 파라미터 추가 + 본문에 전달 (기존 `Object? semanticEmbeddingSource = _undefinedSemanticEmbeddingSource,` 뒤):

```dart
    List<String>? imageFiles,
```

그리고 `return Memo(` 블록 마지막 인자로:

```dart
      imageFiles: imageFiles ?? this.imageFiles,
```

`Memo.create` 교체:

```dart
  factory Memo.create({required String content, List<String>? imageFiles}) {
    final now = DateTime.now();
    return Memo(
      id: _uuid.v4(),
      content: content,
      createdAt: now,
      updatedAt: now,
      imageFiles: imageFiles,
    );
  }
```

`toJson` — 기존 `if (semanticEmbeddingSource != null) ...` 줄 뒤에:

```dart
    // 사진 없는 메모는 키 자체를 안 박음 — 1.0.18 이하 JSON 과 동일(백워드 호환).
    if (imageFiles.isNotEmpty) 'images': imageFiles,
```

`fromJson` — `semanticEmbeddingSource: json['semanticEmbeddingSource'] as String?,` 뒤에:

```dart
      imageFiles: _parseImageFiles(json['images']),
```

파서 (`_parseEmbedding` 아래에 추가):

```dart
  static List<String> _parseImageFiles(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final value in raw)
        if (value is String && isValidImageFileName(value)) value,
    ];
  }
```

- [ ] **Step 4: 통과 확인 + 기존 모델 테스트 회귀 없음**

Run: `flutter test test/models/`
Expected: 전부 PASS (신규 10개 포함).

- [ ] **Step 5: 커밋**

```bash
git add lib/models/memo.dart test/models/memo_images_test.dart
git -c user.email=gayoremix@gmail.com -c user.name=vulcan commit -m "feat(memoyo): Memo.imageFiles 필드 + images JSON 키 (T-260829-022)"
```

---

### Task 2: 의존성 3개 + iOS 권한 문구

**Files:**
- Modify: `pubspec.yaml:36-41`
- Modify: `ios/Runner/Info.plist:30-32`

- [ ] **Step 1: pubspec 의존성 추가**

`pubspec.yaml` 의 `  path_provider: ^2.1.5` (41행) 바로 아래에:

```yaml

  # 메모 이미지 첨부 (T-260829-022): 사진첩·카메라 / 클립보드 이미지 / 축소 저장
  image_picker: ^1.2.3
  pasteboard: ^0.5.0
  flutter_image_compress: ^2.5.1
```

- [ ] **Step 2: 해석 확인**

Run: `flutter pub get`
Expected: `Got dependencies!` (또는 `Changed N dependencies!`). 실패 시 버전 충돌 메시지를 그대로 보고하고 멈춘다 — 버전 임의 하향 금지.

- [ ] **Step 3: Info.plist 문구**

`ios/Runner/Info.plist` 30-32행을 다음으로 교체:

```xml
	<!-- Photo Library: 메모 이미지 첨부(T-260829-022) + file_picker transitive 의존. -->
	<key>NSPhotoLibraryUsageDescription</key>
	<string>메모에 사진을 첨부하기 위해 사진 보관함 접근이 필요합니다.</string>
	<!-- Camera: 메모 이미지 첨부 — 촬영해서 바로 붙이기 (T-260829-022). -->
	<key>NSCameraUsageDescription</key>
	<string>메모에 붙일 사진을 촬영하기 위해 카메라 접근이 필요합니다.</string>
```

Android `AndroidManifest.xml` 은 **건드리지 않는다** — image_picker 는 Photo Picker + `ACTION_IMAGE_CAPTURE` 라 권한 선언 0 이 정석이고, `CAMERA` 를 선언하면 오히려 런타임 권한이 필요해진다.

- [ ] **Step 4: 분석 통과**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: 커밋**

```bash
git add pubspec.yaml pubspec.lock ios/Runner/Info.plist
git -c user.email=gayoremix@gmail.com -c user.name=vulcan commit -m "chore(memoyo): image_picker·pasteboard·flutter_image_compress 의존성 + iOS 사진첩·카메라 문구 (T-260829-022)"
```

---

### Task 3: `AttachmentStore` — 파일 디렉토리

**Files:**
- Create: `lib/features/memos/services/attachment_store.dart`
- Create: `test/features/memos/support/attachment_test_support.dart`
- Test: `test/features/memos/attachment_store_test.dart`

- [ ] **Step 1: 테스트 지원 파일 (v1)**

```dart
// test/features/memos/support/attachment_test_support.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:simple_memo_app/features/memos/services/attachment_store.dart';

/// 1×1 투명 PNG (67B). 실제 디코딩 가능한 최소 이미지.
final Uint8List kTinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

/// 임시 디렉토리에 스토어를 만들어 프로세스 단일 인스턴스로 꽂는다.
/// 반환값은 tearDown 에서 `deleteSync(recursive: true)` 할 루트.
Future<Directory> installTempStore() async {
  final dir = await Directory.systemTemp.createTemp('memoyo-attach-');
  AttachmentStore.instance =
      AttachmentStore(root: Directory('${dir.path}${Platform.pathSeparator}attachments'));
  return dir;
}

/// 스토어에 파일을 하나 심고 파일명을 돌려준다 (테스트 fixture 용).
Future<String> seedStoreFile(String name, [Uint8List? bytes]) async {
  final store = AttachmentStore.instance;
  await store.root.create(recursive: true);
  await store.fileFor(name).writeAsBytes(bytes ?? kTinyPng, flush: true);
  return name;
}
```

- [ ] **Step 2: 실패하는 테스트 작성**

```dart
// test/features/memos/attachment_store_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/attachment_store.dart';

import 'support/attachment_test_support.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await installTempStore();
  });

  tearDown(() {
    AttachmentStore.instance = null;
    tmp.deleteSync(recursive: true);
  });

  test('save: uuid.jpg 파일명으로 저장되고 바이트가 그대로 남는다', () async {
    final store = AttachmentStore.instance;
    final name = await store.save(kTinyPng);

    expect(name, endsWith('.jpg'));
    expect(name, isNot(contains('/')));
    expect(await store.fileFor(name).readAsBytes(), kTinyPng);
    expect(await store.exists(name), isTrue);
  });

  test('save 는 디렉토리가 없어도 만들어서 저장한다', () async {
    final store = AttachmentStore.instance;
    expect(store.root.existsSync(), isFalse);
    await store.save(kTinyPng);
    expect(store.root.existsSync(), isTrue);
  });

  test('delete: 있는 파일은 지우고 없는 파일은 조용히 무시', () async {
    final store = AttachmentStore.instance;
    final a = await store.save(kTinyPng);
    await store.delete([a, 'ghost.jpg']);
    expect(await store.exists(a), isFalse);
  });

  test('fileFor: 검증 실패 파일명은 ArgumentError (attachments/ 밖 접근 차단)', () {
    final store = AttachmentStore.instance;
    expect(() => store.fileFor('../x.jpg'), throwsArgumentError);
    expect(() => store.fileFor('a/b.jpg'), throwsArgumentError);
  });

  test('sweepOrphans: 참조 안 되는 파일만 지우고 개수를 돌려준다', () async {
    final store = AttachmentStore.instance;
    final keep = await store.save(kTinyPng);
    final orphan1 = await store.save(kTinyPng);
    final orphan2 = await store.save(kTinyPng);

    final removed = await store.sweepOrphans([keep, 'not-on-disk.jpg']);

    expect(removed, 2);
    expect(await store.exists(keep), isTrue);
    expect(await store.exists(orphan1), isFalse);
    expect(await store.exists(orphan2), isFalse);
  });

  test('sweepOrphans: 디렉토리 자체가 없으면 0', () async {
    expect(await AttachmentStore.instance.sweepOrphans(const []), 0);
  });

  test('instance 미설정이면 maybeInstance null, instance 는 StateError', () {
    AttachmentStore.instance = null;
    expect(AttachmentStore.maybeInstance, isNull);
    expect(() => AttachmentStore.instance, throwsStateError);
  });
}
```

- [ ] **Step 3: 실패 확인**

Run: `flutter test test/features/memos/attachment_store_test.dart`
Expected: 컴파일 실패 — `attachment_store.dart` 없음.

- [ ] **Step 4: 구현**

```dart
// lib/features/memos/services/attachment_store.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../models/memo.dart';

/// 첨부 사진 파일 저장소 — `<앱문서>/attachments/<uuid>.jpg` 평면 구조.
///
/// 메모 id 하위 폴더를 두지 않는다: 새 메모는 저장 시점에야 id 가 생기므로
/// 편집 중 먼저 파일을 만들 수 있어야 한다. 메모는 파일명만 들고 있다.
class AttachmentStore {
  AttachmentStore({required Directory root}) : _root = root;

  static const _uuid = Uuid();
  static AttachmentStore? _instance;

  /// 프로세스 단일 인스턴스. 초기화 전(테스트·path_provider 실패)엔 null 이며
  /// 호출부는 null 이면 사진 기능만 조용히 비활성화한다(크래시 0).
  static AttachmentStore? get maybeInstance => _instance;

  static AttachmentStore get instance =>
      _instance ?? (throw StateError('AttachmentStore.init() 이 먼저 불려야 한다'));

  @visibleForTesting
  static set instance(AttachmentStore? store) => _instance = store;

  /// 앱 시작 시 1회. 실패해도 던지지 않는다 — 인스턴스가 null 로 남을 뿐.
  static Future<void> init() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      _instance = AttachmentStore(
        root: Directory('${docs.path}${Platform.pathSeparator}attachments'),
      );
    } catch (e) {
      debugPrint('[AttachmentStore.init] $e');
    }
  }

  final Directory _root;
  Directory get root => _root;

  File fileFor(String name) {
    if (!Memo.isValidImageFileName(name)) {
      throw ArgumentError.value(name, 'name', 'invalid attachment file name');
    }
    return File('${_root.path}${Platform.pathSeparator}$name');
  }

  Future<bool> exists(String name) => fileFor(name).exists();

  /// JPEG 바이트를 새 파일로 저장하고 파일명을 돌려준다.
  Future<String> save(Uint8List jpegBytes) async {
    await _root.create(recursive: true);
    final name = '${_uuid.v4()}.jpg';
    await fileFor(name).writeAsBytes(jpegBytes, flush: true);
    return name;
  }

  /// 없는 파일·검증 실패 파일명은 무시한다.
  Future<void> delete(Iterable<String> names) async {
    for (final name in names) {
      if (!Memo.isValidImageFileName(name)) continue;
      try {
        final file = fileFor(name);
        if (await file.exists()) await file.delete();
      } on FileSystemException catch (e) {
        debugPrint('[AttachmentStore.delete] $name: $e');
      }
    }
  }

  /// `referenced` 에 없는 파일을 지운다. cold start 처럼 편집 세션이 없는 시점에만 부를 것 —
  /// 편집 중 대기 파일은 아직 어느 메모도 참조하지 않아 고아로 보인다.
  Future<int> sweepOrphans(Iterable<String> referenced) async {
    if (!await _root.exists()) return 0;
    final keep = referenced.toSet();
    var removed = 0;
    await for (final entry in _root.list(followLinks: false)) {
      if (entry is! File) continue;
      final name = entry.uri.pathSegments.last;
      if (keep.contains(name)) continue;
      try {
        await entry.delete();
        removed++;
      } on FileSystemException catch (e) {
        debugPrint('[AttachmentStore.sweepOrphans] $name: $e');
      }
    }
    return removed;
  }
}
```

- [ ] **Step 5: 통과 확인**

Run: `flutter test test/features/memos/attachment_store_test.dart`
Expected: 7 PASS.

- [ ] **Step 6: 커밋**

```bash
git add lib/features/memos/services/attachment_store.dart test/features/memos/support/attachment_test_support.dart test/features/memos/attachment_store_test.dart
git -c user.email=gayoremix@gmail.com -c user.name=vulcan commit -m "feat(memoyo): AttachmentStore — attachments/ 평면 파일 저장·삭제·고아 정리 (T-260829-022)"
```

---

### Task 4: `ImageIngest` — 긴 변 1600 축소 계산 + 압축기 추상화

**Files:**
- Create: `lib/features/memos/services/image_ingest.dart`
- Test: `test/features/memos/image_ingest_test.dart`

`flutter_image_compress` 의 `minWidth/minHeight` 는 **하한**이다(비율 유지, 둘 다 만족하는 배율 = 큰 쪽; 원본이 더 작으면 배율 1). 그래서 「긴 변 1600」을 얻으려면 원본 크기를 알아내 같은 비율의 목표 크기를 넘겨야 한다 — 그 계산이 `fitLongEdge` 이고 순수 함수라 CI 에서 테스트한다. 네이티브 압축 자체는 CI 에서 못 돌리므로 인터페이스 뒤에 둔다.

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/features/memos/image_ingest_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/image_ingest.dart';

void main() {
  group('fitLongEdge', () {
    test('긴 변이 상한 이하면 그대로', () {
      expect(fitLongEdge(1200, 800, 1600), (1200, 800));
      expect(fitLongEdge(1600, 1600, 1600), (1600, 1600));
    });

    test('가로가 긴 사진 → 가로 1600, 세로 비율 축소', () {
      expect(fitLongEdge(4000, 3000, 1600), (1600, 1200));
    });

    test('세로가 긴 사진 → 세로 1600', () {
      expect(fitLongEdge(3000, 4000, 1600), (1200, 1600));
    });

    test('극단 비율에서도 1 미만으로 떨어지지 않는다', () {
      expect(fitLongEdge(10000, 1, 1600), (1600, 1));
    });

    test('0·음수 입력은 상한 정사각으로 폴백 (크기 못 읽은 경우)', () {
      expect(fitLongEdge(0, 0, 1600), (1600, 1600));
      expect(fitLongEdge(-5, 100, 1600), (1600, 1600));
    });
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/memos/image_ingest_test.dart`
Expected: 컴파일 실패 — `image_ingest.dart` 없음.

- [ ] **Step 3: 구현**

```dart
// lib/features/memos/services/image_ingest.dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// 원본 (w,h) 를 비율 유지한 채 긴 변이 [maxLongEdge] 이하가 되게 줄인 크기.
/// 크기를 못 읽은 경우(0 이하) 는 (max,max) — 압축기의 하한 의미상 짧은 변이
/// max 로 맞춰져 목표보다 크지만 유한하게 묶인다.
(int, int) fitLongEdge(int width, int height, int maxLongEdge) {
  if (width <= 0 || height <= 0) return (maxLongEdge, maxLongEdge);
  final long = width > height ? width : height;
  if (long <= maxLongEdge) return (width, height);
  final scale = maxLongEdge / long;
  int fit(int v) => (v * scale).round().clamp(1, maxLongEdge);
  return (fit(width), fit(height));
}

/// 들어온 이미지 바이트(PNG/HEIC/JPEG…)를 축소된 JPEG 바이트로.
abstract class ImageCompressor {
  Future<Uint8List> toJpeg(
    Uint8List source, {
    required int maxLongEdge,
    required int quality,
  });
}

/// flutter_image_compress 구현. EXIF 회전은 굽고(autoCorrectionAngle) 메타데이터는 버린다.
class FlutterImageCompressor implements ImageCompressor {
  const FlutterImageCompressor();

  @override
  Future<Uint8List> toJpeg(
    Uint8List source, {
    required int maxLongEdge,
    required int quality,
  }) async {
    final (w, h) = await _sourceSize(source);
    final (targetW, targetH) = fitLongEdge(w, h, maxLongEdge);
    return FlutterImageCompress.compressWithList(
      source,
      minWidth: targetW,
      minHeight: targetH,
      quality: quality,
      rotate: 0,
      autoCorrectionAngle: true,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
  }

  /// 전체 디코딩 없이 헤더에서 크기만 읽는다. 실패하면 (0,0) → fitLongEdge 폴백.
  Future<(int, int)> _sourceSize(Uint8List source) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(source);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      return (descriptor.width, descriptor.height);
    } catch (e) {
      debugPrint('[FlutterImageCompressor._sourceSize] $e');
      return (0, 0);
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/features/memos/image_ingest_test.dart`
Expected: 5 PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/features/memos/services/image_ingest.dart test/features/memos/image_ingest_test.dart
git -c user.email=gayoremix@gmail.com -c user.name=vulcan commit -m "feat(memoyo): ImageIngest — 긴 변 1600 축소 계산 + ImageCompressor 추상화 (T-260829-022)"
```

---

### Task 5: `AttachmentService` — 가져오기 3경로 + 결과 타입

**Files:**
- Create: `lib/features/memos/services/attachment_service.dart`
- Modify: `test/features/memos/support/attachment_test_support.dart` (fake 추가)
- Test: `test/features/memos/attachment_service_test.dart`

- [ ] **Step 1: 테스트 지원 파일 (v2 — 전체 교체)**

```dart
// test/features/memos/support/attachment_test_support.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:simple_memo_app/features/memos/services/attachment_service.dart';
import 'package:simple_memo_app/features/memos/services/attachment_store.dart';
import 'package:simple_memo_app/features/memos/services/image_ingest.dart';

/// 1×1 투명 PNG (67B). 실제 디코딩 가능한 최소 이미지.
final Uint8List kTinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

/// 임시 디렉토리에 스토어를 만들어 프로세스 단일 인스턴스로 꽂는다.
/// 반환값은 tearDown 에서 `deleteSync(recursive: true)` 할 루트.
Future<Directory> installTempStore() async {
  final dir = await Directory.systemTemp.createTemp('memoyo-attach-');
  AttachmentStore.instance =
      AttachmentStore(root: Directory('${dir.path}${Platform.pathSeparator}attachments'));
  return dir;
}

/// 스토어에 파일을 하나 심고 파일명을 돌려준다 (테스트 fixture 용).
Future<String> seedStoreFile(String name, [Uint8List? bytes]) async {
  final store = AttachmentStore.instance;
  await store.root.create(recursive: true);
  await store.fileFor(name).writeAsBytes(bytes ?? kTinyPng, flush: true);
  return name;
}

/// 피커·클립보드 fake. 필드에 바이트를 넣으면 그걸 돌려주고, null 이면 취소/없음.
class FakeImageSourcePort implements ImageSourcePort {
  Uint8List? galleryBytes;
  Uint8List? cameraBytes;
  Uint8List? clipboardBytes;
  int galleryCalls = 0;
  int cameraCalls = 0;
  int clipboardCalls = 0;

  @override
  Future<Uint8List?> pickGallery() async {
    galleryCalls++;
    return galleryBytes;
  }

  @override
  Future<Uint8List?> takePhoto() async {
    cameraCalls++;
    return cameraBytes;
  }

  @override
  Future<Uint8List?> clipboardImage() async {
    clipboardCalls++;
    return clipboardBytes;
  }
}

/// 압축기 fake — 바이트를 그대로 통과시키거나 [shouldThrow] 면 던진다.
class PassthroughCompressor implements ImageCompressor {
  bool shouldThrow = false;
  int calls = 0;
  int? lastMaxLongEdge;
  int? lastQuality;

  @override
  Future<Uint8List> toJpeg(
    Uint8List source, {
    required int maxLongEdge,
    required int quality,
  }) async {
    calls++;
    lastMaxLongEdge = maxLongEdge;
    lastQuality = quality;
    if (shouldThrow) throw StateError('compress failed');
    return source;
  }
}

/// 실제 파이프라인 + fake 가장자리. `installTempStore()` 뒤에 부를 것.
AttachmentService fakeAttachmentService({
  FakeImageSourcePort? port,
  PassthroughCompressor? compressor,
}) =>
    AttachmentService(
      source: port ?? FakeImageSourcePort(),
      compressor: compressor ?? PassthroughCompressor(),
      store: AttachmentStore.instance,
    );
```

- [ ] **Step 2: 실패하는 테스트 작성**

```dart
// test/features/memos/attachment_service_test.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/attachment_service.dart';
import 'package:simple_memo_app/features/memos/services/attachment_store.dart';

import 'support/attachment_test_support.dart';

void main() {
  late Directory tmp;
  late FakeImageSourcePort port;
  late PassthroughCompressor compressor;
  late AttachmentService service;

  setUp(() async {
    tmp = await installTempStore();
    port = FakeImageSourcePort();
    compressor = PassthroughCompressor();
    service = fakeAttachmentService(port: port, compressor: compressor);
  });

  tearDown(() {
    AttachmentStore.instance = null;
    tmp.deleteSync(recursive: true);
  });

  test('상수: 10장 · 긴 변 1600 · JPEG 85', () {
    expect(AttachmentService.maxImages, 10);
    expect(AttachmentService.maxLongEdge, 1600);
    expect(AttachmentService.jpegQuality, 85);
  });

  test('사진첩: 성공 → 압축(1600/85) 거쳐 저장, 파일명 반환', () async {
    port.galleryBytes = kTinyPng;
    final result = await service.pickFromGallery(0);

    expect(result, isA<AttachOk>());
    final name = (result as AttachOk).fileName;
    expect(await AttachmentStore.instance.exists(name), isTrue);
    expect(compressor.calls, 1);
    expect(compressor.lastMaxLongEdge, 1600);
    expect(compressor.lastQuality, 85);
  });

  test('카메라: 성공 경로 동일', () async {
    port.cameraBytes = kTinyPng;
    expect(await service.takePhoto(3), isA<AttachOk>());
    expect(port.cameraCalls, 1);
  });

  test('피커 null(취소·권한 거부) → AttachCancelled, 파일 미생성', () async {
    expect(await service.pickFromGallery(0), isA<AttachCancelled>());
    expect(await service.takePhoto(0), isA<AttachCancelled>());
    expect(AttachmentStore.instance.root.existsSync(), isFalse);
  });

  test('클립보드 null·빈 바이트 → AttachNoImage', () async {
    expect(await service.pasteFromClipboard(0), isA<AttachNoImage>());
    port.clipboardBytes = Uint8List.fromList(const []);
    expect(await service.pasteFromClipboard(0), isA<AttachNoImage>());
  });

  test('클립보드 성공 → AttachOk', () async {
    port.clipboardBytes = kTinyPng;
    expect(await service.pasteFromClipboard(0), isA<AttachOk>());
  });

  test('현재 10장 이상이면 AttachLimit 이고 피커·클립보드를 열지 않는다', () async {
    port.galleryBytes = kTinyPng;
    port.clipboardBytes = kTinyPng;
    expect(await service.pickFromGallery(10), isA<AttachLimit>());
    expect(await service.takePhoto(11), isA<AttachLimit>());
    expect(await service.pasteFromClipboard(10), isA<AttachLimit>());
    expect(port.galleryCalls, 0);
    expect(port.cameraCalls, 0);
    expect(port.clipboardCalls, 0);
  });

  test('압축 실패 → AttachFailed(원본 폴백 없음), 파일 미생성', () async {
    port.galleryBytes = kTinyPng;
    compressor.shouldThrow = true;
    final result = await service.pickFromGallery(0);
    expect(result, isA<AttachFailed>());
    expect((result as AttachFailed).error, isA<StateError>());
    expect(AttachmentStore.instance.root.existsSync(), isFalse);
  });

  test('deleteFiles 는 스토어 delete 위임', () async {
    port.galleryBytes = kTinyPng;
    final name = ((await service.pickFromGallery(0)) as AttachOk).fileName;
    await service.deleteFiles([name]);
    expect(await AttachmentStore.instance.exists(name), isFalse);
  });
}
```

- [ ] **Step 3: 실패 확인**

Run: `flutter test test/features/memos/attachment_service_test.dart`
Expected: 컴파일 실패 — `attachment_service.dart` 없음.

- [ ] **Step 4: 구현**

```dart
// lib/features/memos/services/attachment_service.dart
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pasteboard/pasteboard.dart';

import 'attachment_store.dart';
import 'image_ingest.dart';

/// 가져오기 결과. 화면은 이 타입으로만 분기한다 — 예외는 서비스 밖으로 나가지 않는다.
sealed class AttachResult {
  const AttachResult();
}

class AttachOk extends AttachResult {
  const AttachOk(this.fileName);
  final String fileName;
}

/// 피커 취소·권한 거부(플러그인이 null 반환). 화면은 조용히 넘어간다.
class AttachCancelled extends AttachResult {
  const AttachCancelled();
}

/// 클립보드에 이미지가 없다.
class AttachNoImage extends AttachResult {
  const AttachNoImage();
}

/// 이미 [AttachmentService.maxImages] 장.
class AttachLimit extends AttachResult {
  const AttachLimit();
}

/// 압축·저장 실패. 원본 폴백 없음(용량 봉투 보호).
class AttachFailed extends AttachResult {
  const AttachFailed(this.error);
  final Object error;
}

/// 이미지 바이트 출처. 플러그인 의존을 여기 가둬 테스트에서 fake 로 바꾼다.
abstract class ImageSourcePort {
  Future<Uint8List?> pickGallery();
  Future<Uint8List?> takePhoto();
  Future<Uint8List?> clipboardImage();
}

class PluginImageSourcePort implements ImageSourcePort {
  PluginImageSourcePort({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Uint8List?> pickGallery() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    return file?.readAsBytes();
  }

  @override
  Future<Uint8List?> takePhoto() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    return file?.readAsBytes();
  }

  @override
  Future<Uint8List?> clipboardImage() async {
    final bytes = await Pasteboard.image;
    if (bytes == null || bytes.isEmpty) return null;
    return bytes;
  }
}

class AttachmentService {
  AttachmentService({
    required ImageSourcePort source,
    required ImageCompressor compressor,
    required this.store,
  })  : _source = source,
        _compressor = compressor;

  /// 프로덕션 조립. [AttachmentStore.init] 전이면 StateError — 호출부가 잡아 실패로 표시.
  factory AttachmentService.production() => AttachmentService(
        source: PluginImageSourcePort(),
        compressor: const FlutterImageCompressor(),
        store: AttachmentStore.instance,
      );

  static const int maxImages = 10;
  static const int maxLongEdge = 1600;
  static const int jpegQuality = 85;

  final ImageSourcePort _source;
  final ImageCompressor _compressor;
  final AttachmentStore store;

  Future<AttachResult> pickFromGallery(int currentCount) =>
      _ingest(currentCount, _source.pickGallery, onNull: const AttachCancelled());

  Future<AttachResult> takePhoto(int currentCount) =>
      _ingest(currentCount, _source.takePhoto, onNull: const AttachCancelled());

  Future<AttachResult> pasteFromClipboard(int currentCount) =>
      _ingest(currentCount, _source.clipboardImage, onNull: const AttachNoImage());

  Future<void> deleteFiles(Iterable<String> names) => store.delete(names);

  Future<AttachResult> _ingest(
    int currentCount,
    Future<Uint8List?> Function() read, {
    required AttachResult onNull,
  }) async {
    if (currentCount >= maxImages) return const AttachLimit();
    final Uint8List? source;
    try {
      source = await read();
    } catch (e) {
      debugPrint('[AttachmentService] read: $e');
      return AttachFailed(e);
    }
    if (source == null || source.isEmpty) return onNull;
    try {
      final jpeg = await _compressor.toJpeg(
        source,
        maxLongEdge: maxLongEdge,
        quality: jpegQuality,
      );
      final name = await store.save(jpeg);
      return AttachOk(name);
    } catch (e) {
      debugPrint('[AttachmentService] ingest: $e');
      return AttachFailed(e);
    }
  }
}
```

- [ ] **Step 5: 통과 확인**

Run: `flutter test test/features/memos/`
Expected: store 7 + ingest 5 + service 9 = 21 PASS.

- [ ] **Step 6: 커밋**

```bash
git add lib/features/memos/services/attachment_service.dart test/features/memos/support/attachment_test_support.dart test/features/memos/attachment_service_test.dart
git -c user.email=gayoremix@gmail.com -c user.name=vulcan commit -m "feat(memoyo): AttachmentService — 사진첩·카메라·클립보드 → 축소 JPEG 저장, 결과 타입 5종 (T-260829-022)"
```

---

### Task 6: `AppStrings` 문구 12개

**Files:**
- Modify: `lib/l10n/app_strings.dart:359-360`

- [ ] **Step 1: 문구 추가**

`String get untitledMemo => isEnglish ? 'New memo' : '새 메모';` (359행) 바로 아래, 닫는 `}` 앞에:

```dart

  // 메모 이미지 첨부 (T-260829-022)
  String get addPhoto => isEnglish ? 'Add photo' : '사진 추가';
  String get fromGallery => isEnglish ? 'Photo library' : '사진첩';
  String get fromCamera => isEnglish ? 'Camera' : '카메라';
  String get pasteImage => isEnglish ? 'Paste' : '붙여넣기';
  String get noImageInClipboard =>
      isEnglish ? 'No image in clipboard' : '클립보드에 사진이 없어요';
  String get photoLimitReached =>
      isEnglish ? 'Up to 10 photos per memo' : '사진은 메모당 최대 10장까지예요';
  String get photoAttachFailed =>
      isEnglish ? "Couldn't add the photo" : '사진을 추가하지 못했어요';
  String get deletePhotoConfirmTitle => isEnglish ? 'Delete photo' : '사진 삭제';
  String get deletePhotoConfirmBody =>
      isEnglish ? 'Delete this photo?' : '이 사진을 지울까요?';
  String get photosNotInBackup => isEnglish
      ? 'Photos are not included in backups'
      : '사진은 백업에 포함되지 않습니다';
  String get photoMissing => isEnglish ? 'Photo missing' : '사진 없음';
  String get photoViewerClose => isEnglish ? 'Close' : '닫기';
```

- [ ] **Step 2: 가드 통과 확인**

Run: `flutter analyze && flutter test test/l10n/`
Expected: `No issues found!` + l10n 테스트 전부 PASS.

- [ ] **Step 3: 커밋**

```bash
git add lib/l10n/app_strings.dart
git -c user.email=gayoremix@gmail.com -c user.name=vulcan commit -m "feat(memoyo): 이미지 첨부 문구 12개 ko/en (T-260829-022)"
```

---

### Task 7: `AttachmentThumbnail` + `AttachmentStrip` 위젯

**Files:**
- Create: `lib/features/memos/widgets/attachment_thumbnail.dart`
- Create: `lib/features/memos/widgets/attachment_strip.dart`
- Test: `test/features/memos/attachment_widgets_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/features/memos/attachment_widgets_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/attachment_store.dart';
import 'package:simple_memo_app/features/memos/widgets/attachment_strip.dart';
import 'package:simple_memo_app/features/memos/widgets/attachment_thumbnail.dart';

import 'support/attachment_test_support.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await installTempStore();
  });

  tearDown(() {
    AttachmentStore.instance = null;
    tmp.deleteSync(recursive: true);
  });

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('AttachmentThumbnail', () {
    testWidgets('파일이 있으면 Image.file 을 그 경로로 그린다', (tester) async {
      final name = await seedStoreFile('a.jpg');
      await tester.pumpWidget(wrap(AttachmentThumbnail(fileName: name)));

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<FileImage>());
      expect((image.image as FileImage).file.path, AttachmentStore.instance.fileFor(name).path);
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    });

    testWidgets('파일이 없으면 깨진 사진 플레이스홀더, 예외 없음', (tester) async {
      await tester.pumpWidget(wrap(const AttachmentThumbnail(fileName: 'gone.jpg')));
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('스토어 미초기화(maybeInstance null)여도 플레이스홀더로 버틴다', (tester) async {
      AttachmentStore.instance = null;
      await tester.pumpWidget(wrap(const AttachmentThumbnail(fileName: 'a.jpg')));
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('size 가 상자 크기를 정한다', (tester) async {
      await tester.pumpWidget(wrap(const AttachmentThumbnail(fileName: 'gone.jpg', size: 72)));
      final box = tester.getSize(find.byType(AttachmentThumbnail));
      expect(box, const Size(72, 72));
    });
  });

  group('AttachmentStrip', () {
    testWidgets('파일명 수만큼 72px 썸네일, 탭·길게누름이 인덱스로 온다', (tester) async {
      final a = await seedStoreFile('a.jpg');
      final b = await seedStoreFile('b.jpg');
      int? tapped;
      int? held;
      await tester.pumpWidget(wrap(AttachmentStrip(
        fileNames: [a, b],
        onTap: (i) => tapped = i,
        onLongPress: (i) => held = i,
      )));

      expect(find.byType(AttachmentThumbnail), findsNWidgets(2));
      expect(tester.getSize(find.byType(AttachmentThumbnail).first), const Size(72, 72));

      await tester.tap(find.byType(AttachmentThumbnail).at(1));
      expect(tapped, 1);
      await tester.longPress(find.byType(AttachmentThumbnail).first);
      expect(held, 0);
    });
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/memos/attachment_widgets_test.dart`
Expected: 컴파일 실패 — 위젯 파일 없음.

- [ ] **Step 3: 썸네일 구현**

```dart
// lib/features/memos/widgets/attachment_thumbnail.dart
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../../../utils/app_palette.dart';
import '../services/attachment_store.dart';

/// 첨부 사진 정사각 썸네일. 파일이 없거나 스토어가 없으면 깨진 사진 아이콘 —
/// 어떤 경우에도 예외를 올리지 않는다(백업 복원 뒤 파일 부재 시나리오).
class AttachmentThumbnail extends StatelessWidget {
  const AttachmentThumbnail({
    super.key,
    required this.fileName,
    this.size = 36,
    this.radius = 8,
  });

  final String fileName;
  final double size;
  final double radius;

  File? _resolve() {
    final store = AttachmentStore.maybeInstance;
    if (store == null) return null;
    try {
      final file = store.fileFor(fileName);
      return file.existsSync() ? file : null;
    } on ArgumentError {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = _resolve();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: file == null
            ? _Placeholder(size: size)
            : Image.file(
                file,
                fit: BoxFit.cover,
                cacheWidth: (size * 3).round(),
                errorBuilder: (_, _, _) => _Placeholder(size: size),
              ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return ColoredBox(
      color: palette.textSecondary.withValues(alpha: 0.12),
      child: Icon(
        Icons.broken_image_outlined,
        size: size * 0.5,
        color: palette.textSecondary,
        semanticLabel: AppStrings.of(context).photoMissing,
      ),
    );
  }
}
```

`AppPalette` 의 실제 필드명은 `lib/utils/app_palette.dart` 를 열어 확인한다 — 이 plan 은 편집 화면이 이미 쓰는 `palette.textPrimary` / `palette.textSecondary` / `palette.surface` / `palette.background` / `palette.danger` 만 사용한다.

- [ ] **Step 4: 스트립 구현**

```dart
// lib/features/memos/widgets/attachment_strip.dart
import 'package:flutter/material.dart';

import 'attachment_thumbnail.dart';

/// 편집 화면 본문 아래 가로 스크롤 썸네일 줄. 사진 0장이면 호출부가 아예 넣지 않는다.
class AttachmentStrip extends StatelessWidget {
  const AttachmentStrip({
    super.key,
    required this.fileNames,
    required this.onTap,
    required this.onLongPress,
  });

  static const double tileSize = 72;

  final List<String> fileNames;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: tileSize,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: fileNames.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(index),
            onLongPress: () => onLongPress(index),
            child: AttachmentThumbnail(
              fileName: fileNames[index],
              size: tileSize,
              radius: 10,
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: 통과 확인**

Run: `flutter test test/features/memos/attachment_widgets_test.dart`
Expected: 5 PASS. (Dart 3.10 미만 툴체인이면 `(_, _, _)` 와일드카드가 안 먹는다 — 그 경우 `(_, __, ___)` 로 바꾼다. 볼칸 3.41.9 / CI 3.44 는 Dart 3.10+ 라 그대로 통과한다.)

- [ ] **Step 6: 커밋**

```bash
git add lib/features/memos/widgets/attachment_thumbnail.dart lib/features/memos/widgets/attachment_strip.dart test/features/memos/attachment_widgets_test.dart
git -c user.email=gayoremix@gmail.com -c user.name=vulcan commit -m "feat(memoyo): AttachmentThumbnail·AttachmentStrip 위젯 (T-260829-022)"
```

---

### Task 8: `AttachmentViewer` — 전체화면 보기·넘기기·확대·삭제

**Files:**
- Create: `lib/features/memos/widgets/attachment_viewer.dart`
- Test: `test/features/memos/attachment_viewer_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/features/memos/attachment_viewer_test.dart
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/attachment_store.dart';
import 'package:simple_memo_app/features/memos/widgets/attachment_viewer.dart';

import 'support/attachment_test_support.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await installTempStore();
  });

  tearDown(() {
    AttachmentStore.instance = null;
    tmp.deleteSync(recursive: true);
  });

  testWidgets('PageView 로 넘기고 InteractiveViewer 로 감싼다, 초기 인덱스 반영', (tester) async {
    final a = await seedStoreFile('a.jpg');
    final b = await seedStoreFile('b.jpg');
    await tester.pumpWidget(MaterialApp(
      home: AttachmentViewer(fileNames: [a, b], initialIndex: 1),
    ));
    await tester.pump();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsWidgets);
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('onDelete 없으면 삭제 버튼이 없다', (tester) async {
    final a = await seedStoreFile('a.jpg');
    await tester.pumpWidget(MaterialApp(
      home: AttachmentViewer(fileNames: [a], initialIndex: 0),
    ));
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('삭제 → 확인 다이얼로그 → 콜백에 파일명, 마지막 장이면 닫힌다', (tester) async {
    final a = await seedStoreFile('a.jpg');
    final deleted = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => AttachmentViewer.show(
              context,
              fileNames: [a],
              initialIndex: 0,
              onDelete: deleted.add,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(AttachmentViewer), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);

    await tester.tap(find.widgetWithText(CupertinoDialogAction, '사진 삭제'));
    await tester.pumpAndSettle();

    expect(deleted, [a]);
    expect(find.byType(AttachmentViewer), findsNothing);
  });

  testWidgets('파일이 없어도 예외 없이 플레이스홀더 아이콘', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AttachmentViewer(fileNames: ['gone.jpg'], initialIndex: 0),
    ));
    await tester.pump();
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/features/memos/attachment_viewer_test.dart`
Expected: 컴파일 실패 — `attachment_viewer.dart` 없음.

- [ ] **Step 3: 구현**

```dart
// lib/features/memos/widgets/attachment_viewer.dart
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../services/attachment_store.dart';

/// 전체화면 사진 뷰어 — 좌우 넘김(PageView) + 핀치 확대(InteractiveViewer) + 삭제.
/// 새 패키지 없음. 삭제는 [onDelete] 콜백으로 호출부(편집 화면)가 처리한다.
class AttachmentViewer extends StatefulWidget {
  const AttachmentViewer({
    super.key,
    required this.fileNames,
    required this.initialIndex,
    this.onDelete,
  });

  final List<String> fileNames;
  final int initialIndex;
  final ValueChanged<String>? onDelete;

  static Future<void> show(
    BuildContext context, {
    required List<String> fileNames,
    required int initialIndex,
    ValueChanged<String>? onDelete,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => AttachmentViewer(
          fileNames: fileNames,
          initialIndex: initialIndex,
          onDelete: onDelete,
        ),
      ),
    );
  }

  @override
  State<AttachmentViewer> createState() => _AttachmentViewerState();
}

class _AttachmentViewerState extends State<AttachmentViewer> {
  late final PageController _controller;
  late final List<String> _names;
  late int _index;

  @override
  void initState() {
    super.initState();
    _names = List.of(widget.fileNames);
    _index = widget.initialIndex.clamp(0, _names.isEmpty ? 0 : _names.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  File? _fileAt(int i) {
    final store = AttachmentStore.maybeInstance;
    if (store == null) return null;
    try {
      final file = store.fileFor(_names[i]);
      return file.existsSync() ? file : null;
    } on ArgumentError {
      return null;
    }
  }

  Future<void> _confirmDelete() async {
    final strings = AppStrings.of(context);
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(strings.deletePhotoConfirmTitle),
        content: Text(strings.deletePhotoConfirmBody),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(strings.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(strings.deletePhotoConfirmTitle),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final name = _names[_index];
    widget.onDelete?.call(name);
    if (_names.length <= 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _names.removeAt(_index);
      if (_index >= _names.length) _index = _names.length - 1;
      _controller.jumpToPage(_index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: strings.photoViewerClose,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${_index + 1} / ${_names.length}',
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        centerTitle: true,
        actions: [
          if (widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: strings.deletePhotoConfirmTitle,
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: _names.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final file = _fileAt(i);
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: file == null
                  ? Icon(
                      Icons.broken_image_outlined,
                      size: 64,
                      color: Colors.white54,
                      semanticLabel: strings.photoMissing,
                    )
                  : Image.file(
                      file,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.broken_image_outlined,
                        size: 64,
                        color: Colors.white54,
                        semanticLabel: strings.photoMissing,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/features/memos/attachment_viewer_test.dart`
Expected: 4 PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/features/memos/widgets/attachment_viewer.dart test/features/memos/attachment_viewer_test.dart
git -c user.email=gayoremix@gmail.com -c user.name=vulcan commit -m "feat(memoyo): AttachmentViewer — 전체화면 넘김·확대·삭제 (T-260829-022)"
```

---

### Task 9: 편집 화면 배선 — 버튼·시트·스트립·수명·공유

**Files:**
- Modify: `lib/screens/memo_edit_screen.dart` (imports 1-15, State 필드 32-45, initState 47-60, `_buildMemo`~`_cancelEdit` 204-291, AppBar actions 440-483, TextField 511-620)
- Test: `test/screens/memo_edit_image_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/screens/memo_edit_image_test.dart
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/attachment_store.dart';
import 'package:simple_memo_app/features/memos/widgets/attachment_strip.dart';
import 'package:simple_memo_app/features/memos/widgets/attachment_thumbnail.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_edit_screen.dart';

import '../features/memos/support/attachment_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late FakeImageSourcePort port;

  setUp(() async {
    tmp = await installTempStore();
    port = FakeImageSourcePort();
  });

  tearDown(() {
    AttachmentStore.instance = null;
    tmp.deleteSync(recursive: true);
  });

  Memo existing({List<String> images = const []}) {
    final t = DateTime(2026, 8, 29, 12);
    return Memo(id: 'm1', content: '기존 본문', createdAt: t, updatedAt: t, imageFiles: images);
  }

  Future<void> addViaSheet(WidgetTester tester, String action) async {
    await tester.tap(find.byTooltip('사진 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoActionSheetAction, action));
    await tester.pumpAndSettle();
  }

  testWidgets('사진 추가 버튼이 있고, 시트에 사진첩·카메라·붙여넣기 3항목', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MemoEditScreen(attachmentService: fakeAttachmentService(port: port)),
    ));
    expect(find.byTooltip('사진 추가'), findsOneWidget);
    expect(find.byType(AttachmentStrip), findsNothing);

    await tester.tap(find.byTooltip('사진 추가'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(CupertinoActionSheetAction, '사진첩'), findsOneWidget);
    expect(find.widgetWithText(CupertinoActionSheetAction, '카메라'), findsOneWidget);
    expect(find.widgetWithText(CupertinoActionSheetAction, '붙여넣기'), findsOneWidget);
  });

  testWidgets('사진첩에서 추가 → 스트립에 1장, 파일 존재', (tester) async {
    port.galleryBytes = kTinyPng;
    await tester.pumpWidget(MaterialApp(
      home: MemoEditScreen(attachmentService: fakeAttachmentService(port: port)),
    ));
    await addViaSheet(tester, '사진첩');

    expect(find.byType(AttachmentStrip), findsOneWidget);
    expect(find.byType(AttachmentThumbnail), findsOneWidget);
    final dir = AttachmentStore.instance.root;
    expect(dir.listSync().whereType<File>().length, 1);
  });

  testWidgets('클립보드에 사진 없음 → 스낵바, 스트립 없음', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MemoEditScreen(attachmentService: fakeAttachmentService(port: port)),
    ));
    await addViaSheet(tester, '붙여넣기');
    expect(find.text('클립보드에 사진이 없어요'), findsOneWidget);
    expect(find.byType(AttachmentStrip), findsNothing);
  });

  testWidgets('10장이면 시트 대신 상한 스낵바', (tester) async {
    final names = <String>[];
    for (var i = 0; i < 10; i++) {
      names.add(await seedStoreFile('p$i.jpg'));
    }
    await tester.pumpWidget(MaterialApp(
      home: MemoEditScreen(
        memo: existing(images: names),
        attachmentService: fakeAttachmentService(port: port),
      ),
    ));
    await tester.tap(find.byTooltip('사진 추가'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActionSheet), findsNothing);
    expect(find.text('사진은 메모당 최대 10장까지예요'), findsOneWidget);
  });

  testWidgets('본문 없이 사진만 있어도 저장이 호출되고 imageFiles 가 실린다', (tester) async {
    port.galleryBytes = kTinyPng;
    Memo? saved;
    await tester.pumpWidget(MaterialApp(
      home: MemoEditScreen(
        attachmentService: fakeAttachmentService(port: port),
        onSave: (m) => saved = m,
      ),
    ));
    await addViaSheet(tester, '사진첩');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.content, isEmpty);
    expect(saved!.imageFiles.length, 1);
  });

  testWidgets('본문도 사진도 없으면 저장 시 기존 안내 스낵바(회귀 없음)', (tester) async {
    Memo? saved;
    await tester.pumpWidget(MaterialApp(
      home: MemoEditScreen(
        attachmentService: fakeAttachmentService(port: port),
        onSave: (m) => saved = m,
      ),
    ));
    await tester.tap(find.text('저장'));
    await tester.pump();
    expect(saved, isNull);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('편집 취소 → 이 세션에서 추가한 파일은 삭제, 기존 파일은 생존', (tester) async {
    final keep = await seedStoreFile('keep.jpg');
    port.galleryBytes = kTinyPng;
    await tester.pumpWidget(MaterialApp(
      home: MemoEditScreen(
        memo: existing(images: [keep]),
        attachmentService: fakeAttachmentService(port: port),
      ),
    ));
    await addViaSheet(tester, '사진첩');
    expect(find.byType(AttachmentThumbnail), findsNWidgets(2));
    final store = AttachmentStore.instance;
    expect(store.root.listSync().whereType<File>().length, 2);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '취소'));
    await tester.pumpAndSettle();

    expect(await store.exists(keep), isTrue);
    expect(store.root.listSync().whereType<File>().length, 1);
  });

  testWidgets('길게 눌러 기존 사진 삭제 → 저장 시점에 파일 삭제, 저장 결과에서 빠짐', (tester) async {
    final a = await seedStoreFile('a.jpg');
    final b = await seedStoreFile('b.jpg');
    Memo? saved;
    await tester.pumpWidget(MaterialApp(
      home: MemoEditScreen(
        memo: existing(images: [a, b]),
        attachmentService: fakeAttachmentService(port: port),
        onSave: (m) => saved = m,
      ),
    ));

    await tester.longPress(find.byType(AttachmentThumbnail).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '사진 삭제'));
    await tester.pumpAndSettle();
    expect(find.byType(AttachmentThumbnail), findsOneWidget);
    // 아직 저장 전 — 파일은 살아 있다 (취소하면 복귀).
    expect(await AttachmentStore.instance.exists(a), isTrue);

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(saved!.imageFiles, [b]);
    expect(await AttachmentStore.instance.exists(a), isFalse);
    expect(await AttachmentStore.instance.exists(b), isTrue);
  });

  testWidgets('이 세션에서 추가한 사진을 바로 지우면 파일도 즉시 삭제', (tester) async {
    port.galleryBytes = kTinyPng;
    await tester.pumpWidget(MaterialApp(
      home: MemoEditScreen(attachmentService: fakeAttachmentService(port: port)),
    ));
    await addViaSheet(tester, '사진첩');
    await tester.longPress(find.byType(AttachmentThumbnail));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '사진 삭제'));
    await tester.pumpAndSettle();

    expect(find.byType(AttachmentStrip), findsNothing);
    expect(AttachmentStore.instance.root.listSync().whereType<File>(), isEmpty);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/screens/memo_edit_image_test.dart`
Expected: 컴파일 실패 — `MemoEditScreen` 에 `attachmentService` 파라미터 없음.

- [ ] **Step 3: imports + 생성자 + State 필드**

imports (15행 `import '../l10n/app_strings.dart';` 뒤에):

```dart
import '../features/memos/services/attachment_service.dart';
import '../features/memos/services/attachment_store.dart';
import '../features/memos/widgets/attachment_strip.dart';
import '../features/memos/widgets/attachment_viewer.dart';
```

위젯 생성자 (18-26행 교체):

```dart
class MemoEditScreen extends StatefulWidget {
  final Memo? memo;
  final ValueChanged<Memo>? onSave;
  // 테스트 주입용. null 이면 AttachmentService.production() 을 첫 사용 시 조립한다.
  final AttachmentService? attachmentService;

  const MemoEditScreen({
    super.key,
    this.memo,
    this.onSave,
    this.attachmentService,
  });
```

State 필드 (42행 `bool _isClampingSelection = false;` 뒤에):

```dart

  // 첨부 사진 — 화면에 보이는 현재 목록 + 저장/취소 때 확정할 대기 목록 (spec §3.4).
  late final List<String> _imageFiles;
  final List<String> _pendingAdded = [];
  final List<String> _pendingRemoved = [];
  AttachmentService? _defaultService;

  AttachmentService get _attachments =>
      widget.attachmentService ?? (_defaultService ??= AttachmentService.production());

  AttachmentStore? get _store =>
      widget.attachmentService?.store ?? AttachmentStore.maybeInstance;
```

initState (`_isEditing = widget.memo != null;` 뒤에):

```dart
    _imageFiles = List.of(widget.memo?.imageFiles ?? const <String>[]);
```

- [ ] **Step 4: 저장·취소 수명**

`_buildMemo` (204-213행) 교체:

```dart
  Memo? _buildMemo() {
    final content = _normalizeContent(_contentController.text);
    final images = List<String>.unmodifiable(_imageFiles);
    // 본문이 비어도 사진이 있으면 저장 대상 (사진만 있는 메모 허용, 제목은 untitledMemo 폴백).
    if (content.isEmpty && images.isEmpty) return null;

    if (_isEditing && widget.memo != null) {
      return widget.memo!.copyWith(
        content: content,
        updatedAt: DateTime.now(),
        imageFiles: images,
      );
    } else {
      return Memo.create(content: content, imageFiles: images);
    }
  }

  // 저장 확정 뒤: 이번 세션에서 뺀 기존 파일을 실제로 지운다.
  void _commitPendingRemovals() {
    if (_pendingRemoved.isEmpty) return;
    final removed = List<String>.of(_pendingRemoved);
    _pendingRemoved.clear();
    unawaited(_store?.delete(removed) ?? Future<void>.value());
  }

  // 미저장 이탈: 이번 세션에서 추가한 파일을 지운다 (기존 파일은 손대지 않음).
  void _discardPendingAdded() {
    if (_pendingAdded.isEmpty) return;
    final added = List<String>.of(_pendingAdded);
    _pendingAdded.clear();
    _imageFiles.removeWhere(added.contains);
    unawaited(_store?.delete(added) ?? Future<void>.value());
  }
```

`_dispatchSave` (215-220행) 교체:

```dart
  void _dispatchSave() {
    final memo = _buildMemo();
    if (memo != null) {
      widget.onSave?.call(memo);
      _commitPendingRemovals();
    }
  }
```

`_saveMemo` (228-239행) 교체:

```dart
  void _saveMemo() {
    final memo = _buildMemo();
    if (memo == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.of(context).enterContent)));
      return;
    }
    _popHandled = true;
    widget.onSave?.call(memo);
    _commitPendingRemovals();
    Navigator.pop(context);
  }
```

`_cancelEdit` 의 마지막 3줄 (288-290행 `if (confirmed != true || !mounted) return; _popHandled = true; Navigator.pop(context);`) 교체:

```dart
    if (confirmed != true || !mounted) return;
    _discardPendingAdded();
    _popHandled = true;
    Navigator.pop(context);
```

- [ ] **Step 5: 사진 추가·삭제·뷰어 핸들러**

`_cancelEdit` 메서드 끝(`}`) 바로 뒤, `_handlePasteWithNewline` 앞에 추가:

```dart
  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addPhoto() async {
    final strings = AppStrings.of(context);
    if (_imageFiles.length >= AttachmentService.maxImages) {
      _snack(strings.photoLimitReached);
      return;
    }
    // 붙여넣기는 항상 노출 — 미리 클립보드를 읽어 활성/비활성을 정하면
    // iOS 「붙여넣기 허용?」 시스템 프롬프트가 두 번 뜬다.
    final source = await showCupertinoModalPopup<_PhotoSource>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, _PhotoSource.gallery),
            child: Text(strings.fromGallery),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, _PhotoSource.camera),
            child: Text(strings.fromCamera),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx, _PhotoSource.clipboard),
            child: Text(strings.pasteImage),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: Text(strings.cancel),
        ),
      ),
    );
    if (source == null || !mounted) return;

    final count = _imageFiles.length;
    AttachResult result;
    try {
      result = switch (source) {
        _PhotoSource.gallery => await _attachments.pickFromGallery(count),
        _PhotoSource.camera => await _attachments.takePhoto(count),
        _PhotoSource.clipboard => await _attachments.pasteFromClipboard(count),
      };
    } catch (e) {
      // AttachmentService.production() 이 스토어 미초기화로 던지는 경우 등.
      result = AttachFailed(e);
    }
    if (!mounted) return;

    switch (result) {
      case AttachOk(:final fileName):
        setState(() {
          _imageFiles.add(fileName);
          _pendingAdded.add(fileName);
        });
      case AttachCancelled():
        break;
      case AttachNoImage():
        _snack(strings.noImageInClipboard);
      case AttachLimit():
        _snack(strings.photoLimitReached);
      case AttachFailed():
        _snack(strings.photoAttachFailed);
    }
  }

  // 이번 세션에서 추가한 파일은 어느 메모도 참조하지 않으므로 즉시 삭제,
  // 기존 파일은 저장 시점까지 보류 (취소하면 복귀).
  void _removePhoto(String fileName) {
    if (!_imageFiles.contains(fileName)) return;
    setState(() {
      _imageFiles.remove(fileName);
      if (_pendingAdded.remove(fileName)) {
        unawaited(_store?.delete([fileName]) ?? Future<void>.value());
      } else {
        _pendingRemoved.add(fileName);
      }
    });
  }

  Future<void> _confirmRemovePhoto(int index) async {
    if (index < 0 || index >= _imageFiles.length) return;
    final fileName = _imageFiles[index];
    final strings = AppStrings.of(context);
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(strings.deletePhotoConfirmTitle),
        content: Text(strings.deletePhotoConfirmBody),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(strings.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(strings.deletePhotoConfirmTitle),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _removePhoto(fileName);
  }

  void _openViewer(int index) {
    AttachmentViewer.show(
      context,
      fileNames: List.of(_imageFiles),
      initialIndex: index,
      onDelete: _removePhoto,
    );
  }
```

파일 맨 아래(`final _largeCupertinoSelectionControls = ...;` 뒤)에:

```dart

enum _PhotoSource { gallery, camera, clipboard }
```

- [ ] **Step 6: 공유에 사진 동봉**

`_shareMemo` 의 `try { await Share.share(...) }` 블록 (255-260행) 교체:

```dart
    try {
      final store = _store;
      final files = <XFile>[
        if (store != null)
          for (final name in memo.imageFiles)
            if (store.fileFor(name).existsSync())
              XFile(store.fileFor(name).path, mimeType: 'image/jpeg'),
      ];
      if (files.isEmpty) {
        await Share.share(
          memo.content,
          subject: memo.title,
          sharePositionOrigin: _shareOriginRect(shareContext),
        );
      } else {
        await Share.shareXFiles(
          files,
          text: memo.content.isEmpty ? null : memo.content,
          subject: memo.title,
          sharePositionOrigin: _shareOriginRect(shareContext),
        );
      }
```

(`XFile` 은 `package:share_plus/share_plus.dart` 가 export 한다 — 추가 import 불필요.)

- [ ] **Step 7: AppBar 버튼 + 스트립**

AppBar `actions: [` (440행) 바로 다음, 기존 `ValueListenableBuilder<UndoHistoryValue>(` 앞에:

```dart
            IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 22),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
              color: palette.textPrimary,
              tooltip: AppStrings.of(context).addPhoto,
              onPressed: _addPhoto,
            ),
            const SizedBox(width: 8),
```

본문: `builder: (context, bodyFontSize, _) => TextField(` (513행) 을

```dart
                        builder: (context, bodyFontSize, _) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
```

로 바꾸고, TextField 가 닫히는 자리 — 기존 614-620행:

```dart
                            return AdaptiveTextSelectionToolbar.buttonItems(
                              anchors: anchors,
                              buttonItems: items,
                            );
                          },
                        ),
                      ),
```

을 다음으로 교체 (TextField `)` 뒤에 스트립 + Column 닫기, 그 다음 기존 ValueListenableBuilder 닫기):

```dart
                            return AdaptiveTextSelectionToolbar.buttonItems(
                              anchors: anchors,
                              buttonItems: items,
                            );
                          },
                            ),
                            // 사진 0장이면 위젯 자체를 넣지 않는다 → 기존 레이아웃 무변경.
                            if (_imageFiles.isNotEmpty)
                              AttachmentStrip(
                                fileNames: _imageFiles,
                                onTap: _openViewer,
                                onLongPress: _confirmRemovePhoto,
                              ),
                          ],
                        ),
                      ),
```

그 뒤 `dart format lib/screens/memo_edit_screen.dart` 로 들여쓰기를 정리한다 (내용 변경 없음).

- [ ] **Step 8: 통과 확인 + 기존 편집 화면 테스트 회귀 없음**

Run: `flutter analyze && flutter test test/screens/ test/l10n/`
Expected: `No issues found!`, 신규 9개 PASS, 기존 편집 화면·밀림 프로브·en 스모크 전부 PASS. (`use_build_context_synchronously` 경고가 나면 해당 `await` 뒤에 `if (!mounted) return;` 이 빠진 것 — 위 코드대로 보강.)

- [ ] **Step 9: 커밋**

```bash
git add lib/screens/memo_edit_screen.dart test/screens/memo_edit_image_test.dart
git -c user.email=gayoremix@gmail.com -c user.name=vulcan commit -m "feat(memoyo): 편집 화면 사진 추가·스트립·뷰어·저장/취소 수명·공유 동봉 (T-260829-022)"
```

---

### Task 10: 영구삭제 3경로 파일 정리 + cold start 고아 정리 + 앱 초기화

**Files:**
- Modify: `lib/services/memo_storage.dart`
- Modify: `lib/screens/trash_screen.dart:56-70`
- Modify: `lib/screens/memo_list_screen.dart:210-229`
- Modify: `lib/main.dart:50`
- Test: `test/services/memo_storage_images_test.dart`

휴지통 화면의 `_deleteForever`·`_emptyTrash` 는 저장소 로직을 화면 안에 들고 있어 UI 없이 테스트할 수 없다. `MemoStorage.deleteForever(ids)`·`MemoStorage.emptyTrash()` 로 옮기고(파일 삭제 포함) 화면은 호출만 한다 — 경계 정리 + 3경로가 한 곳(MemoStorage)에서 파일을 지운다.

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/services/memo_storage_images_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/memos/services/attachment_store.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/services/memo_storage.dart';

import '../features/memos/support/attachment_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  final now = DateTime(2026, 8, 29, 12);

  Memo memo(String id, {List<String> images = const [], DateTime? deletedAt}) =>
      Memo(id: id, content: id, createdAt: now, updatedAt: now, deletedAt: deletedAt, imageFiles: images);

  setUp(() async {
    tmp = await installTempStore();
  });

  tearDown(() {
    AttachmentStore.instance = null;
    tmp.deleteSync(recursive: true);
  });

  test('purgeExpiredTrash: 만료 메모의 파일만 삭제, 활성·미만료 파일 생존', () async {
    final old = await seedStoreFile('old.jpg');
    final fresh = await seedStoreFile('fresh.jpg');
    final keep = await seedStoreFile('keep.jpg');
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        memo('expired', images: [old], deletedAt: DateTime.now().subtract(const Duration(days: 31))),
        memo('recent', images: [fresh], deletedAt: DateTime.now().subtract(const Duration(days: 1))),
        memo('active', images: [keep]),
      ]),
    });

    expect(await MemoStorage.purgeExpiredTrash(), 1);

    final store = AttachmentStore.instance;
    expect(await store.exists(old), isFalse);
    expect(await store.exists(fresh), isTrue);
    expect(await store.exists(keep), isTrue);
    expect((await MemoStorage.loadMemos()).map((m) => m.id), ['recent', 'active']);
  });

  test('deleteForever: 지정 id 메모 제거 + 그 파일 삭제, 나머지 무변경', () async {
    final a = await seedStoreFile('a.jpg');
    final b = await seedStoreFile('b.jpg');
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        memo('x', images: [a], deletedAt: now),
        memo('y', images: [b], deletedAt: now),
      ]),
    });

    expect(await MemoStorage.deleteForever({'x'}), 1);

    expect(await AttachmentStore.instance.exists(a), isFalse);
    expect(await AttachmentStore.instance.exists(b), isTrue);
    expect((await MemoStorage.loadMemos()).map((m) => m.id), ['y']);
  });

  test('emptyTrash: 휴지통 전부 제거 + 파일 삭제, 활성 메모·파일 무변경', () async {
    final a = await seedStoreFile('a.jpg');
    final keep = await seedStoreFile('keep.jpg');
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        memo('trashed', images: [a], deletedAt: now),
        memo('active', images: [keep]),
      ]),
    });

    expect(await MemoStorage.emptyTrash(), 1);

    expect(await AttachmentStore.instance.exists(a), isFalse);
    expect(await AttachmentStore.instance.exists(keep), isTrue);
    expect((await MemoStorage.loadMemos()).map((m) => m.id), ['active']);
  });

  test('스토어 미초기화여도 삭제 경로는 크래시 없이 메모만 지운다', () async {
    AttachmentStore.instance = null;
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([memo('x', images: ['a.jpg'], deletedAt: now)]),
    });
    expect(await MemoStorage.deleteForever({'x'}), 1);
    expect(await MemoStorage.loadMemos(), isEmpty);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/services/memo_storage_images_test.dart`
Expected: 컴파일 실패 — `deleteForever`·`emptyTrash` 미정의.

- [ ] **Step 3: `MemoStorage` 구현**

`lib/services/memo_storage.dart` 전체 교체:

```dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/memos/services/attachment_store.dart';
import '../models/memo.dart';

class MemoStorage {
  static const _key = 'memos';

  static Future<List<Memo>> loadMemos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_key);
      if (data == null || data.isEmpty) return [];
      return Memo.decodeList(data);
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveMemos(List<Memo> memos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, Memo.encodeList(memos));
    } catch (e) {
      // 저장 실패 시 크래시 방지 — 다음 저장 시 재시도됨
      debugPrint('[MemoStorage.saveMemos] $e');
    }
  }

  /// [Memo.trashRetention](기본 30일) 지난 soft-deleted 메모를 영구 삭제한다.
  /// 활성 메모(deletedAt == null)는 절대 건드리지 않는다.
  /// 변경이 있을 때만 저장하고, 영구삭제된 메모 수를 반환한다.
  /// 호출 위치: cold start(_loadMemos) + app resume.
  static Future<int> purgeExpiredTrash() async {
    final cutoff = DateTime.now().subtract(Memo.trashRetention);
    return _removeWhere((m) {
      final d = m.deletedAt;
      if (d == null) return false; // 활성 — 유지
      return !d.isAfter(cutoff); // 보관기간 지난 휴지통만 제거
    });
  }

  /// 즉시 영구삭제 (휴지통 항목 개별). 제거된 메모 수 반환.
  static Future<int> deleteForever(Set<String> ids) =>
      _removeWhere((m) => ids.contains(m.id));

  /// 휴지통 비우기. 활성 메모(deletedAt == null)는 무변경. 제거된 메모 수 반환.
  static Future<int> emptyTrash() => _removeWhere((m) => m.deletedAt != null);

  /// 영구삭제 단일 펀넬 — 메모 제거 + 그 메모들의 첨부 파일 삭제 (T-260829-022).
  /// 파일 삭제는 메모 저장이 성공한 뒤에만, 스토어가 없으면(테스트·초기화 실패) 건너뛴다.
  static Future<int> _removeWhere(bool Function(Memo) shouldRemove) async {
    final all = await loadMemos();
    final removed = <Memo>[];
    final survivors = <Memo>[];
    for (final m in all) {
      (shouldRemove(m) ? removed : survivors).add(m);
    }
    if (removed.isEmpty) return 0;
    await saveMemos(survivors);
    final store = AttachmentStore.maybeInstance;
    if (store != null) {
      await store.delete(removed.expand((m) => m.imageFiles));
    }
    return removed.length;
  }
}
```

- [ ] **Step 4: 휴지통 화면을 펀넬로**

`lib/screens/trash_screen.dart` 56-70행 교체:

```dart
  // 즉시 영구삭제: 저장소에서 실제 제거(비가역). action sheet 가 확인 게이트.
  // 첨부 파일 삭제까지 MemoStorage 펀넬이 맡는다 (T-260829-022).
  Future<void> _deleteForever(Memo memo) async {
    await MemoStorage.deleteForever({memo.id});
    await _loadTrash();
  }

  // 휴지통 비우기: 휴지통 항목 전체 영구삭제. 활성 메모(deletedAt == null)는 무변경.
  Future<void> _emptyTrash() async {
    await MemoStorage.emptyTrash();
    await _loadTrash();
  }
```

- [ ] **Step 5: 목록 화면 cold start 고아 정리**

`lib/screens/memo_list_screen.dart` — `MemoListScreenState` 클래스 필드 자리(`with WidgetsBindingObserver {` 다음 줄)에:

```dart
  // 고아 첨부 파일 정리는 프로세스당 1회(cold start)만 — resume 때 돌리면
  // 열려 있는 편집 세션의 대기 파일(아직 어느 메모도 참조 안 함)을 지운다.
  static bool _orphanSweepDone = false;
```

`_loadMemos` (210-229행) 의 `final memos = await MemoStorage.loadMemos();` 바로 뒤에:

```dart
      final store = AttachmentStore.maybeInstance;
      if (store != null && !_orphanSweepDone) {
        _orphanSweepDone = true;
        unawaited(store.sweepOrphans(memos.expand((m) => m.imageFiles)));
      }
```

파일 상단 import 에 추가 (다른 `../` import 들 옆):

```dart
import 'dart:async';
import '../features/memos/services/attachment_store.dart';
```

(`dart:async` 가 이미 import 돼 있으면 중복 추가하지 않는다.)

- [ ] **Step 6: 앱 초기화**

`lib/main.dart` 50행 `await SettingsService.instance.init();` 바로 뒤에:

```dart
      // 첨부 사진 디렉토리 (T-260829-022). 실패해도 던지지 않는다 — 사진 기능만 비활성.
      await AttachmentStore.init();
```

import (14행 `import 'utils/app_palette.dart';` 옆):

```dart
import 'features/memos/services/attachment_store.dart';
```

- [ ] **Step 7: 통과 확인**

Run: `flutter analyze && flutter test test/services/ test/screens/trash_screen_test.dart test/screens/`
Expected: `No issues found!`, 신규 4 PASS, 기존 휴지통·목록 테스트 PASS. (`test/screens/trash_screen_test.dart` 가 없으면 그 인자만 빼고 `test/screens/` 전체로.)

- [ ] **Step 8: 커밋**

```bash
git add lib/services/memo_storage.dart lib/screens/trash_screen.dart lib/screens/memo_list_screen.dart lib/main.dart test/services/memo_storage_images_test.dart
git -c user.email=gayoremix@gmail.com -c user.name=vulcan commit -m "feat(memoyo): 영구삭제 3경로를 MemoStorage 펀넬로 + 첨부 파일 삭제, cold start 고아 정리, 스토어 init (T-260829-022)"
```

---

### Task 11: 목록·검색·휴지통 썸네일

**Files:**
- Modify: `lib/screens/memo_list_screen.dart:1002-1017`
- Modify: `lib/screens/search_screen.dart:401-406`
- Modify: `lib/screens/trash_screen.dart:188-191`
- Test: `test/screens/memo_list_thumbnail_test.dart`

목록 행은 `SizedBox(height: 48)` 고정(987-988행)이라 36px 썸네일이 **행 높이 변경 없이** 들어간다 — 리오더·스와이프 테스트는 그대로 통과해야 한다(스펙의 「행 높이 소폭 증가 감수」는 불필요해졌다).

- [ ] **Step 1: 실패하는 테스트 작성**

```dart
// test/screens/memo_list_thumbnail_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/memos/services/attachment_store.dart';
import 'package:simple_memo_app/features/memos/widgets/attachment_thumbnail.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';

import '../features/memos/support/attachment_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  final now = DateTime(2026, 8, 29, 12);

  Memo memo(String id, String title, {List<String> images = const []}) => Memo(
        id: id,
        content: '$title\n본문',
        createdAt: now,
        updatedAt: now,
        imageFiles: images,
      );

  setUp(() async {
    tmp = await installTempStore();
  });

  tearDown(() {
    AttachmentStore.instance = null;
    tmp.deleteSync(recursive: true);
  });

  testWidgets('사진 있는 행에만 36px 썸네일, 행 높이는 48 그대로', (tester) async {
    final a = await seedStoreFile('a.jpg');
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        memo('with', '사진 메모', images: [a]),
        memo('without', '글 메모'),
      ]),
    });

    await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(AttachmentThumbnail), findsOneWidget);
    expect(tester.getSize(find.byType(AttachmentThumbnail)), const Size(36, 36));

    final withRow = tester.getRect(find.ancestor(
      of: find.text('사진 메모'),
      matching: find.byType(SizedBox),
    ).first);
    final withoutRow = tester.getRect(find.ancestor(
      of: find.text('글 메모'),
      matching: find.byType(SizedBox),
    ).first);
    expect(withRow.height, withoutRow.height);
  });

  testWidgets('파일이 없으면(복원 뒤 등) 플레이스홀더, 예외 없음', (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([memo('lost', '유실 메모', images: ['gone.jpg'])]),
    });

    await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/screens/memo_list_thumbnail_test.dart`
Expected: FAIL — `find.byType(AttachmentThumbnail)` findsNothing.

- [ ] **Step 3: 목록 행**

`lib/screens/memo_list_screen.dart` — 별 아이콘 블록(1002-1016행 `if (widget.memo.isFavorite) Padding(...)`) 바로 뒤, `Expanded(` 앞에:

```dart
                        if (widget.memo.hasImages)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: AttachmentThumbnail(
                              fileName: widget.memo.imageFiles.first,
                            ),
                          ),
```

import 추가:

```dart
import '../features/memos/widgets/attachment_thumbnail.dart';
```

- [ ] **Step 4: 검색 결과 카드**

`lib/screens/search_screen.dart` 401-405행 별 아이콘 블록 뒤, `Expanded(` 앞에:

```dart
            if (memo.hasImages)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AttachmentThumbnail(fileName: memo.imageFiles.first, size: 32),
              ),
```

import 추가:

```dart
import '../features/memos/widgets/attachment_thumbnail.dart';
```

- [ ] **Step 5: 휴지통 행**

`lib/screens/trash_screen.dart` 188행 `return ListTile(` 의 `contentPadding:` 앞에:

```dart
                        leading: memo.hasImages
                            ? AttachmentThumbnail(fileName: memo.imageFiles.first)
                            : null,
```

import 추가:

```dart
import '../features/memos/widgets/attachment_thumbnail.dart';
```

- [ ] **Step 6: 통과 확인 (리오더·스와이프·검색·휴지통 회귀 포함)**

Run: `flutter analyze && flutter test test/screens/ test/l10n/`
Expected: `No issues found!`, 신규 2 PASS, 기존 전부 PASS.

- [ ] **Step 7: 커밋**

```bash
git add lib/screens/memo_list_screen.dart lib/screens/search_screen.dart lib/screens/trash_screen.dart test/screens/memo_list_thumbnail_test.dart
git -c user.email=gayoremix@gmail.com -c user.name=vulcan commit -m "feat(memoyo): 목록·검색·휴지통 행에 첫 사진 썸네일 (T-260829-022)"
```

---

### Task 12: 백업 화면 안내 문구

**Files:**
- Modify: `lib/screens/backup_restore_screen.dart:353-354`
- Test: `test/screens/backup_restore_photos_notice_test.dart`

- [ ] **Step 1: 실패하는 테스트 작성**

먼저 `test/screens/backup_restore_screen_test.dart` 를 열어 `BackupRestoreScreen` 을 어떻게 pump 하는지(생성자 인자·mock) 확인하고 같은 방식으로 pump 한다. 아래는 생성자 인자가 없는 경우의 형태이며, 인자가 있으면 기존 테스트의 pump 코드를 그대로 복사한다.

```dart
// test/screens/backup_restore_photos_notice_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/screens/backup_restore_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('백업 화면에 「사진은 백업에 포함되지 않습니다」 안내', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: BackupRestoreScreen()));
    await tester.pumpAndSettle();

    expect(find.text('사진은 백업에 포함되지 않습니다'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `flutter test test/screens/backup_restore_photos_notice_test.dart`
Expected: FAIL — findsNothing.

- [ ] **Step 3: 구현**

`lib/screens/backup_restore_screen.dart` 353행 `_lastBackupLabel()` Text 블록의 닫는 `),` 뒤, 354행 `const SizedBox(height: 28),` 앞에:

```dart
                  const SizedBox(height: 6),
                  // 1단계(T-260829-022): 백업 JSON 엔 사진 파일명만 실리고 실물은 안 간다.
                  Text(
                    AppStrings.of(context).photosNotInBackup,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.textSecondary.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
```

- [ ] **Step 4: 통과 확인**

Run: `flutter test test/screens/backup_restore_photos_notice_test.dart test/screens/backup_restore_screen_test.dart test/l10n/`
Expected: 전부 PASS.

- [ ] **Step 5: 커밋**

```bash
git add lib/screens/backup_restore_screen.dart test/screens/backup_restore_photos_notice_test.dart
git -c user.email=gayoremix@gmail.com -c user.name=vulcan commit -m "feat(memoyo): 백업 화면에 사진 미포함 안내 (T-260829-022)"
```

---

### Task 13: 문서 + 전체 게이트 + PR 갱신

**Files:**
- Modify: `lib/features/memos/README.md`
- Modify: `README.md` (기능 목록), `CHANGELOG.md`
- Modify: `docs/superpowers/specs/2026-08-29-memo-image-attachments-design.md` §3.2·§3.4·§3.6

- [ ] **Step 1: memos 도메인 README 의존 노트**

`lib/features/memos/README.md` 끝에 추가 (AGENTS.md 규칙 7 — 신규 파일이 레거시 top-level 을 2개 넘게 import 하면 노트):

```markdown

## Image attachments (T-260829-022)

- `services/attachment_store.dart` · `attachment_service.dart` · `image_ingest.dart`,
  `widgets/attachment_thumbnail.dart` · `attachment_strip.dart` · `attachment_viewer.dart`.
- Legacy imports: `models/memo.dart` (file-name validation), `l10n/app_strings.dart`,
  `utils/app_palette.dart`. These stay shared — they are app-wide, not memo-owned.
- `services/memo_storage.dart` (legacy) now imports `AttachmentStore` so that the single
  permanent-delete funnel also removes attachment files. That dependency points legacy → domain
  on purpose: file cleanup must never be skipped by a new delete path.
```

- [ ] **Step 2: README / CHANGELOG**

`README.md` 기능 목록에 한 줄: `- 메모에 사진 첨부 (사진첩·카메라·붙여넣기, 메모당 10장, 기기 내 저장 — 백업 미포함)`.
`CHANGELOG.md` 최신 섹션(Unreleased 또는 다음 버전)에: `- feat: 메모 이미지 첨부 1단계 — 사진첩·카메라·클립보드, 본문 아래 스트립, 목록 썸네일, 공유 동봉, 영구삭제 시 파일 정리 (T-260829-022)`.

- [ ] **Step 3: spec 정합**

spec §3.2 의 디렉토리 트리를 `lib/features/memos/services/…`·`widgets/…` 로, §3.4 표의 영구삭제 3경로를 `MemoStorage.deleteForever`·`emptyTrash`·`purgeExpiredTrash` 로, §3.6 의 「행 높이 소폭 증가 감수」를 「행 높이 48 유지 — 36px 썸네일이 안에 들어감」으로 고친다. 결정 자체(Q1~Q5·1안)는 손대지 않는다.

- [ ] **Step 4: 전체 게이트**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` + 전체 PASS (기존 ~124 + 신규 ~40). 실패가 있으면 그 출력을 그대로 보고에 싣고 고친 뒤 재실행 — 「통과했다」는 출력 첨부 후에만.

- [ ] **Step 5: 커밋 + push + PR 갱신**

```bash
git add lib/features/memos/README.md README.md CHANGELOG.md docs/superpowers/specs/2026-08-29-memo-image-attachments-design.md
git -c user.email=gayoremix@gmail.com -c user.name=vulcan commit -m "docs(memoyo): 이미지 첨부 README·CHANGELOG·spec 경로 정합 (T-260829-022)"
git push origin macmini/T-260829-022-image-attachments
```

PR #137 본문에 구현 범위·테스트 수·`flutter test` 결과 요약을 추가한다 (`gh pr edit 137 --repo ssamssae/simple-memo-app --body-file <path>`). `[no-auto-merge]` 유지 — 실기기 검증(§6) 전이다.

---

### Task 14 (별도 GO): 실기기 검증 — 물리 기기 R3

단위 테스트 전부 초록 뒤, 아니키 GO 받고 볼칸 USB 로:

1. `/device-run ios` (또는 android) 로 앱 실행.
2. 편집 화면 → 사진 추가 → 사진첩: 시스템 피커 → 선택 → 스트립에 썸네일. 카메라: 촬영 → 스트립. 붙여넣기: 다른 앱에서 스크린샷 복사 → 붙여넣기 → iOS 「붙여넣기 허용?」 1회 → 스트립.
3. 저장 → 목록 썸네일 36px 확인. 탭 → 뷰어 넘김·핀치. 삭제 → 확인 → 목록 반영.
4. 공유 → 시트에 사진 파일 동봉 확인.
5. 휴지통 → 영구삭제 → 파일 앱(iOS 파일/Android 탐색기 불가 시 `flutter run` 콘솔 `[AttachmentStore]` 로그) 로 파일 소실 확인.
6. 결과·스크린샷을 PR 코멘트 + mac-report 로 남기고, 통과 시 `[no-auto-merge]` 해제 요청.

---

## Self-Review (작성 후 점검 — 반영 완료)

- **Spec coverage**: §3.1 → Task 1 / §3.2 → Task 3(경로만 memos 도메인으로) / §3.3 → Task 4·5 / §3.4 → Task 9·10 / §3.5 → Task 9 / §3.6 → Task 11 / §3.7 → Task 12 / §3.8 → Task 2 / §3.9 → Task 6 / §4 → Task 2 / §5 → 각 Task 의 Step 1 + Task 13 Step 4 + Task 14 / §6 → Task 13 Step 5.
- **Placeholder**: TBD·TODO·「적절히 처리」 없음. 모든 코드 스텝에 코드 블록 있음.
- **Type consistency**: `AttachmentStore(root:)`·`.instance/.maybeInstance/.init()/.fileFor/.exists/.save/.delete/.sweepOrphans`, `AttachmentService(source:, compressor:, store:)`·`.production()`·`.pickFromGallery/.takePhoto/.pasteFromClipboard(int)`·`.deleteFiles`·`.store`, `AttachResult` 5종, `ImageSourcePort` 3메서드, `ImageCompressor.toJpeg(src, maxLongEdge:, quality:)`, `fitLongEdge(w,h,max)→(int,int)`, `AttachmentThumbnail(fileName:, size:, radius:)`, `AttachmentStrip(fileNames:, onTap:, onLongPress:)`, `AttachmentViewer(fileNames:, initialIndex:, onDelete:)`·`.show(...)`, `Memo.imageFiles/hasImages/isValidImageFileName`, `MemoStorage.deleteForever(Set<String>)/emptyTrash()/purgeExpiredTrash()` — 태스크 간 동일.
- **알려진 툴체인 주의**: Dart 3.10 와일드카드 `(_, _, _)`; `use_build_context_synchronously`; CI 는 Linux 라 플러그인 실호출 0 (전부 fake).
