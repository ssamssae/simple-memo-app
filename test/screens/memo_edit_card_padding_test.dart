// T-261101-034 ① — 메모 수정 화면 본문·힌트 글자가 토스 카드 안쪽 여백을 갖는다.
//
// 대종님 아이폰 스크린샷: 본문 글자가 둥근 카드 왼쪽 위 모서리에 여백 없이 붙어 있었다
// (카드 왼쪽 끝 x≈35, 글자 시작 x≈37). 다른 토스톤 카드(홈 목록·검색·도움말)와 같은 16 을 준다.
// 지킬 것: 본문 아래 빈 곳 탭 → 캐럿, 사진 줄 정렬, 글자 크기 설정 반영.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/attachment_store.dart';
import 'package:simple_memo_app/features/memos/widgets/attachment_thumbnail.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_edit_screen.dart';
import 'package:simple_memo_app/services/settings_service.dart';
import 'package:simple_memo_app/widgets/toss_surface_card.dart';

import '../features/memos/support/attachment_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const inset = 16.0;
  final t = DateTime(2026, 11, 1, 9);

  late Directory tmp;
  late String photo;

  setUp(() async {
    tmp = await installTempStore();
    photo = await seedStoreFile('p.jpg');
    AttachmentThumbnail.decodeImages = false;
  });

  tearDown(() {
    AttachmentThumbnail.decodeImages = true;
    AttachmentStore.instance = null;
    tmp.deleteSync(recursive: true);
    SettingsService.instance.bodyFontSize.value =
        SettingsService.defaultBodyFontSize;
  });

  Future<void> pumpEditor(
    WidgetTester tester, {
    String? content,
    List<String> images = const [],
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MemoEditScreen(
          memo: content == null
              ? null
              : Memo(
                  id: 'm',
                  content: content,
                  createdAt: t,
                  updatedAt: t,
                  imageFiles: images,
                ),
          attachmentService: fakeAttachmentService(),
          onSave: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Rect card(WidgetTester tester) =>
      tester.getRect(find.byType(TossSurfaceCard));
  Rect body(WidgetTester tester) => tester.getRect(find.byType(EditableText));

  testWidgets('본문은 카드 왼쪽·위·오른쪽에서 16 떨어져 시작한다', (tester) async {
    await pumpEditor(tester, content: '장보기\n우유');

    final c = card(tester);
    final b = body(tester);
    expect(
      b.left - c.left,
      closeTo(inset, 0.5),
      reason: '본문 $b 가 카드 $c 왼쪽에 붙어 있다',
    );
    expect(
      b.top - c.top,
      closeTo(inset, 0.5),
      reason: '본문 $b 가 카드 $c 위에 붙어 있다',
    );
    expect(c.right - b.right, closeTo(inset, 0.5));
  });

  testWidgets('빈 새 메모의 힌트 글자도 같은 여백 안에 있다', (tester) async {
    await pumpEditor(tester);

    final c = card(tester);
    final hint = tester.getRect(find.text('내용을 입력하세요...'));
    expect(hint.left - c.left, closeTo(inset, 0.5));
    expect(hint.top - c.top, greaterThanOrEqualTo(inset - 0.5));
  });

  testWidgets('글자 크기 설정을 바꿔도 본문 크기만 바뀌고 여백은 16 그대로다', (tester) async {
    await pumpEditor(tester, content: '장보기\n우유');
    expect(
      tester.widget<TextField>(find.byType(TextField)).style!.fontSize,
      SettingsService.defaultBodyFontSize,
    );

    SettingsService.instance.bodyFontSize.value = 24;
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style!.fontSize, 24);
    expect(field.cursorHeight, 24);
    expect(body(tester).left - card(tester).left, closeTo(inset, 0.5));
    expect(body(tester).top - card(tester).top, closeTo(inset, 0.5));
  });

  testWidgets('여백을 눌러도 본문에 캐럿이 간다 — 여백이 입력 칸 안에 있다', (tester) async {
    await pumpEditor(tester, content: '장보기\n우유');
    final c = card(tester);
    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    expect(editable.widget.focusNode.hasFocus, isFalse);

    await tester.tapAt(Offset(c.left + inset / 2, c.top + inset / 2));
    await tester.pump();
    expect(editable.widget.focusNode.hasFocus, isTrue);
  });

  testWidgets('사진 줄은 본문과 같은 왼쪽 선에서 시작하고 카드 아래에 16 을 남긴다', (tester) async {
    await pumpEditor(tester, content: '사진 메모', images: [photo]);

    final c = card(tester);
    final b = body(tester);
    final thumb = tester.getRect(find.byType(AttachmentThumbnail));
    expect(
      thumb.left,
      closeTo(b.left, 0.5),
      reason: '사진 $thumb 과 본문 $b 의 왼쪽 선이 다르다',
    );
    expect(c.bottom - thumb.bottom, closeTo(inset, 0.5));
    // 짧은 메모면 카드는 화면(스크롤 뷰포트)을 정확히 채운다 — 여백 때문에 남는 스크롤이 없다.
    final viewport = tester.getSize(find.byType(SingleChildScrollView)).height;
    expect(c.height, closeTo(viewport, 1));
  });
}
