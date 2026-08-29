import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/memos/services/attachment_store.dart';
import 'package:simple_memo_app/features/memos/widgets/attachment_thumbnail.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';

import '../features/memos/support/attachment_test_support.dart';

/// [done] 이 true 될 때까지 5ms 간격으로 폴링한다. `sweepOrphans` 는
/// `_loadMemos` 안에서 unawaited 로 던져지므로, 완료를 동기 어서션 전에
/// 실측하려면 폴링이 필요하다 (runAsync 안에서만 호출할 것).
Future<void> waitUntil(
  bool Function() done, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('waitUntil timed out after $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late String referenced, orphan;
  final now = DateTime(2026, 8, 29, 12);

  Memo memo(String id, String title, {List<String> images = const []}) => Memo(
    id: id,
    content: '$title\n본문',
    createdAt: now,
    updatedAt: now,
    imageFiles: images,
  );

  bool onDisk(String n) => AttachmentStore.instance.fileFor(n).existsSync();

  // Task 7 규칙: 파일 심기는 setUp(실존)에서. Task 10: 고아 정리 once-플래그는
  // 프로세스 정적이라 테스트마다 리셋한다 — 이 파일은 (thumbnail 테스트와 달리)
  // markOrphanSweepDoneForTest() 를 부르지 않아 실제 sweep 배선을 태운다.
  setUp(() async {
    tmp = await installTempStore();
    referenced = await seedStoreFile('referenced.jpg');
    orphan = await seedStoreFile('orphan.jpg');
    final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
    AttachmentStore.instance
        .fileFor(referenced)
        .setLastModifiedSync(twoDaysAgo);
    AttachmentStore.instance.fileFor(orphan).setLastModifiedSync(twoDaysAgo);
    AttachmentThumbnail.decodeImages = false;
    MemoListScreenState.resetOrphanSweepForTest();
  });

  tearDown(() {
    AttachmentThumbnail.decodeImages = true;
    AttachmentStore.instance = null;
    tmp.deleteSync(recursive: true);
  });

  testWidgets('cold start: 메모가 있으면 1일 넘은 고아 파일을 정리하고 참조 파일은 남긴다', (
    tester,
  ) async {
    // 파일은 setUp 에서 심었다고 가정: referenced.jpg, orphan.jpg (둘 다 mtime 을 2일 전으로)
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        memo('m', '메모', images: [referenced]),
      ]),
    });
    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
      await tester.pumpAndSettle();
      await waitUntil(
        () => !onDisk(orphan),
      ); // sweep 은 unawaited — 실제 IO 완료를 기다린다
    });
    expect(onDisk(referenced), isTrue);
    expect(onDisk(orphan), isFalse);
  });

  testWidgets('cold start: 메모가 0개면 정리하지 않는다 (loadMemos 실패=빈 목록 방어)', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'memos': Memo.encodeList([])});
    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    expect(onDisk(orphan), isTrue);
  });
}
