'use strict';

const MIN_PLAYER_ID = 1;
const MAX_PLAYER_ID = 99999;

function fail(createError, code, message) {
  throw createError(code, message);
}

function getAuthenticatedUid(request, createError) {
  const uid = request && request.auth && request.auth.uid;
  if (typeof uid !== 'string' || uid.length === 0 || uid.length > 128 || uid.includes('/')) {
    fail(createError, 'unauthenticated', 'A valid Firebase Authentication session is required.');
  }

  const data = request.data;
  if (data !== undefined && data !== null) {
    if (typeof data !== 'object' || Array.isArray(data) || Object.keys(data).length !== 0) {
      fail(createError, 'invalid-argument', 'This callable does not accept a target UID or other input.');
    }
  }
  return uid;
}

function validateSequenceCounter(counterExists, counterValue, highestAssigned, createError) {
  if (!counterExists) {
    fail(createError, 'failed-precondition', 'The player ID counter is missing; no ID was assigned.');
  }
  if (!Number.isSafeInteger(counterValue) || counterValue < 0 || counterValue > MAX_PLAYER_ID) {
    fail(createError, 'failed-precondition', 'The player ID counter is invalid; no ID was assigned.');
  }
  if (highestAssigned !== null &&
      (!Number.isSafeInteger(highestAssigned) ||
       highestAssigned < MIN_PLAYER_ID || highestAssigned > MAX_PLAYER_ID)) {
    fail(createError, 'failed-precondition', 'An existing player ID is invalid; no ID was assigned.');
  }
  if (highestAssigned !== null && counterValue < highestAssigned) {
    fail(createError, 'failed-precondition', 'The player ID counter is behind an existing assignment.');
  }
  return counterValue;
}

async function assignSequentialPlayerId({ firestore, uid, serverTimestamp, createError }) {
  return firestore.runTransaction(async (transaction) => {
    const identityRef = firestore.collection('player_identities').doc(uid);
    const counterRef = firestore.collection('system_counters').doc('players');
    const highestIdentityQuery = firestore.collection('player_identities')
      .orderBy('number', 'desc')
      .limit(1);

    const identitySnapshot = await transaction.get(identityRef);
    // Preserve valid old assignments while the administrator repairs any global counter issue.
    if (identitySnapshot.exists) {
      const assigned = identitySnapshot.get('number');
      if (!Number.isSafeInteger(assigned) || assigned < MIN_PLAYER_ID || assigned > MAX_PLAYER_ID) {
        fail(createError, 'failed-precondition', 'The saved player ID is invalid; no changes were made.');
      }
      return assigned;
    }

    const counterSnapshot = await transaction.get(counterRef);
    const highestSnapshot = await transaction.get(highestIdentityQuery);
    const highestDoc = highestSnapshot.docs.length === 0 ? null : highestSnapshot.docs[0];
    const highestAssigned = highestDoc === null ? null : highestDoc.get('number');
    const previous = validateSequenceCounter(
      counterSnapshot.exists,
      counterSnapshot.exists ? counterSnapshot.get('next') : undefined,
      highestAssigned,
      createError,
    );

    if (previous >= MAX_PLAYER_ID) {
      fail(createError, 'resource-exhausted', 'All five-digit player IDs have been assigned.');
    }

    const next = previous + 1;
    transaction.create(identityRef, {
      number: next,
      createdAt: serverTimestamp(),
    });
    transaction.set(counterRef, { next });
    return next;
  });
}

function auditSequenceState(identityRecords, counterExists, counterValue) {
  const errors = [];
  const seen = new Set();
  let highestAssigned = null;

  for (const record of identityRecords) {
    const number = record && record.number;
    if (!Number.isSafeInteger(number) || number < MIN_PLAYER_ID || number > MAX_PLAYER_ID) {
      errors.push('An identity has a missing or out-of-range number.');
      continue;
    }
    if (seen.has(number)) errors.push('Two or more identities share the same number.');
    seen.add(number);
    highestAssigned = highestAssigned === null ? number : Math.max(highestAssigned, number);
  }

  try {
    validateSequenceCounter(counterExists, counterValue, highestAssigned, (code, message) => {
      const error = new Error(message);
      error.code = code;
      return error;
    });
  } catch (error) {
    errors.push(error.message);
  }

  return { valid: errors.length === 0, highestAssigned, errors };
}

module.exports = {
  MAX_PLAYER_ID,
  assignSequentialPlayerId,
  auditSequenceState,
  getAuthenticatedUid,
};
