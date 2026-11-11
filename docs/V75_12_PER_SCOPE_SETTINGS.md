# THEDEMIANFF LAST ZONE — Godot V75.12 controles y ajustes (Android)

**Base:** `codex/v75-11-landing-stability-fix` (`b49851dee5c371c627bd6ca2b815bc4a4e7b7b6a`).  
**Trabajo:** `codex/v75-12-per-scope-mobile-settings`.  
**Estado:** código publicado, validación en Godot CI y en Motorola requerida antes de aprobar.

## Cambios funcionales

1. `scripts/persistence/player_settings.gd` guarda en `user://ajustes.cfg` la sensibilidad general, ADS, punto rojo, 2x, 4x y francotirador 8x. Valores 0–200; valor 100 equivale a multiplicador 1.0. Rechaza NaN y rangos inválidos, usa archivo temporal y respaldo `.bak`, y recupera ajustes válidos si la copia principal se daña.
2. Una instalación anterior conserva su `user://aurora_camera.cfg`. Si aún no existe `ajustes.cfg`, las sensibilidades global y ADS antiguas se leen y se convierten, sin eliminar el archivo viejo; cuando el jugador guarda, ambos formatos quedan sincronizados para compatibilidad.
3. `scripts/player/third_person_operator.gd` aplica realmente el multiplicador de la mira correspondiente a los gestos del área derecha y disparo-con-arrastre. Conserva la cámara panorámica actual, la corrección anti-paredes, el hombro y el ADS x8 de V75.9 en lugar de migrar de golpe a `SpringArm3D`.
4. `scripts/ui/aurora_frontend.gd` muestra cuatro nuevos deslizadores, junto a giro, ADS, efectos y ambiente. Los controles adicionales están en un `ScrollContainer` usable en móviles panorámicos.
5. El lobby permite elegir **30 / 45 / 60 FPS**. El valor se guarda en la sección `[graficos]` y se aplica realmente a `Engine.max_fps`. **Esto no cambia aún la resolución del render, sombras ni la compresión ETC2; estas opciones necesitan implementación y medición separadas.**
6. `scripts/qa/v7512_player_settings_qa.gd` prueba persistencia, recuperación desde backup, bloqueo de entradas inválidas, preset FPS y distinta respuesta real del apuntado 2x/8x. `v753_frontend_qa.gd` comprueba que el lobby aplica los valores a la escena de juego.
7. La exportación Android está aislada con identificador `com.thedemianff.lastzone.nativepreview7512`, versión `75.12.0-scope-settings`, arquitecturas ARM64, y workflows de QA/exportación V75.12.

## Verificación requerida antes de aprobar

- Regresiones CI: `tools/run_qa.sh`, incluida la prueba V75.11 de locomoción y la prueba de avión → salto → paracaídas → aterrizaje → 90 ticks.
- APK de depuración: exportación Android, firma, alineación, tests de código exportado, capturas móviles y artefacto.
- Prueba **física** Motorola Edge 60 Fusion: cámara panorámica, botón de disparo con arrastre, precisión por cada mira, obstáculos de cámara, 30/45/60 FPS medidos y caída desde el avión sin cierre.
- Sin modificar Unity V76, certificados originales, configuración Firebase ni rama protegida `v44-3-2-autosave-guest`.
- El sector actual sigue siendo BR offline 1 + 8 bots, no 50/100 jugadores online ni una Lila final. No se declaran funcionalidades inexistentes.

## Próximos incrementos

La refactorización opcional a yaw/pitch/`SpringArm3D` debe preservar pruebas de retracción de cámara, cambio de hombro, libertad de 360°, vuelo/paracaídas y el apuntado. Después: editor HUD, ajustes de accesibilidad/sonido y presets gráficos con costes medidos en Motorola.
