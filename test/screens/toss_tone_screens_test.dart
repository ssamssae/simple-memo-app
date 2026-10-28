import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/help_faq_screen.dart';
import 'package:simple_memo_app/screens/memo_edit_screen.dart';
import 'package:simple_memo_app/screens/search_screen.dart';
import 'package:simple_memo_app/screens/trash_screen.dart';
import 'package:simple_memo_app/utils/app_palette.dart';
import 'package:simple_memo_app/widgets/toss_surface_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  bool hasTossCard(WidgetTester tester) {
    return tester.widgetList<Material>(find.byType(Material)).any((material) {
      return material.color == AppPalette.light.surface &&
          material.borderRadius ==
              BorderRadius.circular(TossSurfaceCard.radius);
    });
  }

  testWidgets('검색 결과 카드는 토스 면과 모서리 16이다', (tester) async {
    final now = DateTime(2026, 10, 29, 9);
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        Memo(id: 'a', content: '토스 카드', createdAt: now, updatedAt: now),
      ]),
    });
    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '토스');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(hasTossCard(tester), isTrue);
  });

  testWidgets('휴지통 항목은 토스 면과 모서리 16이다', (tester) async {
    final now = DateTime(2026, 10, 29, 9);
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        Memo(
          id: 'b',
          content: '버린 메모',
          createdAt: now,
          updatedAt: now,
          deletedAt: now,
        ),
      ]),
    });
    await tester.pumpWidget(const MaterialApp(home: TrashScreen()));
    await tester.pumpAndSettle();

    expect(find.text('버린 메모'), findsOneWidget);
    expect(hasTossCard(tester), isTrue);
  });

  testWidgets('도움말 항목은 토스 면과 모서리 16이다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HelpFaqScreen()));
    await tester.pumpAndSettle();

    expect(hasTossCard(tester), isTrue);
  });

  testWidgets('메모 편집 본문은 토스 면과 모서리 16이다', (tester) async {
    final now = DateTime(2026, 10, 29, 9);
    await tester.pumpWidget(
      MaterialApp(
        home: MemoEditScreen(
          memo: Memo(id: 'c', content: '본문', createdAt: now, updatedAt: now),
          onSave: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(hasTossCard(tester), isTrue);
    expect(find.text('저장'), findsOneWidget);
    final save = tester.widget<Text>(find.text('저장'));
    expect(save.style?.color, AppPalette.light.accent);
  });
}
