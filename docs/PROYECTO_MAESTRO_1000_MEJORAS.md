# THEDEMIAN: LAST ZONE — Proyecto maestro de 1.000 mejoras

> Documento de producción · 13 noviembre 2026 · Línea de trabajo **Godot / Vulkan Mobile / ARM64** · Este documento registra trabajo previsto, no lo declara implementado.

## Evidencia verificada y distancia al objetivo

- **Última base validada:** V75.59, GitHub Actions [run #43360975642](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/43360975642) = **SUCCESS**, PR [#60](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/pull/60).
- **APK:** una variante Android ARM64 Vulkan, versionCode 49, paquete `com.thedemianff.lastzone.nativepreview`, firma v2/v3 y alineación 16 KiB; SHA256 `404d072c22a9e2ecc11bf30e92cd4b415392e77343e229108a40269c5278d57c`. No pruebas físicas Motorola confirmadas para esta versión.
- **Captura genuina del lobby** incluida en [artefacto CI V75.59](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/43360975642/artifacts/14008852092), archivo `aurora-v75-19-lobby.png`. Proviene de Linux/OpenGL Compatibility con assets de Godot, **no del Motorola** ni de arte conceptual.
- **Lila:** cuerpo/rostro/cabello CC0 provisional; 19 elementos originales del kit táctico Aurora skinning sobre el rig, usando exactamente el mismo GLB en lobby y partida. Enemigos no llevan uniforme de Lila. El rostro/hair/ropa final propios NO existen aún.
- **Battle Royale local:** avión→caída→paracaídas→botín→combate→zona→fin; modalidades 1 jugador + 8/19/29 IA físicas, NO multijugador humano real.
- **Puerto Aurora:** ocho casas costeras con interiores amueblados; armas AR-7 y AWM, botín físico, cámaras y QA de movimiento. La apariencia, calidad ambiental y cantidad de contenidos siguen lejos de una producción comercial.
- **Autenticación y economía:** hay persistencia local; Firebase/Google de las etapas anteriores no se confunden con identidad online Godot completamente conectada. Tienda/pase/social no son aún servicios completos.

## Contrato del producto final

- Battle Royale 3D original, con solo, dúo y escuadra 4, objetivo inicial **50 jugadores humanos online**, posibilidad de 100 solo tras capacidad probada.
- Partidas objetivo de 9–11 minutos, sin mínimo artificial: cierre de zona de diez minutos y victoria anticipada válida.
- Cámara TPS 360, ADS y miras x2/x4/AWM x8; disparo arrastrable, HUD configurable, multitouch, movimiento y animación de cuerpo entero.
- Personajes originales: Lila terminada, personaje masculino y variantes; armas visibles en manos/espalda, agarres adecuados, acciones contextualizadas y efectos físicos.
- Mundo Puerto Aurora original: costa, puerto, residencias, interiores, industria, colinas, botín, coberturas, navegación y sonidos direccionales.
- Progresión y economía justa con guardado fiable; identidad y respaldo Google; clasificados, reanimación, misiones, logros, tienda y pase cuando exista infraestructura funcional.
- En línea: servidor dedicado autoritativo, snapshots, reconciliación, validación de disparos y botín, controles de latencia y seguridad; bots locales **no cuentan** como humanos.

## Arquitectura del programa: 20 áreas × 50 entregables = 1.000

Cada área contiene **10 sistemas**, con **cinco resultados evaluables** por sistema: 1) implementación real, 2) integración de partida/servicio, 3) interacción y presentación, 4) robustez y recuperación, y 5) optimización y QA.

| Nº | Área | Entregables |
|---:|---|---:|
| 01 | Lila y arte 3D | 50 |
| 02 | Animaciones y locomoción | 50 |
| 03 | Cámara y precisión | 50 |
| 04 | Arsenal y combate | 50 |
| 05 | Inventario y botín | 50 |
| 06 | IA individual | 50 |
| 07 | IA cooperativa y escala | 50 |
| 08 | Ciclo Battle Royale | 50 |
| 09 | Puerto Aurora y terreno | 50 |
| 10 | Casas e interiores | 50 |
| 11 | HUD y controles | 50 |
| 12 | Lobby y pantallas | 50 |
| 13 | Audio y efectos | 50 |
| 14 | Rendimiento Vulkan Android | 50 |
| 15 | Multijugador autoritativo | 50 |
| 16 | Modos y escuadras | 50 |
| 17 | Identidad y nube | 50 |
| 18 | Progresión y economía | 50 |
| 19 | Calidad, seguridad y medición | 50 |
| 20 | Publicación y operaciones | 50 |
| | **Total** | **1.000** |

El registro editable con tickets individuales `TLZ-0001..TLZ-1000`, prioridades, dependencias, estado, criterio y campos de evidencia se entrega al usuario como archivo independiente `THEDEMIAN_PLAN_1000_MEJORAS.xlsx`. No inventar commits para celdas todavía vacías.

## Etapas y puertas de calidad (sin plazos ficticios)

### A. Identidad visual jugable
- Lila: rostro/cabello originales, vestuario y mallas de calidad, UV/PBR, rig y deformación fina, animaciones e IK de armas; mismo personaje en lobby y partida.
- Cámara 360/ADS suave, HUD móvil ordenado, mundo costero más detallado e interiores verdaderamente transitables.
- **Gate:** capturas reales de lobby, partida, interiores, ADS; CI de animación/colisiones + perfil móvil. Concept art no satisface el gate.

### B. Battle Royale offline completo
- Secuencia completa, arsenal, botín, inventario, coberturas, IA enemiga con navegación y decisiones tácticas, zona y recompensas.
- 9/20/30 participantes locales = enemigos CharacterBody3D reales; no sustituirlos por clientes de red ficticios.
- **Gate:** partidas enteras repetibles con físicas, QA y botín consistente; sin cierres o errores graves reportados.

### C. Calidad Vulkan móvil
- LOD de personajes/mapa, culling, texturas, físicas/nav, audio, presupuesto de CPU/GPU, consumo energético y tolerancia a temperatura.
- **Gate:** medición física en Edge 60 Fusion cuando el usuario autorice; objetivo 60 FPS, comprobar p10/p50/p90, memoria, termal y crash logs. CI Linux no vale como prueba hardware.

### D. Multijugador humano
- Servidores autoritativos, tick/snapshots, predicción y reconciliación, validación de daño/inventario, matchmaking, squads, reconnect.
- **Gate:** 50 clientes conectados medidos, latencia aceptable, anti-cheat y backend. No afirmar online real antes.

### E. Producto publicable
- Google/guest/profile/cloud backup, misiones, progreso, recompensas, tienda/pase con reglas reales, clasificación, social, localización, derechos, privacidad y soporte.
- **Gate:** funcionalidad auditable, guardado tras reinstalación, licencias de arte y audio, distribución gradual y reversión segura.

## Primer lote vertical integrado (no 50 mini-versiones)

1. **Lila** original visual: reemplazar cabeza/cabello CC0 con assets 3D autorizados y originales, ropa/telas creíbles, IK/manos, materiales y clips jugables.
2. **Cámara y locomoción**: verificar 360°, ADS y miras, multitouch, carreras, agacharse, saltar, aterrizar, paracaídas y colisiones en puertas.
3. **Puerto Aurora**: sector de muestra terminado artísticamente con edificios habitables, cubiertas, luces, materiales, rutas de loot y cobertura.
4. **Combate/IA**: armas con sus propias animaciones, recargas, impactos, coberturas, enemies contra enemies, botín y zona.
5. **Lobby/HUD**: jerarquía visual comercial legible, personaje 3D, estado de partida claro, botones multitáctiles sin superposiciones.
6. **Evidencia**: capturas reales comparativas de lobby, TPS combate e interior, tests y APK Vulkan en CI; pruebas físicas de usuario solo cuando lo indique.

## Definición de terminado

Una tarea solo se marcará completada si:
1. Está implementada en un archivo/activo/servicio real, no un mockup.
2. Funciona integrada en el ciclo de BR, menú o servicio al que pertenece.
3. No rompe la rama estable, historial, Firebase o firma ni controles previos.
4. Tiene PR/commit, prueba automática y evidencia real (imagen del motor, logs, métricas, red o dispositivo según corresponda).
5. Las pruebas fallidas se corrigen; no se eliminan para obtener un CI verde.

### Protección de continuidad

Rama estable `v44-3-2-autosave-guest` intacta. Motor principal Godot; Unity etapa posterior explícita, no hacer migración ahora. Mantener **una sola APK Vulkan ARM64**, misma identidad y clave de firma preview. No prometer entrega de trabajo asíncrono ni pruebas manuales no realizadas.

**Estado al redactar:** 1.000 tickets planificados, **no 1.000 mejoras completas**. V75.59 verificada automáticamente, arte final y arquitectura online pendientes.
