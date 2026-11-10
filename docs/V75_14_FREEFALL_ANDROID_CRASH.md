# THEDEMIANFF LAST ZONE — V75.14: cierre Android durante caída libre

**Evidencia:** vídeo `149768.mp4` enviado por el jugador: abre el BR, se visualiza el avión, pulsa **SALTAR DEL AVIÓN**, el personaje permanece en **CAÍDA LIBRE** sobre Puerto Aurora, el FPS fluctúa y la aplicación vuelve a la pantalla de inicio del Motorola **antes de desplegar el paracaídas y antes del aterrizaje**. El vídeo **no contiene logcat ni traza nativa**, por lo que todavía no se puede afirmar la causa exacta del proceso Android terminado.

**Base verificada:** V75.13 `58ce412a7630ac8ccaa22d4ec5c202cbc7d54ccc`; GitHub Actions QA `42744318064` / exportación ARM64 `42744318139` verdes. Su éxito automatizado NO equivale a estabilidad en teléfono.

## Intervenciones reales sobre el código

1. `scripts/player/third_person_operator.gd`: en avión y **caída libre** la cámara deja de ejecutar `PhysicsServer3D.cast_motion` de esfera cada ciclo. Conserva movimiento panorámico y suavizado 360°; el modo paracaídas mantiene anticolisión en cercanía a edificios/suelo.
2. `scripts/match/airdrop_sequence.gd`: a altura superior a 39 m respecto de terreno ya no se crea y ejecuta un raycast de **200 m cada frame**. Cerca del paracaídas, los rayos de 55 m hacia suelo/techos se ejecutan como máximo cada **0,15 s**; el umbral original de despliegue a 26 m se conserva.
3. `scripts/ui/aurora_frontend.gd`: al iniciar una partida se libera el `SubViewport` de 440×600, su segundo mundo 3D, luces y un segundo modelo animado. Espera un frame para liberar esos recursos antes de crear la escena del juego. El preview se reconstruye al regresar al lobby. Esto evita mantener render targets duplicados durante el vuelo.
4. `scripts/match/flight_diagnostics.gd`: escribe un pequeño registro `user://aurora_flight_trace.cfg` al despegar, saltar, abrir paracaídas y aterrizar, más un punto de control cada 1,2 s. Guarda última fase, FPS, memoria estática estimada del motor, posición y velocidad. Si el proceso Android termina sin avisar, el último estado `active` persiste. Si el jugador vuelve al lobby voluntariamente, queda `aborted`; al aterrizar, `completed`.
5. En la **pantalla inicial** aparece **VUELO ANTERIOR INTERRUMPIDO** si la sesión anterior terminó sin registrar finalización. El botón **COPIAR DATOS DEL VUELO** copia el informe al portapapeles para enviarlo sin root ni cable. Estos datos NO sustituyen una traza de `logcat`.
6. `scripts/qa/v7514_freefall_crash_qa.gd`: test nativo que inicia la escena real, salta, mantiene 210 ciclos de física en caída, simula arrastre de cámara, revisa posiciones finitas, checkpoint persistente, despliegue de paracaídas, aterrizaje y transición real al combate. `v753_frontend_qa.gd` verifica que el segundo viewport se libera durante la partida y vuelve al lobby sin perder la presentación.

## Qué NO está probado

- No hay `logcat`, tombstone ni Android Studio conectado al Motorola Edge 60 Fusion. Es posible que el cierre sea `SIGSEGV`, `SIGABRT`, fallo Vulkan/OpenGL, OOM del sistema, ANR o un bug propio; solo el análisis de registros nativos y el test físico permite distinguirlos.
- **No llamar "solucionado"** al cierre hasta completar una partida en el Motorola y repetir salto, descenso y aterrizaje varias veces sin salida al launcher.
- Godot continúa offline: 1 jugador + 8 bots. No se modifican cuentas Firebase, Unity V76, certificados de firma originales ni rama estable `v44-3-2-autosave-guest`.

## Test de aceptación de usuario (motorola)

1. Instalar APK **V75.14** con identificador separado `com.thedemianff.lastzone.nativepreview7514` (sin desinstalar APK estable).
2. Abrir BR, saltar del avión, mover joysticks, girar cámara, abrir paracaídas, aterrizar, combatir.
3. Repetir por lo menos 3 partidas y comprobar que el teléfono no devuelve al launcher.
4. Si el cierre reaparece, volver a abrir **la misma APK**. En bienvenida, tocar **COPIAR DATOS DEL VUELO** y pegar el informe. Para determinar causa nativa, complementar con Android `adb logcat -b crash` / `logcat -d` cuando sea posible.
5. Validar el preview 3D del lobby tras entrar/salir de entrenamiento, sin duplicar escenas ni perder el progreso local.

**Estado:** trabajo candidato; requiere verde CI/exportación y prueba física. No es un despliegue estable.
