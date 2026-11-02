import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/search_screen.dart';

// T-261103-001: 대종님 「검색 눌렀을 때 토스톤이 아니야 디자인구려」.
void main() {
  setUp(() {
    final t = DateTime(2026, 11, 2);
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        Memo(id: 'a', content: '1058 29 6 광명 16', createdAt: t, updatedAt: t),
        Memo(
          id: 'b',
          content: '0958 25 8 산천\n광명역 승강장 메모',
          createdAt: t,
          updatedAt: t,
        ),
      ]),
    });
  });

  Future<void> search(WidgetTester tester, String query) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Pretendard'),
        home: const SearchScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), query);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  testWidgets('검색 결과 글자는 앱 글꼴을 물려받는다 — 시스템 글꼴로 새지 않는다', (tester) async {
    await search(tester, '광명');
    final hits = tester
        .widgetList<RichText>(find.byType(RichText))
        .where((r) => r.text.toPlainText().contains('1058 29 6 광명'))
        .toList();
    expect(hits, isNotEmpty, reason: '대조군: 결과 카드가 떠야 한다');
    for (final r in hits) {
      expect(
        r.text.style?.fontFamily,
        'Pretendard',
        reason: '결과 제목이 앱 글꼴 대신 기기 기본 글꼴로 그려진다',
      );
    }
  });

  testWidgets('검색어 지우기 버튼은 입력칸 안에 있다', (tester) async {
    await search(tester, '광명');
    final clear = find.byTooltip('지우기');
    expect(clear, findsOneWidget);
    expect(
      find.descendant(of: find.byType(TextField), matching: clear),
      findsOneWidget,
      reason: '지우기 버튼이 입력칸 밖(앱바 오른쪽)에 따로 떠 있다',
    );
  });

  testWidgets('결과 카드는 제목 줄을 미리보기 줄로 되풀이하지 않는다', (tester) async {
    await search(tester, '광명');
    // 한 줄짜리 메모 — 제목 한 번만.
    expect(
      find.textContaining('1058 29 6 광명 16', findRichText: true),
      findsOneWidget,
      reason: '한 줄짜리 메모가 제목과 미리보기에 두 번 나온다',
    );
    // 두 줄 메모 — 미리보기는 둘째 줄에서 맞은 곳을 보여 준다.
    expect(
      find.textContaining('광명역 승강장 메모', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('0958 25 8 산천', findRichText: true),
      findsOneWidget,
      reason: '두 줄 메모의 제목 줄이 미리보기에 다시 나온다',
    );
  });
}
