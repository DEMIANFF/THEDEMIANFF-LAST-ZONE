'use strict';

const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { HttpsError } = require('firebase-functions/v2/https');
const { initializeEmptyPlayerCounter } = require('../src/identity');

const PROJECT_ID = 'thedemianff-last-zone';

async function main() {
  if (getApps().length === 0) initializeApp({ projectId: PROJECT_ID });
  const firestore = getFirestore();
  const result = await initializeEmptyPlayerCounter({
    firestore,
    createError: (code, message) => new HttpsError(code, message),
  });

  if (result.created) {
    console.log('Contador inicial creado de forma segura con next=0.');
    console.log('El primer jugador autenticado podrá recibir 00001.');
  } else {
    console.log('El contador ya existía; no se modificó ningún dato.');
    console.log('Ejecuta la auditoría de solo lectura para comprobar su consistencia.');
  }
}

main().catch((error) => {
  console.error('No se pudo preparar el contador inicial:', error.message);
  process.exitCode = 1;
});
