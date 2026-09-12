import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import vm from 'node:vm';

const source = await readFile(new URL('../src/glue.js', import.meta.url), 'utf8');
const sdkImport = "import { Storage, closeView, getPlatformOS, getSafeAreaInsets } from '@apps-in-toss/web-framework';";
assert.ok(source.includes(sdkImport));
// Execute the real glue surface; substitute only the SDK's native transport.
const runnable = source.replace(sdkImport,
  'const { Storage, closeView, getPlatformOS, getSafeAreaInsets } = sdk;');

function setup({ native = true, legacy = false, rejectInsets = false } = {}) {
  const raw = JSON.stringify([{ id: 'fixture-existing', content: 'synthetic memo' }]);
  const stored = new Map([['memos', raw]]);
  const calls = { reads: [], writes: 0, removals: 0, browserAccess: 0, insets: 0 };
  const window = {};
  if (native) window.ReactNativeWebView = { postMessage() {} };
  if (legacy) window.__GRANITE_NATIVE_EMITTER = {};
  for (const name of ['localStorage', 'sessionStorage']) {
    Object.defineProperty(window, name, { get() {
      calls.browserAccess++;
      throw new Error('browser storage must not be accessed by glue');
    } });
  }
  const sdk = {
    Storage: {
      getItem: async key => { calls.reads.push(key); return stored.get(key) ?? null; },
      setItem: async () => { calls.writes++; throw new Error('unexpected write'); },
      removeItem: async () => { calls.removals++; throw new Error('unexpected removal'); },
    },
    closeView() {},
    getPlatformOS: async () => 'ios',
    getSafeAreaInsets: async () => {
      calls.insets++;
      if (rejectInsets) throw new Error('fixture insets unavailable');
      return { top: 1, bottom: 2, left: 0, right: 0 };
    },
  };
  return { window, sdk, calls, stored, raw, run() {
    vm.runInNewContext(runnable, { window, sdk, Promise });
    return window.__AIT__;
  } };
}

test('SDK3 native bridge without legacy emitter keeps existing SDK memos readable', async () => {
  const fixture = setup();
  const ait = fixture.run();
  assert.equal(ait.available, true);
  assert.equal(await ait.storageGet('memos'), fixture.raw);
  assert.deepEqual(fixture.calls.reads, ['memos']);
  assert.equal(fixture.stored.get('memos'), fixture.raw);
  assert.equal(fixture.calls.writes, 0);
  assert.equal(fixture.calls.removals, 0);
  assert.equal(fixture.calls.browserAccess, 0);
});

test('legacy bridge remains supported and SDK data is not migrated or rewritten', async () => {
  const fixture = setup({ legacy: true });
  const ait = fixture.run();
  assert.equal(ait.available, true);
  assert.equal(await ait.storageGet('memos'), fixture.raw);
  assert.equal(fixture.calls.writes, 0);
  assert.equal(fixture.calls.removals, 0);
  assert.equal(fixture.calls.browserAccess, 0);
});

test('ordinary browser remains unavailable without any SDK or storage calls', () => {
  const fixture = setup({ native: false });
  assert.equal(fixture.run().available, false);
  assert.deepEqual(fixture.calls.reads, []);
  assert.equal(fixture.calls.insets, 0);
  assert.equal(fixture.calls.writes, 0);
  assert.equal(fixture.calls.browserAccess, 0);
});

test('SDK3 detection does not inspect the retired emitter property', () => {
  const fixture = setup();
  Object.defineProperty(fixture.window, '__GRANITE_NATIVE_EMITTER', {
    get() { throw new Error('retired private marker must not be queried'); },
  });
  assert.equal(fixture.run().available, true);
});

test('safe-area failure does not disable access to existing SDK memos', async () => {
  const fixture = setup({ rejectInsets: true });
  const ait = fixture.run();
  await Promise.resolve();
  await Promise.resolve();
  assert.equal(ait.available, true);
  assert.equal(await ait.storageGet('memos'), fixture.raw);
  assert.equal(ait.safeAreaInsets, null);
  assert.equal(fixture.calls.writes, 0);
});
