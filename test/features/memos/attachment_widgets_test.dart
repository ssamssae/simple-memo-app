import 'dart:io';
import 'dart:typed_data';

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
    AttachmentThumbnail.decodeImages = false;
  });

  tearDown(() {
    AttachmentThumbnail.decodeImages = true;
    AttachmentStore.instance = null;
    tmp.deleteSync(recursive: true);
  });

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('AttachmentThumbnail', () {
    testWidgets('파일이 있으면 그 경로로 그린다 (디코딩 스위치 off)', (tester) async {
      // seedStoreFile 은 실제 dart:io 파일 쓰기(writeAsBytes flush:true) 다 —
      // testWidgets 본문에서 runAsync 없이 부르면 FakeAsync 존 안에서 완료 신호가
      // 오지 않아 정지한다(측정: 10분 TimeoutException). setUp 의 installTempStore
      // 는 FakeAsync 존 진입 전(패키지 test 의 순수 setUp)이라 문제없다.
      late final String name;
      await tester.runAsync(() async {
        name = await seedStoreFile('a.jpg');
      });
      await tester.pumpWidget(wrap(AttachmentThumbnail(fileName: name)));
      expect(
        find.byKey(
          ValueKey(
            'attachment-file:${AttachmentStore.instance.fileFor(name).path}',
          ),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    });

    testWidgets('실제 디코딩 경로 — runAsync 로 파일 IO 를 완료시킨다', (tester) async {
      AttachmentThumbnail.decodeImages = true;
      late final String name;
      await tester.runAsync(() async {
        name = await seedStoreFile('a.jpg');
        await tester.pumpWidget(wrap(AttachmentThumbnail(fileName: name)));
        await precacheImage(
          tester.widget<Image>(find.byType(Image)).image,
          tester.element(find.byType(AttachmentThumbnail)),
        );
      });
      await tester.pump();
      final image = tester.widget<Image>(find.byType(Image));
      final provider = image.image;
      final inner = provider is ResizeImage ? provider.imageProvider : provider;
      expect(inner, isA<FileImage>());
      expect(
        (inner as FileImage).file.path,
        AttachmentStore.instance.fileFor(name).path,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('파일이 없으면 깨진 사진 플레이스홀더, 예외 없음', (tester) async {
      await tester.pumpWidget(
        wrap(const AttachmentThumbnail(fileName: 'gone.jpg')),
      );
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('스토어 미초기화(maybeInstance null)여도 플레이스홀더로 버틴다', (tester) async {
      AttachmentStore.instance = null;
      await tester.pumpWidget(
        wrap(const AttachmentThumbnail(fileName: 'a.jpg')),
      );
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('size 가 상자 크기를 정한다', (tester) async {
      await tester.pumpWidget(
        wrap(const AttachmentThumbnail(fileName: 'gone.jpg', size: 72)),
      );
      final box = tester.getSize(find.byType(AttachmentThumbnail));
      expect(box, const Size(72, 72));
      expect(
        tester.widget<ClipRRect>(find.byType(ClipRRect)).borderRadius,
        BorderRadius.circular(8),
      );
    });

    testWidgets('경로 조작 파일명은 placeholder (예외 없음)', (tester) async {
      await tester.pumpWidget(
        wrap(const AttachmentThumbnail(fileName: '../evil.jpg')),
      );
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('손상된 파일도 errorBuilder 가 흡수해 placeholder', (tester) async {
      AttachmentThumbnail.decodeImages = true;
      late final String name;
      await tester.runAsync(() async {
        name = await seedStoreFile('bad.jpg', Uint8List.fromList([1, 2, 3]));
        await tester.pumpWidget(wrap(AttachmentThumbnail(fileName: name)));
        // precacheImage 는 디코딩 실패 시 Future 를 정상 완료시키고 onError 로만
        // 알린다(onError 없으면 FlutterError.reportError 로 새 나가 takeException
        // 에 잡힌다) — 여기서 흡수한다. errorBuilder 가 placeholder 로 대체하는지는
        // runAsync 밖에서 pump 한 뒤 확인한다.
        await precacheImage(
          tester.widget<Image>(find.byType(Image)).image,
          tester.element(find.byType(AttachmentThumbnail)),
          onError: (Object _, StackTrace? _) {},
        );
      });
      await tester.pump();
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AttachmentStrip', () {
    testWidgets('파일명 수만큼 72px 썸네일, 탭·길게누름이 인덱스로 온다', (tester) async {
      late final String a;
      late final String b;
      await tester.runAsync(() async {
        a = await seedStoreFile('a.jpg');
        b = await seedStoreFile('b.jpg');
      });
      int? tapped;
      int? held;
      await tester.pumpWidget(
        wrap(
          AttachmentStrip(
            fileNames: [a, b],
            onTap: (i) => tapped = i,
            onLongPress: (i) => held = i,
          ),
        ),
      );

      expect(find.byType(AttachmentThumbnail), findsNWidgets(2));
      expect(
        tester.getSize(find.byType(AttachmentThumbnail).first),
        const Size(72, 72),
      );

      await tester.tap(find.byType(AttachmentThumbnail).at(1));
      expect(tapped, 1);
      await tester.longPress(find.byType(AttachmentThumbnail).first);
      expect(held, 0);
    });
  });
}
