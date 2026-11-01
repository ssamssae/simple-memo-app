// T-261101-034 ② — 즐겨찾기를 풀면 즐겨찾기 전 일반 목록 자리로 돌아간다.
//
// 대종님 아이폰 제보: 즐겨찾기하면 맨 위로 가는데, 풀어도 원래 자리로 안 돌아가고 맨 위에 남는다.
// 목록 순서 = 저장된 배열 순서(새 메모는 일반 묶음 맨 위, 끌어서 옮기기). 즐겨찾기 묶음은 늘 앞.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 11, 1, 9);

  Memo memo(String id, String title, {int minutesAgo = 0, bool fav = false}) {
    final at = now.subtract(Duration(minutes: minutesAgo));
    return Memo(
      id: id,
      content: '$title\n본문',
      isFavorite: fav,
      createdAt: at,
      updatedAt: at,
    );
  }

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MemoListScreen()));
    await tester.pumpAndSettle();
  }

  // 오른쪽으로 밀면 나오는 별 버튼. 일반 메모는 Icons.star, 즐겨찾기 메모는 Icons.star_outline.
  Future<void> swipeStar(
    WidgetTester tester,
    String title,
    IconData icon,
  ) async {
    await tester.drag(find.text(title), const Offset(90, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(icon));
    await tester.pumpAndSettle();
  }

  List<String> onScreen(WidgetTester tester, List<String> titles) {
    final top = {for (final t in titles) t: tester.getTopLeft(find.text(t)).dy};
    return [...titles]..sort((a, b) => top[a]!.compareTo(top[b]!));
  }

  Future<List<String>> saved() async {
    final prefs = await SharedPreferences.getInstance();
    return Memo.decodeList(
      prefs.getString('memos') ?? '[]',
    ).map((m) => m.id).toList();
  }

  const titles = ['메모 A', '메모 B', '메모 C'];

  testWidgets('가운데 메모를 즐겨찾기했다가 풀면 원래 자리로 돌아간다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        memo('a', '메모 A'),
        memo('b', '메모 B', minutesAgo: 10),
        memo('c', '메모 C', minutesAgo: 20),
      ]),
    });
    await pumpList(tester);
    expect(onScreen(tester, titles), titles);

    await swipeStar(tester, '메모 B', Icons.star);
    expect(onScreen(tester, titles), [
      '메모 B',
      '메모 A',
      '메모 C',
    ], reason: '즐겨찾기하면 맨 위 즐겨찾기 묶음으로 간다 (기존 동작)');

    await swipeStar(tester, '메모 B', Icons.star_outline);
    expect(
      onScreen(tester, titles),
      titles,
      reason: '풀면 A 와 C 사이 원래 자리로 돌아와야 한다',
    );
    expect(await saved(), ['a', 'b', 'c']);
  });

  testWidgets('앱을 다시 켠 뒤 풀어도 원래 자리로 돌아간다 — 자리 기억이 저장된다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        memo('a', '메모 A'),
        memo('b', '메모 B', minutesAgo: 10),
        memo('c', '메모 C', minutesAgo: 20),
      ]),
    });
    await pumpList(tester);
    await swipeStar(tester, '메모 B', Icons.star);

    // 앱 재시작: 화면 State 를 버리고 새로 띄운다. 남는 것은 저장소뿐이다.
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpList(tester);
    expect(onScreen(tester, titles), ['메모 B', '메모 A', '메모 C']);

    await swipeStar(tester, '메모 B', Icons.star_outline);
    expect(onScreen(tester, titles), titles);
    expect(await saved(), ['a', 'b', 'c']);
  });

  testWidgets('자리 기록이 없는 옛 즐겨찾기는 맨 위가 아니라 만든 시각 자리로 간다', (tester) async {
    // 이번 수정 전에 즐겨찾기한 메모 = 저장 데이터에 자리 기록이 없다.
    // 새 메모가 위에 쌓이는 평소 순서(최신 → 오래된)에서 B 의 자리는 A 와 C 사이다.
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        memo('b', '메모 B', minutesAgo: 10, fav: true),
        memo('a', '메모 A'),
        memo('c', '메모 C', minutesAgo: 20),
      ]),
    });
    await pumpList(tester);
    expect(onScreen(tester, titles), ['메모 B', '메모 A', '메모 C']);

    await swipeStar(tester, '메모 B', Icons.star_outline);
    expect(onScreen(tester, titles), titles);
    expect(await saved(), ['a', 'b', 'c']);
  });
}
