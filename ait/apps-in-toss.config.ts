import { defineConfig } from '@apps-in-toss/web-framework/config';

// 메모요 앱인토스 래퍼. appName은 콘솔 등록값 memoyo (ws 60783, 앱 id 54955).
// SDK3 후보 준비 전용. deploy·검토요청·출시는 이 작업에서 호출하지 않는다.
export default defineConfig({
  appName: 'memoyo',
  brand: {
    primaryColor: '#4A90D9',
  },
  permissions: [],
  webView: {
    pullToRefreshEnabled: false,
  },
  webBundleDir: 'dist',
});
