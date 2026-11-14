'use strict';

const { initializeApp, getApps } = require('firebase-admin/app');
const { FieldValue, getFirestore } = require('firebase-admin/firestore');
const { HttpsError, onCall } = require('firebase-functions/v2/https');
const { assignSequentialPlayerId, getAuthenticatedUid } = require('./identity');
const { saveOfflineProgress, loadOfflineProgress } = require('./offline-progress');

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

// V75.72: Authenticated storage of explicitly UNVERIFIED offline results.
// App Check enforcement intentionally prevents use until a trusted Godot
// Android Auth/AppCheck bridge is configured; no auto-deployment is performed.
exports.saveLocalProgressSnapshot = onCall(
  { region: 'us-central1', maxInstances: 10, enforceAppCheck: true },
  async (request) => saveOfflineProgress({
    firestore, request,
    serverTimestamp: () => FieldValue.serverTimestamp(),
    createError: asHttpsError,
  }),
);

exports.loadLocalProgressSnapshot = onCall(
  { region: 'us-central1', maxInstances: 10, enforceAppCheck: true },
  async (request) => loadOfflineProgress({
    firestore, request,
    createError: asHttpsError,
  }),
);
