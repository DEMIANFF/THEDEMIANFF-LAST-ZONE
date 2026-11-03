# V55.3 — IDs secuenciales seguros

## Implementación

- `ensurePlayerIdentity` es una callable Cloud Function de segunda generación en `us-central1`, con runtime Node.js 22 y Firebase Admin SDK.
- Firebase Authentication valida la sesión de quien llama. El cliente no envía UID; el servidor toma exclusivamente `request.auth.uid`.
- La asignación usa una transacción Firestore. Una identidad válida existente se devuelve sin modificarla; para una identidad nueva, primero se valida el contador y el mayor ID existente y luego se crea la identidad y se incrementa el contador en la misma transacción.
- Los ID se guardan como enteros de `1` a `99999`; Android los presenta con cinco dígitos (`00001` a `99999`).
- Si falta el contador, es inválido, está atrasado o se agotó el rango, no se asigna un ID nuevo.
- La app conserva Firebase Authentication y el flujo existente de respaldos de `player_backups`. Las reglas Firestore no se abren ni se modifican.

## Preflight antes de desplegar

Desde `functions/`, con Node.js 22 y credenciales administrativas de Application Default Credentials para `thedemianff-last-zone`, ejecutar:

```bash
npm install
npm test
npm run check
npm run bootstrap:player-ids
npm run audit:player-ids
```

`bootstrap:player-ids` solo crea `/system_counters/players` con `{ next: 0 }` cuando el contador no existe y la colección `player_identities` está completamente vacía. Si encuentra cualquier identidad existente, se detiene y no escribe. Si el contador ya existe, no lo modifica. Ejecutarlo requiere permiso administrativo para crear el documento del contador; nunca actualiza identidades.

La auditoría lee toda `player_identities` en páginas de 1.000 documentos y consulta `/system_counters/players`; comprueba IDs enteros únicos dentro de `00001`–`99999` y que `next` exista y no sea menor que el ID máximo. Es de solo lectura. Si falla, detener el despliegue y resolver la inconsistencia mediante revisión administrativa; no reiniciar el contador ni sobrescribir identidades.

El despliegue requiere que las reglas restrictivas correctas ya estén publicadas en Firebase. El archivo `firestore.rules` de GitHub no se aplica automáticamente a producción. Verificar las reglas desplegadas antes de habilitar clientes. El Admin SDK de la función escribe con privilegios de servidor; los clientes no reciben permisos para `player_identities` ni `system_counters`.

## Despliegue y facturación

Este commit prepara el código, pero no ejecuta `firebase deploy`, no cambia el plan de facturación ni altera datos de producción. La activación de Cloud Functions y cualquier cambio de facturación requieren una operación administrativa separada.

## Pruebas

`npm test` ejecuta 13 pruebas unitarias del asignador con un adaptador transaccional en memoria. Incluyen autenticación, rechazo de UID enviado por el cliente, idempotencia, concurrencia simulada, contador faltante/atrasado/inválido, límite 99.999, auditoría y bootstrap inicial protegido. No sustituyen una prueba de integración con Firebase Emulator ni la auditoría de datos reales de producción.
