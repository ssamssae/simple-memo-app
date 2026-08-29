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
  late String keep;
  late String a;
  late String b;
  late List<String> ten;

  // Task 7 규칙: 파일 심기는 setUp(실존)에서, 실제 IO 를 일으키는 상호작용은 runAsync 로.
  setUp(() async {
    tmp = await installTempStore();
    port = FakeImageSourcePort();
    keep = await seedStoreFile('keep.jpg');
    a = await seedStoreFile('a.jpg');
    b = await seedStoreFile('b.jpg');
    ten = [for (var i = 0; i < 10; i++) await seedStoreFile('p$i.jpg')];
    AttachmentThumbnail.decodeImages = false;
  });

  tearDown(() {
    AttachmentThumbnail.decodeImages = true;
    AttachmentStore.instance = null;
    tmp.deleteSync(recursive: true);
  });

  Memo existing({List<String> images = const []}) {
    final t = DateTime(2026, 8, 29, 12);
    return Memo(id: 'm1', content: '기존 본문', createdAt: t, updatedAt: t, imageFiles: images);
  }

  bool onDisk(String name) => AttachmentStore.instance.fileFor(name).existsSync();
  int filesOnDisk() => AttachmentStore.instance.root.listSync().whereType<File>().length;

  // 사진 추가 = 서비스 파이프라인이 실제 파일을 쓴다 → runAsync 안에서 상호작용하고
  // IO 가 끝날 실시간을 잠깐 준 뒤 바깥에서 한 번 더 settle 한다.
  Future<void> addViaSheet(WidgetTester tester, String action) async {
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('사진 추가'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CupertinoActionSheetAction, action));
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
  }

  // 삭제·취소 확정 = store.delete 실제 IO → 같은 이유로 runAsync.
  Future<void> confirmDialog(WidgetTester tester, String actionLabel) async {
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(CupertinoDialogAction, actionLabel));
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
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
    expect(filesOnDisk(), 13 + 1); // setUp 13장 + 방금 추가 1장
  });

  testWidgets('클립보드에 사진 없음 → 스낵바, 스트립 없음', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MemoEditScreen(attachmentService: fakeAttachmentService(port: port)),
    ));
    await addViaSheet(tester, '붙여넣기');
    expect(find.text('클립보드에 사진이 없거나 붙여넣기가 허용되지 않았어요'), findsOneWidget);
    expect(find.byType(AttachmentStrip), findsNothing);
  });

  testWidgets('10장이면 시트 대신 상한 스낵바', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MemoEditScreen(
        memo: existing(images: ten),
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
    port.galleryBytes = kTinyPng;
    await tester.pumpWidget(MaterialApp(
      home: MemoEditScreen(
        memo: existing(images: [keep]),
        attachmentService: fakeAttachmentService(port: port),
      ),
    ));
    await addViaSheet(tester, '사진첩');
    expect(find.byType(AttachmentThumbnail), findsNWidgets(2));
    expect(filesOnDisk(), 13 + 1);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    await confirmDialog(tester, '취소');

    expect(onDisk(keep), isTrue);
    expect(filesOnDisk(), 13);
  });

  testWidgets('길게 눌러 기존 사진 삭제 → 저장 시점에 파일 삭제, 저장 결과에서 빠짐', (tester) async {
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
    expect(onDisk(a), isTrue);

    // 저장 = _commitPendingRemovals 가 실제 파일을 지운다 → runAsync.
    await tester.runAsync(() async {
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    expect(saved!.imageFiles, [b]);
    expect(onDisk(a), isFalse);
    expect(onDisk(b), isTrue);
  });

  testWidgets('이 세션에서 추가한 사진을 바로 지우면 파일도 즉시 삭제', (tester) async {
    port.galleryBytes = kTinyPng;
    await tester.pumpWidget(MaterialApp(
      home: MemoEditScreen(attachmentService: fakeAttachmentService(port: port)),
    ));
    await addViaSheet(tester, '사진첩');
    expect(filesOnDisk(), 13 + 1);
    await tester.longPress(find.byType(AttachmentThumbnail));
    await tester.pumpAndSettle();
    await confirmDialog(tester, '사진 삭제');

    expect(find.byType(AttachmentStrip), findsNothing);
    expect(filesOnDisk(), 13);
  });

  // Task 7 리뷰 회귀 가드: Column 도입 뒤에도 TextField 가 뷰포트(−스트립)를 채워
  // 본문 아래 빈 영역 탭이 캐럿을 잡아야 한다.
  testWidgets('사진이 있어도 본문 아래 빈 영역 탭 → TextField 포커스 (뷰포트 채움 유지)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MemoEditScreen(
        memo: existing(images: [a]),
        attachmentService: fakeAttachmentService(port: port),
      ),
    ));
    await tester.pumpAndSettle();

    final viewport = tester.getSize(find.byType(SingleChildScrollView)).height;
    final field = tester.getRect(find.byType(TextField));
    final strip = tester.getRect(find.byType(AttachmentStrip));
    expect(field.height, closeTo(viewport - (AttachmentStrip.tileSize + 16), 1));
    // AttachmentStrip 자신의 outermost Padding(top: 16) 이 getRect 경계에 포함돼
    // TextField.bottom 과 strip.top 사이 실측 간격은 0 — 레이아웃은 올바르고
    // 경계 측정 지점의 차이일 뿐 (플랜 메모 참조).
    expect(strip.top - field.bottom, closeTo(0, 1));

    await tester.tapAt(Offset(field.center.dx, field.bottom - 8));
    await tester.pump();
    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    expect(editable.widget.focusNode.hasFocus, isTrue);
  });

  testWidgets('사진이 없으면 TextField 가 뷰포트 전체를 채운다 (기존 동작 무회귀)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MemoEditScreen(
        memo: existing(),
        attachmentService: fakeAttachmentService(port: port),
      ),
    ));
    await tester.pumpAndSettle();
    final viewport = tester.getSize(find.byType(SingleChildScrollView)).height;
    expect(tester.getSize(find.byType(TextField)).height, closeTo(viewport, 1));
  });
}
