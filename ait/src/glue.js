// T-260718-045 스파이크 — 앱인토스 SDK 글루.
// esbuild 로 IIFE 번들해 web/ait_glue.js 로 배치, Flutter 웹 앱이
// window.__AIT__ 표면(dart:js_interop)으로 소비한다.
import { Storage, closeView, getPlatformOS, getSafeAreaInsets } from '@apps-in-toss/web-framework';

// 토스 러닝타임 감지 — bridge-core 가 쓰는 주입 마커 실측 기준
// (window.ReactNativeWebView + __GRANITE_NATIVE_EMITTER).
const available =
  typeof window !== 'undefined' &&
  !!(window.ReactNativeWebView && window.__GRANITE_NATIVE_EMITTER);

const AIT = {
  available,
  safeAreaInsets: null,
  storageGet: (k) => Storage.getItem(k),
  storageSet: (k, v) => Storage.setItem(k, v),
  storageRemove: (k) => Storage.removeItem(k),
  closeView: () => closeView(),
  platformOS: async () => {
    try {
      return await getPlatformOS();
    } catch {
      return null;
    }
  },
};

if (available) {
  try {
    Promise.resolve(getSafeAreaInsets())
      .then((v) => {
        AIT.safeAreaInsets = v ?? null;
      })
      .catch(() => {});
  } catch {
    /* SDK 미지원 환경 — 폴백 유지 */
  }
}

window.__AIT__ = AIT;
