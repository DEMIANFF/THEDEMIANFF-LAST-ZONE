'use strict';

// Firebase Auth UID is always taken from callable request.auth. Permanent
// numeric identities come from the pre-existing ensurePlayerIdentity callable.
// The client cannot select a player number or write another player's profile.
const { getAuthenticatedUid } = require('./identity');

const COLLECTION = 'player_profiles';
const ID_COLLECTION = 'player_identities';
const DEFAULT_NAME = 'Operador';
const MAX_PLAYER_ID = 99999;
const NAME_REGEX = /^[A-Za-z0-9ÁÉÍÓÚÜÑáéíóúüñ_]+( [A-Za-z0-9ÁÉÍÓÚÜÑáéíóúüñ_]+)*$/u;
const RESERVED = new Set([
  'ADMIN', 'ADMINISTRADOR', 'MODERADOR', 'SOPORTE', 'THEDEMIAN',
  'FIREBASE', 'SISTEMA',
]);

const isObject = (x) => x !== null && typeof x === 'object' && !Array.isArray(x);
const integer = (x, min, max) => Number.isSafeInteger(x) && x >= min && x <= max;
function fail(createError, code, detail) { throw createError(code, detail); }

function validDisplayName(value) {
  return typeof value === 'string' && value.length >= 3 && value.length <= 16 &&
    value === value.trim() && value.normalize('NFC') === value &&
    NAME_REGEX.test(value) && !RESERVED.has(value.toUpperCase());
}

function readRequestUid(request, createError) {
  // The preexisting helper rejects caller-provided data, so pass only the
  // authenticated context and separately validate this callable's data.
  return getAuthenticatedUid({ auth: request?.auth }, createError);
}

function requireIdentity(snap, createError) {
  if (!snap.exists) {
    fail(createError, 'failed-precondition',
      'Assign a permanent ID using ensurePlayerIdentity first.');
  }
  const number = snap.get('number');
  if (!integer(number, 1, MAX_PLAYER_ID)) {
    fail(createError, 'failed-precondition', 'Saved player identity is invalid.');
  }
  return number;
}

function formatPlayerId(number) {
  if (!integer(number, 1, MAX_PLAYER_ID)) throw new RangeError('Invalid player ID');
  return String(number).padStart(5, '0');
}

function validateProfile(snapshot, number, createError) {
  if (!snapshot.exists) {
    return { displayName: DEFAULT_NAME, revision: 0, configured: false };
  }
  const profile = snapshot.data();
  if (!isObject(profile) || profile.schema !== 1 ||
      profile.number !== number || !integer(profile.revision, 1, 1000000000) ||
      !validDisplayName(profile.displayName)) {
    fail(createError, 'failed-precondition', 'Player profile needs repair.');
  }
  return { displayName: profile.displayName, revision: profile.revision, configured: true };
}

function formatProfile(number, state) {
  return {
    playerId: formatPlayerId(number),
    number,
    displayName: state.displayName,
    revision: state.revision,
    configured: state.configured,
    authenticated: true,
  };
}

async function readPlayerProfile({ firestore, request, createError }) {
  const uid = readRequestUid(request, createError);
  const data = request?.data;
  if (data != null && (!isObject(data) || Object.keys(data).length !== 0)) {
    fail(createError, 'invalid-argument', 'Profile retrieval accepts no parameters.');
  }
  const [identity, profile] = await Promise.all([
    firestore.collection(ID_COLLECTION).doc(uid).get(),
    firestore.collection(COLLECTION).doc(uid).get(),
  ]);
  const number = requireIdentity(identity, createError);
  return formatProfile(number, validateProfile(profile, number, createError));
}

async function savePlayerDisplayName({
  firestore, request, serverTimestamp, createError,
}) {
  const uid = readRequestUid(request, createError);
  const data = request?.data;
  if (!isObject(data) || Object.keys(data).length !== 2 ||
      !Object.hasOwn(data, 'displayName') ||
      !Object.hasOwn(data, 'expectedRevision') ||
      !validDisplayName(data.displayName) ||
      !integer(data.expectedRevision, 0, 1000000000)) {
    fail(createError, 'invalid-argument',
      'A valid displayName and expectedRevision are required; UID/ID are server-owned.');
  }
  const identityRef = firestore.collection(ID_COLLECTION).doc(uid);
  const profileRef = firestore.collection(COLLECTION).doc(uid);
  return firestore.runTransaction(async (tx) => {
    const identity = await tx.get(identityRef);
    const number = requireIdentity(identity, createError);
    const previous = await tx.get(profileRef);
    const state = validateProfile(previous, number, createError);
    if (previous.exists && state.displayName === data.displayName) {
      return { ...formatProfile(number, state), changed: false };
    }
    if (state.revision !== data.expectedRevision) {
      fail(createError, 'aborted', 'Player name changed on another device; reload the profile.');
    }
    if (state.revision >= 1000000000) {
      fail(createError, 'resource-exhausted', 'Player profile revision limit reached.');
    }
    const next = {
      schema: 1, number,
      displayName: data.displayName,
      revision: state.revision + 1,
      updatedAt: serverTimestamp(),
    };
    if (previous.exists) {
      tx.update(profileRef, next);
    } else {
      tx.create(profileRef, { ...next, createdAt: serverTimestamp() });
    }
    return {
      ...formatProfile(number, {
        displayName: data.displayName,
        revision: next.revision,
        configured: true,
      }),
      changed: true,
    };
  });
}

module.exports = {
  COLLECTION,
  DEFAULT_NAME,
  validDisplayName,
  formatPlayerId,
  readPlayerProfile,
  savePlayerDisplayName,
};
