import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/memos/semantic_search_availability.dart';
import 'package:simple_memo_app/features/memos/services/embedding_engine.dart';
import 'package:simple_memo_app/features/memos/services/semantic_search_coordinator.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/search_screen.dart';
import 'package:simple_memo_app/services/memo_storage.dart';

void main() {
  late List<Memo> memos;

  setUp(() {
    final time = DateTime(2026, 10, 16);
    memos = [
      Memo(id: 'one', content: '첫 결과', createdAt: time, updatedAt: time),
      Memo(id: 'two', content: '다음 결과', createdAt: time, updatedAt: time),
    ];
    SharedPreferences.setMockInitialValues({'memos': Memo.encodeList(memos)});
  });

  Future<void> openSearch(
    WidgetTester tester,
    _DeferredCoordinator coordinator,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: SearchScreen(semanticCoordinator: coordinator)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('새 입력의 디바운스 중에는 이전 뜻 검색 결과를 표시하지 않는다', (tester) async {
    final coordinator = _DeferredCoordinator();
    await openSearch(tester, coordinator);
    await tester.tap(find.text('뜻으로 찾기'));
    await tester.enterText(find.byType(TextField), '이전 검색어');
    await tester.pump(const Duration(milliseconds: 350));
    expect(coordinator.requests, hasLength(1));

    await tester.enterText(find.byType(TextField), '새 검색어');
    coordinator.requests.first.complete([memos.first]);
    await tester.pump();
    expect(find.textContaining('첫 결과', findRichText: true), findsNothing);

    await tester.pump(const Duration(milliseconds: 350));
    expect(coordinator.requests, hasLength(2));
    coordinator.requests.last.complete([memos.last]);
    await tester.pumpAndSettle();
    expect(find.textContaining('다음 결과', findRichText: true), findsWidgets);
  }, skip: !kSemanticSearchEnabled);

  testWidgets('입력 직후 검색 방식을 바꿔도 같은 뜻 검색은 한 번만 시작한다', (tester) async {
    final coordinator = _DeferredCoordinator();
    await openSearch(tester, coordinator);
    await tester.enterText(find.byType(TextField), '검색어');
    await tester.tap(find.text('뜻으로 찾기'));
    await tester.pump();
    expect(coordinator.requests, hasLength(1));
    coordinator.requests.first.complete([memos.first]);
    await tester.pump(const Duration(milliseconds: 350));
    expect(coordinator.requests, hasLength(1));
    await tester.pumpAndSettle();
  }, skip: !kSemanticSearchEnabled);

  testWidgets('검색에서 편집한 메모를 늦은 색인 저장이 덮어쓰지 않는다', (tester) async {
    final coordinator = _DeferredCoordinator();
    await openSearch(tester, coordinator);
    await tester.tap(find.text('뜻으로 찾기'));
    await tester.enterText(find.byType(TextField), '첫');
    await tester.pump(const Duration(milliseconds: 350));
    final oldSearch = coordinator.requests.single;
    await tester.tap(find.textContaining('첫 결과', findRichText: true).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '수정한 첫 결과');
    await tester.tap(find.text('저장'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect((await MemoStorage.loadMemos()).first.content, '수정한 첫 결과');

    await oldSearch.persist(oldSearch.memos);
    oldSearch.complete([oldSearch.memos.first]);
    await tester.pump();
    expect((await MemoStorage.loadMemos()).first.content, '수정한 첫 결과');
    final resumed = coordinator.requests.last;
    resumed.complete([resumed.memos.first]);
    await tester.pumpAndSettle();
    expect(find.textContaining('수정한 첫 결과', findRichText: true), findsWidgets);
  }, skip: !kSemanticSearchEnabled);

  testWidgets('검색 화면을 닫은 뒤에는 늦은 색인 저장을 무시한다', (tester) async {
    final coordinator = _DeferredCoordinator();
    await openSearch(tester, coordinator);
    await tester.tap(find.text('뜻으로 찾기'));
    await tester.enterText(find.byType(TextField), '첫');
    await tester.pump(const Duration(milliseconds: 350));
    final oldSearch = coordinator.requests.single;
    await tester.pumpWidget(const SizedBox.shrink());
    final updated = memos.first.copyWith(content: '다른 화면에서 수정');
    await MemoStorage.saveMemos([updated, memos.last]);

    await oldSearch.persist(oldSearch.memos);
    oldSearch.complete([oldSearch.memos.first]);
    await tester.pump();
    expect((await MemoStorage.loadMemos()).first.content, '다른 화면에서 수정');
    expect(tester.takeException(), isNull);
  }, skip: !kSemanticSearchEnabled);

  testWidgets('입력 직후 메모를 열었다 돌아오면 현재 입력으로 검색한다', (tester) async {
    await openSearch(tester, _DeferredCoordinator());
    await tester.enterText(find.byType(TextField), '첫');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byType(TextField), '다음');
    await tester.tap(find.textContaining('첫 결과', findRichText: true).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '다음',
    );
    expect(find.textContaining('다음 결과', findRichText: true), findsWidgets);
    expect(find.textContaining('첫 결과', findRichText: true), findsNothing);
  });
}

class _DeferredCoordinator extends SemanticSearchCoordinator {
  _DeferredCoordinator()
    : super(policy: SemanticEnginePolicy.ondevicePreferred);

  final requests = <_PendingSearch>[];

  @override
  Future<SemanticSearchOutcome> search({
    required String query,
    required List<Memo> memos,
    required SemanticIndexPersist persist,
    void Function(SemanticReindexProgress progress)? onProgress,
  }) {
    final request = _PendingSearch(List.of(memos), persist);
    requests.add(request);
    return request.completer.future;
  }
}

class _PendingSearch {
  _PendingSearch(this.memos, this.persist);

  final List<Memo> memos;
  final SemanticIndexPersist persist;
  final completer = Completer<SemanticSearchOutcome>();

  void complete(List<Memo> results) {
    completer.complete(
      SemanticSearchOutcome(
        memos: memos,
        results: results,
        semantic: true,
        changed: false,
      ),
    );
  }
}
