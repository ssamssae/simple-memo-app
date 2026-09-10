import { Migration } from '@apps-in-toss/web-framework';
import { runOriginStorageMigration } from './origin-storage-migration-core.mjs';

const AIT_HOST = /(^|\.)(?:private-)?apps\.tossmini\.com$/;

async function prepareStorageBeforeFlutter() {
  if (!AIT_HOST.test(window.location.hostname)) {
    return { status: 'local_development' };
  }
  try {
    return await runOriginStorageMigration(
      () => Migration.getOriginStorage(),
      window.localStorage,
    );
  } catch (error) {
    return { status: 'blocked', reason: 'storage_access_failed', error: String(error) };
  }
}

const result = await prepareStorageBeforeFlutter();
window.__memoyoOriginMigration = result;
window.dispatchEvent(new CustomEvent('memoyo-origin-migration', { detail: result }));

if (result.status === 'blocked') {
  const message = document.createElement('p');
  const needsRecovery = ['validation_or_conflict', 'invalid_marker', 'write_race'].includes(
    result.reason,
  );
  message.textContent = needsRecovery
    ? '저장 데이터가 서로 달라 자동으로 불러올 수 없습니다. 앱 데이터를 지우지 말고 개발자에게 문의해 주세요.'
    : '저장 데이터 확인을 완료하지 못했습니다. 잠시 후 앱을 다시 열어 주세요.';
  message.setAttribute('role', 'alert');
  document.body.append(message);
  console.warn('[memoyo] origin storage migration blocked', result.reason);
} else {
  await import('./flutter_bootstrap.js');
}
