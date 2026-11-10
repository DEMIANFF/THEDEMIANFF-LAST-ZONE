# V75.16 — aislamiento de cierre Android en los primeros ciclos del avión

## Evidencia de dispositivo real

Motorola Edge 60 Fusion. La V75.15 pasó QA Godot/ARM64 en GitHub, pero volvió a cerrarse según el usuario. Registro aportado:

- `state=active`, `phase=aircraft`, `note=flight_tick`, `last_transition=start`
- `position=(0,97,76)` (posición inicial exacta del avión), `velocity=(0,0,0)`
- `FPS=60`, `Performance.MEMORY_STATIC=63.6 MB`, `render_backend=gl_compatibility`
- `timestamp=1794328106` (reloj de Android)

En el código original, `flight_tick` se escribía **al principio del primer `_physics_process`**, antes de actualizar la posición del avión. Por ello la salida no prueba que el cierre ocurriera durante la transición al paracaídas. `last_transition=start` significa que **no se registró ninguna solicitud de salto ni la nueva secuencia diferida**. La cifra 63,6 MB es memoria estática del motor, no memoria total del proceso Android ni VRAM. Los 60 FPS del primer tick no excluyen bloqueos posteriores.

## Cambios de código en V75.16

- `sector_director.gd`: al comenzar una partida aérea se desactiva **el procesamiento completo de `CombatRange` (y su renderizado)**. Los bots no aparecen en pantalla ni siguen procesando animaciones y el modelo de armas no se renderiza durante el avión. Se suspende temporalmente el cálculo de rutas `AuroraNavigation` y sus `intersect_shape`, `cast_motion` y raycasts. **Tras aterrizar** se restaura el modo de procesamiento y visualización de combate, se reanuda el cálculo de rutas cuando estaba activo y se inicia la batalla de ocho bots. No elimina ninguno de estos componentes.
- `airdrop_sequence.gd`: elimina el ambiguo checkpoint inicial `flight_tick` emitido antes de mover el avión. Marca `first_player_motion` después de la primera transformación del personaje, luego `first_aircraft_frame_committed` tras mover el avión. Continúa anotando ticks a intervalos de 0,35 s los primeros 2 segundos y de 1 s posteriormente; el paracaídas y caída registran tick cada 1 s.
- `flight_diagnostics.gd`: impide que los ticks periódicos sobreescriban el campo de **última transición significativa**, y añade el tiempo monótono del motor en milisegundos.
- `v7516_aircraft_startup_qa.gd`: nueva prueba de la **escena real** que exige primer fotograma, avance efectivo, navegación terrestre y combate suspendidos, transición a caída y paracaídas, y restauración íntegra del combate (nueve participantes) después del aterrizaje.
- V75.16 utiliza APK/nombre/namespace independiente. Conserva ajustes de cámara, HUD y código de V75.15.

## Criterios de aceptación

1. CI Godot y exportación ARM64 deben ser verdes, incluyendo QA ejecutada desde el PCK exportado.
2. Usuario instala la APK **V75.16** y prueba avión/salto/caída/paracaídas/aterrizaje en el Motorola; al menos tres repeticiones.
3. Si vuelve a cerrarse, reiniciar la **misma V75.16** y copiar `COPIAR DATOS DEL VUELO`; `Detalle`, `Última transición` y `Tiempo motor` permitirán distinguir primer frame, siguientes frames y salto.
4. Para causa nativa: obtener el log del sistema **`logcat -b crash`** o bugreport del mismo fallo. Un checkpoint de GDScript no indica una excepción de driver ni prueba OOM.

**Estado actual:** trabajo candidato en PR draft. No decir "crash resuelto" hasta prueba física. No modificar la estable `v44-3-2-autosave-guest`, certificados originales, Unity V76 ni Firebase. Este juego Godot sigue siendo un BR offline, no un multijugador de 50–100 personas.
