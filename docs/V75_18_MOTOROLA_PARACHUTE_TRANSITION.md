# V75.18 — A/B del cierre al abrir paracaídas en Motorola

## Evidencia física V75.17

```text
Estado: active
Fase: parachute
Detalle: canopy_deployed
Última transición: canopy_deployed
Versión: THEDEMIANFF LAST ZONE | Aurora V75.17 Caída Libre Protegida Motorola
Render: gl_compatibility
Tiempo Unix: 1794337483
Tiempo motor (ms): 9641
FPS: 37
Memoria estática del motor: 64.0 MB (NO memoria total del proceso)
Posición: (0.0,32.9407,59.60513)
Velocidad: (0.0,-26.0,0.0)
```

La prueba real avanzó más que V75.16: la secuencia ya había activado el modo paracaídas. El checkpoint `canopy_deployed` se escribe inmediatamente después de `player.deploy_parachute()`, `hud.set_air_stage()` y `hud.impact()`, antes de procesar el primer frame de física de paracaídas. Por ello la velocidad -26 m/s es esperable y no indica un paracaídas físicamente inoperante.

### Dos operaciones sospechosas del mismo cambio de fase

- `player.deploy_parachute()` creaba 1 malla de toldo + 4 mallas de cuerdas y materiales en la misma ruta de llamada del proceso de física.
- `_air_step()` reactivaba el `PhysicsShapeQueryParameters3D` / `direct_space_state.cast_motion` para colisiones de cámara **en cada frame del paracaídas**, aunque V75.14 las había desactivado durante la caída libre.

No existe `logcat` ni tombstone de Android; son hipótesis, **no causa demostrada**. Para aislar ambas operaciones en V75.18, la creación de mallas pasa a `call_deferred` y la cámara aérea conserva la suavidad sin `cast_motion`; las colisiones del personaje, del suelo y de edificios continúan en `move_and_slide()`. En tierra la cámara mantiene sus comprobaciones de obstáculos.

Se escriben checkpoints `canopy_transition_before`, `canopy_physics_mode_after`, `canopy_deployed`, `first_parachute_physics_tick` y `parachute_tick_N` para diferenciar un cierre en la transición, el primer tick o los siguientes. La nueva regresión V75.18 instancia la escena real, salta, coloca al operador en la misma posición y velocidad del reporte, abre el paracaídas, valida que desacelera y que aparece la malla, mueve la cámara, aterriza y restaura los 9 participantes offline.

**Aprobación:** CI Godot y Android/exported-bytecode verdes, seguida de 3 vuelos completos en Motorola. No declarar el cierre resuelto antes de la prueba física. Si vuelve a cerrarse, recoger el nuevo checkpoint y bugreport Android o logcat del mismo evento.

Protegidas: `v44-3-2-autosave-guest`, Unity V76, Firebase y certificados originales. APK con identificador independiente `com.thedemianff.lastzone.nativepreview7518`.
