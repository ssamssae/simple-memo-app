import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_memo_app/features/memos/services/mini_lm_model_controller.dart';
import 'package:simple_memo_app/features/memos/services/mini_lm_model_manifest.dart';
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
    // T-260811-015: 종전 기대값은 '설치됨' 이었다. 설치 후 서브타이틀이 모델 정체를
    //   담도록 바뀌면서 그 낱말이 사라졌으므로, 같은 뜻을 재는 조각으로 옮긴다.
    expect(find.textContaining('오프라인 검색 가능'), findsOneWidget);
  });

  // ★T-260805-145 로 이 파일에 이사 온 축.
  //   원래 settings_screen_test.dart 의 「미지원 기기는 Gemini 폴백을 표시한다」가 이걸 쟀는데,
  //   그 테스트는 ★설정 화면에 타일이 보인다는 전제 위에 서 있었다. 말로찾기가 잠긴 동안
  //   설정 화면은 그 타일을 아예 안 보여주는 것이 새 계약이라 그 자리에서는 잴 수 없다.
  //   그렇다고 지우면 unsupported 소제목을 재는 유일한 축이 사라지므로, 게이트가 걸리지 않는
  //   ★타일 단위인 여기로 옮긴다. (계약은 바뀌었지만 커버리지는 안 잃는다)
  testWidgets('unsupported device shows the Gemini fallback subtitle', (
    tester,
  ) async {
    final manager = _FakeModelManager(MiniLmModelState.unsupported);
    await tester.pumpWidget(_app(manager));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('minilm-model-tile')), findsOneWidget);
    expect(find.text('기기 내 뜻 검색 모델'), findsOneWidget);
    expect(find.text('이 기기에서는 Gemini 검색을 사용합니다'), findsOneWidget);
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

  // T-260811-015: 아니키 지적 — 설치 후 「어떤 모델이 설치되어 있는지 확인이 안 됨」.
  //   설치 전에는 용량·라이선스가 보이는데 설치되면 그마저 사라지던 상태를 고정한다.
  testWidgets('installed subtitle names the model with size and license', (
    tester,
  ) async {
    final manager = _FakeModelManager(MiniLmModelState.ready);
    await tester.pumpWidget(_app(manager));
    await tester.pumpAndSettle();

    expect(find.textContaining('MiniLM'), findsOneWidget);
    expect(find.textContaining('Apache-2.0'), findsOneWidget);
    // ★용량은 매니페스트 합계에서 도출된다 — 하드코딩이면 상수가 바뀌어도 안 움직인다.
    //   기준 = MB 10^6 · 올림 ⇒ ceil(123481449/1e6) = 124.
    expect(
      find.textContaining(
        '${(MiniLmModelManifest.totalDownloadBytes / 1000000).ceil()}MB',
      ),
      findsOneWidget,
    );
  });

  // 한 줄에 못 담는 값(저장소 전체 이름·리비전·해시)은 탭했을 때만 펼친다.
  testWidgets('tapping the installed tile opens model details', (tester) async {
    final manager = _FakeModelManager(MiniLmModelState.ready);
    await tester.pumpWidget(_app(manager));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('minilm-model-tile')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('minilm-details-dialog')), findsOneWidget);
    expect(find.textContaining(MiniLmModelManifest.repository), findsOneWidget);
    expect(
      find.textContaining(MiniLmModelManifest.revision.substring(0, 8)),
      findsOneWidget,
    );
    expect(find.textContaining(MiniLmModelManifest.model.name), findsOneWidget);
    // 상세는 읽기 전용이다 — 설치·삭제 어느 것도 호출되지 않아야 한다.
    expect(manager.installCalls, 0);
    expect(manager.deleteCalls, 0);

    await tester.tap(find.byKey(const Key('minilm-details-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('minilm-details-dialog')), findsNothing);
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

  // T-260730-029: 3분류 밖 코드는 화면에 코드가 보여야 한다 (아니키 기기 실측이 이 분기였고
  //   코드가 안 보여서 근인을 못 좁혔다 — 감사 PR#1409 §4).
  testWidgets('unclassified error code is surfaced in subtitle', (tester) async {
    final manager = _FakeModelManager(
      MiniLmModelState.error,
      errorCode: 'MEMOYO_MINILM_STATUS_FAILED',
    );
    await tester.pumpWidget(_app(manager));

    expect(find.textContaining('설치 실패'), findsOneWidget);
    expect(find.textContaining('[#STATUS_FAILED]'), findsOneWidget);
  });

  // 코드가 없으면 덧붙이지 않는다 (빈 괄호를 보여주지 않는다).
  testWidgets('null error code keeps the plain generic message', (tester) async {
    final manager = _FakeModelManager(MiniLmModelState.error);
    await tester.pumpWidget(_app(manager));

    expect(find.textContaining('설치 실패'), findsOneWidget);
    expect(find.textContaining('[#'), findsNothing);
  });

  // 3분류 문구는 그대로 — 사유를 이미 말하므로 코드를 덧붙이지 않는다.
  testWidgets('classified reason text stays code-free', (tester) async {
    final manager = _FakeModelManager(
      MiniLmModelState.error,
      errorCode: 'MEMOYO_MINILM_INSUFFICIENT_SPACE',
    );
    await tester.pumpWidget(_app(manager));

    expect(find.textContaining('[#'), findsNothing);
  });

  // 스낵바 경로도 같은 규칙 (설치 시도 중 분류 밖 실패).
  testWidgets('install failure snackbar surfaces unclassified code', (
    tester,
  ) async {
    final manager = _FakeModelManager(MiniLmModelState.installing);
    await tester.pumpWidget(_app(manager));

    manager.emit(
      MiniLmModelState.error,
      errorCode: 'MEMOYO_MINILM_INSTALL_FAILED',
    );
    await tester.pump();

    expect(
      find.byKey(const Key('minilm-install-failed-snackbar')),
      findsOneWidget,
    );
    expect(find.textContaining('[#INSTALL_FAILED]'), findsWidgets);
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
