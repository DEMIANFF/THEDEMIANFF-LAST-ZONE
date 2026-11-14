'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const {
  COLLECTION, validateEnvelope, saveOfflineProgress, loadOfflineProgress,
} = require('../src/offline-progress');

const createError = (code, message) => Object.assign(new Error(message), { code });
const sha256 = (s) => createHash('sha256').update(s).digest('hex');

function sampleProfile(played = 2) {
  const history = [];
  for (let id = played; id > Math.max(0, played - 2); id--) {
    history.push({
      match_id: id, victory: id === 1, kills: id === 1 ? 3 : 1,
      survived_seconds: id === 1 ? 93 : 140, saved_at_unix: 1763060000,
    });
  }
  return {
    schema: 1, next_match_id: played + 1, played,
    wins: played > 0 ? 1 : 0, kills: played > 0 ? played + 2 : 0,
    survival_seconds: played > 0 ? 93 + (played - 1) * 140 : 0,
    best_kills: played > 0 ? 3 : 0,
    longest_survival_seconds: played > 1 ? 140 : 93,
    history,
  };
}

function envelope(profile = sampleProfile(), timestamp = 1763060000) {
  const packet = {
    format: 'aurora_offline_profile_export',
    version: 1,
    origin: 'local_godot_no_auth',
    wallet_policy: 'no_currency_export',
    last_match_id: profile.played,
    captured_at_unix: timestamp,
    profile,
  };
  const payload = JSON.stringify(packet);
  return JSON.stringify({ payload, sha256: sha256(payload) });
}

function makeFirestore() {
  const documents = new Map();
  let queue = Promise.resolve();
  function ref(name, uid) {
    assert.equal(name, COLLECTION);
    return {
      async get() {
        const value = documents.get(uid);
        return { exists: Boolean(value), data: () => value ? structuredClone(value) : undefined };
      },
      _uid: uid,
    };
  }
  return {
    collection(name) {
      assert.equal(name, COLLECTION);
      return { doc: (uid) => ref(name, uid) };
    },
    async runTransaction(callback) {
      const before = queue;
      let release;
      queue = new Promise((resolve) => { release = resolve; });
      await before;
      const pending = [];
      const tx = {
        get: (r) => r.get(),
        create(r, value) {
          assert.ok(!documents.has(r._uid), 'create must not overwrite');
          pending.push([r._uid, structuredClone(value)]);
        },
        set(r, value) { pending.push([r._uid, structuredClone(value)]); },
      };
      try {
        const result = await callback(tx);
        for (const [uid, value] of pending) documents.set(uid, value);
        return result;
      } finally {
        release();
      }
    },
    state(uid) { return documents.get(uid); },
  };
}

const save = (db, uid, packet, revision) => saveOfflineProgress({
  firestore: db,
  request: { auth: uid == null ? undefined : { uid },
    data: { envelope: packet, expectedRevision: revision } },
  serverTimestamp: () => 'SERVER_TIMESTAMP',
  createError,
});
const load = (db, uid, data = {}) => loadOfflineProgress({
  firestore: db,
  request: { auth: uid == null ? undefined : { uid }, data },
  createError,
});

test('rejects unauthenticated saves and loads and caller-supplied UIDs', async () => {
  const db = makeFirestore();
  await assert.rejects(save(db, null, envelope(), 0), { code: 'unauthenticated' });
  await assert.rejects(load(db, null), { code: 'unauthenticated' });
  await assert.rejects(load(db, 'user-one', { uid: 'other' }), { code: 'invalid-argument' });
  await assert.rejects(saveOfflineProgress({
    firestore: db,
    request: { auth: { uid: 'user-one' }, data: {
      envelope: envelope(), expectedRevision: 0, uid: 'other',
    } },
    serverTimestamp: () => 'STAMP', createError,
  }), { code: 'invalid-argument' });
});

test('rejects malformed, oversized, tampered, premium, and competitive claims', () => {
  const bad = (item) => assert.throws(() => validateEnvelope(item, createError),
    { code: 'invalid-argument' });
  bad('{}');
  bad('x'.repeat(120001));
  bad(envelope().replace('aurora_offline_profile_export', 'different'));
  const profile = sampleProfile();
  for (const key of ['local_coins', 'diamonds', 'rank_points', 'uid', 'xp']) {
    bad(envelope({ ...profile, [key]: 200 }));
  }
  bad(envelope({ ...profile, history: [{ ...profile.history[0], local_coins_awarded: 999 }] }));
  bad(envelope({ ...profile, history: [{ ...profile.history[0], match_id: 1 }] }));
  bad(envelope({ ...profile, wins: profile.played + 1 }));
  bad(envelope({ ...profile, next_match_id: 99 }));
  bad(envelope({ ...profile, history: [{ ...profile.history[0], shots: 1, hits: 9 }] }));
  const withExtra = JSON.parse(envelope());
  const payload = JSON.parse(withExtra.payload);
  payload.uid = 'chosen-identity';
  const forged = JSON.stringify(payload);
  bad(JSON.stringify({ payload: forged, sha256: sha256(forged) }));
});

test('stores real offline history under authenticated UID, without currency or ranked claims', async () => {
  const db = makeFirestore();
  const first = await save(db, 'user-a', envelope(), 0);
  assert.deepEqual(first, {
    revision: 1, lastMatchId: 2, changed: true,
    verifiedCompetitive: false, walletIncluded: false,
  });
  const dbValue = db.state('user-a');
  assert.equal(dbValue.source, 'unverified_local_godot');
  assert.equal(dbValue.updatedAt, 'SERVER_TIMESTAMP');
  assert.equal(dbValue.createdAt, 'SERVER_TIMESTAMP');
  assert.equal(dbValue.profile.played, 2);
  assert.ok(!Object.hasOwn(dbValue.profile, 'local_coins'));
  assert.equal(dbValue.verifiedCompetitive, false);
  const response = await load(db, 'user-a');
  assert.equal(response.found, true);
  assert.equal(response.revision, 1);
  assert.equal(response.profile.kills, 4);
  assert.equal(response.walletIncluded, false);
  assert.deepEqual(await load(db, 'user-b'), {
    found: false, revision: 0,
    verifiedCompetitive: false, walletIncluded: false,
  });
});

test('same progress with newer export timestamp is idempotent, never pays or versions twice', async () => {
  const db = makeFirestore();
  await save(db, 'user-a', envelope(sampleProfile(2), 1763060000), 0);
  const repeat = await save(db, 'user-a', envelope(sampleProfile(2), 1763060100), 0);
  assert.equal(repeat.revision, 1);
  assert.equal(repeat.changed, false);
  assert.equal(db.state('user-a').revision, 1);
});

test('rejects equal or stale progression; requires matching cloud revision for a new save', async () => {
  const db = makeFirestore();
  await save(db, 'user-a', envelope(sampleProfile(2)), 0);
  await assert.rejects(save(db, 'user-a', envelope({ ...sampleProfile(2), wins: 0 }), 1),
    { code: 'failed-precondition' });
  await assert.rejects(save(db, 'user-a', envelope(sampleProfile(1)), 1),
    { code: 'failed-precondition' });
  await assert.rejects(save(db, 'user-a', envelope(sampleProfile(3)), 0),
    { code: 'aborted' });
  const second = await save(db, 'user-a', envelope(sampleProfile(3)), 1);
  assert.equal(second.revision, 2);
  assert.equal(second.lastMatchId, 3);
  assert.equal((await load(db, 'user-a')).profile.played, 3);
});

test('concurrent conflicting devices cannot silently overwrite each other', async () => {
  const db = makeFirestore();
  await save(db, 'user-a', envelope(sampleProfile(2)), 0);
  const submissions = await Promise.allSettled([
    save(db, 'user-a', envelope(sampleProfile(3)), 1),
    save(db, 'user-a', envelope(sampleProfile(4)), 1),
  ]);
  assert.equal(submissions.filter((x) => x.status === 'fulfilled').length, 1);
  assert.equal(submissions.filter((x) => x.status === 'rejected').length, 1);
  assert.equal(submissions.find((x) => x.status === 'rejected').reason.code, 'aborted');
  assert.equal(db.state('user-a').revision, 2);
});

test('refuses to load corrupted server documents rather than manufacturing a profile', async () => {
  const db = makeFirestore();
  await save(db, 'user-a', envelope(sampleProfile(2)), 0);
  db.state('user-a').profileHash = 'wrong';
  await assert.rejects(load(db, 'user-a'), { code: 'failed-precondition' });
});
