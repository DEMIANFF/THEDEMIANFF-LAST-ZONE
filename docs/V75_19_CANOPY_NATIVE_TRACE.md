# V75.19 — preconstrucción del paracaídas y registro de cierre nativo Android

## Evidencia de hardware V75.18

El Motorola Edge 60 Fusion volvió a salir de la aplicación durante el despliegue del paracaídas:

```text
state=active
phase=parachute
note=canopy_deployed
last_transition=canopy_deployed
version=Aurora V75.18 Paracaídas Seguro Motorola
timestamp=1794355058
uptime_ms=16937
fps=48
memory_static_mb=63.9 (NO RAM de Android)
position=(0, 32.9407, 52.30001)
velocity=(0,-26,0)
```

El último checkpoint se guarda **después** del cambio de fase y de actualizar HUD, pero **antes** del primer checkpoint de `_physics_process` del director. No prueba si el cierre ocurre en el renderizador Android, en el callback diferido del toldo o durante `CharacterBody3D.move_and_slide()` / `AnimationPlayer` del actor, que puede ejecutarse antes del director.

### Cambio de V75.19

- Precrear durante `third_person_operator._ready()` la malla de toldo y cuatro cuerdas originales; se ocultan hasta el salto. La transición de paracaídas ya **no crea ninguna geometría ni material** en vuelo: únicamente activa la visibilidad desde el callback diferido. No se retira el paracaídas visual ni la física.
- Añadir checkpoints `canopy_visual_before` / `canopy_visual_enabled` justo alrededor del cambio visual.
- Dentro del primer callback **físico del jugador**, antes de que el director actualice su propio checkpoint, registrar `operator_first_tick_enter`, `operator_before_move_and_slide`, `operator_after_move_and_slide`, `operator_before_canopy_animation` y `operator_after_canopy_animation` cuando corresponda.
- Conservar las **últimas 12 transiciones significativas en el archivo diagnóstico de Godot**, para diferenciar el último registro útil de todas las fases previas incluso después de un cierre brusco. No supone una pila de error nativo.
- Regresión `v7519_canopy_preload_qa.gd`: exige identidad estable del toldo antes/durante/después del vuelo, modo físico verdadero, conservación de colisiones, marcadores de callback, descenso desacelerado y retorno a batalla local con 9 participantes. También se adapta la regresión V75.18 al orden de los dos callbacks físicos.

### Verificación y paso decisivo

1. GitHub CI Godot, firma y paquete exportado ARM64 deben superar pruebas antes de entregarlo.
2. En Motorola, probar salto / paracaídas / aterrizaje; si vuelve a cerrarse, copiar diagnóstico de **V75.19** con historial.
3. **Además**, recopilar informe nativo inmediatamente después del cierre: Android > Opciones de desarrollador > Crear informe de errores > Informe interactivo/completo > compartir ZIP. Android señala que contiene registros y trazas de error. Ese ZIP puede tener datos privados del dispositivo y otras apps; revisar/redactar antes de compartir o extraer solo líneas relevantes a `com.thedemianff.lastzone.nativepreview7519`, `SIGSEGV`, `AndroidRuntime`, `libgodot`, `FATAL EXCEPTION` o `Fatal signal`. Si existe ADB autorizado, guardar `adb logcat -b crash -d`.
4. Sin pila nativa, **no** atribuir causa concluyente ni afirmar que se resolvió.

Base V75.18, PR draft, rama estable `v44-3-2-autosave-guest`, Unity V76, Firebase y certificados originales protegidos. La vista previa Godot es un BR offline sectorial de 9 participantes; no sincroniza cuentas.
