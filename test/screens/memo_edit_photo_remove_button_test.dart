// T-261101-034 ③ — 첨부 사진 썸네일 오른쪽 위 빼기(−) 버튼.
//
// 대종님 아이폰 사용 소감: 사진을 지우려면 길게 눌러야 하는데 안내가 없어 어렵다.
// 버튼을 누르면 길게 누르기 경로와 같은 「사진 삭제」 확인이 뜬다. 길게 누르기는 그대로 둔다.

import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/attachment_store.dart';
import 'package:simple_memo_app/features/memos/widgets/attachment_strip.dart';
import 'package:simple_memo_app/features/memos/widgets/attachment_thumbnail.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_edit_screen.dart';
import 'package:simple_memo_app/services/settings_service.dart';
import 'package:simple_memo_app/utils/app_palette.dart';

import '../features/memos/support/attachment_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late String a;
  late String b;

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
    SettingsService.instance.languageCode.value = 'ko';
  });

  final t = DateTime(2026, 11, 1, 9);
  final removeIcon = find.byIcon(Icons.remove);

  Future<void> pumpEditor(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    ValueChanged<Memo>? onSave,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: brightness,
          extensions: [
            brightness == Brightness.light ? AppPalette.light : AppPalette.dark,
          ],
        ),
        home: MemoEditScreen(
          memo: Memo(
            id: 'm1',
            content: '사진 메모',
            createdAt: t,
            updatedAt: t,
            imageFiles: [a, b],
          ),
          attachmentService: fakeAttachmentService(),
          onSave: onSave,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool onDisk(String name) =>
      AttachmentStore.instance.fileFor(name).existsSync();

  Future<void> waitUntil(bool Function() done) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!done()) {
      if (DateTime.now().isAfter(deadline)) throw TimeoutException('waitUntil');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  double contrast(Color x, Color y) {
    final lx = x.computeLuminance();
    final ly = y.computeLuminance();
    final hi = lx > ly ? lx : ly;
    final lo = lx > ly ? ly : lx;
    return (hi + 0.05) / (lo + 0.05);
  }

  testWidgets('사진마다 빼기 버튼 — 누르면 길게 누르기와 같은 「사진 삭제」 확인, 확인하면 빠진다', (
    tester,
  ) async {
    Memo? saved;
    await pumpEditor(tester, onSave: (m) => saved = m);
    expect(removeIcon, findsNWidgets(2));

    await tester.tap(removeIcon.first);
    await tester.pumpAndSettle();
    // 길게 누르기 → 「사진 삭제」 를 고른 뒤 뜨는 것과 같은 대화상자.
    final dialog = find.byType(CupertinoAlertDialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.text('사진 삭제')),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: dialog, matching: find.text('이 사진을 지울까요?')),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(CupertinoDialogAction, '사진 삭제'));
    await tester.pumpAndSettle();
    expect(find.byType(AttachmentThumbnail), findsOneWidget);
    expect(removeIcon, findsOneWidget);
    // 길게 누르기 경로와 같이 기존 사진 파일은 저장 때 지운다.
    expect(onDisk(a), isTrue);

    await tester.runAsync(() async {
      await tester.tap(find.text('저장'));
      await tester.pumpAndSettle();
      await waitUntil(() => !onDisk(a));
    });
    expect(saved!.imageFiles, [b]);
    expect(onDisk(b), isTrue);
  });

  testWidgets('확인 대화상자에서 취소하면 사진은 그대로다', (tester) async {
    await pumpEditor(tester);
    await tester.tap(removeIcon.last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CupertinoDialogAction, '취소'));
    await tester.pumpAndSettle();
    expect(find.byType(AttachmentThumbnail), findsNWidgets(2));
  });

  testWidgets('누르는 곳은 44pt 이상이고, 썸네일 가운데(보기 탭·길게 누르기)는 덮지 않는다', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpEditor(tester);
    final button = find.bySemanticsLabel('사진 삭제').first;
    final hit = tester.getRect(button);
    final thumb = tester.getRect(find.byType(AttachmentThumbnail).first);
    final badge = tester.getRect(
      find
          .ancestor(of: removeIcon.first, matching: find.byType(DecoratedBox))
          .first,
    );

    expect(hit.width, greaterThanOrEqualTo(44));
    expect(hit.height, greaterThanOrEqualTo(44));
    expect(
      hit.contains(thumb.center),
      isFalse,
      reason: '버튼 $hit 이 썸네일 $thumb 가운데를 덮는다',
    );
    expect(hit.contains(badge.center), isTrue);
    // 빼기 원은 썸네일 오른쪽 위 모서리 안쪽에 붙어 있다.
    expect(thumb.right - badge.right, inInclusiveRange(0, 8));
    expect(badge.top - thumb.top, inInclusiveRange(0, 8));

    // 가운데를 길게 누르면 지금처럼 시트가 뜬다.
    await tester.longPress(find.byType(AttachmentThumbnail).first);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(CupertinoActionSheetAction, '갤러리에 저장'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  for (final brightness in Brightness.values) {
    testWidgets('$brightness — 빼기 버튼이 카드·사진 위에서 잘 보인다', (tester) async {
      await pumpEditor(tester, brightness: brightness);
      final palette = brightness == Brightness.light
          ? AppPalette.light
          : AppPalette.dark;
      final box = tester.widget<DecoratedBox>(
        find
            .ancestor(of: removeIcon.first, matching: find.byType(DecoratedBox))
            .first,
      );
      final decoration = box.decoration as BoxDecoration;
      final fill = decoration.color!;
      final ring = decoration.border!.top.color;
      final icon = tester.widget<Icon>(removeIcon.first).color!;

      expect(decoration.shape, BoxShape.circle);
      // 카드 바탕 위에서 원이 보이고(비텍스트 대비 3:1 이상), 원 위에서 빼기 표시가 보인다.
      expect(contrast(fill, palette.surface), greaterThanOrEqualTo(3));
      expect(contrast(icon, fill), greaterThanOrEqualTo(3));
      // 사진 위에서는 바깥 테두리가 원과 사진을 가른다.
      expect(contrast(ring, fill), greaterThanOrEqualTo(3));
    });
  }

  testWidgets('접근성 라벨 — 한국어 「사진 삭제」, 영어 「Delete photo」', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpEditor(tester);
    expect(find.bySemanticsLabel('사진 삭제'), findsNWidgets(2));

    // 영어는 사진 줄만 띄운다. 편집 화면 상단바 왼쪽(뒤로·취소·공유)은 시험 글꼴(글자마다
    // 1em 정사각)에서 영어 글자가 넘쳐 이 항목과 상관없는 넘침 오류를 낸다.
    SettingsService.instance.languageCode.value = 'en';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttachmentStrip(
            fileNames: [a, b],
            onTap: (_) {},
            onLongPress: (_) {},
            onRemove: (_) {},
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Delete photo'), findsNWidgets(2));
    semantics.dispose();
  });
}
