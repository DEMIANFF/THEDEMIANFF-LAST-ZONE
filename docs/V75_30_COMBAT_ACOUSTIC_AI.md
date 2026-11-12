# V75.30 — Reacción acústica real de IA durante combate

## Base comprobada
Continúa desde `codex/v75-29-zone-bot-sync-house-qa` (PR #42), sin descartar las seis casas, botín, zona, animaciones, controles y editor HUD de versiones previas. V75.29 CI #43214371496 tuvo resultado `success`; requiere todavía prueba física en Motorola.

## Cambios de juego
1. **Disparos audibles en 3D**: cada disparo efectivo del jugador (AR o AWM) avisa a enemigos vivos cercanos a la posición real de la boca de fuego. El sonido de disparos IA se distribuye con la señal `weapon_fired` que ya emite el bot.
2. **Percepción acotada**: máximo 42 metros del emisor, sin detección desde distancias ilimitadas. La señal solo activa investigación y ruta hacia la última fuente acústica. No proporciona un objetivo visible ni omite las pruebas existentes de línea de visión previas a disparar.
3. **Combate con prioridad**: el bot no abandona a un enemigo que ya tiene a la vista para ir tras un sonido no confirmado. No reacciona a sus propios disparos ni después de caer. Este comportamiento se activa solamente durante Battle Royale; el entrenamiento conserva su compatibilidad previa.
4. **Búsqueda y navegación**: al percibir una detonación nueva, se invalida su ruta A* anterior para investigar el punto de origen y se adelanta un nuevo chequeo de percepción. Se usan los sistemas de navegación existentes, sin añadir barridos masivos en cada frame.
5. **Reinicio limpio**: reiniciar BR borra la memoria acústica del combate previo para evitar rutas fantasma.

## Pruebas
`v7530_combat_sound_awareness_qa.gd` verifica propagación de señales reales entre enemigos, proximidad, exclusión de emisor/eliminados, prioridad visual, desactivación fuera de BR, disparo real de jugador y reinicio. Se añade a la batería fuente y bytecode exportado.

## APK
Android `com.thedemianff.lastzone.nativepreview`, ARM64, `versionCode=32`. El workflow sigue validando la firma de preview fijada desde V75.27. No se modifica Firebase, Unity ni certificados de producción.

## Pendiente y alcance
El pase de CI **no sustituye** la prueba táctil y rendimiento en Motorola Edge 60 Fusion. Sigue siendo BR offline 1 jugador + 8 bots; multijugador con servidor, 50 usuarios y antitrampas permanecen pendientes.
