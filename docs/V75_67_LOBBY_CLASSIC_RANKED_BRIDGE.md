# THEDEMIAN: LAST ZONE — V75.67, lobby y transición responsable al online

## Base verificable
- Rama base: `codex/v75-66-hit-react-awm-animation-vulkan`, commit `d7c79bce3d893b1a5c7e8974ab2aa688ab7b80e7` (PR #68, CI 43515741446 SUCCESS).
- Otra rama V75.66, `codex/v75-66-lila-awm-bolt-muzzle-recoil-vulkan` (PR #69), **diverge** de la base; su CI 43516676184 falló en la regresión nativa. No se ha incluido ni descartado: requiere arreglo y fusión revisada.
- Godot 4.7.2 / Android ARM64 / **solo Vulkan Mobile**, mismo application ID y certificado previo; versionCode 57 para permitir actualizar APK anteriores. No cambiar `v44-3-2-autosave-guest`.

## Implementado en el código de V75.67
1. Selector explícito de **Clásico local**, **Clasificatoria online pendiente** y **Entrenamiento local**, usando las escenas y la lógica ya existentes.
2. Clásico permite únicamente partidas existentes de 9/20/30 participantes (un usuario humano y 8/19/29 bots físicos). No declara conexiones online.
3. Clasificatoria está visible pero bloqueada tanto en la IU como en `_launch()`; no se adjudican RP ficticios, ranking ni partidas supuestamente multijugador.
4. Entrenamiento sigue accediendo a su escena real. El editor HUD puede abrir esa escena temporalmente y retornar al lobby sin perder configuración.
5. Detalles del lobby en un `ScrollContainer` de tamaño flexible para evitar tapar información en horizontal. Los ajustes ocultan el selector de partida para dedicar su área a los controles.
6. QA `v7567_lobby_mode_gate_qa.gd` incluida en el conjunto nativo y en los recursos exportados del APK; CI bloquea la entrega si falta su marca PASS.

> Aún no se declara CI verde ni prueba Motorola de V75.67. Solo cuentan los resultados reales.

## Arquitectura necesaria para cuentas y autorespaldo (NO IMPLEMENTADA en esta versión)
- Adaptador autenticación Android/Godot para Firebase Auth con proveedor Google y modo invitado; **vincular** credenciales de invitado a Google sin cambiar UID cuando sea posible. Resolver cuentas existentes explícitamente y sin fusionar inventarios a ciegas.
- Función de servidor `ensurePlayerIdentity` con sesión validada en backend: ID secuencial, no confiar en datos del cliente ni volver a asignar ID desde Android. Auditar el despliegue de reglas y Cloud Functions antes de habilitar.
- Firestore: datos por `uid`, reglas de propietario y funciones privilegiadas; `player_backups` con formato versionado, checksum, `revision`, `updatedAt` y `deviceId` no autoritativo. Historial local de escritura atómica y backup alterno `.bak`, cola de sincronización, reintento con backoff y confirmación remota.
- Conflictos entre dos dispositivos: comprobar revisiones en transacción; no sobrescribir silenciosamente el progreso más reciente. Validación de esquema y migración, recuperación tras reinstalación, cierre de sesión, eliminación y exportación de cuenta, consentimiento y privacidad.
- No guardar claves administrativas/secretos Firebase en el cliente ni confiar en la aplicación para XP, monedas premium, inventario o calificación online.

## Clásico y Clasificatoria online (PLAN, no falsa funcionalidad)
- **Clásico:** primero partida humana de prueba con servidor dedicado autoritativo; luego solo/dúo/escuadra con reanimación, abandono, reconexión y estados sincronizados. El estado de bots se genera/simula en el servidor, no en cada móvil.
- **Clasificatoria:** abrir solo tras cuentas verificadas, colas con MMR/rango, temporadas y protección ante trampas; el servidor firma el resultado y entrega recompensas una sola vez mediante operaciones idempotentes.
- Telemetría: latencia, pérdida de paquetes, 1% low FPS, caídas, divergencias y coste por concurrencia.
- Google/Firebase maneja identidad y respaldo, **no sustituye** al servidor de partida.

## Puertas de aprobación
1. CI nativa y del APK Vulkan PASS, sin regresiones de vuelo, cámaras, armas, IA, cuenta o firma.
2. Captura real del lobby y prueba de accesibilidad en pantalla Motorola horizontal; prueba física solo con autorización.
3. Flujo invitado → Google → borrar/reinstalar → recuperar progreso y cambiar de móvil sin corrupción ni duplicados.
4. Alfa online privada con humanos reales, servidores y métricas; después beta cerrada de escalabilidad, seguridad y balance.
5. Lanzamiento público tras estabilidad, cuentas recuperables, soporte, privacidad, monetización legal y partidas consistentes.

## Seguimiento de 1.000 mejoras
El plan de 1.000 es un **backlog**. No se debe llamar completadas las tareas por tenerlas enumeradas. Llevar evidencia por criterio: cambio, ruta, SHA, prueba nativa, prueba del APK y, cuando corresponda, prueba física.
