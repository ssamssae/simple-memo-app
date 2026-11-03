// T-261103-009 — iOS 붙여넣기 허용 창 없애기.
//
// ■왜
//   대종님 2026-11-03 11:07 실기기(1.0.23(51)) 사진: 「'메모요'이(가) 'LINE'에서 붙여넣으려고 함
//   — 이 동작을 허용하겠습니까?」 + 개발자 멈춤 감지 「메모요 2738 ms」. Flutter 가 그린 메뉴의
//   「붙여넣기」는 앱이 클립보드를 직접 읽어서 iOS 가 매번 묻고, 답을 기다리는 동안 앱이 멈춘다.
//   iOS 기본 편집 메뉴(SystemContextMenu)의 붙여넣기는 시스템이 하므로 묻지 않는다.
//
// ■무엇을 지키나
//   (a) 기본 메뉴를 쓸 수 있는 기기에서 메모 본문은 iOS 기본 메뉴를 띄운다
//   (b) 검색칸도 iOS 기본 메뉴를 띄운다 — Flutter 기본값이 이미 그렇다. 메뉴를 바꾸다 이 기본값을 덮지 않게 지킨다
//   (c) 기본 메뉴를 못 쓰는 기기(안드로이드 등)는 지금 메뉴 그대로다
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_edit_screen.dart';
import 'package:simple_memo_app/screens/search_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const miniLmChannel = MethodChannel('memoyo/minilm');
  late List<String> platformCalls;

  setUp(() {
    platformCalls = <String>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call.method);
      return null;
    });
    messenger.setMockMethodCallHandler(miniLmChannel, (call) async {
      return switch (call.method) {
        'isSupported' => false,
        _ => null,
      };
    });
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(miniLmChannel, null);
  });

  Widget withSystemMenu(Widget home, {required bool supported}) {
    return MediaQuery(
      data: MediaQueryData(supportsShowingSystemContextMenu: supported),
      child: MaterialApp(home: home),
    );
  }

  Future<void> openMenu(WidgetTester tester) async {
    final state = tester.state<EditableTextState>(
      find.byType(EditableText).first,
    );
    state.renderEditable.selectWordsInRange(
      from: Offset.zero,
      cause: SelectionChangedCause.longPress,
    );
    expect(state.showToolbar(), isTrue);
    await tester.pump();
  }

  testWidgets(
    '(a) 메모 본문은 iOS 기본 편집 메뉴를 띄운다',
    (tester) async {
      await tester.pumpWidget(
        withSystemMenu(
          MemoEditScreen(memo: Memo.create(content: '복사한 글을 붙일 곳')),
          supported: true,
        ),
      );
      await tester.pumpAndSettle();
      await openMenu(tester);

      expect(find.byType(SystemContextMenu), findsOneWidget);
      expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
      expect(platformCalls, contains('ContextMenu.showSystemContextMenu'));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    '(b) 검색칸도 iOS 기본 편집 메뉴를 띄운다',
    (tester) async {
      await tester.pumpWidget(
        withSystemMenu(const SearchScreen(), supported: true),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '치과');
      await tester.pump();
      await openMenu(tester);

      expect(find.byType(SystemContextMenu), findsOneWidget);
      expect(platformCalls, contains('ContextMenu.showSystemContextMenu'));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    '(c) 기본 메뉴를 못 쓰면 지금 메뉴 그대로',
    (tester) async {
      await tester.pumpWidget(
        withSystemMenu(
          MemoEditScreen(memo: Memo.create(content: '안드로이드 메뉴')),
          supported: false,
        ),
      );
      await tester.pumpAndSettle();

      // 지금 쓰는 옛 방식 큰 손잡이 도구 그대로(메뉴도 지금과 같다).
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.selectionControls, isNotNull);
      expect(
        field.selectionControls,
        isNot(isA<TextSelectionHandleControls>()),
      );
      expect(
        platformCalls,
        isNot(contains('ContextMenu.showSystemContextMenu')),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
