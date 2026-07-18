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

  // T-260719-018: 설치 탭 직후(청크 수신 전) 진행 표시 — 준비중 문구 + indeterminate 바.
  testWidgets('installing at 0% shows preparing subtitle and indeterminate bar',
      (tester) async {
    final manager = _FakeModelManager(MiniLmModelState.installing);
    await tester.pumpWidget(_app(manager));

    expect(find.textContaining('다운로드 준비 중'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('minilm-install-progress')),
    );
    expect(bar.value, isNull);
  });

  // T-260719-018: 실패 사유 3분류 — 네트워크 계열 code 가 사유 문구로 표면화.
  testWidgets('error state surfaces network failure reason in subtitle',
      (tester) async {
    final manager = _FakeModelManager(
      MiniLmModelState.error,
      errorCode: 'MEMOYO_MINILM_DOWNLOAD_FAILED',
    );
    await tester.pumpWidget(_app(manager));

    expect(find.textContaining('네트워크 중단'), findsOneWidget);
  });

  // T-260719-018: 설치 시도 중 실패 전이 → 즉시 스낵바 알림 (사유 포함).
  for (final (code, reasonFragment) in const [
    ('MEMOYO_MINILM_DOWNLOAD_FAILED', '네트워크 중단'),
    ('MEMOYO_MINILM_HASH_MISMATCH', '모델 검증(SHA-256) 실패'),
    ('MEMOYO_MINILM_INSUFFICIENT_SPACE', '저장 공간 부족'),
  ]) {
    testWidgets('install failure $code shows immediate snackbar', (
      tester,
    ) async {
      final manager = _FakeModelManager(MiniLmModelState.installing);
      await tester.pumpWidget(_app(manager));

      manager.emit(MiniLmModelState.error, errorCode: code);
      await tester.pump();

      expect(
        find.byKey(const Key('minilm-install-failed-snackbar')),
        findsOneWidget,
      );
      expect(find.textContaining(reasonFragment), findsWidgets);
    });
  }

  // T-260719-018: 화면 진입 refresh 가 띄우는 error(설치 시도 아님)는 스낵바 미발화.
  testWidgets('non-install error transition does not fire snackbar', (
    tester,
  ) async {
    final manager = _FakeModelManager(MiniLmModelState.checking);
    await tester.pumpWidget(_app(manager));

    manager.emit(
      MiniLmModelState.error,
      errorCode: 'MEMOYO_MINILM_STATUS_FAILED',
    );
    await tester.pump();

    expect(
      find.byKey(const Key('minilm-install-failed-snackbar')),
      findsNothing,
    );
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
  _FakeModelManager(this._state, {String? errorCode}) : _errorCode = errorCode;

  MiniLmModelState _state;
  String? _errorCode;
  int installCalls = 0;
  int deleteCalls = 0;

  void emit(MiniLmModelState state, {String? errorCode}) {
    _state = state;
    _errorCode = errorCode;
    notifyListeners();
  }

  @override
  String? get errorCode => _errorCode;

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
