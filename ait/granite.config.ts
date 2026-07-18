import { defineConfig } from '@apps-in-toss/web-framework/config';

// T-260718-045 스파이크 전용 설정.
// appName 은 임시 플레이스홀더 — 앱인토스 콘솔 등록값 아님 (appName 은 등록 후 변경 불가라
// 실제 값은 아니키·본진 게이트에서 확정). deploy 는 이 스파이크에서 절대 호출하지 않는다.
export default defineConfig({
  appName: 'memoyo-spike-placeholder',
  brand: {
    displayName: '메모요 (스파이크)',
    primaryColor: '#4A90D9',
    icon: 'https://static.toss.im/appsintoss/placeholder.png',
  },
  web: {
    host: 'localhost',
    port: 5173,
    commands: {
      // flutter build web 은 Windows 측 toolchain 에서 선행 실행되고 (WSL 함정 우회,
      // wsl-flutter-test 패턴), 여기서는 산출물을 dist/ 로 복사만 한다.
      dev: 'npm run serve-flutter',
      build: 'npm run copy-flutter',
    },
  },
  permissions: [],
});
