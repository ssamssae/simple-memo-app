import { defineConfig } from '@apps-in-toss/web-framework/config';

// T-260718-045 스파이크 전용 설정.
// appName 은 앱인토스 콘솔 등록값 memoyo 로 정렬됨 (T-260718-049 콘솔 등록, workspace minusbeta/60783,
// 앱 id 54955). 테스트 채널 .ait 업로드용. deploy(출시)·검토요청 은 이 스파이크에서 절대 호출하지 않는다.
export default defineConfig({
  appName: 'memoyo',
  brand: {
    displayName: '메모요',
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
