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
  late String a;
  final now = DateTime(2026, 8, 29, 12);

  Memo memo(String id, String title, {List<String> images = const []}) => Memo(
        id: id,
        content: '$title\n본문',
        createdAt: now,
        updatedAt: now,
        imageFiles: images,
      );

  // Task 7 규칙: 파일 심기는 setUp(실존)에서. Task 10: 고아 정리 once-플래그는 프로세스 정적이라
  // 테스트마다 리셋 — 안 하면 첫 테스트만 실제 sweep(FakeAsync 안 실제 IO)을 타고 나머지는 다른 분기.
  setUp(() async {
    tmp = await installTempStore();
    a = await seedStoreFile('a.jpg');
    AttachmentThumbnail.decodeImages = false;
    MemoListScreenState.resetOrphanSweepForTest();
    // 이 파일의 테스트는 sweep 이 돌지 않게 한다: 메모가 비어 있지 않으므로 게이트를 통과하는데,
    // sweepOrphans 는 실제 IO 라 FakeAsync 에서 멈춘다 → 플래그를 미리 세팅해 건너뛴다.
    MemoListScreenState.markOrphanSweepDoneForTest();
  });

  tearDown(() {
    AttachmentThumbnail.decodeImages = true;
    AttachmentStore.instance = null;
    tmp.deleteSync(recursive: true);
  });

  testWidgets('사진 있는 행에만 36px 썸네일, 행 높이는 48 그대로', (tester) async {
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
