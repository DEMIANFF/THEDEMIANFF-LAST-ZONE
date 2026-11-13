# THEDEMIAN: LAST ZONE — V75.48 | Vulkan único y botín por eliminación

## Decisión confirmada por el jugador
Después de ensayar V75.46 en Motorola Edge 60 Fusion, el usuario prefiere Vulkan Mobile. **No volver a compilar dos APK Android por versión.** Conservar el proyecto y las pruebas antiguas; su renderer OpenGL headless de escritorio en CI no equivale a generar un segundo APK Android.

## Base y restricción
- Parte de V75.47, rama `codex/v75-47-vulkan-frame-pacing-optimizations`, PR #52.
- Android: `rendering_method.mobile=mobile` y `driver.android=vulkan`, versionCode 42, Android ARM64 firmado con el mismo certificado e ID preview `com.thedemianff.lastzone.nativepreview`.
- Conservar la rama estable V44, cuentas Firebase, firmas, física 60 Hz, cámara 360°, ADS, controles y avances anteriores.
- Se genera **una** APK V75.48 Mobile/Vulkan; no APK de comparación OpenGL.

## Sistemas jugables implementados
1. Señal explícita y verificable `bot_eliminated` producida por bajas reales de CharacterBody3D.
2. Botín de campo creado junto al rival eliminado en una partida activa.
3. El botín es un `Area3D` recogible de verdad por el jugador.
4. El recurso de botín modifica la munición, botiquines o protección mediante el inventario ya existente.
5. Recompensa por bajas del jugador diferenciada de muertes de IA entre sí.
6. Eliminaciones entre bots dejan suministros; no se acreditan al jugador.
7. Muertes por la zona fuera del círculo no crean botín inaccesible.
8. Botín sobre terreno o suelo elevado válido, no enterrado bajo el piso de las casas.
9. Etiqueta visible `RIVAL / ...` en el objeto físico que procede de una eliminación.
10. Antiduplicación por identidad del rival durante la misma partida.
11. Límite de 12 nuevos suministros procedentes de eliminaciones para evitar saturación en móviles.
12. Al reiniciar se libera el botín de la ronda previa y se reinicia el contador.
13. Preservadas las 25 ubicaciones iniciales de botín real (16 exteriores + 8 interiores + AWM).
14. Conservar la AWM como arma física recogible en el mapa.
15. Nuevo QA de integración `v7548_battle_loot_qa.gd`, incluido en QA fuente y APK exportada.
16. Exportación única Vulkan, sin una segunda APK OpenGL.

No son 1.000 mejoras terminadas: se han cambiado sistemas concretos, y cada hito exige pruebas. Se requiere ensayo real Android, porque GitHub Actions no emula GPU Mali del Motorola.

## Aceptación del hito
- CI verde para importación, todos los tests existentes y V75.48.
- Exportación y firma APK Android ARM64, manifest Vulkan comprobado, SHA256, alineación 16KiB y regresión sobre recursos exportados.
- Prueba en Motorola (9/20/30 jugadores locales contando la persona) con movimiento, cámara, disparos, botín de enemigos, victoria, persistencia y FPS.
- No confundir jugadores IA con sesiones de 50 humanos; multiplayer online sigue pendiente.

## Siguiente bloque
Priorizar animaciones naturales de Lila, navegación y tácticas IA, interiores, controles de disparo y ADS, fidelidad de escenario y finalmente infraestructura de red autoritativa para partidas reales. Evitar reabrir trabajos ya completados o introducir simulaciones como sustitutos.
