# THEDEMIAN: LAST ZONE — V75.73 · Nombre e ID de jugador

## Base confirmada
Se continúa a partir de V75.72 (PR #75), conservando el código Firebase de respaldo offline V75.72, Godot con la cámara, BR, animaciones y economía local ya integrados, y una única exportación Android ARM64 Vulkan Mobile con firma y package preview intactos. VersionCode **63**. No se altera `v44-3-2-autosave-guest`, Firestore Rules ni las cuentas/credenciales Firebase de producción.

## 1. Godot: nombre de jugador real, local y editable

- `scripts/persistence/local_player_name.gd`: perfil de nombre local independiente del registro de partidas, con archivo `user://profiles/aurora_player_name_v1.cfg`, escritura transaccional `.tmp`, copia anterior validada `.bak` y recuperación al reabrir.
- Validación en cliente: 3–16 caracteres, letras latinas, acentos, números, espacios internos únicos y guion bajo; rechazo de nombres como ADMIN, SOPORTE, FIREBASE o THEDEMIAN, caracteres fuera del formato y campos vacíos.
- El lobby Godot enseña el nombre actual en la barra superior sin tapar el título oficial. En **Cuenta** hay `LineEdit` y botón funcional **Guardar nombre local**; al guardar actualiza la visualización y persiste entre aperturas.
- El ID mostrado es **«ID OFICIAL: PENDIENTE DE FIREBASE»**, porque el cliente nativo aún NO ha vinculado Firebase Auth/App Check ni obtenido un número del servidor. No se inventa `00001`, UID o cuenta Google.
- La barra de monedas/diamantes conserva su significado anterior; cambiar nombre no altera resultados, monedas, inventario ni el modo de juego.

## 2. Firebase: preparar recuperación del nombre junto al ID que ya existía

- **Se conserva sin modificar** `ensurePlayerIdentity`, la transacción de `player_identities`, el contador `system_counters/players` y sus protecciones. Los ID secuenciales se representan con cinco dígitos: `00001`…`99999`. El nombre es un campo aparte, no el ID.
- Nuevo módulo `functions/src/player-profile.js` y callables `getPlayerProfile` y `setPlayerDisplayName` con **Firebase Authentication** y **App Check obligatorios**, listos para despliegue autorizado, no desplegados en este PR.
- El servidor consulta `player_identities/{request.auth.uid}`, exige un número válido ya asignado por `ensurePlayerIdentity`, y lee/escribe solo `player_profiles/{request.auth.uid}`. La aplicación NO puede pasar un UID, seleccionar un número, renumerar otra cuenta ni acceder a su perfil.
- El nombre se valida nuevamente en servidor y se guarda con `revision` monotónica y `updatedAt` de servidor. El cambio requiere `expectedRevision` para rechazar sobrescrituras concurrentes; un reintento idéntico es idempotente.
- `getPlayerProfile` retorna `playerId` con cero inicial, `displayName`, revisión y estado; si existe ID pero el nombre no se personalizó, devuelve `Operador` como valor predeterminado sin crear documentos silenciosamente.
- Las reglas de Firestore actuales ya deniegan `player_profiles` a clientes por la política `deny by default`; todas las mutaciones pasan por callables. **No hay compra/diamantes/rango ni autorizaciones de economía en este servicio.**

## 3. QA y límites

- `v7573_local_name_identity_qa.gd`: nombres válidos/inválidos, guardado y reapertura, copia local recuperable, editor real en móvil, nombre en lobby, **ID pendiente**, retorno a controles de Clásico. Se ejecuta en datos QA aislados.
- `functions/test/player-profile.test.js`: formato 5 dígitos, rechazo de nombres reservados, Auth/UID, asignación previa requerida, lectura sin crear, idempotencia, cuentas distintas, rechazo de asignación de número desde cliente, detección de discrepancias de ID y competencia entre renombrados.
- La CI exige pruebas Node 22 y toda la QA Godot antes de exportar APK; verifica nuevamente la QA sobre recursos exportados, versión, firma y arquitectura. **CI verde no equivale a integración real de Firebase ni prueba Motorola.**

### Pendiente para que el ID y nombre se sincronicen tras reinstalar

1. Configurar un puente Android–Godot **seguro**, en pruebas, para Firebase Auth Google/invitado, vinculación de la cuenta, App Check y llamadas callable con token válido. Confirmar paquete Android nativo `com.thedemianff.lastzone.nativepreview` frente a antiguo `com.thedemianff.lastzone`, fingerprints y secretos sin filtrarlos.
2. Desplegar controladamente los callables en un entorno Firebase de pruebas, auditar permisos, validación de conflictos y pruebas de usuario A/B. No desplegar a producción sin consentimiento y QA.
3. Recuperar el ID y nombre verdaderos y unificarlos con el perfil local, resolviendo conflictos con revisiones y consentimiento. Después activar V75.72 respaldo remoto/restauración de progreso y probar desinstalación/reinstalación en Motorola.
4. Mantener monedas y diamantes autoritativos fuera de la exportación local y alejar puntos/ranking online de estadísticas offline manipulables.

No declarar conexión Google, ID numérico asignado en Godot, compra premium ni recuperación tras desinstalar hasta que estas pruebas se hayan ejecutado.
