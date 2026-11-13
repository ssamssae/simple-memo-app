import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/home_shell.dart';
import 'package:simple_memo_app/utils/app_palette.dart';

// T-261113-027: 다크 포인트색 = 호박 골드. 화면이 보라를 직접 들고 있으면
// 팔레트를 바꿔도 그 자리만 보라로 남는다 — 하단 탭·새메모 단추·즐겨찾기 별이
// 팔레트 accent 를 따르는지 잰다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('다크 포인트색은 호박 골드, 라이트는 보라 그대로', () {
    expect(AppPalette.dark.accent, const Color(0xFFF2B84B));
    expect(AppPalette.dark.onAccent, const Color(0xFF1F1606));
    expect(AppPalette.light.accent, const Color(0xFF7C5CFF));
    expect(AppPalette.purpleLight.accent, const Color(0xFF7C5CFF));
  });

  testWidgets('다크에서 하단 탭·새메모 단추·즐겨찾기 별이 팔레트 포인트색을 쓴다', (
    tester,
  ) async {
    final t = DateTime(2026, 11, 13, 9);
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        Memo(
          id: 'f',
          content: '즐겨찾기 메모',
          createdAt: t,
          updatedAt: t,
          isFavorite: true,
        ),
      ]),
    });
    const p = AppPalette.dark;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          extensions: const [p],
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: p.accent,
            brightness: Brightness.dark,
          ),
        ),
        home: const HomeShell(),
      ),
    );
    await tester.pumpAndSettle();

    final bar = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(bar.selectedItemColor, p.accent);

    final newMemoBox = tester.widget<Container>(
      find
          .ancestor(
            of: find.byIcon(Icons.add_box_outlined),
            matching: find.byType(Container),
          )
          .first,
    );
    expect((newMemoBox.decoration! as BoxDecoration).color, p.accent);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.add_box_outlined)).color,
      p.onAccent,
    );

    final star = tester.widget<Icon>(find.byIcon(Icons.star).first);
    expect(star.color, p.accent);
  });
}
