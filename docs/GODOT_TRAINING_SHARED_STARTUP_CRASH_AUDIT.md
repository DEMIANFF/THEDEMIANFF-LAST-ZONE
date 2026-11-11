# Auditoría complementaria — cierre inmediato de Entrenamiento y cierre en vuelo

## Nueva evidencia del usuario

El Motorola Edge 60 Fusion **también cierra la aplicación justo después de entrar en Entrenamiento**, sin avión ni paracaídas. Esto **invalida la suposición de que la transición del paracaídas es necesariamente la única causa**. Podrían existir varios errores distintos; no está probada una causa común.

En `aurora_frontend._launch(false)`, Entrenamiento y Battle Royale llaman a `_activate_game` y crean **la misma** escena `Main.tscn`. La diferencia es que BR activa además `begin_aircraft_phase()`; Entrenamiento queda en el suelo con navegación IA activa. En `Main._ready` se crean sin pausas intermedias el terreno, edificio base, barrio costero, vegetación, rig del jugador, HUD, audio, 4 bots animados, armas, navegación y controlador de sector. La versión Android del usuario no ha aportado aún la pila nativa `logcat`.

## Cambios instrumentados, sin presentar una solución no demostrada

- `main.gd`: persistir `main_ready_enter`, `terrain_build_begin/done`, `district_build_begin/done`, `coastal_build_begin/done`, `nature_build_done`, `operator_build_begin/done`, `hud_build_done`, `audio_build_done`, `combat_build_begin/done`, `navigation_ready`, `main_scene_ready`.
- `aurora_frontend.gd`: persistir antes de instanciar `Main`, antes de conectarla al árbol, inmediatamente después y después del **primer fotograma de mundo renderizado**. Indicar `training_entered` cuando es Entrenamiento, no etiquetar esos cierres como `parachute`.
- `aurora_navigation.gd`: registrar primer lote de consultas `intersect_ray`/`intersect_shape` antes/después. Estas llamadas requieren PhysicsServer3D y se ejecutan en entrenamiento, no en el avión de BR.
- `flight_diagnostics.gd`: conservar el perfil exacto de carga seleccionado junto a los 48 eventos, FPS, datos del dispositivo, posición, animación y tiempos. Garantizar rutas locales absolutas de archivo al renombrar los snapshots de forma atómica.
- `scene_startup_diagnostics.gd`: perfiles guardados en `user://`; el teléfono puede escoger **una sola APK** para distinguir presión gráfica y consultas de navegación, no una APK diferente por cada hipótesis.
- QA `shared_scene_startup_qa.gd` ejecuta los cinco perfiles de la escena real y abre Entrenamiento desde la interfaz real; comprueba que se conservan jugador, terreno, cuatro enemigos y colisiones.

## Cinco perfiles para identificar la fuente del cierre

| Perfil | Cambio temporal y reversible | Conserva |
|---|---|---|
| 0 | Mundo completo original | Todos los componentes |
| 1 | Sin el barrio costero decorativo ni vegetación | Terreno, distrito táctico, jugador, bots y colisiones |
| 2 | Sin las mallas esqueléticas de los 4 bots | Bots reales, colisiones, daño y física |
| 3 | Sin las dos capas visuales de 1 y 2 | Terreno y distrito táctico, jugador, bots físicos |
| 4 | Sin construcción del grafo de navegación IA (solo diagnóstico) | Bots, movimiento físico, mallas, colisiones y escenario |

Los perfiles 1–4 son **modos de prueba A/B**, no una reducción del diseño final del juego. Si cambia el resultado, habrá que corregir el componente aislado e integrarlo de nuevo.

### Método de prueba física después de validar la APK

1. Con el perfil **CARGA 0 / ESCENARIO COMPLETO**, entrar en **Entrenamiento**. Si se cierra, reabrir la misma aplicación y usar **VER REGISTRO DETALLADO** / **COPIAR INFORME COMPLETO**.
2. Si la traza acaba en `terrain_build_begin`, investigar malla y colisión del terreno; en `operator_build_begin`, investigar GLB/AnimationTree del personaje; en `combat_build_begin`, los bots/armas/rigs; en `navigation_first_batch_before`, las consultas físicas de navegación; y en `frontend_scene_enter_tree_after`, antes del siguiente marcador render, investigar primer fotograma/driver. **No afirmar causa por el último checkpoint solamente**.
3. Para contrastar hipótesis, probar uno de los perfiles 1–4 elegido según el último marcador. Cambiar modo en la bienvenida **antes** de abrir Entrenamiento.
4. Si el cierre persiste, aportar el `logcat` o informe de errores Android, revisando datos privados. Un GDScript no puede capturar un fallo nativo de motor/driver.

## Resultado de GitHub vs prueba de teléfono

CI Godot en Linux headless y render de escritorio no reproducen necesariamente la GPU/driver `gl_compatibility` del Motorola. Pasar las pruebas protege el flujo de juego y las colisiones pero no permite afirmar que el cierre físico esté resuelto.

**Protegidos:** `v44-3-2-autosave-guest`, Firebase, certificados originales, Unity V76. Mantener el mismo BR offline actual; no hacer pasar bots locales por 50 jugadores conectados.
