import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/l10n/app_strings.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/home_shell.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';
import 'package:simple_memo_app/services/memo_storage.dart';

/// T-261022-006 r3 — 메모 목록은 IndexedStack 뒤에 숨어 있어도 살아 있다.
/// 설정 탭에서 복원·휴지통 복구로 저장소가 바뀐 뒤 그 목록이 예전 상태를 통째로
/// 저장하면 방금 복원한 메모가 사라진다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const miniLmChannel = MethodChannel('memoyo/minilm');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    messenger.setMockMethodCallHandler(miniLmChannel, (call) async {
      return switch (call.method) {
        'isSupported' => false,
        'close' => null,
        _ => throw PlatformException(code: 'UNEXPECTED', message: call.method),
      };
    });
    PackageInfo.setMockInitialValues(
      appName: 'simple_memo_app',
      packageName: 'com.daejongkang.simple_memo_app',
      version: '9.9.9',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(miniLmChannel, null);
  });

  final strings = AppStrings.fromCode('ko');
  final t = DateTime(2026, 10, 22, 9);

  Memo memo(String id, String content, {DateTime? deletedAt}) => Memo(
        id: id,
        content: content,
        createdAt: t,
        updatedAt: t,
        deletedAt: deletedAt,
      );

  Future<Map<String, bool>> storedActive() async => {
        for (final m in await MemoStorage.loadMemos())
          m.content: m.deletedAt == null,
      };

  Future<void> writeNewMemoFromBottomBar(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.add_box_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '새로 쓴 메모');
    await tester.tap(find.text(strings.save));
    await tester.pumpAndSettle();
  }

  testWidgets('설정에서 휴지통 메모를 복구한 뒤 새메모를 저장해도 복구가 유지된다',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        memo('a', '그대로 있는 메모'),
        memo('tr', '휴지통 메모', deletedAt: t),
      ]),
    });
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(strings.trash),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(strings.trash));
    await tester.pumpAndSettle();
    await tester.tap(find.text('휴지통 메모'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.restoreAction));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect((await storedActive())['휴지통 메모'], isTrue);

    await writeNewMemoFromBottomBar(tester);
    expect(await storedActive(), {
      '새로 쓴 메모': true,
      '그대로 있는 메모': true,
      '휴지통 메모': true,
    });
  });

  testWidgets('설정 탭에 있는 동안 복원된 메모는 새메모를 저장해도 남는다',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([memo('a', '그대로 있는 메모')]),
    });
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    // 백업 & 복원 화면의 복원이 저장소에 남기는 결과와 같다.
    await MemoStorage.saveMemos([
      memo('a', '그대로 있는 메모'),
      memo('imp', '복원된 메모'),
    ]);

    await writeNewMemoFromBottomBar(tester);
    expect(await storedActive(), {
      '새로 쓴 메모': true,
      '그대로 있는 메모': true,
      '복원된 메모': true,
    });
  });

  testWidgets('삭제 알림의 실행 취소는 그사이 바뀐 저장 내용을 덮어쓰지 않는다',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([memo('a', '지울 메모')]),
    });
    await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
    await tester.pumpAndSettle();

    await tester.drag(find.text('지울 메모'), const Offset(-90, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, strings.delete));
    await tester.pumpAndSettle();

    // 알림이 떠 있는 동안 다른 화면에서 복원이 끝났다.
    final stored = await MemoStorage.loadMemos();
    await MemoStorage.saveMemos([...stored, memo('imp', '복원된 메모')]);

    await tester.tap(find.text(strings.undoSpaced));
    await tester.pumpAndSettle();
    expect(await storedActive(), {'지울 메모': true, '복원된 메모': true});
    expect(find.text('지울 메모'), findsOneWidget);
    expect(find.text('복원된 메모'), findsOneWidget);
  });
}
