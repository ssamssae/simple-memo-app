// Opt-in widget render for the checklist screens. Default runs skip this.
// macOS system fonts are loaded locally and are not redistributed.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_edit_screen.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';
import 'package:simple_memo_app/services/settings_service.dart';

const capture = bool.fromEnvironment('CHECKLIST_CAPTURE');

void main() {
  testWidgets('capture checklist editor and list', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      final gothic = ByteData.sublistView(
        await File('/System/Library/Fonts/AppleSDGothicNeo.ttc').readAsBytes(),
      );
      final symbols = ByteData.sublistView(
        await File('/System/Library/Fonts/Apple Symbols.ttf').readAsBytes(),
      );
      final latin = ByteData.sublistView(
        await File('/System/Library/Fonts/SFNS.ttf').readAsBytes(),
      );
      for (final family in ['Roboto', 'CupertinoSystemText', '.SF Pro Text']) {
        final loader = FontLoader(family)
          ..addFont(Future.value(latin))
          ..addFont(Future.value(gothic))
          ..addFont(Future.value(symbols));
        await loader.load();
      }
    });

    final now = DateTime(2026, 11, 10, 9);
    const body = '☐ 우유 사기\n☑ 계란\n☐ 커피\n일반 줄\n☐ 산책';
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        Memo(
          id: 'check',
          content: body,
          createdAt: now,
          updatedAt: now,
        ),
        Memo(
          id: 'plain',
          content: '일반 메모',
          createdAt: now,
          updatedAt: now,
        ),
      ]),
    });
    SettingsService.instance.languageCode.value = 'ko';
    MemoListScreenState.markOrphanSweepDoneForTest();

    final boundary = GlobalKey();
    Future<void> save(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('test/features/memos/checklist_captures/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: MemoEditScreen(
            memo: Memo(id: 'check', content: body, createdAt: now, updatedAt: now),
            onSave: (_) {},
          ),
        ),
      ),
    );
    await save('edit');

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          home: MemoListScreen(),
        ),
      ),
    );
    await save('list');
  }, skip: !capture);
}
