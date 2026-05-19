# 메모요 1.0.7 (1) Drive 1버튼 백업 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 메모요 1.0.6+24 의 share sheet 자유 선택 export 흐름을 **Google Drive 명시 1버튼 백업** 으로 갈아끼운다. 사용자 1번 누름 = Drive 의 "Memoyo" 폴더 안에 자동 업로드 + rotate N=7. "내 메모 어디 갔어요" CS 시나리오 0.

**Architecture:** 신규 서비스 `DriveBackupService` 1개 (lib/services/drive_backup_service.dart) + `memo_list_screen` overflow menu 의 export 흐름 교체. `google_sign_in` 이 OAuth 시트, `googleapis` 의 DriveApi v3 가 Drive 호출, `extension_google_sign_in_as_googleapis_auth` 가 둘 연결. share_plus 패키지는 의존성 유지 (1.0.7 다른 항목 메모공유에서 사용), export 흐름의 호출만 제거.

**Tech Stack:** Flutter, Dart, google_sign_in ^6.2, googleapis ^13.x (drive_v3), extension_google_sign_in_as_googleapis_auth ^2.x, url_launcher ^6.x.

**Spec 참조:** `docs/superpowers/specs/2026-05-19-memoyo-drive-export-design.md`

---

## File Structure

신규 / 수정 파일 (정확한 경로):

- **Create**: `lib/services/drive_backup_service.dart` — DriveBackupService 클래스 + DriveBackupResult sealed class. 100~150 LoC.
- **Create**: `test/services/drive_backup_service_test.dart` — mock 기반 단위 테스트. ~200 LoC.
- **Modify**: `pubspec.yaml` — 4개 패키지 추가 (google_sign_in / googleapis / extension_google_sign_in_as_googleapis_auth / url_launcher). share_plus 라인은 유지.
- **Modify**: `lib/services/export_import_service.dart:32-56` — `shareExport()` 메서드 제거 (share_plus 호출 retire).
- **Modify**: `lib/screens/memo_list_screen.dart` — overflow menu 라벨 변경 + export case 호출 흐름 교체 + SnackBar 액션 추가.
- **Modify**: `test/services/export_import_service_test.dart` — shareExport 관련 케이스 제거 (있다면).
- **Modify**: `ios/Runner/Info.plist` — `CFBundleURLTypes` 에 `REVERSED_CLIENT_ID` URL scheme 추가.
- **수동 (코드 외)**: Google Cloud Console — OAuth client (iOS type + Android type) 생성, Android SHA-1 등록.
- **Modify**: `pubspec.yaml` 버전 — `1.0.6+24` → `1.0.7+25` (마지막 task 에서).
- **Modify**: `fastlane/metadata/android/ko-KR/changelogs/25.txt` — 신규 release notes (마지막 task).

---

## Task 1: 의존성 추가 + 검증

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: pubspec.yaml 의 dependencies 섹션에 4개 패키지 추가**

`share_plus: ^10.1.4` 라인 바로 아래에 다음 4줄 추가:

```yaml
  # Drive 1버튼 백업 (1.0.7 (1))
  google_sign_in: ^6.2.1
  googleapis: ^13.2.0
  extension_google_sign_in_as_googleapis_auth: ^2.0.12
  url_launcher: ^6.3.1
```

- [ ] **Step 2: flutter pub get 실행**

Run: `cd ~/simple_memo_app && flutter pub get`
Expected: `Got dependencies!` (또는 동등 메시지), pubspec.lock 갱신, 신규 의존성 다운로드 성공.

- [ ] **Step 3: flutter analyze 로 빌드 healthy 확인**

Run: `flutter analyze`
Expected: `No issues found!` (기존 코드 영향 없어야 함).

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "deps(memoyo): add google_sign_in/googleapis/url_launcher for 1.0.7 (1)"
```

---

## Task 2: DriveBackupResult sealed class + 단위 테스트

**Files:**
- Create: `lib/services/drive_backup_service.dart`
- Create: `test/services/drive_backup_service_test.dart`

- [ ] **Step 1: 테스트 파일 먼저 작성 — sealed class 의 5 variant 인스턴스화 가능 확인**

`test/services/drive_backup_service_test.dart` 생성:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/services/drive_backup_service.dart';

void main() {
  group('DriveBackupResult', () {
    test('Success holds folderUrl', () {
      const r = DriveBackupSuccess('https://drive.google.com/drive/folders/abc');
      expect(r.folderUrl, 'https://drive.google.com/drive/folders/abc');
    });

    test('NetworkError is distinct from Unknown', () {
      const a = DriveBackupNetworkError();
      const b = DriveBackupUnknown('boom');
      expect(a, isNot(equals(b)));
    });

    test('PermissionDenied / QuotaExceeded / Unknown all subtype DriveBackupResult', () {
      const list = <DriveBackupResult>[
        DriveBackupSuccess('x'),
        DriveBackupNetworkError(),
        DriveBackupPermissionDenied(),
        DriveBackupQuotaExceeded(),
        DriveBackupUnknown('msg'),
      ];
      expect(list.length, 5);
    });
  });
}
```

- [ ] **Step 2: 테스트 실행 → 컴파일 에러 (class 미정의)**

Run: `flutter test test/services/drive_backup_service_test.dart`
Expected: FAIL — "Error: Couldn't resolve the package 'simple_memo_app/services/drive_backup_service.dart'" 또는 "Undefined name 'DriveBackupSuccess'".

- [ ] **Step 3: lib/services/drive_backup_service.dart 생성 — sealed class 만 (메서드 X)**

```dart
sealed class DriveBackupResult {
  const DriveBackupResult();
}

class DriveBackupSuccess extends DriveBackupResult {
  final String folderUrl;
  const DriveBackupSuccess(this.folderUrl);
}

class DriveBackupNetworkError extends DriveBackupResult {
  const DriveBackupNetworkError();
}

class DriveBackupPermissionDenied extends DriveBackupResult {
  const DriveBackupPermissionDenied();
}

class DriveBackupQuotaExceeded extends DriveBackupResult {
  const DriveBackupQuotaExceeded();
}

class DriveBackupUnknown extends DriveBackupResult {
  final String message;
  const DriveBackupUnknown(this.message);
}
```

- [ ] **Step 4: 테스트 다시 실행 → PASS**

Run: `flutter test test/services/drive_backup_service_test.dart`
Expected: PASS — 3 tests passed.

- [ ] **Step 5: Commit**

```bash
git add lib/services/drive_backup_service.dart test/services/drive_backup_service_test.dart
git commit -m "feat(memoyo): DriveBackupResult sealed class skeleton"
```

---

## Task 3: GoogleSignIn 초기화 + AuthClient 헬퍼

**Files:**
- Modify: `lib/services/drive_backup_service.dart`
- Modify: `test/services/drive_backup_service_test.dart`

- [ ] **Step 1: 테스트 케이스 추가 — `_obtainAuthClient` 가 GoogleSignIn 의 signIn 실패 시 PermissionDenied 반환**

`test/services/drive_backup_service_test.dart` 에 mocktail 기반 테스트 추가. 먼저 dev_dependencies 확인 (mocktail 이미 있는지 grep):

```bash
grep -E 'mocktail|mockito' pubspec.yaml
```

mocktail 없으면 dev_dependencies 에 `mocktail: ^1.0.4` 추가 후 `flutter pub get`.

테스트 케이스:

```dart
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

class _MockGoogleSignIn extends Mock implements GoogleSignIn {}

void main() {
  // ... 기존 group ...

  group('DriveBackupService._obtainAuthClient', () {
    test('signIn 이 null 반환 시 PermissionDenied', () async {
      final gsi = _MockGoogleSignIn();
      when(() => gsi.signIn()).thenAnswer((_) async => null);
      final result = await DriveBackupService.obtainAuthClientForTest(gsi);
      expect(result, isA<DriveBackupPermissionDenied>());
    });
  });
}
```

- [ ] **Step 2: 테스트 실행 → FAIL ("obtainAuthClientForTest" 미정의)**

Run: `flutter test test/services/drive_backup_service_test.dart`
Expected: FAIL.

- [ ] **Step 3: drive_backup_service.dart 에 헬퍼 추가**

```dart
import 'package:google_sign_in/google_sign_in.dart';

class DriveBackupService {
  static const _scopes = ['https://www.googleapis.com/auth/drive.file'];
  static final _signIn = GoogleSignIn(scopes: _scopes);

  static Future<DriveBackupResult?> obtainAuthClientForTest(
      GoogleSignIn gsi) async {
    final account = await gsi.signIn();
    if (account == null) {
      return const DriveBackupPermissionDenied();
    }
    return null;
  }
}
```

(실제 AuthClient 반환 로직은 Task 4 에서 묶음 method 에 통합. 여기선 sign-in null 분기 검증만.)

- [ ] **Step 4: 테스트 PASS 확인**

Run: `flutter test test/services/drive_backup_service_test.dart`
Expected: PASS — 4 tests passed (sealed 3 + auth 1).

- [ ] **Step 5: Commit**

```bash
git add lib/services/drive_backup_service.dart test/services/drive_backup_service_test.dart pubspec.yaml pubspec.lock
git commit -m "feat(memoyo): GoogleSignIn drive.file scope + PermissionDenied 분기"
```

---

## Task 4: Memoyo 폴더 조회 + 생성 헬퍼

**Files:**
- Modify: `lib/services/drive_backup_service.dart`
- Modify: `test/services/drive_backup_service_test.dart`

- [ ] **Step 1: 테스트 추가 — Memoyo 폴더 없으면 생성, 있으면 그 id 반환**

```dart
import 'package:googleapis/drive/v3.dart' as drive;

class _MockDriveApi extends Mock implements drive.DriveApi {}
class _MockFilesResource extends Mock implements drive.FilesResource {}

void main() {
  // ... 기존 ...

  group('DriveBackupService._ensureMemoyoFolder', () {
    setUpAll(() {
      registerFallbackValue(drive.File());
    });

    test('폴더 없음 → 생성 후 id 반환', () async {
      final api = _MockDriveApi();
      final files = _MockFilesResource();
      when(() => api.files).thenReturn(files);
      when(() => files.list(
            q: any(named: 'q'),
            spaces: any(named: 'spaces'),
            $fields: any(named: r'$fields'),
          )).thenAnswer((_) async => drive.FileList(files: []));
      when(() => files.create(any(), $fields: any(named: r'$fields')))
          .thenAnswer((_) async => drive.File()..id = 'newFolderId');

      final id = await DriveBackupService.ensureMemoyoFolderForTest(api);
      expect(id, 'newFolderId');
    });

    test('폴더 이미 있음 → 기존 id 반환, create 호출 X', () async {
      final api = _MockDriveApi();
      final files = _MockFilesResource();
      when(() => api.files).thenReturn(files);
      when(() => files.list(
            q: any(named: 'q'),
            spaces: any(named: 'spaces'),
            $fields: any(named: r'$fields'),
          )).thenAnswer((_) async => drive.FileList(files: [
                drive.File()..id = 'existingId',
              ]));

      final id = await DriveBackupService.ensureMemoyoFolderForTest(api);
      expect(id, 'existingId');
      verifyNever(() => files.create(any(), $fields: any(named: r'$fields')));
    });
  });
}
```

- [ ] **Step 2: 테스트 FAIL 확인**

Run: `flutter test test/services/drive_backup_service_test.dart`
Expected: FAIL — "ensureMemoyoFolderForTest" 미정의.

- [ ] **Step 3: drive_backup_service.dart 에 헬퍼 추가**

```dart
import 'package:googleapis/drive/v3.dart' as drive;

class DriveBackupService {
  // ... 기존 ...

  static Future<String> ensureMemoyoFolderForTest(drive.DriveApi api) async {
    const folderName = 'Memoyo';
    const folderMime = 'application/vnd.google-apps.folder';
    final query =
        "name = '$folderName' and mimeType = '$folderMime' and trashed = false";
    final list = await api.files.list(
      q: query,
      spaces: 'drive',
      $fields: 'files(id, name)',
    );
    if (list.files != null && list.files!.isNotEmpty) {
      return list.files!.first.id!;
    }
    final folder = await api.files.create(
      drive.File()
        ..name = folderName
        ..mimeType = folderMime,
      $fields: 'id',
    );
    return folder.id!;
  }
}
```

- [ ] **Step 4: 테스트 PASS 확인**

Run: `flutter test test/services/drive_backup_service_test.dart`
Expected: PASS — 6 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/services/drive_backup_service.dart test/services/drive_backup_service_test.dart
git commit -m "feat(memoyo): ensureMemoyoFolder — search or create"
```

---

## Task 5: 백업 파일 멀티파트 업로드 헬퍼

**Files:**
- Modify: `lib/services/drive_backup_service.dart`
- Modify: `test/services/drive_backup_service_test.dart`

- [ ] **Step 1: 테스트 추가 — uploadFile 가 올바른 metadata + bytes 로 DriveApi.files.create 호출**

```dart
group('DriveBackupService._uploadJsonFile', () {
  test('multipart media 로 업로드 호출', () async {
    final api = _MockDriveApi();
    final files = _MockFilesResource();
    when(() => api.files).thenReturn(files);
    when(() => files.create(
          any(),
          uploadMedia: any(named: 'uploadMedia'),
          $fields: any(named: r'$fields'),
        )).thenAnswer((_) async => drive.File()..id = 'uploadedId');

    final id = await DriveBackupService.uploadJsonFileForTest(
      api,
      folderId: 'memoyoFolderId',
      filename: 'memoyo-export-2026-05-19-201700.json',
      jsonBytes: const [123, 125], // "{}"
    );
    expect(id, 'uploadedId');

    final captured = verify(() => files.create(
          captureAny(),
          uploadMedia: any(named: 'uploadMedia'),
          $fields: any(named: r'$fields'),
        )).captured;
    final meta = captured.first as drive.File;
    expect(meta.name, 'memoyo-export-2026-05-19-201700.json');
    expect(meta.parents, ['memoyoFolderId']);
    expect(meta.mimeType, 'application/json');
  });
});
```

- [ ] **Step 2: 테스트 FAIL 확인**

Run: `flutter test test/services/drive_backup_service_test.dart`
Expected: FAIL — "uploadJsonFileForTest" 미정의.

- [ ] **Step 3: 헬퍼 추가**

```dart
import 'dart:async';

class DriveBackupService {
  // ...

  static Future<String> uploadJsonFileForTest(
    drive.DriveApi api, {
    required String folderId,
    required String filename,
    required List<int> jsonBytes,
  }) async {
    final media = drive.Media(
      Stream<List<int>>.fromIterable([jsonBytes]),
      jsonBytes.length,
      contentType: 'application/json',
    );
    final result = await api.files.create(
      drive.File()
        ..name = filename
        ..parents = [folderId]
        ..mimeType = 'application/json',
      uploadMedia: media,
      $fields: 'id',
    );
    return result.id!;
  }
}
```

- [ ] **Step 4: 테스트 PASS**

Run: `flutter test test/services/drive_backup_service_test.dart`
Expected: PASS — 7 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/services/drive_backup_service.dart test/services/drive_backup_service_test.dart
git commit -m "feat(memoyo): uploadJsonFile — multipart media upload"
```

---

## Task 6: rotate (N=7) 로직

**Files:**
- Modify: `lib/services/drive_backup_service.dart`
- Modify: `test/services/drive_backup_service_test.dart`

- [ ] **Step 1: 테스트 추가 — 7 초과면 초과분 만큼 가장 오래된 것부터 삭제**

```dart
group('DriveBackupService._rotate', () {
  test('7개 → 1개 추가 후 호출 → 8개 → 1개 삭제 → 7개 유지', () async {
    final api = _MockDriveApi();
    final files = _MockFilesResource();
    when(() => api.files).thenReturn(files);
    // 8개 파일 (createdTime 오름차순)
    final fileList = drive.FileList(files: [
      for (int i = 0; i < 8; i++) drive.File()..id = 'f$i',
    ]);
    when(() => files.list(
          q: any(named: 'q'),
          spaces: any(named: 'spaces'),
          orderBy: any(named: 'orderBy'),
          $fields: any(named: r'$fields'),
        )).thenAnswer((_) async => fileList);
    when(() => files.delete(any())).thenAnswer((_) async {});

    await DriveBackupService.rotateForTest(api, folderId: 'memoyoId', keep: 7);
    verify(() => files.delete('f0')).called(1);
    verifyNever(() => files.delete('f1'));
  });

  test('9개 → 1개 추가 후 호출 → 10개 → 3개 삭제 → 7개 유지', () async {
    final api = _MockDriveApi();
    final files = _MockFilesResource();
    when(() => api.files).thenReturn(files);
    final fileList = drive.FileList(files: [
      for (int i = 0; i < 10; i++) drive.File()..id = 'f$i',
    ]);
    when(() => files.list(
          q: any(named: 'q'),
          spaces: any(named: 'spaces'),
          orderBy: any(named: 'orderBy'),
          $fields: any(named: r'$fields'),
        )).thenAnswer((_) async => fileList);
    when(() => files.delete(any())).thenAnswer((_) async {});

    await DriveBackupService.rotateForTest(api, folderId: 'memoyoId', keep: 7);
    verify(() => files.delete('f0')).called(1);
    verify(() => files.delete('f1')).called(1);
    verify(() => files.delete('f2')).called(1);
    verifyNever(() => files.delete('f3'));
  });

  test('7개 이하 → 삭제 호출 0', () async {
    final api = _MockDriveApi();
    final files = _MockFilesResource();
    when(() => api.files).thenReturn(files);
    final fileList = drive.FileList(files: [
      for (int i = 0; i < 5; i++) drive.File()..id = 'f$i',
    ]);
    when(() => files.list(
          q: any(named: 'q'),
          spaces: any(named: 'spaces'),
          orderBy: any(named: 'orderBy'),
          $fields: any(named: r'$fields'),
        )).thenAnswer((_) async => fileList);

    await DriveBackupService.rotateForTest(api, folderId: 'memoyoId', keep: 7);
    verifyNever(() => files.delete(any()));
  });
});
```

- [ ] **Step 2: 테스트 FAIL 확인**

Run: `flutter test test/services/drive_backup_service_test.dart`
Expected: FAIL — "rotateForTest" 미정의.

- [ ] **Step 3: 헬퍼 추가**

```dart
class DriveBackupService {
  // ...

  static Future<void> rotateForTest(
    drive.DriveApi api, {
    required String folderId,
    required int keep,
  }) async {
    final query =
        "'$folderId' in parents and mimeType = 'application/json' and trashed = false";
    final list = await api.files.list(
      q: query,
      spaces: 'drive',
      orderBy: 'createdTime',
      $fields: 'files(id, name, createdTime)',
    );
    final files = list.files ?? [];
    if (files.length <= keep) return;
    final excess = files.length - keep;
    for (int i = 0; i < excess; i++) {
      await api.files.delete(files[i].id!);
    }
  }
}
```

- [ ] **Step 4: 테스트 PASS**

Run: `flutter test test/services/drive_backup_service_test.dart`
Expected: PASS — 10 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/services/drive_backup_service.dart test/services/drive_backup_service_test.dart
git commit -m "feat(memoyo): rotate N=7 — drop oldest excess"
```

---

## Task 7: uploadBackup() 통합 메서드 + 에러 매핑

**Files:**
- Modify: `lib/services/drive_backup_service.dart`
- Modify: `test/services/drive_backup_service_test.dart`

- [ ] **Step 1: 테스트 추가 — 4 에러 케이스 매핑 검증**

```dart
import 'dart:io';

group('DriveBackupService 에러 매핑', () {
  test('SocketException → NetworkError', () {
    final r = DriveBackupService.mapErrorForTest(
        const SocketException('no network'));
    expect(r, isA<DriveBackupNetworkError>());
  });

  test('drive.DetailedApiRequestError 403 storageQuotaExceeded → QuotaExceeded',
      () {
    final err = drive.DetailedApiRequestError(403, 'storageQuotaExceeded');
    final r = DriveBackupService.mapErrorForTest(err);
    expect(r, isA<DriveBackupQuotaExceeded>());
  });

  test('drive.DetailedApiRequestError 401 → PermissionDenied', () {
    final err = drive.DetailedApiRequestError(401, 'unauthorized');
    final r = DriveBackupService.mapErrorForTest(err);
    expect(r, isA<DriveBackupPermissionDenied>());
  });

  test('그 외 Exception → Unknown', () {
    final r = DriveBackupService.mapErrorForTest(Exception('something else'));
    expect(r, isA<DriveBackupUnknown>());
  });
});
```

- [ ] **Step 2: 테스트 FAIL 확인**

Run: `flutter test test/services/drive_backup_service_test.dart`
Expected: FAIL — "mapErrorForTest" 미정의.

- [ ] **Step 3: 에러 매핑 + uploadBackup 통합 메서드**

```dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import '../models/memo.dart';

class DriveBackupService {
  // ... 기존 ...

  static DriveBackupResult mapErrorForTest(Object e) {
    if (e is SocketException) return const DriveBackupNetworkError();
    if (e is drive.DetailedApiRequestError) {
      if (e.status == 403 &&
          (e.message?.contains('storageQuotaExceeded') ?? false)) {
        return const DriveBackupQuotaExceeded();
      }
      if (e.status == 401 || e.status == 403) {
        return const DriveBackupPermissionDenied();
      }
    }
    return DriveBackupUnknown(e.toString());
  }

  static Future<DriveBackupResult> uploadBackup(List<Memo> memos) async {
    try {
      final account = await _signIn.signIn();
      if (account == null) return const DriveBackupPermissionDenied();
      final authClient = await _signIn.authenticatedClient();
      if (authClient == null) return const DriveBackupPermissionDenied();

      final api = drive.DriveApi(authClient);
      final folderId = await ensureMemoyoFolderForTest(api);

      final ts = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final filename = 'memoyo-export-$ts.json';
      final jsonStr = Memo.encodeList(memos);
      final bytes = utf8.encode(jsonStr);

      await uploadJsonFileForTest(
        api,
        folderId: folderId,
        filename: filename,
        jsonBytes: bytes,
      );

      await rotateForTest(api, folderId: folderId, keep: 7);

      final folderUrl = 'https://drive.google.com/drive/folders/$folderId';
      return DriveBackupSuccess(folderUrl);
    } catch (e) {
      return mapErrorForTest(e);
    }
  }
}
```

- [ ] **Step 4: 테스트 PASS**

Run: `flutter test test/services/drive_backup_service_test.dart`
Expected: PASS — 14 tests.

- [ ] **Step 5: flutter analyze 통과 확인**

Run: `flutter analyze`
Expected: `No issues found!`.

- [ ] **Step 6: Commit**

```bash
git add lib/services/drive_backup_service.dart test/services/drive_backup_service_test.dart
git commit -m "feat(memoyo): uploadBackup integration + 4-case error mapping"
```

---

## Task 8: memo_list_screen — 메뉴 라벨 + 호출 흐름 교체

**Files:**
- Modify: `lib/screens/memo_list_screen.dart`
- Modify: `test/screens/memo_list_screen_test.dart` (없으면 skip, 있으면 라벨 변경 반영)

- [ ] **Step 1: memo_list_screen.dart 의 overflow menu 항목 라벨 변경**

기존 (검색 grep: `메모 내보내기`) → `Drive 에 백업` 으로 1곳 교체.
PopupMenuItem 의 value 도 `'export'` → `'drive_backup'` 으로 변경 (호환 함의: 새 case 추가하니 기존 'export' value 호출처도 같이 정리).

- [ ] **Step 2: `_onOverflowSelected` 의 `'export'` case → `'drive_backup'` case 로 교체, 흐름 갈아끼움**

기존 `'export'` case 의 share_plus 호출 흐름 (memo_list_screen.dart:126-150 부근) 을 다음으로 교체:

```dart
if (value == 'drive_backup') {
  if (_memos.isEmpty) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('내보낼 메모가 없습니다')),
    );
    return;
  }
  final result = await DriveBackupService.uploadBackup(_memos);
  if (!mounted) return;
  switch (result) {
    case DriveBackupSuccess(:final folderUrl):
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Drive 에 저장됐어요'),
          action: SnackBarAction(
            label: 'Memoyo 폴더 열기',
            onPressed: () async {
              final uri = Uri.parse(folderUrl);
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
        ),
      );
    case DriveBackupNetworkError():
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인터넷 연결을 확인해주세요')),
      );
    case DriveBackupPermissionDenied():
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Drive 권한이 필요해요')),
      );
    case DriveBackupQuotaExceeded():
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Drive 용량이 부족해요')),
      );
    case DriveBackupUnknown(:final message):
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Drive 백업 실패: $message')),
      );
  }
  return;
}
```

상단 import 에 다음 추가:

```dart
import 'package:url_launcher/url_launcher.dart';
import '../services/drive_backup_service.dart';
```

- [ ] **Step 3: flutter analyze 통과**

Run: `flutter analyze`
Expected: `No issues found!`. 만약 `'export'` 잔재 case (없는 value 호출처) 가 있으면 같이 제거.

- [ ] **Step 4: flutter test 전체 통과 (DriveBackupService 14 + 기존)**

Run: `flutter test`
Expected: All tests passed.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/memo_list_screen.dart
git commit -m "feat(memoyo): wire overflow menu to DriveBackupService + SnackBar 액션"
```

---

## Task 9: ExportImportService.shareExport 메서드 retire

**Files:**
- Modify: `lib/services/export_import_service.dart`
- Modify: `test/services/export_import_service_test.dart`

- [ ] **Step 1: export_import_service.dart 에서 shareExport 메서드 + share_plus import 제거**

`lib/services/export_import_service.dart` 의 line 6 (`import 'package:share_plus/share_plus.dart';`) 와 line 32-56 (`static Future<void> shareExport(...)` 전체) 제거. `dart:ui` 의 `Rect` 사용도 함께 정리 (다른 곳에서 안 쓰면 import 제거).

- [ ] **Step 2: export_import_service_test.dart 에서 shareExport 관련 케이스 제거 (있다면)**

`grep -n 'shareExport' test/services/export_import_service_test.dart` 로 확인. 매칭 없으면 skip. 있으면 해당 test 케이스 + 의존 코드 제거.

- [ ] **Step 3: flutter analyze 통과**

Run: `flutter analyze`
Expected: `No issues found!`. 만약 잔재 호출처 있으면 같이 정리.

- [ ] **Step 4: flutter test 전체 통과**

Run: `flutter test`
Expected: All tests passed.

- [ ] **Step 5: Commit**

```bash
git add lib/services/export_import_service.dart test/services/export_import_service_test.dart
git commit -m "refactor(memoyo): retire ExportImportService.shareExport (share_plus export 흐름)"
```

---

## Task 10: iOS Info.plist URL scheme (자동 부분)

**Files:**
- Modify: `ios/Runner/Info.plist`

> **수동 단계 필요 — Task 11 에 박힘. 본 task 는 Info.plist 의 URL scheme 자리만 미리 박는 것. REVERSED_CLIENT_ID 값은 Task 11 의 Google Cloud Console 단계에서 받아옴.**

- [ ] **Step 1: Info.plist 의 `<dict>` 최상위에 CFBundleURLTypes 자리 추가**

`ios/Runner/Info.plist` 의 `</dict>\n</plist>` 직전에 다음 블록 추가 (REVERSED_CLIENT_ID 자리는 placeholder, Task 11 수동 단계에서 실제 값으로 교체):

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>REVERSED_CLIENT_ID_PLACEHOLDER</string>
        </array>
    </dict>
</array>
```

- [ ] **Step 2: flutter build ios --debug --no-codesign 으로 빌드 가능 확인 (placeholder 라도 syntax 통과)**

Run: `flutter build ios --debug --no-codesign --simulator`
Expected: Build 성공 (URL scheme placeholder 라도 plist 문법 OK).

- [ ] **Step 3: Commit (placeholder 상태)**

```bash
git add ios/Runner/Info.plist
git commit -m "ios(memoyo): CFBundleURLTypes 자리 추가 (REVERSED_CLIENT_ID placeholder)"
```

---

## Task 11: 수동 단계 — Google Cloud Console OAuth client 셋업

> **⚠️ 형님 손 1회 필수 단계. 자동화 불가 (Google Cloud Console GUI).**
> **챗봇이 안내 메시지만 surface 하고, 형님이 ack 후 placeholder → 실제 값 교체까지 자동 commit.**

- [ ] **Step 1: 챗봇 → 형님 안내 메시지 (Telegram reply)**

본 task 진입 직전 챗봇이 다음을 텔레그램으로 surface:

- Google Cloud Console 접속 → 메모요 전용 프로젝트 생성 (또는 기존 재사용 — 1.0.4 sync 시기 Firebase 프로젝트 있었으면 재사용 가능, 메모리 grep 1번)
- APIs & Services → OAuth consent screen → External + 메모요 앱 정보 입력 (앱 이름 "메모요", 지원 이메일 강대종, 개발자 연락처)
- Credentials → Create Credentials → OAuth client ID
  - (a) Application type: iOS → Bundle ID = `com.daejongkang.memoyo` (또는 메모요 실제 bundle id, grep 으로 확인) → 생성 후 받은 **REVERSED_CLIENT_ID** (예: `com.googleusercontent.apps.1234567890-abc`) 챗봇에 텔레그램 reply 로 전달
  - (b) Application type: Android → Package name = `com.daejongkang.memoyo` (또는 실제) + SHA-1 = (메모요 release keystore SHA-1, 챗봇이 한 줄 명령으로 추출해 surface)

- [ ] **Step 2: 챗봇 — release keystore SHA-1 추출 자동 (형님 손 0)**

Run: `cd ~/simple_memo_app && keytool -list -v -keystore $(grep storeFile android/key.properties | cut -d= -f2 | tr -d ' ') -alias $(grep keyAlias android/key.properties | cut -d= -f2 | tr -d ' ') -storepass $(grep storePassword android/key.properties | cut -d= -f2 | tr -d ' ') 2>&1 | grep 'SHA1:'`
Expected: `SHA1: AB:CD:...` 한 줄. 챗봇이 이 값을 텔레그램 reply 로 surface.

- [ ] **Step 3: 형님 — Google Cloud Console GUI 작업 (1회, ~10분)**

형님이 위 안내 따라 (a) iOS OAuth client + (b) Android OAuth client 생성. (a) 의 REVERSED_CLIENT_ID 1줄을 텔레그램으로 챗봇에 전달.

- [ ] **Step 4: 챗봇 — Info.plist placeholder 교체 (자동)**

Run: `sed -i.bak "s/REVERSED_CLIENT_ID_PLACEHOLDER/<형님이_보내준_REVERSED_CLIENT_ID>/" ios/Runner/Info.plist && rm ios/Runner/Info.plist.bak`
Expected: Info.plist 의 placeholder 가 실제 값으로 교체. diff 1줄.

- [ ] **Step 5: flutter build ios --debug --no-codesign 로 빌드 healthy 확인**

Run: `flutter build ios --debug --no-codesign --simulator`
Expected: 빌드 통과.

- [ ] **Step 6: Commit**

```bash
git add ios/Runner/Info.plist
git commit -m "ios(memoyo): REVERSED_CLIENT_ID 실제 값 (OAuth iOS client)"
```

---

## Task 12: 버전 bump 1.0.6+24 → 1.0.7+25

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: sed -i 로 version 라인 한 줄 교체**

Run: `sed -i.bak 's/^version: 1.0.6+24$/version: 1.0.7+25/' pubspec.yaml && rm pubspec.yaml.bak`
Expected: diff 1줄 (version 라인만).

- [ ] **Step 2: flutter pub get 로 lock 갱신**

Run: `flutter pub get`
Expected: pubspec.lock 의 version 필드 갱신.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(memoyo): bump version 1.0.6+24 → 1.0.7+25"
```

---

## Task 13: Release notes (Android changelog)

**Files:**
- Create: `fastlane/metadata/android/ko-KR/changelogs/25.txt`

- [ ] **Step 1: changelog 파일 생성**

`fastlane/metadata/android/ko-KR/changelogs/25.txt` 내용:

```
1.0.7 (1) Drive 1버튼 백업
- 메모 백업이 이제 Google Drive 의 "Memoyo" 폴더에 한 번에 저장됩니다.
- 백업 7개까지 자동 보관, 8개째 누르면 가장 오래된 1개를 자동으로 정리합니다.
- "내 메모 어디 갔지" 걱정 0 — 백업은 항상 같은 자리에 있습니다.
```

- [ ] **Step 2: Commit**

```bash
git add fastlane/metadata/android/ko-KR/changelogs/25.txt
git commit -m "fastlane(memoyo): release notes for 1.0.7+25"
```

---

## Task 14: Manual smoke test (형님 손 1회 + 챗봇 결과 capture)

> **⚠️ 형님 손 1회 필수 — 실제 Drive 백업 동작 검증.**
> **챗봇이 mac mini night-builder v2 에 빌드 위임, 형님이 iPhone17 / Galaxy S24 에서 메뉴 클릭.**

- [ ] **Step 1: 챗봇 — Mac mini 에 release 빌드 위임**

Run: `~/.claude/automations/scripts/mac-mini-directive.sh -f /tmp/build-107-25.txt`
(directive 본문: "메모요 1.0.7+25 release ipa + aab 빌드 → mac-report.sh 로 본진 reverse reply")

Expected: Mac mini night-builder v2 가 빌드 완료 보고. ~30분.

- [ ] **Step 2: 형님 — iPhone17 / Galaxy S24 에서 메모요 1.0.7+25 설치 + "Drive 에 백업" 클릭**

형님 손:
- 폰에 새 빌드 설치 (TestFlight / Play Console Internal)
- 메모요 열기 → AppBar 우측 ⋮ → "Drive 에 백업" 클릭
- (첫 누름) Google 계정 시트 → 강대종 본인 계정 선택 → 권한 동의
- SnackBar "Drive 에 저장됐어요" 확인 → 액션 "Memoyo 폴더 열기" 누름 → Drive 앱에서 Memoyo 폴더 열림, 백업 1개 박힘 확인

8번 연속 클릭 → 폴더에 7개만 남는지 확인 (rotate 동작).

- [ ] **Step 3: 형님 — 결과 챗봇에 텔레그램 reply 로 surface**

형님이 챗봇에 "smoke PASS" 또는 "실패: <증상>" 1줄. 챗봇이 worklog/done 박음.

- [ ] **Step 4: PASS 시 → Task 15 (PR 머지 + ASC/Play 제출). FAIL 시 → 증상 surface 후 디버그 cycle**

---

## Task 15: PR 머지 + 스토어 제출 위임

> **⚠️ 1.0.7 메이저 = 메이저 PR. 자동 squash merge 룰의 메이저 ack 흐름 유지 (spec/docs only 예외 적용 X — 본 PR 은 코드 변경 포함).**

- [ ] **Step 1: PR 생성 (Task 14 PASS 후)**

Run: `gh pr create --title "feat(memoyo): 1.0.7 (1) Drive 1버튼 백업" --body "$(<docs/superpowers/plans/2026-05-19-memoyo-drive-export.md cat | head -50)"`
Expected: PR # 반환.

- [ ] **Step 2: 챗봇 — 형님께 ack 요청 (텔레그램)**

본진 챗봇이 PR # + 변경 요약 + smoke test PASS 증거 텔레그램으로 surface. "ㄱ" / "머지" 명시 ack 받기.

- [ ] **Step 3: 형님 ack 후 — 챗봇 squash merge**

Run: `gh pr merge <PR#> --squash --delete-branch`
Expected: main 에 머지, 브랜치 자동 삭제.

- [ ] **Step 4: 챗봇 — Mac mini 에 ASC/Play 업로드 위임**

Run: `~/.claude/automations/scripts/mac-mini-directive.sh -f /tmp/submit-107-25.txt`
(directive 본문: "메모요 1.0.7+25 ASC TestFlight + Play Internal 업로드, 결과 reverse reply")

Expected: Mac mini submit-app 스킬 호출 → 업로드 → 결과 reverse reply.

- [ ] **Step 5: 챗봇 — 텔레그램 reply 로 형님께 최종 보고**

업로드 완료 + 검토 상태 + 다음 단계 (TestFlight 옵트인 / Play Internal 옵트인 / 형님 폰 자동 업데이트 도달 예상 시각).

---

## Self-Review 체크리스트

(plan 작성 직후 챗봇이 자체 점검 — 형님 손 0)

**1. Spec coverage**: spec 의 각 섹션을 task 에 매핑.

- §1 결정 요약 → 전체 plan motivation
- §2 비기능 박제 → Task 7 (drive.file scope, rotate N=7) + Task 8 (SnackBar)
- §3.1 Drive 1버튼 → Task 3+4+5+6+7+8
- §3.2 가져오기 / §3.3 undo / §3.4 전체 선택 → 변경 없음, plan task 없음
- §4 데이터 모델 → Task 5 (filename 포맷), Task 6 (rotate)
- §5 의존성 → Task 1 + Task 9 (share_plus retire)
- §6 아키텍처 → Task 2~8 전체
- §7 UI 변경 → Task 8
- §8 에러 처리 → Task 7
- §9 안 하는 것 → plan task 없음 (negative requirement, plan 안 위반 확인용)
- §10 iOS/Android 셋업 → Task 10 + Task 11
- §11 테스트 → Task 2~7 의 unit test, Task 14 manual smoke
- §12 plan 참조 → 본 문서

**2. Placeholder scan**: "TBD" / "TODO" / "implement later" / "appropriate error handling" 검색.

- Task 10 의 `REVERSED_CLIENT_ID_PLACEHOLDER` 는 의도된 placeholder (Task 11 에서 교체). spec 명시 OK.
- 그 외 placeholder 없음.

**3. Type consistency**: method 명/property 명/class 명 task 간 일치.

- `uploadBackup` (public) / `ensureMemoyoFolderForTest` / `uploadJsonFileForTest` / `rotateForTest` / `mapErrorForTest` / `obtainAuthClientForTest` 일관.
- `DriveBackupResult` sealed class + 5 variant (Success/NetworkError/PermissionDenied/QuotaExceeded/Unknown) 일관.
- `folderUrl` / `message` property 명 일관.

**4. 빠진 항목**:
- spec §11 의 "memo_list_screen 위젯 테스트" — Task 8 에서 명시 안 함. plan 시 본진 판단으로 inline 추가 또는 skip 결정 (위젯 테스트 작성 cost vs gain).
- mocktail dev_dependency 추가 — Task 3 안에 inline 박음.

---

## Execution Options

plan 작성 완료. 실행 옵션 3가지:

**(1) Subagent-Driven (writing-plans 권장 디폴트)** — 본진 안에서 task 별 fresh subagent 디스패치. 각 task 종료 후 본진 챗봇 review 후 다음 task. 토큰 비용 영향 큼 (subagent 1개당 ~3K input 토큰 + 작업 분량 output). 형님 손 0 으로 Task 1~10 까지 자동 진행 (Task 11 manual / Task 14 manual 만 형님 손).

**(2) Inline Execution** — 본진 단일 세션이 task 차례로 직접 작업. 토큰 비용 적당. 형님 손 0, 속도는 (1) 보다 약간 느림.

**(3) loop-fleet 5노드 dynamic fan-out** — Flutter 빌드 환경이 본진 + Mac mini 만 있어서 5노드 적합도 낮음. 분산 가능 task 는 사실상 (test 작성 vs 구현) 정도. 추천 X.

**비용 사전 경고 (CLAUDE.md hard rule)**: (1) Subagent-Driven 은 토큰 비용 영향 있음. (2) Inline 은 비용 적당. 발동 직전 형님 ack 1회 받음.
