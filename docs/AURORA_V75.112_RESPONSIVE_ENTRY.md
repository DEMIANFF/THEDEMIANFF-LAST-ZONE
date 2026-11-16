# THEDEMIAN: LAST ZONE — V75.112 · Entrada Aurora adaptativa y panel de misión real

**Base:** `codex/v75-111-lila-lobby-fullbody-framing`, commit `aa7ae6123a0a0a8295f3561c22744e27d8690a4c`, PR #116, [CI completa aprobada](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/43806839669). Godot 4.7.2, Android ARM64/Vulkan Mobile.

## Evidencia visual y defecto

Recuperado el artefacto verdadero `THEDEMIAN-V75.111-LOBBY-ACCOUNT-PREVIEW` (GitHub Actions ID 14198698285). Las capturas `aurora-v75-111-login.png` y `aurora-v75-111-lobby.png` prueban que V75.111 recuperó el encuadre completo de Lila, pero la pantalla de acceso a 1280×720 dejaba un área vacía grande encima de los proveedores. Además, la descripción «BASE AURORA / OPERACIÓN INVIERNO» se dibujaba sobre el horizonte de la escena y era difícil de leer.

## Implementación nativa en esta rama

- Nuevo `PanelContainer` real `AuroraMissionBriefing` (Godot) integrado en la columna de login: panel translúcido con «PUESTO DE MANDO / AURORA», el modo BR clásico de 50 participantes y la descripción honesta «1 operador y 49 rivales IA»; no inventa multijugador, usuarios, compras ni pagos.
- Se muestra solo con altura de superficie **al menos 620 px**; se oculta en la ventana compacta de **964×434** para proteger la accesibilidad de Google, Invitado y Sin conexión. `_layout_safe()` actualiza su visibilidad cuando cambia el tamaño de pantalla. No se crea un nuevo `SubViewport` ni se añade una malla 3D.
- El texto de misión se desplaza hacia arriba (anclas verticales .42–.76 en lugar de .57–.86) para evitar que atraviese la línea del horizonte de Base Aurora, sin alterar sus palabras.
- Prueba nativa `v75112_responsive_auth_briefing_qa.gd` antes del resto de QA: valida contenido veraz, tamaño/presencia del panel en 1280×720, ausencia del panel en 964×434, visibilidad y hitboxes de las tres acciones, navegación real a lobby y limpieza de `SubViewport` al regresar al acceso.
- El workflow de Godot utiliza el identificador dinámico del preset Android para las capturas y su carga a artifacts; el flujo de exportación del APK sigue siendo **manual** mediante `workflow_dispatch`. VersionName `75.112.0-mobile-vulkan` y `versionCode=102`.

## Criterios de aceptación

1. CI `run_qa.sh` y capturas software OpenGL completas. Comparar la pantalla de acceso V75.112 con V75.111 y verificar que el panel no tapa los proveedores ni introduce scroll.
2. Conservar el encuadre de Lila en lobby en 964×434 y 1280×720, y el ciclo carga→Google/Invitado/Sin conexión→lobby→BR→regreso sin superposición ni fugas.
3. Antes de publicar, usar el workflow manual de GitHub Actions para construir, firmar y validar el APK ARM64/Vulkan (firma preexistente, versionCode 102, recursos de audio con derechos), descargar el artifact de esa ejecución y probarlo físicamente en Motorola Edge 60 Fusion: FPS/VRAM, taps, cortes, salida/reingreso.
4. La IA de 49 rivales offline es distinta de 49 jugadores humanos online. El rig masculino, la economía real y funciones de red **siguen pendientes**, no marcarlas como completadas.

**Invariantes:** no modificar `main`, `v44-3-2-autosave-guest`, Firebase productivo, ID del jugador, firma, paquete Android ni contratos de guardado.
