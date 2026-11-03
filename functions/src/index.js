'use strict';

const { initializeApp, getApps } = require('firebase-admin/app');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');
const { HttpsError, onCall } = require('firebase-functions/v2/https');
const { assignSequentialPlayerId, getAuthenticatedUid } = require('./identity');

if (getApps().length === 0) initializeApp();

const firestore = getFirestore();
const asHttpsError = (code, message) => new HttpsError(code, message);

exports.ensurePlayerIdentity = onCall(
  { region: 'us-central1', maxInstances: 10 },
  async (request) => {
    // Callable infrastructure verifies Firebase Auth tokens; the client cannot choose a UID.
    const uid = getAuthenticatedUid(request, asHttpsError);
    const number = await assignSequentialPlayerId({
      firestore,
      uid,
      serverTimestamp: () => FieldValue.serverTimestamp(),
      createError: asHttpsError,
    });
    return { number };
  },
);
