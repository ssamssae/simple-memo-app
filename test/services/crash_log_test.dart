import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_memo_app/services/crash_log.dart';

/// T-260730-057 — 크래시 가시성 가드.
///
/// 이 테스트가 지키는 것: 「잡은 에러가 ★다음 실행에서 읽히는가」.
/// 종전에는 debugPrint 로만 흘러서 기기를 회수하지 않으면 읽을 수 없었다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 전역 훅(FlutterError.onError · PlatformDispatcher.onError)은 테스트 간에
  // 살아남는다. 저장·복원하지 않으면 앞 테스트가 건 훅이 겹쳐서 같은 에러가
  // 두 번 기록된다 — 실제로 밟은 함정이라 여기서 못박는다.
  late void Function(FlutterErrorDetails)? savedFlutterOnError;
  late bool Function(Object, StackTrace)? savedPlatformOnError;

  setUp(() async {
    savedFlutterOnError = FlutterError.onError;
    savedPlatformOnError = PlatformDispatcher.instance.onError;
    CrashLog.resetInstalledForTest();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await CrashLog.clear();
  });

  tearDown(() {
    FlutterError.onError = savedFlutterOnError;
    PlatformDispatcher.instance.onError = savedPlatformOnError;
    CrashLog.resetInstalledForTest();
  });

  test('기록한 에러를 다음 실행에서 읽을 수 있다', () async {
    await CrashLog.record('zone', Exception('boom'), StackTrace.current);

    final entries = await CrashLog.read();
    expect(entries, hasLength(1));
    expect(entries.first['kind'], 'zone');
    expect(entries.first['error'], contains('boom'));
    expect(entries.first['stack'], isNotEmpty);
    expect(entries.first['at'], isNotEmpty);
  });

  test('기록이 없으면 빈 목록이다 (대조군 — 항상 1건 나오는 버그 차단)', () async {
    expect(await CrashLog.read(), isEmpty);
    expect(await CrashLog.dumpPrevious(), 0);
  });

  test('기록은 maxEntries 로 제한된다 — 무한 증가로 저장소를 먹지 않는다', () async {
    for (var i = 0; i < CrashLog.maxEntries + 5; i++) {
      await CrashLog.record('zone', Exception('e$i'), null);
    }

    final entries = await CrashLog.read();
    expect(entries, hasLength(CrashLog.maxEntries));
    // 오래된 5건(e0~e4)이 밀려나고 e5 가 가장 오래된 기록이 된다.
    expect(entries.first['error'], contains('e5'));
    expect(entries.last['error'], contains('e${CrashLog.maxEntries + 4}'));
  });

  test('긴 스택은 상한으로 잘린다', () async {
    await CrashLog.record(
      'zone',
      Exception('long'),
      StackTrace.fromString('x' * (CrashLog.maxStackChars + 500)),
    );

    final stack = (await CrashLog.read()).first['stack']!;
    expect(stack.length, lessThan(CrashLog.maxStackChars + 50));
    expect(stack, endsWith('(truncated)'));
  });

  test('clear 하면 비워진다', () async {
    await CrashLog.record('zone', Exception('boom'), null);
    expect(await CrashLog.read(), hasLength(1));

    await CrashLog.clear();
    expect(await CrashLog.read(), isEmpty);
  });

  test('★의도적 예외 1건 — FlutterError 훅이 실제로 잡아서 기록한다', () async {
    // flutter_test 는 자기 onError 를 걸어두고 보고된 에러가 있으면 테스트를
    // 실패시킨다. install() 이 기존 핸들러를 체인하는지도 같이 보려고
    // 감시용 핸들러로 갈아끼운다(복원은 tearDown).
    var chainedToPrevious = false;
    FlutterError.onError = (FlutterErrorDetails details) {
      chainedToPrevious = true;
    };

    CrashLog.install();
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: Exception('의도적 테스트 예외'),
        stack: StackTrace.current,
        library: 'crash_log_test',
      ),
    );
    await CrashLog.pendingWrite;

    final entries = await CrashLog.read();
    expect(entries, hasLength(1));
    expect(entries.first['kind'], 'flutter');
    expect(entries.first['error'], contains('의도적 테스트 예외'));
    // 기존 핸들러를 지우지 않고 체인했는지 — 콘솔 출력이 죽으면 안 된다.
    expect(chainedToPrevious, isTrue);
  });

  test('★의도적 예외 1건 — PlatformDispatcher 훅이 실제로 잡아서 기록한다', () async {
    CrashLog.install();

    final handler = PlatformDispatcher.instance.onError;
    expect(handler, isNotNull, reason: 'install() 이 훅을 걸어야 한다');
    handler!(Exception('의도적 플랫폼 예외'), StackTrace.current);
    await CrashLog.pendingWrite;

    final entries = await CrashLog.read();
    expect(entries, hasLength(1));
    expect(entries.first['kind'], 'platform');
    expect(entries.first['error'], contains('의도적 플랫폼 예외'));
  });

  test('install() 을 두 번 불러도 훅이 겹치지 않는다 — 중복 기록 차단', () async {
    FlutterError.onError = (FlutterErrorDetails details) {};

    CrashLog.install();
    CrashLog.install(); // 두 번째는 no-op 이어야 한다

    FlutterError.reportError(
      FlutterErrorDetails(exception: Exception('중복 확인용 예외')),
    );
    await CrashLog.pendingWrite;

    expect(await CrashLog.read(), hasLength(1));
  });

  test('기록 중 저장소가 터져도 throw 하지 않는다 — 계측이 앱을 죽이면 안 된다', () async {
    // record 는 에러 핸들러 안에서 불린다. 여기서 예외가 새어나가면
    // 크래시 계측이 크래시를 만든다.
    await CrashLog.clear();
    await expectLater(
      CrashLog.record('zone', _ThrowingError(), StackTrace.current),
      completes,
    );
  });
}

/// toString() 이 던지는 병적인 에러 객체 — record 의 방어를 실증한다.
class _ThrowingError implements Exception {
  @override
  String toString() => throw StateError('toString 이 터졌다');
}
