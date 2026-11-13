# THEDEMIAN: LAST ZONE — V75.68 | Monedas locales verificables

## Alcance implementado

- El registro **real** de cada partida Clásico offline concede monedas locales en el mismo commit atómico que guarda resultado, bajas, tiempo e historial; entrenamiento no registra este resultado.
- Recompensa determinista inicial: **25** por partida completada + **5** por baja (máximo 20 bajas contabilizadas para recompensa) + **2** por minuto de supervivencia (máximo 10 minutos) + **75** si gana. Estas tasas son parámetros de **prueba offline**, no promesas de economía monetizada ni recompensas online.
- Protección idempotente: se emplea el `match_id` del registro de partidas. Un segundo intento de guardar la misma partida no añade monedas.
- Saldo visible en la franja superior y secciones **Cuenta** y **Tienda** como **MONEDAS LOCALES**.
- **Diamantes: sin conexión.** No se escriben balances premium, no se simulan recargas, compras, catálogo, RP o partidas online.
- Migración compatible con los anteriores perfiles de esquema 1: si el campo `local_coins` no existía, se considera 0. No genera dinero ficticio por partidas históricas.
- `local_coins_awarded` se conserva en el historial reciente para auditar el cálculo de cada recompensa. Tope entero y validación impiden datos corruptos o sobredimensionados.
- `v7568_local_coins_ledger_qa.gd` usa rutas QA aisladas y comprueba recompensa, partidas duplicadas, reapertura, migración y ausencia de cartera premium. Corre en Godot fuente y de nuevo en recursos de APK firmado.

## Seguridad y límites de este hito

- El sistema offline y su SHA256 proporcionan **recuperación e integridad accidental**, no autenticación criptográfica ni anti-cheat ante un jugador que controle su dispositivo.
- **Jamás** aceptar monedas locales del dispositivo como prueba de derecho a una compra en el servidor. No migrarlas automáticamente a la economía online ni convertirlas en diamantes.
- La economía online necesita **Firebase Auth Google/invitado**, Firestore con reglas por usuario y un backend con validación autoritativa del saldo, compras por ID transaccional e idempotencia y sus propias tablas/versiones de catálogo.
- Para monedas online: eventos de recompensa otorgados por el servidor después de validar resultados; deduplicar por matchId; no confiar en el total enviado por un móvil.
- Para diamantes: gestionar compras de la plataforma, validación server-side de comprobantes, preventa/reembolsos/reversiones, prevención de doble abono y políticas aplicables.
- Artículos cosméticos y pase de batalla deben evitar ventajas competitivas injustas.
- No modificar Firebase real, credenciales, configuraciones actuales, rama estable V44 ni claves de firma.

## QA y aprobación
La CI V75.68 requiere `V7568_LOCAL_COINS PASS` tanto en fuente como en exportación Android ARM64 únicamente Vulkan Mobile, package y certificado conservados y versionCode 58.
No declarar APK lista ni juego completo hasta ver CI SUCCESS y obtener prueba física autorizada.

## Próximo trabajo
Agrupar en el lobby Misiones/Eventos/Logros, diseño visual de tienda/Pase, estados de cuenta, vinculación Google y recuperación de respaldo. Preparar Clásico online con servidor autoritativo antes de activar Clasificatoria. El backlog maestro de 1.000 mejoras permanece abierto y necesita conciliación por cambios probados.
