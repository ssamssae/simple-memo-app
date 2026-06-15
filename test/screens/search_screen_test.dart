// 메모요 1.0.8 검색 화면 위젯 테스트 (T-260615-26, spec §5.2 / §6).
// SharedPreferences mock 시딩 패턴은 memo_list_softdelete_test.dart 와 동일.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/search_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Memo m(String id, String content, DateTime t, {bool fav = false}) => Memo(
        id: id,
        content: content,
        createdAt: t,
        updatedAt: t,
        isFavorite: fav,
      );

  final now = DateTime(2026, 6, 16, 10);

  void seed(List<Memo> memos) {
    SharedPreferences.setMockInitialValues({'memos': Memo.encodeList(memos)});
  }

  // 디바운스(300ms) 통과시키며 검색어 입력.
  Future<void> type(WidgetTester tester, String q) async {
    await tester.enterText(find.byType(TextField), q);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
  }

  // RichText 안에 amber 배경 스팬이 있는지 검사 (하이라이트 검증).
  bool hasAmberHighlight(WidgetTester tester) {
    var found = false;
    for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
      rt.text.visitChildren((span) {
        if (span is TextSpan &&
            span.style?.backgroundColor == Colors.amber.shade300) {
          found = true;
        }
        return true;
      });
    }
    return found;
  }

  testWidgets('진입 시 검색 입력 필드 + 안내 문구 렌더', (tester) async {
    seed([m('a', 'Karpathy 룰', now)]);
    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('검색해 보세요'), findsOneWidget);
  });

  testWidgets('검색어 입력 → 결과 카운트 + 매치 메모 + amber 하이라이트', (tester) async {
    seed([
      m('a', 'Karpathy 룰 4가지\nthink before coding', now),
      m('b', '딴 메모\n관계 없는 내용', now),
    ]);
    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    await tester.pumpAndSettle();

    await type(tester, 'Karpathy');

    expect(find.textContaining('메모 결과 (1건)'), findsOneWidget);
    expect(
      find.textContaining('Karpathy', findRichText: true),
      findsWidgets,
    );
    expect(hasAmberHighlight(tester), isTrue);
  });

  testWidgets('매치 없는 검색어 → 빈 결과 empty state', (tester) async {
    seed([m('a', 'Karpathy 룰', now)]);
    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    await tester.pumpAndSettle();

    await type(tester, 'zzzzzz');

    expect(find.textContaining('검색 결과가 없습니다'), findsOneWidget);
  });

  testWidgets('빈 쿼리로 되돌리면 안내 문구 복귀', (tester) async {
    seed([m('a', 'Karpathy 룰', now)]);
    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    await tester.pumpAndSettle();

    await type(tester, 'Karpathy');
    expect(find.textContaining('메모 결과'), findsOneWidget);

    await type(tester, '');
    expect(find.textContaining('검색해 보세요'), findsOneWidget);
  });
}
