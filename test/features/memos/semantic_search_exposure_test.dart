// T-261103-001 — 말로찾기(뜻으로 찾기) 오프보딩 계약.
// (구 노출 계약 T-260806-022 → 그 전 잠금 계약 semantic_search_hidden_test, T-260804-086)
//
// ■왜 다시 닫았나
//   대종님 2026-11-03 00:3x 「메모요 뜻으로 찾기 오프보딩해줘」(설정 「설치된 모델 정보」 창 사진).
//   이번에는 돈이 아니라 ★기능 정리다 — 쓰지 않는 기능이 검색 화면과 설정에 자리를 차지하고,
//   받아 둔 사람의 폰에는 124MB 가 남는다. 코드는 지우지 않고 스위치 하나로 닫는다
//   (kSemanticSearchEnabled — 판정은 그 파일 하나뿐이다).
//
// ■무엇을 지키나
//   (a) 검색 화면에 「뜻으로 찾기」가 없다  (b) 일반 검색은 그대로 답을 준다
//   (c) 스위치 기본 OFF  (d) 받지 않은 사람에게 124MB 설치를 권하지 않는다
//   (e) 지우기 전 잠깐이라도 받은 사람에게는 삭제 문이 남는다
//   (f) ★받아 둔 모델 파일은 앱이 알아서 지운다 — 기능을 뺐는데 124MB 를 남기면 사용자 손해다
//
// ■mutation probe
//   flutter test --dart-define=MEMOYO_SEMANTIC_SEARCH=true \
//     test/features/memos/semantic_search_exposure_test.dart
//   스위치를 켠 실행에서는 (a)(c)(d)(f) 가 빨개져야 정상이다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/features/memos/semantic_search_availability.dart';
import 'package:simple_memo_app/features/memos/services/mini_lm_model_controller.dart';
import 'package:simple_memo_app/features/memos/services/mini_lm_model_installer.dart';
import 'package:simple_memo_app/features/memos/services/mini_lm_model_manifest.dart';
import 'package:simple_memo_app/models/memo.dart';
import 'package:simple_memo_app/screens/search_screen.dart';
import 'package:simple_memo_app/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Memo m(String id, String content) {
    final t = DateTime(2026, 8, 4, 10);
    return Memo(id: id, content: content, createdAt: t, updatedAt: t);
  }

  const miniLmChannel = MethodChannel('memoyo/minilm');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    messenger.setMockMethodCallHandler(miniLmChannel, (call) async {
      return switch (call.method) {
        'isSupported' => false,
        'close' => null,
        _ => null,
      };
    });
    SharedPreferences.setMockInitialValues({
      'memos': Memo.encodeList([
        m('dentist', '치과 예약\n스케일링 전화하기'),
        m('curry', '카레 레시피\n양파 볶기'),
      ]),
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(miniLmChannel, null);
  });

  testWidgets('(a) 검색 화면에 「뜻으로 찾기」가 없다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    await tester.pumpAndSettle();

    // ★대조군 먼저 — 검색 화면이 실제로 떴는지 증명한다.
    expect(
      find.byType(TextField),
      findsOneWidget,
      reason: '검색 화면이 안 떴다 — 아래 판정이 무의미해진다',
    );

    expect(
      find.text('뜻으로 찾기'),
      findsNothing,
      reason: '뺀 기능의 문이 검색 화면에 남았다 (T-261103-001)',
    );
    expect(find.text('일반 검색'), findsNothing, reason: '남는 방식이 하나뿐인데 선택기가 남았다');
  });

  testWidgets('(b) 일반 검색은 그대로 답을 준다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '치과');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('치과 예약', findRichText: true),
      findsWidgets,
      reason: '뜻으로 찾기를 빼다가 일반 검색까지 죽었다',
    );
  });

  test('(c) 스위치는 기본 OFF 다 — 대종님 오프보딩 결정(11/03)', () {
    expect(
      kSemanticSearchEnabled,
      isFalse,
      reason: '뜻으로 찾기가 다시 열렸다 — 되돌린 것이라면 (a)(d)(f) 도 같이 뒤집어야 한다',
    );
  });

  testWidgets('(d) 받지 않은 사람에게 설정이 124MB 설치를 권하지 않는다', (tester) async {
    final manager = _FakeModelManager(MiniLmModelState.absent);
    addTearDown(manager.dispose);

    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(miniLmModelManager: manager)),
    );
    await tester.pumpAndSettle();

    // ★대조군 먼저 — 설정 화면이 실제로 떴는지 증명한다.
    expect(
      find.text('글자 크기'),
      findsOneWidget,
      reason: '설정 화면이 안 떴다 — 아래 판정이 무의미해진다',
    );

    expect(
      find.byKey(const Key('minilm-model-tile')),
      findsNothing,
      reason: '뺀 기능을 위해 124MB 를 받으라고 권한다',
    );
  });

  testWidgets('(e) 아직 지워지지 않은 모델이 있으면 삭제 문이 남는다', (tester) async {
    // (f) 가 앱 시작 때 지우지만, 지우기 전이나 지우다 실패한 기기에서도 회수 문은 있어야 한다.
    final manager = _FakeModelManager(MiniLmModelState.ready);
    addTearDown(manager.dispose);

    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(miniLmModelManager: manager)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('minilm-model-tile')),
      findsOneWidget,
      reason: '설치된 모델의 타일까지 감췄다 — 124MB 를 지울 문이 사라진다',
    );
    await tester.ensureVisible(find.byKey(const Key('minilm-model-tile')));
    await tester.tap(find.byKey(const Key('minilm-model-tile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('minilm-delete-button')), findsOneWidget);
  });

  test('(f) 받아 둔 모델 파일(조각 파일 포함)을 앱이 지운다', () async {
    final dir = await Directory.systemTemp.createTemp('minilm-offboard-');
    addTearDown(() => dir.delete(recursive: true));
    final leftovers = [
      for (final artifact in MiniLmModelManifest.artifacts) ...[
        File('${dir.path}/${artifact.name}'),
        File('${dir.path}/${artifact.name}.part'),
      ],
    ];
    for (final file in leftovers) {
      await file.writeAsString('model bytes');
    }
    // ★대조군 — 다른 파일은 건드리지 않는다.
    final unrelated = File('${dir.path}/memo-photo.jpg');
    await unrelated.writeAsString('photo');

    final installer = MiniLmModelInstaller(
      directoryProvider: () async => dir,
      freeSpaceProvider: (_) async => 1 << 40,
    );
    await offboardSemanticSearchModel(installer: installer);

    for (final file in leftovers) {
      expect(
        await file.exists(),
        isFalse,
        reason: '${file.path} 가 남았다 — 기능을 뺐는데 용량을 안 돌려줬다',
      );
    }
    expect(await unrelated.exists(), isTrue, reason: '모델 파일이 아닌 것까지 지웠다');
  });
}

class _FakeModelManager extends MiniLmModelManager {
  _FakeModelManager(this._state);

  final MiniLmModelState _state;

  @override
  String? get errorCode => null;

  @override
  double get progress => 0;

  @override
  MiniLmModelState get state => _state;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> install() async {}

  @override
  Future<void> delete() async {}
}
