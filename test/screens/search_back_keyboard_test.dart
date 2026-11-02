import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/screens/search_screen.dart';

// T-261103-001: 대종님 폰에서 검색 화면에 들어갔다 뒤로 오면 메모 목록 위에 키보드가 남은 적이
// 있다(사진: 메모 목록 + 「검색」 키 달린 한글 키보드). 검색 입력칸이 화면이 완전히 사라질 때까지
// 앱은 뒤로 가는 순간 입력칸 포커스를 놓고 키보드 내림을 보낸다(시험으로 확인). 그런데 들어오자마자
// 뒤로 가면 그 내림이 아이폰 키보드 올림과 엇갈려 묻힐 수 있다. 화면이 사라진 뒤 한 번 더 내린다.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> openSearch(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
                ),
                child: const Text('검색 열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('검색 열기'));
    await tester.pumpAndSettle();
  }

  testWidgets('검색 화면이 완전히 사라진 뒤 키보드를 한 번 더 내린다', (tester) async {
    await openSearch(tester);
    expect(
      tester.testTextInput.isVisible,
      isTrue,
      reason: '대조군: 검색 화면은 키보드를 올린다',
    );

    await tester.pageBack();
    await tester.pump(); // 전환 첫 프레임 — 입력칸은 여기서 이미 포커스를 놓는다.
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isFalse,
    );

    // ★아이폰에서는 들어오자마자 뒤로 가면 이 첫 내림이 올림과 엇갈려 묻힐 수 있다.
    //   그래서 전환이 끝나 화면이 사라진 뒤에 한 번 더 내리는지를 본다.
    tester.testTextInput.log.clear();
    await tester.pumpAndSettle();
    expect(find.text('검색 열기'), findsOneWidget);
    expect(find.byType(EditableText), findsNothing, reason: '대조군: 검색 화면이 사라졌다');
    expect(
      tester.testTextInput.log.map((call) => call.method),
      contains('TextInput.hide'),
      reason: '검색 화면이 사라진 뒤 키보드 내림을 다시 보내지 않는다 — 첫 내림이 묻히면 목록 위에 남는다',
    );
  });
}
