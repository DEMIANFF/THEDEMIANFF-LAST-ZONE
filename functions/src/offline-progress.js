'use strict';

// Strict server-side storage of UNVERIFIED offline progression only.
// Authenticated UID comes from Firebase callable context, never from the app.
// No diamonds, local coins, online rank, purchases, or competitive rewards.
const { createHash } = require('node:crypto');

const FORMAT = 'aurora_offline_profile_export';
const COLLECTION = 'player_progress_snapshots';
const MAX_ENVELOPE_BYTES = 120000;
const PROFILE_KEYS = new Set([
  'schema', 'next_match_id', 'played', 'wins', 'kills',
  'survival_seconds', 'best_kills', 'longest_survival_seconds', 'history',
]);
const RESULT_KEYS = new Set([
  'match_id', 'victory', 'kills', 'survived_seconds', 'saved_at_unix',
  'rank', 'participants', 'damage', 'accuracy', 'loot', 'shots',
  'hits', 'headshots', 'reloads',
]);
const EXTRAS = {
  rank: 100, participants: 100, damage: 500000, accuracy: 100,
  loot: 1000, shots: 20000, hits: 20000, headshots: 20000,
  reloads: 10000,
};

const hash = (value) => createHash('sha256').update(value, 'utf8').digest('hex');
const isRecord = (x) => x !== null && typeof x === 'object' && !Array.isArray(x);
const integer = (x, min, max) => Number.isSafeInteger(x) && x >= min && x <= max;
const keysOnly = (obj, allowed) => Object.keys(obj).every((key) => allowed.has(key));
function fail(createError, code, message) { throw createError(code, message); }

function authenticatedUid(request, createError) {
  const uid = request?.auth?.uid;
  if (typeof uid !== 'string' || uid.length === 0 || uid.length > 128 || uid.includes('/')) {
    fail(createError, 'unauthenticated', 'Firebase Authentication is required.');
  }
  return uid;
}

function validateProfile(profile, createError) {
  const bad = () => fail(createError, 'invalid-argument',
    'The offline statistics do not match the versioned export contract.');
  if (!isRecord(profile) || !keysOnly(profile, PROFILE_KEYS) ||
      !integer(profile.schema, 1, 1) ||
      !integer(profile.played, 0, 1000000) ||
      !integer(profile.next_match_id, 1, 1000001) ||
      profile.next_match_id !== profile.played + 1 ||
      !integer(profile.wins, 0, profile.played) ||
      !integer(profile.kills, 0, profile.played * 100) ||
      !integer(profile.survival_seconds, 0, profile.played * 86400) ||
      !integer(profile.best_kills, 0, 100) ||
      !integer(profile.longest_survival_seconds, 0, 86400) ||
      !Array.isArray(profile.history) ||
      profile.history.length > Math.min(12, profile.played)) bad();
  for (let i = 0; i < profile.history.length; i++) {
    const row = profile.history[i];
    if (!isRecord(row) || !keysOnly(row, RESULT_KEYS) ||
        row.match_id !== profile.played - i ||
        typeof row.victory !== 'boolean' ||
        !integer(row.kills, 0, 100) ||
        !integer(row.survived_seconds, 0, 86400) ||
        !integer(row.saved_at_unix, 0, 4102444800)) bad();
    for (const [field, maximum] of Object.entries(EXTRAS)) {
      if (Object.hasOwn(row, field) && !integer(row[field], 0, maximum)) bad();
    }
    if (Object.hasOwn(row, 'rank') && row.rank < 1) bad();
    if (Object.hasOwn(row, 'participants') && row.participants < 1) bad();
    if (Object.hasOwn(row, 'rank') && Object.hasOwn(row, 'participants') &&
        row.rank > row.participants) bad();
    if (Object.hasOwn(row, 'hits') && Object.hasOwn(row, 'shots') &&
        row.hits > row.shots) bad();
    if (Object.hasOwn(row, 'headshots') && Object.hasOwn(row, 'hits') &&
        row.headshots > row.hits) bad();
    if (Object.hasOwn(row, 'accuracy') && Object.hasOwn(row, 'shots') &&
        row.shots === 0 && row.accuracy > 0) bad();
  }
  return profile;
}

function validateEnvelope(envelope, createError) {
  if (typeof envelope !== 'string' ||
      Buffer.byteLength(envelope, 'utf8') > MAX_ENVELOPE_BYTES ||
      Buffer.byteLength(envelope, 'utf8') < 40) {
    fail(createError, 'invalid-argument', 'Offline profile envelope has an invalid size.');
  }
  let wrapped;
  let packet;
  try {
    wrapped = JSON.parse(envelope);
    if (!isRecord(wrapped) || !keysOnly(wrapped, new Set(['payload', 'sha256'])) ||
        typeof wrapped.payload !== 'string' || typeof wrapped.sha256 !== 'string' ||
        !/^[a-f0-9]{64}$/.test(wrapped.sha256) ||
        hash(wrapped.payload) !== wrapped.sha256) {
      fail(createError, 'invalid-argument', 'The local profile checksum is invalid.');
    }
    packet = JSON.parse(wrapped.payload);
  } catch (error) {
    if (error?.code === 'invalid-argument') throw error;
    fail(createError, 'invalid-argument', 'The local profile cannot be decoded.');
  }
  const fields = new Set([
    'format', 'version', 'origin', 'wallet_policy',
    'last_match_id', 'captured_at_unix', 'profile',
  ]);
  if (!isRecord(packet) || !keysOnly(packet, fields) ||
      packet.format !== FORMAT || packet.version !== 1 ||
      packet.origin !== 'local_godot_no_auth' ||
      packet.wallet_policy !== 'no_currency_export' ||
      !integer(packet.captured_at_unix, 1, 4102444800)) {
    fail(createError, 'invalid-argument', 'Unsupported local profile format.');
  }
  const profile = validateProfile(packet.profile, createError);
  if (packet.last_match_id !== profile.played) {
    fail(createError, 'invalid-argument', 'The profile revision is inconsistent.');
  }
  // This SHA is a content fingerprint only. Client data is NOT authoritative.
  return { profile, played: profile.played, profileHash: hash(JSON.stringify(profile)) };
}

function parseSaveRequest(request, createError) {
  const uid = authenticatedUid(request, createError);
  const data = request?.data;
  if (!isRecord(data) || !keysOnly(data, new Set(['envelope', 'expectedRevision'])) ||
      !Object.hasOwn(data, 'envelope') ||
      !integer(data.expectedRevision, 0, 1000000000)) {
    fail(createError, 'invalid-argument', 'An envelope and expectedRevision are required.');
  }
  return { uid, expectedRevision: data.expectedRevision,
    ...validateEnvelope(data.envelope, createError) };
}

async function saveOfflineProgress({ firestore, request, serverTimestamp, createError }) {
  const { uid, expectedRevision, profile, played, profileHash } =
    parseSaveRequest(request, createError);
  const ref = firestore.collection(COLLECTION).doc(uid);
  return firestore.runTransaction(async (transaction) => {
    const old = await transaction.get(ref);
    const existing = old.exists ? old.data() : null;
    const currentRevision = existing?.revision ?? 0;
    const lastMatchId = existing?.lastMatchId ?? 0;
    if (!integer(currentRevision, 0, 1000000000) ||
        !integer(lastMatchId, 0, 1000000)) {
      fail(createError, 'failed-precondition', 'The existing cloud backup needs repair.');
    }
    // A repeated request must never consume another revision.
    if (existing && existing.profileHash === profileHash) {
      return { revision: currentRevision, lastMatchId, changed: false,
        verifiedCompetitive: false, walletIncluded: false };
    }
    if (existing && played <= lastMatchId) {
      fail(createError, 'failed-precondition',
        'An equal or older offline match revision cannot replace the backup.');
    }
    if (currentRevision !== expectedRevision) {
      fail(createError, 'aborted', 'Cloud backup changed on another device; reload first.');
    }
    if (currentRevision >= 1000000000) {
      fail(createError, 'resource-exhausted', 'Cloud backup revision limit reached.');
    }
    const revision = currentRevision + 1;
    const doc = {
      source: 'unverified_local_godot',
      schema: 1,
      revision,
      lastMatchId: played,
      profileHash,
      profile,
      verifiedCompetitive: false,
      walletIncluded: false,
      updatedAt: serverTimestamp(),
    };
    if (existing) transaction.set(ref, doc);
    else transaction.create(ref, { ...doc, createdAt: serverTimestamp() });
    return { revision, lastMatchId: played, changed: true,
      verifiedCompetitive: false, walletIncluded: false };
  });
}

async function loadOfflineProgress({ firestore, request, createError }) {
  const uid = authenticatedUid(request, createError);
  const input = request?.data;
  if (input != null && (!isRecord(input) || Object.keys(input).length !== 0)) {
    fail(createError, 'invalid-argument', 'Loading a profile takes no arguments.');
  }
  const ref = firestore.collection(COLLECTION).doc(uid);
  const doc = await ref.get();
  if (!doc.exists) {
    return { found: false, revision: 0, verifiedCompetitive: false, walletIncluded: false };
  }
  const value = doc.data();
  if (!integer(value?.revision, 1, 1000000000) ||
      !integer(value?.lastMatchId, 0, 1000000) ||
      value?.source !== 'unverified_local_godot' ||
      value?.verifiedCompetitive !== false || value?.walletIncluded !== false) {
    fail(createError, 'failed-precondition', 'Cloud profile integrity check failed.');
  }
  validateProfile(value.profile, createError);
  if (value.profile.played !== value.lastMatchId ||
      value.profileHash !== hash(JSON.stringify(value.profile))) {
    fail(createError, 'failed-precondition', 'Cloud profile revision or fingerprint differs.');
  }
  return { found: true, revision: value.revision, lastMatchId: value.lastMatchId,
    profile: value.profile, verifiedCompetitive: false, walletIncluded: false };
}

module.exports = {
  COLLECTION,
  authenticatedUid,
  validateProfile,
  validateEnvelope,
  parseSaveRequest,
  saveOfflineProgress,
  loadOfflineProgress,
};
