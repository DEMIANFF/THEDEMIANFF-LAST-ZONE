'use strict';

const { initializeApp, getApps } = require('firebase-admin/app');
const { FieldPath, getFirestore } = require('firebase-admin/firestore');
const { auditSequenceState } = require('../src/identity');

const PROJECT_ID = 'thedemianff-last-zone';

async function main() {
  if (getApps().length === 0) initializeApp({ projectId: PROJECT_ID });
  const firestore = getFirestore();

  // Read-only preflight. Paginate to avoid loading the full collection in a single query.
  const identities = [];
  const collection = firestore.collection('player_identities');
  let cursor = null;
  while (true) {
    let query = collection.orderBy(FieldPath.documentId()).limit(1000);
    if (cursor !== null) query = query.startAfter(cursor);
    const page = await query.get();
    if (page.empty) break;
    for (const document of page.docs) {
      identities.push({ uid: document.id, number: document.get('number') });
    }
    cursor = page.docs[page.docs.length - 1];
    if (page.size < 1000) break;
  }

  const counterSnapshot = await firestore.collection('system_counters').doc('players').get();
  const audit = auditSequenceState(
    identities,
    counterSnapshot.exists,
    counterSnapshot.exists ? counterSnapshot.get('next') : undefined,
  );

  console.log(`Proyecto: ${PROJECT_ID}`);
  console.log(`Identidades revisadas: ${identities.length}`);
  console.log(`ID máximo encontrado: ${audit.highestAssigned === null ? 'ninguno' : String(audit.highestAssigned).padStart(5, '0')}`);
  console.log(`Contador: ${counterSnapshot.exists ? counterSnapshot.get('next') : 'FALTANTE'}`);
  if (!audit.valid) {
    console.error('AUDITORÍA FALLIDA. No habilites nuevas asignaciones:');
    for (const error of audit.errors) console.error(`- ${error}`);
    process.exitCode = 1;
    return;
  }
  console.log('AUDITORÍA CORRECTA. No se modificó ningún documento.');
}

main().catch((error) => {
  console.error('No se pudo completar la auditoría de solo lectura:', error.message);
  process.exitCode = 1;
});
