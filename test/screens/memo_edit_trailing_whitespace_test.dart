import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/memo_edit_screen.dart';

/// T-260718-021: 라인 끝 잔여 공백 유령 현상.
///
/// 아니키 실기기 영상(2026-07-18) 판독 결과 — 라인 끝에 축적된 긴 공백 런의
/// "중간"에 탭 커서가 꽂혀, 백스페이스로 왼쪽만 지우면 오른쪽 잔여가 남아
/// 재진입 때마다 공백이 부활하는 것처럼 보인다. 저장 시 라인별 trailing
/// whitespace 를 정규화해 이 계열을 차단한다 (문장 중간 공백은 보존 —
/// 기존 선택 clamp 철학과 동일).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpEditor(
    WidgetTester tester, {
    Memo? memo,
    required ValueChanged<Memo> onSave,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MemoEditScreen(memo: memo, onSave: onSave),
                  ),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
  }

  testWidgets('뒤로 저장 시 라인 끝 공백·탭이 제거된다', (tester) async {
    final memo = Memo.create(
      content: '1233 24 8\n\n7 2 37          \n\n부산 0949 서울 1233\t',
    );
    Memo? saved;
    await pumpEditor(tester, memo: memo, onSave: (m) => saved = m);

    await tester.tap(find.text('뒤로'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.content, '1233 24 8\n\n7 2 37\n\n부산 0949 서울 1233');
  });

  testWidgets('문장 중간 연속 공백은 보존된다', (tester) async {
    final memo = Memo.create(content: '동대구 1043   서울 1233\n행낭 1개(2개입) 14호차');
    Memo? saved;
    await pumpEditor(tester, memo: memo, onSave: (m) => saved = m);

    await tester.tap(find.text('뒤로'));
    await tester.pumpAndSettle();

    expect(saved!.content, '동대구 1043   서울 1233\n행낭 1개(2개입) 14호차');
  });

  testWidgets('저장 버튼 경로도 동일하게 정규화된다', (tester) async {
    final memo = Memo.create(content: '제목 라인   \n본문  \n');
    Memo? saved;
    await pumpEditor(tester, memo: memo, onSave: (m) => saved = m);

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(saved!.content, '제목 라인\n본문');
  });

  testWidgets('둘째 줄 이후의 들여쓰기(라인 앞 공백)는 보존된다', (tester) async {
    final memo = Memo.create(content: '첫줄\n  들여쓴 둘째줄');
    Memo? saved;
    await pumpEditor(tester, memo: memo, onSave: (m) => saved = m);

    await tester.tap(find.text('뒤로'));
    await tester.pumpAndSettle();

    expect(saved!.content, '첫줄\n  들여쓴 둘째줄');
  });
}
