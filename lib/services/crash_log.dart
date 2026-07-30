import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// T-260730-057 — 계정 0 · 외부 전송 0 크래시 가시성.
///
/// 왜 있나: 이 앱에는 크래시 SDK 가 없다(Crashlytics·Sentry 0건). 기존 에러 훅은
/// 잡은 에러를 debugPrint 로만 흘려서, 기기를 직접 회수하지 않으면 아무도 읽을 수
/// 없었다. 「첫 실행 이탈이 크래시 때문인가」를 답하려면 최소한 ★다음 실행에서
/// 읽을 수 있는 기록이 남아야 한다.
///
/// 의도적 경계 — 넓히기 전에 배차·정책을 먼저 확인할 것:
///  * 외부 전송 0. 네트워크 코드가 없다. 수집·전송은 별도 결정(R3) 사항이다.
///  * 신규 의존성 0. 이미 쓰던 shared_preferences 만 쓴다.
///  * ★Dart 레벨 에러만 잡는다. 네이티브 크래시(SIGSEGV·ANR·OOM)는 이 훅으로
///    잡히지 않는다 — 그건 스토어 콘솔(Play Android Vitals · ASC) 축이다.
class CrashLog {
  CrashLog._();

  /// SharedPreferences 키. v1 = 이 스키마의 첫 판.
  static const String storageKey = 'crash_log_v1';

  /// 저장 상한. 넘으면 오래된 것부터 밀어낸다 — 무한 증가로 저장소를 먹지 않게.
  static const int maxEntries = 20;

  /// 스택 1건의 문자 상한. 긴 스택이 prefs 를 통째로 먹는 걸 막는다.
  static const int maxStackChars = 2000;

  /// 훅이 띄운 마지막 기록 작업. 에러 핸들러는 동기라 await 할 수 없으므로
  /// 테스트가 완료를 기다릴 수 있도록 노출한다(프로덕션 코드는 쓰지 않는다).
  @visibleForTesting
  static Future<void>? pendingWrite;

  /// 크래시 1건 기록.
  ///
  /// ★에러 핸들러 안에서 불린다 — 어떤 경우에도 throw 하지 않는다.
  /// 기록에 실패해서 앱이 죽으면 본말전도다.
  ///
  /// 핸들러는 동기라 이 Future 를 await 할 수 없다. 대신 [pendingWrite] 에
  /// 남겨 두어 테스트가 완료를 기다릴 수 있게 한다.
  static Future<void> record(String kind, Object error, StackTrace? stack) {
    final future = _write(kind, error, stack);
    pendingWrite = future;
    return future;
  }

  static Future<void> _write(
    String kind,
    Object error,
    StackTrace? stack,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = prefs.getStringList(storageKey) ?? <String>[];
      entries.add(
        jsonEncode(<String, String>{
          'kind': kind,
          'error': error.toString(),
          'stack': _clip(stack?.toString() ?? '', maxStackChars),
          'at': DateTime.now().toIso8601String(),
        }),
      );
      if (entries.length > maxEntries) {
        entries.removeRange(0, entries.length - maxEntries);
      }
      await prefs.setStringList(storageKey, entries);
    } catch (e) {
      debugPrint('[CrashLog] record failed: $e');
    }
  }

  /// 저장된 기록을 ★기록순(오래된 것 먼저)으로 돌려준다.
  static Future<List<Map<String, String>>> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(storageKey) ?? <String>[];
      final out = <Map<String, String>>[];
      for (final line in raw) {
        try {
          final decoded = jsonDecode(line);
          if (decoded is Map) {
            out.add(decoded.map((k, v) => MapEntry('$k', '$v')));
          }
        } catch (_) {
          // 한 줄이 깨져도 나머지는 살린다.
        }
      }
      return out;
    } catch (e) {
      debugPrint('[CrashLog] read failed: $e');
      return <Map<String, String>>[];
    }
  }

  /// 기록 삭제.
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (e) {
      debugPrint('[CrashLog] clear failed: $e');
    }
  }

  /// ★다음 실행에서 읽는 경로. UI 는 건드리지 않고 콘솔로만 흘린다
  /// (`adb logcat` / Xcode 콘솔로 회수 가능). 읽어도 지우지 않는다 —
  /// 나중에 화면에 붙일 때 데이터가 남아 있어야 한다.
  ///
  /// 반환값 = 기록 건수.
  static Future<int> dumpPrevious() async {
    final entries = await read();
    if (entries.isEmpty) return 0;
    debugPrint('[CrashLog] errors recorded in previous run: ${entries.length}');
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      debugPrint('[CrashLog]  #$i ${e['at']} (${e['kind']}) ${e['error']}');
    }
    return entries.length;
  }

  static bool _installed = false;

  /// 테스트에서 훅 설치 상태를 되돌린다. 전역 훅은 테스트 간에 살아남는다.
  @visibleForTesting
  static void resetInstalledForTest() => _installed = false;

  /// 전역 훅 2종을 건다. 세 번째(runZonedGuarded)는 zone 을 감싸야 해서
  /// main() 쪽에서 직접 두르고 onError 에서 [record] 를 부른다.
  ///
  /// 기존 핸들러는 ★지우지 않고 체인한다 — 콘솔 출력·프레임워크 기본 동작
  /// (FlutterError.presentError)을 그대로 살린다.
  static void install() {
    // ★두 번 걸면 체인이 겹쳐 같은 에러가 중복 기록된다. 한 번만 건다.
    if (_installed) return;
    _installed = true;

    final previousFlutterOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      previousFlutterOnError?.call(details);
      unawaited(record('flutter', details.exception, details.stack));
    };

    final previousPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      unawaited(record('platform', error, stack));
      return previousPlatformOnError?.call(error, stack) ?? true;
    };
  }

  static String _clip(String s, int limit) =>
      s.length <= limit ? s : '${s.substring(0, limit)}…(truncated)';
}
