# THEDEMIAN: LAST ZONE — V75.71: paquete local verificado del perfil

## Alcance real
Se parte de V75.70 PR #73, con CI GitHub Actions [43530023236](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/43530023236) SUCCESS. Se mantiene la APK Android ARM64 Vulkan Mobile, firma y package preview, con `versionCode=61`. Nada en `v44-3-2-autosave-guest` ni en Firebase producción se modifica.

Este hito crea un **paquete exportable dentro del almacenamiento privado Godot**, diseñado como **base de contrato** para una futura integración autenticada. **No hay ningún inicio de sesión Firebase, subida, descarga, sincronización, importación automática ni recuperación tras reinstalación en esta versión.**

### Implementación
- Nuevo `native-godot/scripts/persistence/local_profile_export.gd`.
- `create()` lee el registro de partidas local válido, repara primero recuperaciones `.auto` pendientes mediante la lógica existente, y genera `user://profiles/aurora_profile_export_v1.json`.
- El sobre incluye formato `aurora_offline_profile_export`, `version=1`, fecha local, última revisión, origen `local_godot_no_auth`, resultados y historial de partidas, y un checksum SHA256 del payload. El archivo se escribe primero en `.tmp`, se comprueba y se renombra.
- `inspect()` verifica sintaxis, checksum, versión, coherencia de la revisión, validación de resultados y ausencia de valores prohibidos.
- **Las monedas locales, diamantes, pagos, credenciales y puntos de Clasificatoria están excluidos deliberadamente**: no existe un saldo fiable que pueda migrarse directamente a una economía online.
- El menú **Ajustes → Cuenta** dispone de dos acciones funcionales: **GENERAR PAQUETE LOCAL VERIFICADO** y **COMPROBAR PAQUETE DE PROGRESO**. Se especifica en pantalla que el paquete no está en la nube y podría perderse al desinstalar.

### No confundir un checksum con confianza del servidor
Un usuario con control de su dispositivo puede modificar el payload **y recalcular SHA256**. Por ello, un futuro backend no puede aceptar sin más los resultados del paquete como evidencia de partidas competitivas, RP, saldo ni artículos. La autenticación Google/Firebase identifica una cuenta, pero **no autoriza automáticamente** las recompensas de una partida. Clásico online y Clasificatoria necesitan resultados firmados/almacenados por servidor autoritativo.

### QA verificable
- `v7571_local_profile_export_qa.gd` usa archivos aislados en `user://qa/`, prueba perfil ausente, resultados con dos partidas reales guardadas, campos de versión e identidad, ausencia de monedas y diamantes, rechazo de checksum alterado y de payload con monedas introducidas aunque se recalcule SHA256, y actualización a la tercera partida sin duplicar saldo.
- CI `native-godot/tools/run_qa.sh` ejecuta estas pruebas y el flujo `native-godot-preview-apk.yml` requiere su marca `V7571_PROFILE_EXPORT PASS` tanto en origen como sobre los recursos exportados al APK.
- La aprobación requiere CI SUCCESS; la validación táctil del Motorola Edge 60 Fusion sigue pendiente de autorización del usuario.

### Proximidad a Firebase
El paquete contiene únicamente estadísticas **no competitivas offline** para definir el contrato del cliente. La siguiente fase deberá integrar Firebase Auth (Google/invitado), una identidad de jugador real, validación del vínculo entre app Android histórica `com.thedemianff.lastzone` y paquete Godot preview `com.thedemianff.lastzone.nativepreview`, Firestore y Cloud Functions con reglas propietarias. Después se deberá diseñar restauración tras reinstalación con revisión, transacciones, conflictos y migraciones por UID. No activar estas operaciones hasta la verificación completa.

Las 1.000 mejoras siguen siendo una lista de tareas a conciliar con pruebas, no un número completado.
