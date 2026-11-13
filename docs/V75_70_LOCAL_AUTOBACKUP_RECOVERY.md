# THEDEMIAN: LAST ZONE — V75.70, autorespaldo local recuperable

## Continuidad y alcance
- Se continúa desde V75.69 PR #72 (CI 43522402417 SUCCESS), sin reescribir Lila, combate, cámara, HUD, avión ni el sistema de monedas.
- Godot 4.7.2, Android ARM64 **Vulkan Mobile solamente**, aplicación preview/keystore sin cambios, versionCode 60.
- No se modifica la rama estable `v44-3-2-autosave-guest`, el Firebase antiguo, sus reglas ni sus funciones.
- Este hito **NO IMPLEMENTA AUTORESPALDO EN LA NUBE NI RECUPERACIÓN TRAS DESINSTALAR**. El archivo está dentro de `user://` en el teléfono.

## Implementado en fuente
1. Después de confirmar una partida Clásico en `offline_match_records.gd`, se copia el registro SHA256 validado a una **tercera copia independiente `.auto`**, escribiendo primero `.auto.tmp` y promoviendo mediante renombrado.
2. `reload()` compara primary, `.bak`, `.tmp` y `.auto` y recupera la revisión válida con mayor `next_match_id`. Así no se pierde una victoria o su moneda local si se dañan los dos registros tradicionales.
3. `retry_pending()` vuelve a escribir el resultado recuperado. No concede monedas por segunda vez: `match_id` y la contabilidad atómica continúan siendo la fuente de verdad.
4. `auto_backup_status()` distingue copia ausente, desactualizada y verificada; nunca inventa un estado online.
5. `refresh_auto_backup()` permite actualizar manualmente la copia tras validar el archivo principal. Su uso no crea partidas ni recompensas.
6. El lobby **Cuenta** indica respaldo de partidas, cantidad verificada y que desinstalar puede perder estos datos.
7. La sección **Cuenta** de Ajustes permite **Verificar/actualizar respaldo local** de forma funcional, mientras el respaldo de ajustes separado se conserva sin alteraciones.

## Recuperación y compatibilidad
- Backups existentes `.bak/.tmp` y perfiles anteriores de esquema 1 siguen siendo legibles. Los perfiles anteriores pueden crear su copia local con el botón de Ajustes.
- El guardado principal se considera exitoso incluso si falla la copia extra: el fallo emite una advertencia sin convertir el registro guardado en una derrota o repetir recompensas.
- El checksum protege de **corrupción accidental**, no de manipulaciones intencionales. No hay seguridad criptográfica contra un usuario que controle el móvil.
- NO se deben sincronizar automáticamente las monedas locales como monedas online ni confundirlas con diamantes, inventario premium, rango ni sesiones Firebase.

## Pruebas
- V75.70 añade `v7570_local_autobackup_recovery_qa.gd` para comprobar la copia después de cada partida, recuperación de la última revisión al corromper primary y `.bak`, restauración persistida, prevención de doble pago, rechazo de `.auto` corrupta, restauración manual y creación para perfil antiguo.
- Regresiones actualizadas para seleccionar el backup válido más reciente en lugar de volver a una partida anterior. Las pruebas aisladas limpian las copias `.auto/.auto.tmp` para evitar residuos entre ejecuciones.
- `run_qa.sh` y CI comprueban fuente y recursos dentro de la **APK exportada**. La ejecución debe terminar en SUCCESS antes de aprobar una versión.
- Las pruebas automatizadas no sustituyen la prueba física de Motorola que el usuario mantiene pospuesta.

## Puente real de Firebase que aún falta
1. Integrar un cliente Godot–Android nativo con Firebase Auth invitado/Google y un mismo identificador/contrato de cuenta; confirmar los nombres de paquete y huellas SHA con cuidado, pues el paquete Godot preview no es el de la app Android anterior.
2. Diseñar backup remoto del progreso con esquema versionado, revisión monotónica, conflictos por dispositivo, reglas propietario y restauración tras reinstalar. Preparar pruebas de eliminación, vinculación y recuperación de cuentas.
3. Separar billetera monetizada y recompensas online en backend autoritativo con deduplicación de eventos y compras verificadas por plataforma.
4. Luego habilitar pruebas humanas en servidores privados para Clásico y posteriormente Clasificatoria con rango real, anti-cheat y escalabilidad.

## Meta de 1.000 mejoras
Es un backlog pendiente de verificación por cambio/archivo/commit/CI, no una cifra de funciones ya implementadas.
