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

  testWidgets('onSave 없으면 저장 버튼이 없고, 있으면 현재 장 파일명으로 콜백', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AttachmentViewer(fileNames: [a, b], initialIndex: 1),
    ));
    expect(find.byTooltip('갤러리에 저장'), findsNothing);

    final saved = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: AttachmentViewer(fileNames: [a, b], initialIndex: 1, onSave: saved.add),
    ));
    await tester.pump();
    await tester.tap(find.byTooltip('갤러리에 저장'));
    await tester.pump();
    expect(saved, [b]);
    // 저장은 첨부를 건드리지 않는다 — 뷰어는 그대로 2장.
    expect(find.text('2 / 2'), findsOneWidget);
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

  testWidgets('스와이프로 다음 장 → 타이틀 2 / 2', (tester) async {
    await tester.pumpWidget(MaterialApp(home: AttachmentViewer(fileNames: [a, b], initialIndex: 0)));
    await tester.pump();
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('삭제 확인에서 취소 → 아무것도 안 바뀐다', (tester) async {
    final deleted = <String>[];
    await tester.pumpWidget(MaterialApp(home: AttachmentViewer(fileNames: [a, b], initialIndex: 0, onDelete: deleted.add)));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '취소'));
    await tester.pumpAndSettle();
    expect(deleted, isEmpty);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byType(AttachmentViewer), findsOneWidget);
  });

  testWidgets('initialIndex 가 범위를 벗어나면 clamp', (tester) async {
    await tester.pumpWidget(MaterialApp(home: AttachmentViewer(fileNames: [a, b], initialIndex: 9)));
    await tester.pump();
    expect(find.text('2 / 2'), findsOneWidget);
    await tester.pumpWidget(MaterialApp(home: AttachmentViewer(fileNames: [a, b], initialIndex: -3)));
    await tester.pump();
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('빈 목록이면 삭제 버튼이 없고 예외도 없다', (tester) async {
    await tester.pumpWidget(MaterialApp(home: AttachmentViewer(fileNames: const [], initialIndex: 0, onDelete: (_) {})));
    await tester.pump();
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
