# THEDEMIANFF LAST ZONE — Godot V75.7: terreno, cámara y sonido

**Base verificada:** V75.6 commit `6185ec24f9f26bb33ba53e664108526b1b6d48fb`. **Trabajo:** `codex/v75-7-terrain-camera-audio-repair`.

## Fallos reproducidos desde capturas Motorola

1. Viviendas suspendidas en desniveles, sin unión con el suelo y enormes pendientes atravesando interiores.
2. Plaza de baldosas siguiendo montañas y formando una alfombra inclinada, sin calles caminables claras.
3. Cámara de tercera persona ocupada por paredes o por el propio avatar cuando la distancia se reduce.
4. HUD con FPS superpuestos a armas, munición y botón de lobby.
5. Partida prácticamente silenciosa, sin audio ligado a acciones.

## Cambios de código realmente integrados

- El terreno físico y visual en `island_terrain.gd` incorpora una terraza urbana a 7 metros de elevación, que se mezcla progresivamente con el relieve del resto del archipiélago mediante una transición suave de 45 metros. Esto sustituye soluciones de plataformas flotantes: todas las casas, jardineras y el adoquinado leen el mismo heightfield.
- Se conservan las viviendas transitables, puertas, techos físicos, coberturas y la IA. Un QA nuevo verifica la diferencia de altura entre el suelo real y las cuatro casas, además de comprobar que el terreno no interseca el volumen ocupado de sus interiores.
- El jugador oculta únicamente su avatar local cuando una pared obliga a retraer la cámara demasiado; el mundo y los enemigos permanecen visibles. Se mantienen la cámara libre, x2/x4 y la mira exclusiva AWM x8.
- El HUD ubica FPS fuera de las cifras de munición, minimapa y botón de lobby.
- Nuevo `aurora_audio.gd`: **11 cues de PCM originales** calculados una vez en carga y reutilizados por un pool de 8 voces, buses separados AuroraSFX/AuroraAmbience y mezclador de efectos/ambiente configurable en el lobby. Los eventos están conectados a disparos AR/AWM, impactos, daño recibido, recarga, curación, pasos y saltos. Se conserva un ambiente de viento en bucle.
- La primera biblioteca auditiva está sintetizada con capas filtradas de transitorios, ruido, frecuencias graves y envolventes, **no es una colección comercial masterizada**. Para una producción definitiva necesitamos sustituir/mejorar estas grabaciones con foley profesional original o CC0 verificado y diseñar espacialización por materiales y distancias.

## Validación

- `v757_world_audio_qa.gd`: comprobar once recursos WAV, voces de audio, señales realmente emitidas por el combate y jugador, altura urbanizada, edificios apoyados y ausencia de penetración de suelo.
- Se mantiene la totalidad de QA anteriores, incluida la prueba física de caminar por cada puerta.
- Generar capturas reales de Godot desde vista aérea y a nivel de calle; verificar exportación ARM64, firma de depuración, alineación 16 KiB, SHA-256 y suites sobre recursos exportados.
- Probar en Motorola Edge 60 Fusion la transición del terreno, interiores, cámara, controles táctiles simultáneos y niveles del sonido. Medir FPS y latencia real; CI no acredita rendimiento físico.

## Límites

Esta entrega es una corrección profunda de un **sector de juego offline con 1 jugador y 8 bots**, no un Battle Royale comercial final: mapa 8×8 km, 100 jugadores online, social, Lila definitiva, 4v4 y tienda real siguen siendo desarrollo pendiente. La identidad final de las dos ilustraciones seleccionadas es una meta, no un activo jugable implementado.

Firebase, certificados, Unity y rama estable `v44-3-2-autosave-guest` permanecen sin cambios. La nueva APK usa el identificador independiente `com.thedemianff.lastzone.nativepreview757` para no sobreescribir partidas de prueba anteriores.
