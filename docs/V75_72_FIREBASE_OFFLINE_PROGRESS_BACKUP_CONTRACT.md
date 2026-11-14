# THEDEMIAN: LAST ZONE — V75.72: contrato de respaldo Firebase del progreso offline

## Alcance implementado en código

Se continúa desde V75.71 PR #74. Esta versión incorpora un servicio real **del lado del servidor** en `functions/src/offline-progress.js`, el registro de dos callable functions nuevas en `functions/src/index.js`, pruebas de concurrencia y CI Node.js 22. **No se despliega Firebase ni se conecta todavía el cliente Godot**, por lo que estas funciones no son una copia cloud operativa para jugadores hasta completar y verificar los próximos pasos.

### Nuevas callable functions (pendientes de despliegue)
- `saveLocalProgressSnapshot`: exige Firebase Auth con UID obtenido de la sesión, verificación Firebase App Check, paquete local de progreso versionado V75.71 y `expectedRevision`. Guarda el perfil **solo offline/no competitivo** en `player_progress_snapshots/{uid}` con transacción de Firestore, número de revisión y hora del servidor.
- `loadLocalProgressSnapshot`: exige Firebase Auth y App Check, no acepta UID ni otros datos del usuario como parámetros. Lee exclusivamente el documento de la cuenta autenticada; valida contenido, revisión y fingerprint antes de devolver el progreso.
- Se rechazan campos desconocidos o de economía: `local_coins`, `diamonds`, `rank_points`, `uid`, recompensas, inventarios y datos de compras. Las cifras de partidas offline de un móvil **nunca** se convierten en RP, saldo autorizado, inventario de pago o prueba de combates humanos.
- El sobre SHA256 del dispositivo sirve para detectar corrupciones accidentales. No es una firma de origen fiable; por ello el backend marca siempre `verifiedCompetitive: false` y `walletIncluded: false`.
- `expectedRevision` implementa control de concurrencia para no sobreescribir el progreso de otro dispositivo. Un paquete idéntico es idempotente. Un paquete con menor o igual `played` y datos diferentes se rechaza. Las escrituras usan operaciones transaccionales atómicas de Firestore.
- Se reutilizan Cloud Functions Node.js 22, Firebase Admin y Firestore; las funciones previas `ensurePlayerIdentity`, sus contadores e identidades permanecen intactas.
- El nuevo documento no requiere cambios a `firestore.rules`: los clientes están denegados por defecto y el acceso se implementa por callable autenticada del servidor. `player_backups` heredado permanece separado, con reglas idénticas.

### Tests implementados y CI
- `functions/test/offline-progress.test.js` cubre ausencia de sesión, falsificación de UID, paquete manipulado o demasiado grande, campos prohibidos, inconsistencia de datos, idempotencia, revisión, aislamiento entre dos cuentas, concurrencia entre dos dispositivos, rechazos por revisión antigua y lectura de documento corrupto.
- La workflow CI instala Node.js 22, verifica sintaxis del servidor y ejecuta las pruebas de `functions/test/*.test.js` **sin desplegar funciones**. También se conserva el conjunto de QA Godot y exportación Android ARM64 Vulkan Mobile, con versionCode 62 y firma histórica.
- El éxito de CI valida código y simulaciones controladas, pero **no prueba despliegue a Firebase, credenciales Google, red en Motorola ni restauración real tras desinstalar**.

## Pasos antes de activar una copia en la nube

1. Confirmar y configurar proyecto Firebase, App Check, certificados Android SHA y package `com.thedemianff.lastzone.nativepreview` sin sobrescribir la app antigua `com.thedemianff.lastzone`.
2. Integrar cliente Godot–Android de Auth y App Check con cuenta invitado y vinculación Google; pedir su token válido a Firebase y usar callable SDK, sin imprimir tokens en logs.
3. Auditar reglas, cuotas/costes de Firestore, permisos administrativos, validación de datos históricos y políticas de conservación/borrado.
4. Ejecutar manualmente pruebas en un entorno Firebase **de pruebas/emuladores**. Probar usuario A/B, conflictos, retransmisiones, restauración después de reinstalación, migración controlada, vinculación de Google y cancelaciones.
5. Solo después autorizar despliegue a producción y activar sincronización automática del cliente cuando haya sesión válida, con backoff y estado de confirmación. **Ningún cambio de este PR despliega servicios ni modifica cuentas productivas.**

## Próximas fases del juego
Primero respaldos remotos verificados y Clásico online de prueba con servidor autoritativo. Después Clasificatoria, MMR, temporadas y recompensas reales. Diamantes y monedas online seguirán totalmente separados del perfil local y solo podrán ser acreditados o gastados mediante operaciones server-side.

El catálogo de 1.000 mejoras es un backlog aún abierto; cada mejora se considera lista únicamente con evidencia de código, QA y, cuando corresponda, pruebas móviles.
