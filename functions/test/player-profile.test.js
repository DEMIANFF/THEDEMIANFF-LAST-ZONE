'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  validDisplayName, formatPlayerId,
  readPlayerProfile, savePlayerDisplayName,
} = require('../src/player-profile');

const createError = (code, message) => Object.assign(new Error(message), { code });

function makeFirestore({ identities = [{ uid: 'alice', number: 7 }] } = {}) {
  const ids = new Map(identities.map(({ uid, number }) => [uid, { number }]));
  const profiles = new Map();
  let queue = Promise.resolve();

  const snapshot = (name, uid) => {
    const data = name === 'player_identities' ? ids.get(uid) : profiles.get(uid);
    return {
      exists: Boolean(data),
      get: (field) => data?.[field],
      data: () => data == null ? undefined : structuredClone(data),
    };
  };
  const ref = (name, uid) => ({
    name, uid, get: async () => snapshot(name, uid),
  });
  return {
    collection(name) {
      assert.ok(['player_identities', 'player_profiles'].includes(name));
      return { doc: (uid) => ref(name, uid) };
    },
    async runTransaction(callback) {
      const before = queue;
      let unlock;
      queue = new Promise((resolve) => { unlock = resolve; });
      await before;
      const operations = [];
      const tx = {
        get: (item) => item.get(),
        create(item, data) {
          assert.equal(item.name, 'player_profiles');
          assert.equal(profiles.has(item.uid), false);
          operations.push(['create', item.uid, structuredClone(data)]);
        },
        update(item, data) {
          assert.equal(item.name, 'player_profiles');
          assert.equal(profiles.has(item.uid), true);
          operations.push(['update', item.uid, structuredClone(data)]);
        },
      };
      try {
        const answer = await callback(tx);
        for (const [action, uid, value] of operations) {
          profiles.set(uid, action === 'update' ?
            { ...profiles.get(uid), ...value } : value);
        }
        return answer;
      } finally {
        unlock();
      }
    },
    state(uid) { return profiles.get(uid); },
    putProfile(uid, data) { profiles.set(uid, data); },
    removeIdentity(uid) { ids.delete(uid); },
  };
}

const get = (db, uid, data = {}) => readPlayerProfile({
  firestore: db, request: { auth: uid == null ? undefined : { uid }, data },
  createError,
});
const save = (db, uid, displayName, expectedRevision, more = {}) =>
  savePlayerDisplayName({
    firestore: db,
    request: {
      auth: uid == null ? undefined : { uid },
      data: { displayName, expectedRevision, ...more },
    },
    createError, serverTimestamp: () => 'SERVER_TIME',
  });

test('formats only real assigned IDs, preserving leading zeros', () => {
  assert.equal(formatPlayerId(1), '00001');
  assert.equal(formatPlayerId(7), '00007');
  assert.equal(formatPlayerId(99999), '99999');
  assert.throws(() => formatPlayerId(0), RangeError);
  assert.throws(() => formatPlayerId(100000), RangeError);
});

test('validates nicknames with same bounds and reserved names as Godot', () => {
  for (const name of ['Lila Aurora', 'Ñandú_777', 'AURORA_2026', 'Operador']) {
    assert.equal(validDisplayName(name), true, name);
  }
  for (const name of ['', 'Al', ' Admin', 'ADMIN', 'Firebase',
    'THEDEMIAN', 'bad@name', 'a  b', 'A'.repeat(17), 'a\nname', '🙂🙂🙂']) {
    assert.equal(validDisplayName(name), false, name);
  }
});

test('only a Firebase authenticated account with an assigned ID can read a profile', async () => {
  const db = makeFirestore();
  await assert.rejects(get(db, null), { code: 'unauthenticated' });
  await assert.rejects(get(db, 'bob'), { code: 'failed-precondition' });
  await assert.rejects(get(db, 'alice', { uid: 'bob' }), { code: 'invalid-argument' });
  assert.deepEqual(await get(db, 'alice'), {
    playerId: '00007', number: 7, displayName: 'Operador',
    revision: 0, configured: false, authenticated: true,
  });
  assert.equal(db.state('alice'), undefined); // Read never invents a document.
});

test('persists nickname under UID without changing existing server ID', async () => {
  const db = makeFirestore();
  const result = await save(db, 'alice', 'Lila Aurora', 0);
  assert.deepEqual(result, {
    playerId: '00007', number: 7, displayName: 'Lila Aurora',
    revision: 1, configured: true, authenticated: true, changed: true,
  });
  const doc = db.state('alice');
  assert.equal(doc.number, 7);
  assert.equal(doc.revision, 1);
  assert.equal(doc.createdAt, 'SERVER_TIME');
  assert.equal(doc.updatedAt, 'SERVER_TIME');
  assert.deepEqual(await get(db, 'alice'), {
    playerId: '00007', number: 7, displayName: 'Lila Aurora',
    revision: 1, configured: true, authenticated: true,
  });
});

test('rejects cross-account IDs, credentials, missing login and malformed names', async () => {
  const db = makeFirestore();
  await assert.rejects(save(db, null, 'AURORA_2026', 0), { code: 'unauthenticated' });
  await assert.rejects(save(db, 'bob', 'AURORA_2026', 0), { code: 'failed-precondition' });
  await assert.rejects(save(db, 'alice', 'ADMIN', 0), { code: 'invalid-argument' });
  await assert.rejects(save(db, 'alice', 'good name', 0, { uid: 'bob' }),
    { code: 'invalid-argument' });
  await assert.rejects(save(db, 'alice', 'good name', 0, { number: 1 }),
    { code: 'invalid-argument' });
  assert.equal(db.state('alice'), undefined);
});

test('idempotent updates and stale-revision protection preserve the ID', async () => {
  const db = makeFirestore();
  await save(db, 'alice', 'Lila Aurora', 0);
  const duplicate = await save(db, 'alice', 'Lila Aurora', 0);
  assert.equal(duplicate.changed, false);
  assert.equal(duplicate.revision, 1);
  await assert.rejects(save(db, 'alice', 'AURORA_2026', 0), { code: 'aborted' });
  const renamed = await save(db, 'alice', 'AURORA_2026', 1);
  assert.equal(renamed.revision, 2);
  assert.equal(renamed.playerId, '00007');
  assert.equal(db.state('alice').createdAt, 'SERVER_TIME');
  assert.equal(db.state('alice').number, 7);
});

test('concurrent rename requests cannot overwrite each other silently', async () => {
  const db = makeFirestore();
  const results = await Promise.allSettled([
    save(db, 'alice', 'Lila Aurora', 0),
    save(db, 'alice', 'AURORA_2026', 0),
  ]);
  assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
  assert.equal(results.filter((r) => r.status === 'rejected').length, 1);
  assert.equal(results.find((r) => r.status === 'rejected').reason.code, 'aborted');
  assert.equal(db.state('alice').revision, 1);
});

test('rejects mismatched or malformed server identity/profile records', async () => {
  const db = makeFirestore();
  db.putProfile('alice', { schema: 1, number: 20, revision: 1, displayName: 'Lila Aurora' });
  await assert.rejects(get(db, 'alice'), { code: 'failed-precondition' });
  await assert.rejects(save(db, 'alice', 'AURORA_2026', 1),
    { code: 'failed-precondition' });
  assert.equal(db.state('alice').number, 20);
  db.removeIdentity('alice');
  await assert.rejects(get(db, 'alice'), { code: 'failed-precondition' });
});

test('separates account names and ID records under different authenticated UIDs', async () => {
  const db = makeFirestore({ identities: [
    { uid: 'alice', number: 7 }, { uid: 'bob', number: 8 },
  ] });
  await save(db, 'alice', 'Lila Aurora', 0);
  await save(db, 'bob', 'AURORA_2026', 0);
  assert.equal((await get(db, 'alice')).playerId, '00007');
  assert.equal((await get(db, 'bob')).playerId, '00008');
  assert.equal((await get(db, 'bob')).displayName, 'AURORA_2026');
  assert.equal((await get(db, 'alice')).displayName, 'Lila Aurora');
});
