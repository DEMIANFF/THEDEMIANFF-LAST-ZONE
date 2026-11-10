# V75.17 — diagnóstico dirigido a cierre nativo durante caída libre en Motorola

## Evidencia real enviada por usuario (Godot V75.16)

```text
Estado: active
Fase: freefall
Detalle: freefall_tick_235
Última transición: jump_committed
Versión: THEDEMIANFF LAST ZONE | Aurora V75.16 Inicio de Vuelo Motorola
Render: gl_compatibility
Tiempo Unix: 1794336408
Tiempo motor (ms): 17262
FPS: 57
Memoria estática del motor: 63.9 MB (NO RAM/VRAM total)
Posición: (-5.024177,51.14075,43.35427)
Velocidad: (-6.144969,-26.0,-5.872764)
```

En el código V75.16 se consulta `terrain.height_at(x,z)` en cada tick de caída, y al bajar de 39 m sobre el terreno se ejecuta hasta cada 150 ms una nueva consulta `direct_space_state.intersect_ray` hacia abajo desde el actor, para detectar los techos antes de desplegar el paracaídas. La ruta original del ensayo CI de caída prolongada comenzaba a 215 m: **no verificaba específicamente el cruce del umbral de 39 m** con el movimiento real reportado.

La última posición indicada coincide aproximadamente con la región donde puede activarse esa consulta, pero el checkpoint periódico se escribía hasta 1 s antes de la salida del proceso, por lo que **no demuestra** que la consulta provocara el cierre.

**No asumir OOM ni error de driver**: FPS=57 es histórico del último checkpoint, y Performance.MEMORY_STATIC no incluye toda la RAM/VRAM de Android. Sin `logcat` del mismo evento no se dispone de diagnóstico causal de SIGSEGV/ANR/driver/sistema.

## Cambio controlado (A/B de una sola operación)

1. Eliminar exclusivamente la consulta `PhysicsRayQueryParameters3D.create(...)` / `direct_space_state.intersect_ray(...)` **dentro de `airdrop_sequence._physics_process` durante caída libre**. No eliminar la física de `CharacterBody3D.move_and_slide()`, los colliders del terreno, los edificios ni el sistema de choque de cámara durante paracaídas.
2. Mantener el despliegue automático del paracaídas al descender por debajo de **26 m sobre el terreno continuo que utiliza la propia malla de colisión**, preservando la física real del paracaídas y su control táctil.
3. Al cruzar por primera vez 42 m sobre terreno, escribir `terrain_approach_no_ray_<clearance>m` como checkpoint persistente y conservarlo como última transición incluso con ticks periódicos. Al solicitar despliegue automático se registra `auto_canopy_terrain_clearance_<clearance>m` antes de `canopy_deployed`.
4. Guardarraíl para separación no finita: diagnóstico `invalid_ground_clearance` y desplegar paracaídas, evitando propagar NaNs.
5. Prueba automatizada `v7517_terrain_freefall_qa.gd`: instanciar la **escena real**, saltar del avión, restaurar (x,z) y velocidad horizontal/vertical del reporte físico en 40 m sobre terreno real, atravesar umbral de 39 m con cámara táctil, confirmar checkpoint persistido, desplegar dosificando posición a 27 m y velocidad vertical −26 m/s y aterrizar en la batalla real de 1+8 bots. No se trata de un multijugador de 100 personas.

## Criterios

- QA Godot / Android ARM64 / QA desde bytecode exportado verdes en un único commit V75.17.
- APK debug instalada en Motorola Edge 60 Fusion con nombre **Aurora V75.17 Caída Libre Protegida Motorola**.
- Durante 3 pruebas: avión -> salto -> caída dirigida -> paracaídas -> aterrizaje. Si cierra, copiar diagnóstico de la **misma V75.17**. Cierre no resuelto hasta validación física.
- Si tras retirar ese rayo sigue fallando en la misma zona, dejar de proponer modificaciones ciegas y extraer informe de errores Android (Ajustes -> Opciones de desarrollador -> Crear informe de errores) del mismo intento, o `adb logcat -b crash -d` desde conexión ADB autorizada; en Android 16 Termux sin privilegios puede carecer de acceso a registros de otra app.

## Protecciones

PR draft a partir de V75.16; no modificar estable `v44-3-2-autosave-guest`, Unity V76, certificados de producción ni Firebase. Compilación de este prototipo BR offline no confirma rendimiento/estabilidad físicos sin prueba de Motorola.
