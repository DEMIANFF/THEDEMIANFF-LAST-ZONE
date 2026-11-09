# THEDEMIANFF LAST ZONE — Plan de entrega profesional (base V74)
**Fecha:** 8 de noviembre de 2026. **Motor actual:** Godot 4.7.2 Android, render OpenGL Compatibility. **Ramas protegidas:** `v44-3-2-autosave-guest` y APK V70 firmada no se modifican. **Rama del trabajo armamento:** `codex/v74-1-weapons-ik-awm`.

## 0. Definición de éxito (lo que realmente significa "battle royale completo")
La definición de producto NO es "una APK que compila": es un juego estable en Motorola Edge 60 Fusion con pantalla de inicio y lobby, control TPS y ADS fluido, paracaídas, mundo 3D útil, combate, inventario, botín, zona que cierra, enemigos funcionales, partida completa con victoria y derrota, reintento y persistencia; después **multijugador real con servidor autoritativo, 100 jugadores y 8×8 km** sin sustituir la simulación offline por una etiqueta falsa. Un producto móvil estilizado de calidad es viable; un nivel idéntico a un AAA con fotorrealismo y 100 jugadores no se consigue automáticamente al activar Plus.

## 1. Lo que YA existe en el repositorio V74 (verificar siempre en CI y Motorola)
- Demo de sector Aurora 3D, 9 luchadores simulados (1 jugadora y 8 bots), física corregida, HUD táctil con joystick, correr, saltar, agacharse, cámaras de mirada libre, fuego con arrastre, AR x2/x4, sistema AWM de daño/cinco tiros/x8 y cerrojo de 0.5 s; botiquines, munición, zona, contador vivos, victoria/derrota/reinicio.
- Edificios modulados, hielo, vegetación limitada, paisajes todavía simples; falta navegación profesional, 8 POI reales y arte final Lila.
- El AK-74 se importó, pero el socket del esqueleto provisional hereda escala de FBX ~0.008; es necesario compensarla y comprobar que el arma se ve y apunta en la dirección correcta.
- La AWM era **lógica solamente**, desaparecía el rifle al cambiar de arma. V74.1 añade visual GLB y animación, sin afirmar equivalencia AAA.
- No existe servidor de 100 personas, Google/Firebase migrado al ejecutable Godot, avión jugable, 8×8 km ni personaje 3D final de las imágenes.

## 2. Etapas secuenciadas con criterios observables
| Etapa | Entregables concretos | Criterios de aprobación |
|---|---|---|
| **V74.1 — Armas y rig** | AK visible a escala correcta en mano, AWM GLB original, alternancia de modelos, ADS x2/x4/x8, cerrojo automático de 0,5 s, animaciones de manos/antebrazos y transiciones de estados. | CI importa ambas mallas y clips, comprueba tamaños del rifle en *metros globales*, vista de AWM al seleccionarla, disparo único por pulsación y no disparo automático con AWM, capturas AK/AWM; Motorola confirma ambas manos, cero arma flotante. |
| **V75 — Lila original** | Modelo original inspirado en referencias entregadas: cabello lavanda, ojos violeta, ropa futurista blanco/azul/negro, mochila, guantes, calzado, materiales PBR, LOD; esqueleto humanoide real y retarget, IK manos-pies. | Vistas frontal/lateral/espalda y escenas equipadas sin T-pose, clipping ni pies flotantes; caminar, correr, salto, caída, agacharse, apuntar y recarga ensayados física/visualmente. No reemplazar por mera ilustración. |
| **V76 — Puerto Aurora de calidad** | Sector jugable denso: interiores reales, edificios hechos con mallas, puertas y ventanas dimensionadas, caminos naturales, vegetación, mobiliario, colisiones, cobertura, audio y luz con presupuesto móvil. | Recorrer casas sin atravesar paredes ni estrechez, bots navegan puertas y cubiertas; mediciones de FPS, tiempos de carga y memoria en Motorola. |
| **V77 — Combate e IA** | Cobertura, escucha/visión, navegación NavigationAgent3D, reacciones a daño, ruta al botín, mejora de animación, variedad de AR/SMG/pistola/AWM, inventario, recarga e impacto, sistema de muerte y botín; zonas y daño consistentes. | Pruebas de escenario con bot vs bot y jugador, recarga/munición/daño/impacto sin falso HUD; 10 partidas de 10 min sin cuelgues; perfiles de rendimiento ADS. |
| **V78 — Flujo battle royale offline completo** | Pantalla inicio, lobby, selección modo, avión, trayectoria/marcador, salto, caída libre, paracaídas, aterrizaje, loot, zona, minimapa, derrota/victoria y vuelta al lobby. | Partida completa reproducible 10 veces, cámara operativa en avión/paracaídas y suelo, no HUD de combate donde no corresponda. |
| **V79 — Expansión del mundo** | Los ocho POI del archipiélago: Cráter Aurora, Bahía de Cristal, Bosque Lumínico, Complejo Helios, Glaciar Espejo, Valle de los Ecos, Puerto Vórtex y Santuario de Hielo; chunks, LOD, streaming y marcadores. | Mapa 8192×8192 solo cuando cada chunk/colisión/navegación funciona y memoria/tiempos de carga caben en móvil. |
| **V80 — Cuenta y persistencia** | Integración Auth Google/invitado, progreso y contenido de cuenta, reglas Firebase, ID numérico, respaldo/reinstalación. Migración de app sin pérdida. | Cambiar de móvil/reinstalar y recuperar inventario y progreso mediante pruebas físicas; revisión de permisos, transacciones y no duplicar ID. |
| **V81+ — Multijugador real** | Servidor autoritativo, sincronización de 20→40→100 jugadores, lobby/matchmaking, reconexión, seguridad, anti-cheat, métricas, cargas y coste de hosting. | Pruebas de carga y latencia en red real; servidores y cuentas; 100 jugadores demostrados, no bots contados como personas; tasas de pérdida y FPS publicadas. |
| **Salida de producción** | Firma permanente compatible, crash reporting, accesibilidad, controles configurables, UX/tienda/eventos/compatibilidad, políticas de privacidad, QA/Play Store. | APK release y Android App Bundle verificables, actualización sin borrar datos, ningún secreto en repositorio ni telemetría privada expuesta. |

**Sin plazos inventados.** Cada etapa se cierra por evidencia, no por nombre de versión. La complejidad de multijugador y arte final exige diseño/rigging/servidores/pruebas, que pueden ser proyectos de producción independientes.

## 3. Arquitectura objetivo
- **Cliente Godot**: escena y mundo divididos por chunks, estados de partida desacoplados, cámara TPS independiente de orientación corporal, ADS con sensibilidad por zoom; entradas multitáctiles poseídas por widgets reales.
- **Juego offline**: colisiones y terreno concavo verificables, NavigationAgent3D para bots con colisiones y puertas, combate por hitboxes o hitscan con trazadoras coherentes, AWM con semiautomático y cerrojo, recarga y armas con rigs y sockets.
- **Contenidos**: mallas originales y assets licenciados, texturas PBR comprimidas, LOD y atlas, sombra y luz móvil, tablas de presupuestos de materiales y draw calls.
- **Servicios**: Firebase Auth/Firestore solo para cuenta y respaldo inicialmente, con reglas owner-only y credenciales protegidas; servicio de identidad transaccional; gameplay de red **en servidor separado**, no confiar en Firestore para simulación 100 jugadores.
- **Datos seguros**: mantener V70 y rama protegida intactos, separar identificadores Android hasta que haya migración respaldada y ruta de firma comprobada.

## 4. Plan de pruebas y presupuesto
- **CI Godot**: importación GLB y formato, animaciones requeridas, pose/altura global de arma, física suelo, joystick, correr/saltar, cámara ADS, AWM 0.5 s, botín, daño, victoria/derrota y reintento; verificar cada commit y artifact con SHA-256, paquete y certificado.
- **Motorola**: registrar 10 min por modo, FPS mínimo/percentiles, latencia de entrada, calentamiento, uso memoria y cierres; objetivo inicial sostenido 30 FPS y ajustes de calidad, sin prometer 60 FPS.
- **Aceptación**: video del móvil con cámara detrás, correr/saltar, movimiento + mirar + disparar simultáneamente, AK/AWM visible y adherida al rig, zoom x2/x4/x8 preciso, enemigo golpeado y eliminación; tester confirma qué falla y segundo de video.
- **QA de cuentas**: guardado/reapertura/desinstalación con backups y restauración, sin tocar clave permanente/keystore.
- **Métricas**: tiempos de frame GPU/CPU, polígonos/draw calls, VRAM, latencia, APK tamaño, duración de carga, eventos de bloqueo, regresiones por versión.

## 5. Riesgos y decisiones
1. **Lila actual no es final**: rig CC0 temporal no cumple las imágenes lila/silueta/ropa. Avanzar animación provisional permite corregir física, pero producir un nuevo modelo original es la única vía para fidelidad visual.
2. El AK-74 importado en V73 es un asset ya presente en repositorio; **licencia comercial pendiente**. No distribuirlo públicamente sin verificar.
3. Captura Godot headless/render software no representa rendimiento Android, multitouch físico ni iluminación exacta del Motorola.
4. El mapa y 100 usuarios son metas finales; primero sector offline robusto, luego expansión y red.
5. Plus amplía capacidad de asistencia, **no crea assets profesionales, servidores, pruebas móviles ni infinitos recursos en forma automática**.

**Rama protegida**: jamás alterar `v44-3-2-autosave-guest` ni firmar por encima de la app V70. **Entrega de cada fase**: commit, PR, Actions real, APK debug verificada y checklist de prueba en Motorola.