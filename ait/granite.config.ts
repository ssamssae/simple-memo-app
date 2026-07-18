import { defineConfig } from '@apps-in-toss/web-framework/config';

// T-260718-045 스파이크 전용 설정.
// appName 은 앱인토스 콘솔 등록값 memoyo 로 정렬됨 (T-260718-049 콘솔 등록, workspace minusbeta/60783,
// 앱 id 54955). 테스트 채널 .ait 업로드용. deploy(출시)·검토요청 은 이 스파이크에서 절대 호출하지 않는다.
export default defineConfig({
  appName: 'memoyo',
  brand: {
    displayName: '메모요',
    primaryColor: '#4A90D9',
    // 기존 스토어 아이콘 1024 자산의 600×600 불투명 다운스케일본 (T-260718-055).
    // brand.icon 은 런타임에 URI 로 주입되므로 도달 가능한 URL 필요 — public repo raw 참조.
    // 콘솔 정식 등록 아이콘이 확정되면 그 URL 로 교체한다 (spike 브랜치 삭제 시 이 URL 도 만료).
    icon: 'https://raw.githubusercontent.com/ssamssae/simple-memo-app/spike/T-260718-045-ait/docs/store-assets/memoyo_icon_600.png',
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
