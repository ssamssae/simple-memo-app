import assert from 'node:assert/strict';
import test from 'node:test';
import {
  MIGRATION_MARKER_KEY,
  applyOriginStorageMigration,
  inspectMigrationMarker,
  parseMemoPayload,
  planOriginStorageMigration,
  runOriginStorageMigration,
} from '../src/origin-storage-migration-core.mjs';

const memoList = [
  {
    id: 'm1',
    content: '장보기',
    isFavorite: false,
    createdAt: '2026-07-18T12:00:00.000Z',
    updatedAt: '2026-07-18T12:00:00.000Z',
  },
];
const memosRaw = JSON.stringify(memoList);
const flutterMemosRaw = JSON.stringify(memosRaw);

class MemoryStorage {
  constructor(entries = {}, failKey = '') {
    this.values = new Map(Object.entries(entries));
    this.failKey = failKey;
  }
  getItem(key) {
    return this.values.has(key) ? this.values.get(key) : null;
  }
  setItem(key, value) {
    if (key === this.failKey) throw new Error('fixture write failure');
    this.values.set(key, value);
  }
  removeItem(key) {
    this.values.delete(key);
  }
}

class FailOnceKeyStorage extends MemoryStorage {
  constructor(failKey) {
    super();
    this.onceKey = failKey;
  }
  setItem(key, value) {
    if (key === this.onceKey) {
      this.onceKey = null;
      throw new Error('one-time write failure');
    }
    super.setItem(key, value);
  }
}

function dumps(previous = {}, current = {}, errors = {}) {
  return {
    previous: { localStorage: previous, errors: errors.previous || [] },
    current: { localStorage: current, errors: errors.current || [] },
  };
}

test('accepts AIT Storage memos JSON and SharedPreferences-encoded flutter.memos', () => {
  assert.equal(parseMemoPayload(memosRaw)?.[0].id, 'm1');
  assert.equal(parseMemoPayload(flutterMemosRaw)?.[0].content, '장보기');
});

test('copies only memoyo keys and writes marker last', () => {
  const storage = new MemoryStorage();
  const plan = planOriginStorageMigration(
    dumps({
      memos: memosRaw,
      'flutter.memos': flutterMemosRaw,
      flutter_unrelated: JSON.stringify('no'),
    }),
    storage,
  );
  assert.deepEqual(plan.writes.map(({ key }) => key).sort(), ['flutter.memos', 'memos']);
  const result = applyOriginStorageMigration(plan, storage, () => new Date('2026-09-10T00:00:00Z'));
  assert.equal(result.status, 'complete');
  assert.equal(storage.getItem('flutter_unrelated'), null);
  assert.equal(JSON.parse(storage.getItem(MIGRATION_MARKER_KEY)).status, 'complete');
});

test('empty previous storage completes without inventing memos', () => {
  const storage = new MemoryStorage();
  const result = applyOriginStorageMigration(
    planOriginStorageMigration(dumps(), storage),
    storage,
  );
  assert.equal(result.status, 'complete');
  assert.deepEqual(result.written, []);
  assert.equal(storage.getItem('memos'), null);
});

test('duplicate run is idempotent', () => {
  const storage = new MemoryStorage();
  const first = applyOriginStorageMigration(
    planOriginStorageMigration(dumps({ memos: memosRaw }), storage),
    storage,
  );
  assert.equal(first.status, 'complete');
  const second = planOriginStorageMigration(
    dumps({}, {}, { previous: [{ storage: 'localStorage', message: 'after complete' }] }),
    storage,
  );
  assert.equal(second.status, 'already_complete');
});

test('invalid completion marker fails closed', () => {
  const storage = new MemoryStorage({ [MIGRATION_MARKER_KEY]: '{broken' });
  const result = inspectMigrationMarker(storage);
  assert.equal(result.status, 'blocked');
  assert.equal(result.reason, 'invalid_marker');
});

test('current memo list is preserved and blocks completion', () => {
  const currentList = JSON.stringify([{ ...memoList[0], content: '현재값' }]);
  const storage = new MemoryStorage({ memos: currentList });
  const plan = planOriginStorageMigration(dumps({ memos: memosRaw }, { memos: currentList }), storage);
  assert.equal(plan.status, 'blocked');
  assert.equal(plan.conflicts[0].reason, 'current_value_wins');
  assert.equal(storage.getItem(MIGRATION_MARKER_KEY), null);
  assert.equal(storage.getItem('memos'), currentList);
});

test('partial dump errors block writes and marker', () => {
  const storage = new MemoryStorage();
  const plan = planOriginStorageMigration(
    dumps({ memos: memosRaw }, {}, { previous: [{ storage: 'localStorage', message: 'fail' }] }),
    storage,
  );
  assert.equal(plan.reason, 'dump_errors');
  assert.equal(storage.getItem('memos'), null);
  assert.equal(storage.getItem(MIGRATION_MARKER_KEY), null);
});

test('malformed memo JSON blocks planned writes', () => {
  const storage = new MemoryStorage();
  const plan = planOriginStorageMigration(dumps({ memos: '{broken', 'flutter.memos': flutterMemosRaw }), storage);
  assert.equal(plan.status, 'blocked');
  assert.deepEqual(plan.invalid, ['memos']);
  assert.equal(storage.getItem('flutter.memos'), null);
});

test('write failure never creates completion marker', () => {
  const storage = new MemoryStorage({}, 'memos');
  const result = applyOriginStorageMigration(
    planOriginStorageMigration(dumps({ memos: memosRaw }), storage),
    storage,
  );
  assert.equal(result.reason, 'write_failed');
  assert.equal(storage.getItem(MIGRATION_MARKER_KEY), null);
});

test('origin API rejection blocks without writing user data', async () => {
  const storage = new MemoryStorage();
  const result = await runOriginStorageMigration(async () => {
    throw new Error('fixture origin unavailable');
  }, storage);
  assert.equal(result.status, 'blocked');
  assert.equal(result.reason, 'storage_or_origin_unavailable');
  assert.equal(storage.getItem('memos'), null);
  assert.equal(storage.getItem(MIGRATION_MARKER_KEY), null);
});

test('second key one-time failure then retry completes both values and marker', () => {
  const previous = { memos: memosRaw, 'flutter.memos': flutterMemosRaw };
  const storage = new FailOnceKeyStorage('flutter.memos');
  const first = applyOriginStorageMigration(planOriginStorageMigration(dumps(previous), storage), storage);
  assert.equal(first.status, 'blocked');
  assert.equal(first.reason, 'write_failed');
  assert.equal(storage.getItem(MIGRATION_MARKER_KEY), null);

  const retry = applyOriginStorageMigration(planOriginStorageMigration(dumps(previous), storage), storage);
  assert.equal(retry.status, 'complete');
  assert.equal(storage.getItem('memos'), memosRaw);
  assert.equal(storage.getItem('flutter.memos'), flutterMemosRaw);
  assert.equal(JSON.parse(storage.getItem(MIGRATION_MARKER_KEY)).status, 'complete');
});

test('marker one-time failure then retry completes', () => {
  const previous = { memos: memosRaw, 'flutter.memos': flutterMemosRaw };
  const storage = new FailOnceKeyStorage(MIGRATION_MARKER_KEY);
  const first = applyOriginStorageMigration(planOriginStorageMigration(dumps(previous), storage), storage);
  assert.equal(first.status, 'blocked');
  assert.equal(first.reason, 'write_failed');
  assert.equal(storage.getItem('memos'), memosRaw);
  assert.equal(storage.getItem('flutter.memos'), flutterMemosRaw);
  assert.equal(storage.getItem(MIGRATION_MARKER_KEY), null);

  const retry = applyOriginStorageMigration(planOriginStorageMigration(dumps(previous), storage), storage);
  assert.equal(retry.status, 'complete');
  assert.equal(storage.getItem('memos'), memosRaw);
  assert.equal(storage.getItem('flutter.memos'), flutterMemosRaw);
  assert.equal(JSON.parse(storage.getItem(MIGRATION_MARKER_KEY)).status, 'complete');
});

test('actual value different from previous stays blocked and is not overwritten', () => {
  const currentList = JSON.stringify([{ ...memoList[0], content: '현재값' }]);
  const storage = new FailOnceKeyStorage('flutter.memos');
  applyOriginStorageMigration(
    planOriginStorageMigration(dumps({ memos: memosRaw, 'flutter.memos': flutterMemosRaw }), storage),
    storage,
  );
  storage.setItem('memos', currentList);
  const retry = planOriginStorageMigration(
    dumps({ memos: memosRaw, 'flutter.memos': flutterMemosRaw }),
    storage,
  );
  assert.equal(retry.status, 'blocked');
  assert.equal(retry.conflicts[0].reason, 'current_value_wins');
  assert.equal(storage.getItem('memos'), currentList);
  assert.equal(storage.getItem(MIGRATION_MARKER_KEY), null);
});
