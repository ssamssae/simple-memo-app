import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/mini_lm_model_controller.dart';
import 'package:simple_memo_app/features/memos/widgets/mini_lm_model_settings_tile.dart';

void main() {
  testWidgets('install requires a second explicit confirmation tap', (
    tester,
  ) async {
    final manager = _FakeModelManager(MiniLmModelState.absent);
    await tester.pumpWidget(_app(manager));

    await tester.tap(find.byKey(const Key('minilm-model-tile')));
    await tester.pumpAndSettle();

    expect(find.text('뜻 검색 모델 설치'), findsOneWidget);
    expect(find.textContaining('SHA-256 검증'), findsOneWidget);
    expect(manager.installCalls, 0);

    await tester.tap(find.byKey(const Key('minilm-install-confirm')));
    await tester.pumpAndSettle();

    expect(manager.installCalls, 1);
    expect(find.textContaining('설치됨'), findsOneWidget);
  });

  testWidgets('installed model deletion also requires confirmation', (
    tester,
  ) async {
    final manager = _FakeModelManager(MiniLmModelState.ready);
    await tester.pumpWidget(_app(manager));

    await tester.tap(find.byKey(const Key('minilm-delete-button')));
    await tester.pumpAndSettle();
    expect(manager.deleteCalls, 0);
    expect(find.text('뜻 검색 모델 삭제'), findsOneWidget);

    await tester.tap(find.byKey(const Key('minilm-delete-confirm')));
    await tester.pumpAndSettle();

    expect(manager.deleteCalls, 1);
    expect(find.textContaining('약 124MB'), findsOneWidget);
  });
}

Widget _app(MiniLmModelManager manager) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: ListView(children: [MiniLmModelSettingsTile(manager: manager)]),
    ),
  );
}

class _FakeModelManager extends MiniLmModelManager {
  _FakeModelManager(this._state);

  MiniLmModelState _state;
  int installCalls = 0;
  int deleteCalls = 0;

  @override
  String? get errorCode => null;

  @override
  double get progress => 0;

  @override
  MiniLmModelState get state => _state;

  @override
  Future<void> delete() async {
    deleteCalls++;
    _state = MiniLmModelState.absent;
    notifyListeners();
  }

  @override
  Future<void> install() async {
    installCalls++;
    _state = MiniLmModelState.ready;
    notifyListeners();
  }

  @override
  Future<void> refresh() async {}
}
