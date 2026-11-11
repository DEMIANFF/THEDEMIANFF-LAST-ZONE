# THEDEMIANFF LAST ZONE V75.20 — dos cierres de Android, dos ventanas de investigación

## Evidencia física recibida desde Motorola Edge 60 Fusion

**El usuario probó el mismo paquete con caja negra de 48 eventos y `gl_compatibility`:**

**Entrenamiento, perfil de carga 0 (completo), vuelo 0 (normal):**
- `#21 training_entered` después de `Main._ready` completo;
- `#22 shared_scene_first_frame_rendered`, la escena 3D **sí alcanzó** a dibujar al menos un fotograma;
- `#23 navigation_first_batch_before` con 374 muestras pendientes;
- `#24 navigation_first_batch_after` con 38 nodos; último evento guardado;
- 58 FPS al escribir la traza, 412 fotogramas físicos / 395 de proceso, 65.4 MB **solo memoria estática del motor**;
- ocurrió después del primer lote, pero no se puede saber si fue durante el segundo lote o una llamada de render/IA diferente. El último checkpoint no demuestra causa nativa.

**Battle Royale, perfiles 0/0:**
- se crea el mismo mundo y sale el primer fotograma del avión;
- `#33 operator_freefall_before`, `#34 operator_freefall_after`, `#35 hud_freefall_after`, `#36 freefall / jump_committed`;
- último checkpoint justo antes del primer ciclo de física/render posterior al salto; 27 FPS previos, posición (0,97,62.57436) y velocidad (0,-4,-11.84615);
- no se ha confirmado que falle el paracaídas en **este nuevo** intento; este cierre fue **antes** de su apertura.

## Mejoras V75.20 investigativas y de estabilidad

1. **Navegación:** `aurora_navigation.gd` espera 18 fotogramas físicos tras crear la escena y limita la construcción a 12 muestras por ciclo (antes 40). Mantiene las consultas reales, el terreno, las colisiones y el grafo A*. Registra `navigation_batch_before` y `navigation_batch_after` con índice, nodos y duración para **cada** lote, más la posición/estado de Lila en lugar de dejar estos campos vacíos.
2. **Caída libre:** `third_person_operator.gd` registra en el **primer** callback físico de caída libre, antes/después de cámara, `move_and_slide()` y `AnimationPlayer/AnimationTree`. Eventos `freefall_tick_* ` (no sobrescriben `last_transition=jump_committed`), más señal diferida al terminar primer fotograma visible de caída libre.
3. **Modos A/B específicos del BR:** `VUELO 4 / SIN ANIMACION CAIDA LIBRE` conserva modelo visible, física y usa pose reposo provisional en vez de `AuroraFreefall`; `VUELO 5 / SIN MALLA LILA EN CAIDA` conserva física/cámara/HUD, pero oculta temporalmente la malla esquelética **solo durante la caída libre**. La malla se restaura al abrir el paracaídas. Modos 0–3 originales siguen sin cambios. **No son funciones para la versión final**.
4. Los cinco perfiles `CARGA 0–4` siguen disponibles. `CARGA 4` desactiva **solo el grafo de navegación**, no las colisiones, bots ni disparos. Comprobar el cambio en Entrenamiento permite evaluar si esa ruta es un disparador. El informe ya refleja `CARGA 4`.
5. Regresiones nuevas `v7520_navigation_batch_qa.gd` y `v7520_freefall_first_tick_qa.gd` comprueban los caminos concretos, rendimiento acotado de navegación, eventos durables, física real y restauración del personaje.

### Pruebas físicas recomendadas

**Primera prueba con la APK actual que generó el usuario:**
- Entrar a bienvenida, cambiar `CARGA` de `0` a `4` y hacer **un Entrenamiento**. No hace falta una nueva versión para esto. Si entra y camina sin cierre, se acota el problema hacia el procesamiento de navegación. Si se cierra, el siguiente paso sería probar perfil 1/2/3 según última traza.
- Enviar resultado y reporte con el perfil 4 indicado. No mezclar modos entre pruebas.

**Después de aprobar y entregar V75.20:**
- En Entrenamiento, con `CARGA 0`, verificar lotes 12/24/... y guardar si cae.
- En Battle Royale, empezar `CARGA 0 / VUELO 0`, copiar primer registro nuevo; solo si se cierra, probar `VUELO 4` y después `VUELO 5` para aislar animación y render del actor de caída libre.

### Limitaciones fundamentales

Los registros GDScript **no recuperan SIGSEGV, SIGABRT, shader compilation fallida, memoria GPU ni low-memory-killer**. Solo acotan el último evento completado. Los ~64 MB registrados no representan la memoria total de Android. Con fallos repetidos de ambos modos, sigue siendo prioritario pedir **Android bugreport/logcat -b crash** inmediatamente después de reproducir el cierre, revisando datos privados antes de compartir.

No modificar rama estable `v44-3-2-autosave-guest`, certificados originales, Unity V76 ni Firebase. La rama Godot continúa siendo un sector offline con un jugador y ocho bots (Entrenamiento cuatro bots).
