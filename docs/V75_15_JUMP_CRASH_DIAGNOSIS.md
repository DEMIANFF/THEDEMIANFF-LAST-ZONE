# THEDEMIANFF LAST ZONE — V75.15: diagnosticar cierre durante avión/salto

## Evidencia enviada por usuario (10 de noviembre de 2026)

El jugador aportó el siguiente extracto persistente de V75.14:

```text
Estado: active
Fase: aircraft
Detalle: flight_tick
Tiempo Unix: 1794310573
FPS: 45
Memoria proceso (MB): 63.6
Posición juego: (0.0, 97.0, 76.0)
Velocidad: (0.0, 0.0, 0.0)
```

Marca temporal local Colombia: **06:36:13**. Coincide con el **inicio de la ruta del avión**, registrado al principio del primer tick de física. **NO prueba que la app haya terminado mientras permanecía en el avión**: en V75.14 el checkpoint `freefall` se escribía solo DESPUÉS de liberar el avión, actualizar `CharacterBody3D` y actualizar el HUD. Si fallaba cualquiera de esas operaciones, el último registro continuaba mostrando `aircraft`. El monitor `Performance.MEMORY_STATIC` no es la memoria física ni VRAM total del proceso Android. Los 45 FPS corresponden únicamente al checkpoint.

El vídeo `149768.mp4` previamente entregado muestra salida al launcher durante caída libre; esto y el registro de avión son compatibles con una falla en o poco después de la transición al salto. **Sin `logcat -b crash` o tombstone nativo no se puede distinguir de manera concluyente señal SIGSEGV, renderizador GLES, OOM del sistema, ANR o un fallo de otra clase.**

## Reparación/reducción de riesgo en código (candidato, sin afirmar resuelto)

- `scripts/match/airdrop_sequence.gd` ya NO ejecuta `player.begin_freefall()`, liberación de avión ni `hud.set_air_stage()` dentro del mismo `_physics_process`. Al recibir la solicitud se registra inmediatamente `jump_requested`; al entrar a la transición se marca `jump_pending`, se detiene la física de la secuencia y se programa la liberación mediante `call_deferred`.
- En la pasada diferida se marca `craft_release_started`, se oculta y programa liberar el avión con `queue_free()`, y se deja pasar un frame para que el renderizador libere la malla. En el siguiente `process_frame`, el personaje entra en caída libre, se actualiza la interfaz y se reanuda la secuencia, conservando `jump_committed`. Las etapas son idempotentes ante doble clic.
- Cada operación clave escribe un checkpoint **ANTES** y **DESPUÉS** de los cambios 3D. Si el cierre ocurre otra vez, el campo `Detalle` identifica la operación inmediatamente anterior; `Última transición` persiste incluso cuando los ticks periódicos vuelven a cambiar el detalle a `flight_tick`.
- `scripts/match/flight_diagnostics.gd` incluye la versión de la app y el backend gráfico, y aclara que la memoria estática del motor no es la memoria total del teléfono.
- `scripts/qa/v7515_jump_transition_qa.gd` prueba la transición física diferida, rechazo de salto duplicado, liberación real del avión, huellas persistentes, renderizador y supervivencia de caída libre. `launch_airdrop_qa.gd` y `v7514_freefall_crash_qa.gd` se adaptan para comprobar la transición real de múltiples frames en vez de asumir que un salto debe ocurrir instantáneamente.

## Criterios de aceptación (prioridad absoluta)

1. Compilar y verificar **V75.15 ARM64** con identificador independiente `com.thedemianff.lastzone.nativepreview7515` y firma de depuración, QA de código y de recursos exportados.
2. En el Motorola Edge 60 Fusion: iniciar BR, pulsar `SALTAR DEL AVIÓN`, girar cámara, dejar caer al personaje durante al menos 10 segundos, abrir paracaídas, aterrizar; repetir 3 veces.
3. Si vuelve a cerrar, abrir exactamente la APK V75.15, pulsar `COPIAR DATOS DEL VUELO` y enviar el informe. Buscar `jump_requested`, `jump_pending`, `operator_freefall_before/after`, `hud_freefall_after`, `jump_committed`.
4. Si Android sigue terminando el proceso a pesar de logs correctos, obtener **bug report o logcat Android del mismo intento** y simbolicar la traza nativa con los símbolos de la misma plantilla Godot; el checkpoint GDScript no identifica la causa nativa.

## Protección de alcance

Se conservan cámara panorámica, terreno Puerto/Base Aurora, controles, modos y mecánicas de V75.14. No modificar rama estable `v44-3-2-autosave-guest`, Firebase, Unity V76 ni certificados originales. No afirmar ausencia de cierre en Motorola sin prueba física y log real. Este PR se mantiene en borrador mientras se valide.
