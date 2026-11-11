# THEDEMIANFF LAST ZONE — Caja negra de vuelo (Godot)

## Propósito

Recuperar un informe mucho más informativo tras un cierre brusco de Android, especialmente en `aircraft → freefall → parachute → ground`. **No captura automáticamente la pila de excepciones nativas**: si Android mata el proceso por SIGSEGV, fallo GPU/driver u OOM, GDScript se interrumpe antes de poder registrar la causa. Los puntos guardados muestran *hasta dónde llegó el juego*.

## Datos incluidos

- Registro persistente de los últimos **48 eventos** (`user://aurora_flight_trace.cfg`), con número de evento, milisegundos del motor, número de fotograma de física y de proceso, fase, operación y contexto adicional.
- Modelo del dispositivo y plataforma (`OS.get_model_name()`, `OS.get_name()`), nombre de versión, renderer, FPS y memoria **estática del motor** (esta cifra **no** es la RAM total ni la memoria de la GPU).
- Posición y velocidad del personaje, fase interna, clip de animación actual y si está en el suelo.
- Distinción de apertura por altura automática, cambio de fase del jugador, activación de HUD, apertura de la malla, primer tick físico, cámara, `move_and_slide`, entrada/salida de `AnimationTree` y **primer fotograma renderizado con la malla visible** (solo con renderer activo; en `--headless` este marcador puede faltar normalmente).
- Hasta 48 transiciones conservadas a través de un cierre. Al iniciar otro vuelo, el informe anterior no completado se respalda como `user://aurora_previous_interrupted_flight.cfg` para no perder pruebas del crash anterior.

Se escriben los marcadores antes y después de operaciones críticas y se guarda el reporte en disco mediante `FileAccess.flush()`. Para evitar fallos de reentrada, la señal `RenderingServer.frame_post_draw` solo agenda el guardado mediante `call_deferred`. Este instrumentado tiene coste de escritura; está destinado a la **APK de diagnóstico**, no a la configuración final de producción.

## Acceso desde el teléfono

1. Instalar la APK de **Caja Negra** cuando esté validada y jugar BR.
2. Si se cierra, volver a abrir **esa misma APK**; en la bienvenida aparecerá el último vuelo sin terminar.
3. Pulsar **VER REGISTRO DETALLADO**, desplazar el texto y después **COPIAR INFORME COMPLETO**. Enviar el texto íntegro, sin cortar las últimas líneas.
4. Si ya iniciaste otra partida y se reemplazó el diagnóstico, usar **VER VUELO INTERRUMPIDO ANTERIOR**.
5. El selector **VUELO 0/1/2/3** sigue disponible para una prueba diferencial controlada:
   - 0 Normal, con malla y animación.
   - 1 Sin la animación específica `AuroraParachute`, con malla y física reales.
   - 2 Sin malla visible, con animación y física reales.
   - 3 Sin ambas capas visuales, **con física y aterrizaje reales**.

**No es necesario probar modos que no se acuerden de antemano.** Primero observar el registro de un único vuelo en modo 0. Los modos 1–3 son pruebas A/B temporales para descartar hipótesis gráficas y deben distinguirse en el informe.

## Cómo interpretar el último registro

- `canopy_auto_deferred_queued`: se detectó el umbral automático y se encoló la transición; no demuestra ejecución del callback.
- `canopy_deferred_commit_started`: se ejecutó el cambio de fase fuera de física.
- `canopy_hud_after`: terminó el cambio de controles.
- `canopy_visual_enabled`: se activó la visibilidad de la malla, **sin garantía de que la GPU la haya renderizado**.
- `operator_after_camera`: terminó el ajuste de cámara.
- `operator_before_move_and_slide` / `operator_after_move_and_slide`: permiten distinguir si la física retornó de `move_and_slide()`.
- `operator_before_canopy_animation` / `operator_after_canopy_animation`: delimitan el pedido de animación, **no certifican que el driver GPU procesó el skinning**.
- `canopy_first_frame_rendered`: señal de que RenderingServer completó un fotograma con la malla habilitada y el informe pudo persistirse. La ausencia del evento **no demuestra por sí sola un fallo GPU**.
- `first_parachute_physics_tick`: confirma que corrió el director de descenso por lo menos una vez.

**Regla central:** el último marcador es un límite temporal, **no el nombre de la función culpable**. Un cierre puede venir de Android, el driver o el propio motor.

## Si continúa el cierre

Enviar un informe de errores del Motorola tomado justo después del cierre, **tras revisar/redactar datos privados**. Buscar `FATAL EXCEPTION`, `Fatal signal`, `SIGSEGV`, `SIGABRT`, `libgodot_android.so`, `ActivityManager` y `lowmemorykiller`; un `logcat -b crash -d` por ADB autorizado también sirve. La app no posee permisos para leer los registros privados de todo Android y no debe intentar eludir esa restricción.

## QA y criterios

`native-godot/scripts/qa/flight_blackbox_qa.gd` prueba en Godot real:
- retención máxima de 48 eventos;
- secuenciación, contadores de Engine y contexto;
- copia de vuelo activo previo antes del inicio de otro;
- reporte legible en pantalla y estado `completed` al aterrizar.

Se ejecuta en la batería completa y además como **QA rápida independiente de Blender** en GitHub. Las pruebas de render con Mesa en Linux complementan pero **no sustituyen una ejecución en Motorola**.

Se preservan `v44-3-2-autosave-guest`, Unity V76, Firebase y certificados de firma originales; el identificador Android de la vista previa de diagnóstico es independiente.
