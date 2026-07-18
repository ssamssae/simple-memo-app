// T-260718-045 앱인토스 웹 래퍼 스파이크 — JS interop 브릿지.
//
// web/ait_glue.js 가 @apps-in-toss/web-framework ESM 을 번들해 window.__AIT__ 로
// 노출하고, 이 파일은 그 표면만 호출한다. 토스 러닝타임 밖(일반 브라우저)에서는
// __AIT__.available == false 로 떨어져 전 API 가 안전 폴백된다.
//
// 스파이크 검증 대상 4항 매핑:
//  (a) SDK 호출 성립  → available / platformOS / schemeUri
//  (b) 뒤로가기       → closeView (루트에서 PopScope 이탈 시 호출)
//  (c) Storage 어댑터 → storageGet/Set/Remove (AitMemoStore 가 소비)
//  (d) safe area      → safeAreaInsets
import 'dart:async';
import 'dart:js_interop';

@JS('__AIT__')
external _AitGlue? get _ait;

extension type _AitGlue(JSObject _) implements JSObject {
  external bool get available;
  external JSPromise<JSString?> storageGet(JSString key);
  external JSPromise<JSAny?> storageSet(JSString key, JSString value);
  external JSPromise<JSAny?> storageRemove(JSString key);
  external JSPromise<JSAny?> closeView();
  external JSPromise<JSString?> platformOS();
  external _AitInsets? get safeAreaInsets;
}

extension type _AitInsets(JSObject _) implements JSObject {
  external double get top;
  external double get bottom;
  external double get left;
  external double get right;
}

class AitInsets {
  const AitInsets(this.top, this.bottom, this.left, this.right);
  final double top, bottom, left, right;
  @override
  String toString() => 'T$top B$bottom L$left R$right';
}

/// 앱인토스 SDK 브릿지. 글루 부재/일반 브라우저에서는 전부 안전 폴백.
class AitBridge {
  /// 글루가 로드됐고 SDK 가 토스 러ntime 을 감지했는가.
  static bool get sdkAvailable => _ait?.available ?? false;

  /// 글루 스크립트 자체가 로드됐는가 (SDK 미탐지와 구분 — 진단용).
  static bool get glueLoaded => _ait != null;

  static Future<String?> storageGet(String key) async {
    final g = _ait;
    if (g == null || !g.available) return null;
    final v = await g.storageGet(key.toJS).toDart;
    return v?.toDart;
  }

  static Future<bool> storageSet(String key, String value) async {
    final g = _ait;
    if (g == null || !g.available) return false;
    await g.storageSet(key.toJS, value.toJS).toDart;
    return true;
  }

  static Future<bool> storageRemove(String key) async {
    final g = _ait;
    if (g == null || !g.available) return false;
    await g.storageRemove(key.toJS).toDart;
    return true;
  }

  /// 루트 뒤로가기 → 미니앱 종료. SDK 부재 시 no-op(false).
  static Future<bool> closeView() async {
    final g = _ait;
    if (g == null || !g.available) return false;
    await g.closeView().toDart;
    return true;
  }

  static Future<String?> platformOS() async {
    final g = _ait;
    if (g == null || !g.available) return null;
    final v = await g.platformOS().toDart;
    return v?.toDart;
  }

  static AitInsets? get safeAreaInsets {
    final i = _ait?.safeAreaInsets;
    if (i == null) return null;
    return AitInsets(i.top, i.bottom, i.left, i.right);
  }
}
