# Auditoría dirigida: cierres de Android al abrir el paracaídas — 11 nov 2026

**Repositorio:** `DEMIANFF/THEDEMIANFF-LAST-ZONE`  
**Base revisada:** `codex/v75-19-prewarmed-canopy-native-trace`  
**Rama de corrección, sin APK nueva:** `codex/godot-canopy-physics-audit`  
**Dispositivo informado por usuario:** Motorola Edge 60 Fusion, Android, renderer `gl_compatibility`.

## Alcance de la revisión

Inspección de los **29 scripts GDScript de ejecución** de `native-godot/scripts/` (excluidas pruebas QA), aproximadamente **6 495 líneas**: `main.gd`; sector, avión, suelo, botín y zona; operador TPS, control de animaciones y cámara; HUD, lobby y controles táctiles; IA, navegación, combate y armas; mundo 3D, terreno, audio y persistencia. Además: escenas de inicio y mundo, `project.godot`, `export_presets.cfg`, generador Blender del personaje, rutinas QA V75.14–V75.19, flujo GitHub Actions y validación del paquete Android real. Esta es una auditoría de **código y rutas de ejecución**, no un análisis de memoria nativa del dispositivo ni una afirmación de que se ejecutaron todos los casos físicamente en Android. No se reauditan como parte del fallo las aplicaciones HTML/Three.js anteriores ni la futura rama Unity.

### Evidencia registrada

| Versión probada físicamente | Último checkpoint | Altura Y | Velocidad vertical | FPS previo |
|---|---|---:|---:|---:|
| V75.15 | `freefall / flight_tick`, `jump_committed` | 45.94073 | -26 | 30 |
| V75.16 | `freefall / freefall_tick_235`, `jump_committed` | 51.14075 | -26 | 57 |
| V75.17 | `parachute / canopy_deployed` | 32.9407 | -26 | 37 |
| V75.18 | `parachute / canopy_deployed` | 32.9407 | -26 | 48 |

El mismo Y=32.9407 en V75.17 y V75.18 es coherente con el umbral automático de **26 m sobre el terreno** en la trayectoria x=0, pero sin el registro completo del punto `terrain.height_at` y sin `logcat` no podemos certificar la correlación ni la causa nativa. **V75.19 está aprobada en CI, pero sin resultado físico aportado todavía.**

## Hallazgos ordenados por prioridad

### H1 — Defecto arquitectónico concreto (prioridad P0): transición automática dentro del callback de física

En la base V75.19, `airdrop_sequence._physics_process` llamaba **sin diferir** a `deploy_parachute()` cuando `clearance<26`. A su vez, ese método:
1. cambia `phase` a `parachute`;
2. llama a `player.deploy_parachute()` (cambio de modo y visual diferido);
3. llama inmediatamente a `hud.set_air_stage("parachute")`, que ejecuta `reset_controls()`, cambia visibilidades de controles y ejecuta `_layout()`;
4. escribe varios checkpoints persistentes con `FileAccess.flush()`.

En cambio, el salto avión→caída libre (`jump_from_aircraft`) y el aterrizaje→combate (`landed`) **ya difieren sus cambios de fase** precisamente para evitar mutar jerarquías y UI dentro de un paso de física. Esta asimetría es un riesgo verificable en el flujo de transición. **No prueba** que sea el origen del cierre Android.

**Corrección auditada:** el disparo **automático** por altura (incluido el fallback de separación no finita) pasa a `parachute_pending` y llama `_commit_parachute` mediante `call_deferred`. El HUD y el estado físico conservan `freefall` hasta salir del ciclo activo; el jugador abre el paracaídas real, conserva la malla 3D precargada, el descenso controlado y el aterrizaje original. El botón manual conserva la API anterior. Los checkpoints `canopy_auto_deferred_queued`, `canopy_deferred_commit_started` y `canopy_hud_after` distinguen la secuencia.

**Prueba añadida:** `scripts/qa/canopy_auto_handoff_qa.gd` reproduce el **umbral automático** llamando al callback real del director a 25.8 m de separación, y exige que HUD, física y visual sigan sin cambios durante la cola; después verifica el commit diferido, velocidad de paracaídas, malla precargada y combate sectorial con 1 operador + 8 bots. Se integra en `run_qa.sh`.

### H2 — Brecha importante en QA (P0)

- `v7518_canopy_transition_qa.gd` y `v7519_canopy_preload_qa.gd` llamaban **manualmente** `deploy_parachute()` desde la prueba; no reproducían el punto de entrada automático que vemos en el código.
- `v7517_terrain_freefall_qa.gd` sí atraviesa el umbral por la física, pero ejecuta la lógica **sin renderizado en un Linux headless**.
- La mayoría de QA de `run_qa.sh` se ejecutan con `godot --headless`. Las pruebas de recursos extraídos del APK, mediante `run_exported_qa.sh`, **vuelven a ejecutar la versión Linux de Godot** con el proyecto descomprimido; no ejecutan código de Godot en un emulador Android ni en un teléfono.
- Las capturas gráficas utilizan `xvfb-run` y OpenGL/Mesa en Linux; no reproducen la GPU/driver GL Compatibility ni el gestor de memoria de Android 16 del Motorola.

Un `PASS` de GitHub significa que el proyecto compila, los casos automatizados funcionan y el paquete es válido. **Nunca equivale a estabilidad física verificada.**

### H3 — Animación y controlador nativo de GPU (P1, causa no probada)

`third_person_operator._air_step()` cambia por primera vez a la animación esquelética `AuroraParachute` cuando entra en `air_mode="parachute"`. El controlador `operator_animation.gd` utiliza `AnimationTree` con callback de animación en física. El recurso GLB rigged se regenera con Blender por `tools/convert_operator.py` durante CI. Godot debe procesar y dibujar nuevas poses en el primer frame del paracaídas.

El código V75.18 había desactivado el cast de cámara en paracaídas; el cierre persistió. V75.19 precarga las mallas visibles del paracaídas, **pero precargar una malla oculta no garantiza que el primer render en el driver Android haya compilado todos los shaders**. Quedan como sospechas diferenciadas `AnimationTree.playback.travel`, skinning GPU y material del toldo. Se necesita logcat/tombstone o una prueba A/B que desactive un solo subsistema, no varios a la vez.

### H4 — Memoria y telemetría insuficiente (P1)

`Performance.MEMORY_STATIC` muestra memoria estática manejada por el motor; **no** representa RSS total del proceso ni memoria del driver/GPU. Los FPS de la traza son puntos previos, no la velocidad en el instante de terminación. `flight_diagnostics.checkpoint()` hace una escritura y `flush` síncronos por marcador. Esto podría introducir pausas en dispositivos lentos; **no hay evidencia** de que sea la causa de un cierre nativo. No existe actualmente `logcat -b crash`, señal POSIX, tombstone ni `OutOfMemory` del mismo evento.

### H5 — Riesgos aislados, no causales demostrados (P2)

- El mundo y la colisión del terreno, edificios y bots se instancian antes de subir al avión, aunque la física de bots y el procesamiento de navegación se suspenden durante el vuelo. Su coste GPU real en el Motorola no está medido.
- Se comprobó que la IA, el audio, el loot, los registros locales, el editor de controles y la zona no disparan la apertura del paracaídas; la ruta principal relevante es `Main → sector_director → airdrop_sequence → third_person_operator → HUD/AnimationTree`.
- La rama Godot actual es un sector **offline de 9 participantes**, no 50 o 100 jugadores reales en red. No hay Firebase conectado a esta vista previa.

## Límites y criterio de aceptación

Esta auditoría no contiene un backtrace nativo ni una reproducción física; por tanto la **causa real del cierre no está confirmada** y la corrección H1 es una **hipótesis técnica comprobable**, no una solución definitiva.

La próxima compilación destinada al usuario solo debe entregarse tras:
1. Pasar una QA que fuerce el disparo automático desde el camino de física y verifique la entrega de HUD y del personaje en diferido.
2. Ejecutar una prueba gráfica que cubra **el primer frame visible** del paracaídas y la animación real, no solo el suelo o el lobby.
3. Preferiblemente recopilar el informe del Android de un cierre: `FATAL EXCEPTION`, `Fatal signal`, `SIGSEGV`, `SIGABRT`, `libgodot_android.so` y/o registros `lowmemorykiller` / `ActivityManager`. El informe completo puede contener información sensible; se deben extraer únicamente líneas pertinentes antes de compartir.

**Preservación:** no modificar `v44-3-2-autosave-guest`, Firebase, certificados o Unity V76. No se ha generado otra APK por esta auditoría. El nuevo branch solo activa Godot QA, no el empaquetado Android.
