import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/attachment_store.dart';
import 'package:simple_memo_app/features/memos/widgets/attachment_thumbnail.dart';
import 'package:simple_memo_app/features/memos/widgets/attachment_viewer.dart';

import 'support/attachment_test_support.dart';

void main() {
  late Directory tmp;
  late String a;
  late String b;

  // 파일 심기는 setUp(실존)에서 — testWidgets 본문의 실제 dart:io await 는 FakeAsync 에서 멈춘다 (Task 7 규칙).
  setUp(() async {
    tmp = await installTempStore();
    a = await seedStoreFile('a.jpg');
    b = await seedStoreFile('b.jpg');
    AttachmentThumbnail.decodeImages = false;
  });

  tearDown(() {
    AttachmentThumbnail.decodeImages = true;
    AttachmentStore.instance = null;
    tmp.deleteSync(recursive: true);
  });

  testWidgets('PageView 로 넘기고 InteractiveViewer 로 감싼다, 초기 인덱스 반영', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AttachmentViewer(fileNames: [a, b], initialIndex: 1),
    ));
    await tester.pump();

    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsWidgets);
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('onDelete 없으면 삭제 버튼이 없다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AttachmentViewer(fileNames: [a], initialIndex: 0),
    ));
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('삭제 → 확인 다이얼로그 → 콜백에 파일명, 마지막 장이면 닫힌다', (tester) async {
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

  testWidgets('두 장 중 첫 장 삭제 → 뷰어는 남고 남은 장을 보여준다', (tester) async {
    final deleted = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: AttachmentViewer(fileNames: [a, b], initialIndex: 0, onDelete: deleted.add),
    ));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '사진 삭제'));
    await tester.pumpAndSettle();

    expect(deleted, [a]);
    expect(find.byType(AttachmentViewer), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.byKey(ValueKey('attachment-file:${AttachmentStore.instance.fileFor(b).path}')), findsOneWidget);
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
