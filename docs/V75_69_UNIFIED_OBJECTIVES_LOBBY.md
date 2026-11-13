# V75.69 — Objetivos unificados y lobby adaptable de THEDEMIAN: LAST ZONE

## Base
- Continua V75.68, conservando el sistema de monedas locales, protección de duplicados, selector Clásico/Clasificatoria/Entrenamiento y el banner segmentado de identidad, estadísticas, monedas y estado de diamantes.
- Godot 4.7.2; Android ARM64 solo Vulkan Mobile, exportación versionCode 59; mismo paquete/firma de preview. Sin cambios en Firebase ni en la rama estable V44.
- La otra V75.66 PR #69 sigue divergente; no se integra con cambios no revisados.

## Cambio implementado
- Menú de **ocho** apartados: Personaje, Armas, **Objetivos**, Tienda, Pase, Social, Cuenta, Ajustes. Antes existían nueve botones con Misiones y Eventos separados.
- Dentro de Objetivos, un selector funcional abre **Misiones / Logros / Eventos** en el mismo panel. El área de partidas Clásico se oculta temporalmente para dejar sitio a la navegación de objetivos, sin impedir volver a iniciarlas.
- **Metas locales basadas en registros reales**: tres partidas, cinco eliminaciones y una victoria; límites de progreso claros.
- **Logros informativos**: primera partida, primera victoria y diez eliminaciones, calculados de registros firmados, no de clics.
- **Eventos online**: visualmente disponibles como categoría pero explícitamente sin temporada, recompensas ni programación activa. No se fabrican cuentas, monedas premium o temporadas.
- Cuenta, tienda y barra superior siguen mostrando solo monedas locales ganadas; diamantes no disponibles hasta tener cartera de servidor y validación de pagos.
- Los datos permanecen en `offline_match_records.gd`, sin esquema de temporada inventado.

## Pruebas
- `v755_lobby_combat_qa.gd` actualizada para verificar ocho secciones sin perder comprobaciones previas de cámara, HUD, título y controles.
- Nueva `v7569_unified_objectives_qa.gd` crea partidas de prueba aisladas en `user://qa/`, verifica contador de misiones, logros derivados y eventos no ficticios, restauración del botón Clásico y navegación móvil.
- La batería de Godot y la QA de recursos APK exportados deben aprobar y emitir `V7569_OBJECTIVES PASS` para considerar apto el cambio.
- No se ha realizado prueba física Motorola de esta rama: solo el usuario puede autorizarla.

## Siguiente trabajo
Integración de Auth Google/invitado y enlace seguro sin perder UID, sincronización de perfil con respaldo por revisión y controles de conflicto; después servidor autoritativo para Clásico online y Clasificatoria. Almacenes y balance de diamantes siguen cerrados. El objetivo de 1.000 mejoras es un backlog, no un conteo de funcionalidades entregadas.
