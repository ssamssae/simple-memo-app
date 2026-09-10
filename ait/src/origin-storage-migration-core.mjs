/** 메모요 AIT SDK3 origin 보존. 앱 소유 키만. 한줄일기 스키마를 가져오지 않는다. */

export const MIGRATION_MARKER_KEY = 'memoyo.sdk3.origin-migration.v1';
export const OWNED_STORAGE_KEYS = Object.freeze(['memos', 'flutter.memos']);

const ISO =
  /^\d{4}-\d{2}-\d{2}(?:[T ]\d{2}:\d{2}(?::\d{2}(?:\.\d{1,6})?)?(?:[zZ]|[+-]\d{2}(?::?\d{2})?)?)?$/;

function isIsoDate(value) {
  return typeof value === 'string' && ISO.test(value) && !Number.isNaN(Date.parse(value));
}

function asMemoList(value) {
  if (!Array.isArray(value)) return null;
  for (const item of value) {
    if (item === null || typeof item !== 'object') return null;
    if (typeof item.id !== 'string' || item.id.length === 0) return null;
    if (item.content !== undefined && item.content !== null && typeof item.content !== 'string') {
      return null;
    }
    if (item.createdAt !== undefined && item.createdAt !== null && !isIsoDate(item.createdAt)) {
      return null;
    }
    if (item.updatedAt !== undefined && item.updatedAt !== null && !isIsoDate(item.updatedAt)) {
      return null;
    }
    if (item.deletedAt !== undefined && item.deletedAt !== null && !isIsoDate(item.deletedAt)) {
      return null;
    }
    if (item.isFavorite !== undefined && item.isFavorite !== null && typeof item.isFavorite !== 'boolean') {
      return null;
    }
  }
  return value;
}

export function parseMemoPayload(raw) {
  if (typeof raw !== 'string' || raw.length === 0) return null;
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return null;
  }
  const direct = asMemoList(parsed);
  if (direct) return direct;
  if (typeof parsed === 'string') {
    try {
      return asMemoList(JSON.parse(parsed));
    } catch {
      return null;
    }
  }
  return null;
}

function validOwnedValue(raw) {
  return parseMemoPayload(raw) !== null;
}

export function inspectMigrationMarker(storage) {
  const marker = storage.getItem(MIGRATION_MARKER_KEY);
  if (marker === null) return { status: 'missing' };
  try {
    const parsed = JSON.parse(marker);
    if (parsed?.version === 1 && parsed?.status === 'complete') {
      return { status: 'already_complete', writes: [] };
    }
  } catch {
    // broken marker must not be treated as success
  }
  return { status: 'blocked', reason: 'invalid_marker', errors: [] };
}

function dumpErrors(dump, side) {
  if (!dump || typeof dump !== 'object' || !Array.isArray(dump.errors)) {
    return [`${side}:invalid_dump`];
  }
  return dump.errors.map((error) => `${side}:${String(error?.storage || 'unknown')}`);
}

export function planOriginStorageMigration(dumps, actualStorage) {
  const markerResult = inspectMigrationMarker(actualStorage);
  if (markerResult.status !== 'missing') return markerResult;

  const previous = dumps?.previous;
  const current = dumps?.current;
  const errors = [...dumpErrors(previous, 'previous'), ...dumpErrors(current, 'current')];
  if (errors.length > 0) return { status: 'blocked', reason: 'dump_errors', errors };
  if (!previous.localStorage || !current.localStorage) {
    return { status: 'blocked', reason: 'invalid_local_storage', errors: [] };
  }

  const writes = [];
  const already = [];
  const conflicts = [];
  const invalid = [];
  for (const key of OWNED_STORAGE_KEYS) {
    const previousRaw = previous.localStorage[key];
    if (previousRaw === undefined || previousRaw === null) continue;
    if (!validOwnedValue(previousRaw)) {
      invalid.push(key);
      continue;
    }
    const dumpRaw = current.localStorage[key];
    const actualRaw = actualStorage.getItem(key);
    const normalizedDump = dumpRaw === undefined ? null : dumpRaw;
    if (actualRaw === previousRaw) {
      already.push(key);
      continue;
    }
    if (actualRaw !== null && actualRaw !== previousRaw) {
      if (!validOwnedValue(actualRaw)) invalid.push(key);
      else conflicts.push({ key, reason: 'current_value_wins' });
      continue;
    }
    if (normalizedDump !== null) {
      conflicts.push({ key, reason: 'current_dump_stale' });
      continue;
    }
    writes.push({ key, value: previousRaw });
  }
  if (invalid.length > 0 || conflicts.length > 0) {
    return { status: 'blocked', reason: 'validation_or_conflict', invalid, conflicts, writes: [] };
  }
  return { status: 'ready', writes, already };
}

function rollbackOwnWrites(storage, plan, writtenKeys) {
  const expected = new Map((plan.writes || []).map((item) => [item.key, item.value]));
  for (const key of writtenKeys) {
    const value = expected.get(key);
    if (value === undefined) continue;
    if (storage.getItem(key) !== value) continue;
    if (typeof storage.removeItem === 'function') storage.removeItem(key);
  }
}

export function applyOriginStorageMigration(plan, storage, now = () => new Date()) {
  if (plan.status === 'already_complete') return plan;
  if (plan.status !== 'ready') return plan;
  const written = [];
  const already = [...(plan.already || [])];
  let phase = 'data';
  try {
    for (const item of plan.writes) {
      const existing = storage.getItem(item.key);
      if (existing === item.value) {
        already.push(item.key);
        continue;
      }
      if (existing !== null) {
        rollbackOwnWrites(storage, plan, written);
        return { status: 'blocked', reason: 'write_race', written: [] };
      }
      storage.setItem(item.key, item.value);
      written.push(item.key);
    }
    phase = 'marker';
    const migratedKeys = [...already, ...written];
    storage.setItem(
      MIGRATION_MARKER_KEY,
      JSON.stringify({
        version: 1,
        status: 'complete',
        migratedKeys,
        completedAt: now().toISOString(),
      }),
    );
    return { status: 'complete', written: migratedKeys };
  } catch (error) {
    if (phase === 'data') rollbackOwnWrites(storage, plan, written);
    return { status: 'blocked', reason: 'write_failed', written, error: String(error) };
  }
}

export async function runOriginStorageMigration(getDumps, storage, milliseconds = 15000) {
  let timer;
  try {
    const markerResult = inspectMigrationMarker(storage);
    if (markerResult.status !== 'missing') return markerResult;
    const dumps = await Promise.race([
      getDumps(),
      new Promise((_, reject) => {
        timer = setTimeout(() => reject(new Error('origin_storage_timeout')), milliseconds);
      }),
    ]);
    return applyOriginStorageMigration(planOriginStorageMigration(dumps, storage), storage);
  } catch (error) {
    return { status: 'blocked', reason: 'storage_or_origin_unavailable', error: String(error) };
  } finally {
    clearTimeout(timer);
  }
}
