'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  assignSequentialPlayerId,
  auditSequenceState,
  getAuthenticatedUid,
} = require('../src/identity');

const createError = (code, message) => Object.assign(new Error(message), { code });

function makeFirestore({ identities = [], counterExists = true, counterValue = 0 } = {}) {
  const identityDocs = new Map(identities.map(({ uid, number }) => [uid, { number }]));
  let counter = counterExists ? { next: counterValue } : null;
  let queue = Promise.resolve();
  const identityCollection = {
    doc: (id) => ({ collection: 'player_identities', id }),
    orderBy(field, direction) {
      return {
        collection: 'player_identities', field, direction,
        limit(count) { this.count = count; return this; },
      };
    },
  };
  const counterCollection = { doc: (id) => ({ collection: 'system_counters', id }) };

  return {
    collection(name) {
      if (name === 'player_identities') return identityCollection;
      if (name === 'system_counters') return counterCollection;
      throw new Error(`Unexpected collection ${name}`);
    },
    async runTransaction(callback) {
      const previous = queue;
      let release;
      queue = new Promise((resolve) => { release = resolve; });
      await previous;
      const identityWrites = new Map();
      let counterWrite = null;
      const transaction = {
        async get(ref) {
          if (ref.collection === 'player_identities' && ref.id) {
            const data = identityDocs.get(ref.id);
            return { exists: Boolean(data), get: (key) => data?.[key] };
          }
          if (ref.collection === 'system_counters') {
            return { exists: counter !== null, get: (key) => counter?.[key] };
          }
          if (ref.collection === 'player_identities' && ref.field) {
            const docs = [...identityDocs.entries()]
              .filter(([, data]) => Object.prototype.hasOwnProperty.call(data, ref.field))
              .sort((a, b) => ref.direction === 'desc' ? b[1][ref.field] - a[1][ref.field] : a[1][ref.field] - b[1][ref.field])
              .slice(0, ref.count || undefined)
              .map(([id, data]) => ({ id, get: (key) => data[key] }));
            return { docs };
          }
          throw new Error('Unexpected transaction read');
        },
        create(ref, data) {
          if (identityDocs.has(ref.id) || identityWrites.has(ref.id)) throw new Error('document exists');
          identityWrites.set(ref.id, data);
        },
        set(ref, data) { counterWrite = data; },
      };
      try {
        const result = await callback(transaction);
        for (const [uid, data] of identityWrites) identityDocs.set(uid, data);
        if (counterWrite !== null) counter = counterWrite;
        return result;
      } finally {
        release();
      }
    },
    snapshot() {
      return { identities: [...identityDocs.entries()].map(([uid, data]) => ({ uid, ...data })), counter: counter && { ...counter } };
    },
  };
}

async function assign(firestore, uid) {
  return assignSequentialPlayerId({
    firestore, uid,
    serverTimestamp: () => 'SERVER_TIMESTAMP',
    createError,
  });
}

test('requires a valid Firebase Authentication UID', () => {
  assert.throws(() => getAuthenticatedUid({}, createError), { code: 'unauthenticated' });
  assert.throws(() => getAuthenticatedUid({ auth: { uid: '' } }, createError), { code: 'unauthenticated' });
  assert.throws(() => getAuthenticatedUid({ auth: { uid: 'bad/uid' } }, createError), { code: 'unauthenticated' });
  assert.equal(getAuthenticatedUid({ auth: { uid: 'google-user-1' } }, createError), 'google-user-1');
});

test('rejects caller-supplied target UID or other request data', () => {
  assert.throws(() => getAuthenticatedUid({ auth: { uid: 'user-1' }, data: { uid: 'user-2' } }, createError), { code: 'invalid-argument' });
  assert.throws(() => getAuthenticatedUid({ auth: { uid: 'user-1' }, data: { targetUid: 'user-2' } }, createError), { code: 'invalid-argument' });
  assert.throws(() => getAuthenticatedUid({ auth: { uid: 'user-1' }, data: [] }, createError), { code: 'invalid-argument' });
});

test('creates the next integer ID atomically and records server timestamp', async () => {
  const db = makeFirestore({ counterValue: 7 });
  assert.equal(await assign(db, 'user-8'), 8);
  assert.deepEqual(db.snapshot(), {
    identities: [{ uid: 'user-8', number: 8, createdAt: 'SERVER_TIMESTAMP' }],
    counter: { next: 8 },
  });
});

test('returns existing valid ID without changing it while counter repair is pending', async () => {
  const db = makeFirestore({ identities: [{ uid: 'user-1', number: 42 }], counterExists: false });
  assert.equal(await assign(db, 'user-1'), 42);
  assert.equal(db.snapshot().counter, null);
  assert.equal(db.snapshot().identities.length, 1);
});

test('concurrent new users receive unique consecutive assignments', async () => {
  const db = makeFirestore({ counterValue: 100 });
  const ids = await Promise.all(Array.from({ length: 24 }, (_, index) => assign(db, `user-${index}`)));
  assert.deepEqual([...ids].sort((a, b) => a - b), Array.from({ length: 24 }, (_, index) => 101 + index));
  assert.equal(new Set(ids).size, 24);
  assert.equal(db.snapshot().counter.next, 124);
});

test('fails closed when counter document is missing', async () => {
  const db = makeFirestore({ counterExists: false });
  await assert.rejects(assign(db, 'new-user'), { code: 'failed-precondition' });
  assert.deepEqual(db.snapshot(), { identities: [], counter: null });
});

test('fails closed when counter is behind the highest existing identity', async () => {
  const db = makeFirestore({ identities: [{ uid: 'old-user', number: 18 }], counterValue: 17 });
  await assert.rejects(assign(db, 'new-user'), { code: 'failed-precondition' });
  assert.equal(db.snapshot().identities.length, 1);
  assert.equal(db.snapshot().counter.next, 17);
});

test('fails closed for invalid counters and invalid existing assignments', async () => {
  for (const invalid of [-1, 100000, 1.5, '9', null]) {
    const db = makeFirestore({ counterValue: invalid });
    await assert.rejects(assign(db, 'new-user'), { code: 'failed-precondition' });
    assert.equal(db.snapshot().identities.length, 0);
  }
  const badIdentity = makeFirestore({ identities: [{ uid: 'user-1', number: 100000 }], counterValue: 100000 });
  await assert.rejects(assign(badIdentity, 'user-1'), { code: 'failed-precondition' });
});

test('stops at the five-digit limit without creating another identity', async () => {
  const db = makeFirestore({ counterValue: 99999 });
  await assert.rejects(assign(db, 'last-user'), { code: 'resource-exhausted' });
  assert.equal(db.snapshot().identities.length, 0);
  assert.equal(db.snapshot().counter.next, 99999);
});

test('read-only audit accepts a valid high-water mark and detects duplicate or malformed records', () => {
  assert.deepEqual(auditSequenceState([{ uid: 'a', number: 1 }, { uid: 'b', number: 4 }], true, 6), {
    valid: true, highestAssigned: 4, errors: [],
  });
  const broken = auditSequenceState([
    { uid: 'a', number: 3 }, { uid: 'b', number: 3 }, { uid: 'c', number: 'four' },
  ], true, 2);
  assert.equal(broken.valid, false);
  assert.ok(broken.errors.some((error) => error.includes('share the same number')));
  assert.ok(broken.errors.some((error) => error.includes('missing or out-of-range')));
  assert.ok(broken.errors.some((error) => error.includes('behind an existing assignment')));
});
