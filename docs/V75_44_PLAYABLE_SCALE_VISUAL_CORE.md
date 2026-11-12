# V75.44 — Núcleo jugable escalable y escenario 3D del lobby

Base: V75.43, PR #48, Actions SUCCESS #43279589824, SHA fe3ce2d5c8a76bec17cb674fc81603053f0b18ec.
Identidad: THEDEMIAN: LAST ZONE / PUERTO AURORA.

## Implementado realmente en Godot

- Lobby: botón de selección de encuentro local, 9 (1 jugador + 8 bots), 20 (1 + 19 bots), o 30 (1 + 29 bots). Son personajes físicos IA: no afirmar multijugador humano online.
- Mantener por defecto 9 combatientes, valor seguro para Motorola. 20 y 30 son pruebas opcionales de carga que necesitan medición real de FPS.
- Cada bot tiene CharacterBody3D, vida, hitbox, movimiento, percepción, combate y colisiones. Spawns extendidos de forma reproducible sobre el terreno, evitando viviendas, mar y pendientes peligrosas.
- LOD de IA lejana: bots adicionales conservan física y lógica con representación económica, cargan rig completo cerca del jugador (39m), liberan rig lejos (56m). A más de 75m, espaciado de actualizaciones físicas por fotograma para evitar saturar Android.
- Escenario 3D verdadero en el viewport de Lila: montañas nevadas de malla, hangares en Puerto Aurora, pista iluminada, arcos emisivos y cortinas de aurora. No es una captura de referencia ni una interfaz ficticia; el juego libera el viewport antes de cargar batalla.
- El menú lateral adapta tamaño a la altura útil del Motorola en horizontal y mantiene sus nueve secciones.
- Se conservan zonas físicas, ocho casas costeras, cuatro edificios históricos, botín, AWM, cámaras, inventario, paracaídas, HUD y configuración de versiones previas.

## Pruebas y restricciones

La QA V75.44 escala los enemigos a 20 y 30 combatientes y vuelve a 9 sin crear una sala ficticia; verifica hitboxes, posiciones y LOD, selección en lobby, y escena 3D real. Todos los tests anteriores se ejecutan en el proyecto y en el código exportado de Android. Firma y namespace preview se mantienen. No tocar la rama protegida v44-3-2-autosave-guest, Unity ni Firebase.

## Trabajo pendiente para lograr las imágenes de referencia

Los montajes de referencia son una dirección de arte y funcionalidad, NO imágenes del juego actual. No se copian modelos o logos de Free Fire, Nexora ni terceros. Puerto Aurora necesita modelado de edificios propio, materiales PBR, iluminación, biomas, carreteras, texturas y personajes detallados; Lila sigue usando rig temporal. Para 20/30 personas humanas de verdad será necesario implementar servidor autoritativo, conexión, replicación, sincronización de daños y anti-trampa, pruebas de red y compatibilidad real con Android. Ninguno de esos sistemas puede considerarse listo simplemente por mostrar un contador 20/30.

Prueba obligatoria antes de mezclar PR: APK firmada, CI verde y comprobaciones manuales de FPS/temperatura/estabilidad en Motorola Edge 60 Fusion.
