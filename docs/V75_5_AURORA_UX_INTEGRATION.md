# Godot V75.5 — integración del lobby Aurora y HUD de combate

## Origen y alcance

Base **Godot V75.4**, commit `93b1d5b396d9fb8dbd103d8cdc5c3248eff29ba3`. La rama de trabajo es `codex/v75-5-aurora-lobby-combat-ui`. Se combinaron las preferencias estéticas aportadas por el usuario en **dos conceptos**: ciudad costera con personaje central y panel lateral de navegación, y combate TPS panorámico con HUD de minimapa, salud, armas y botones táctiles.

**No se incorporaron logotipos de terceros ni imágenes de Nexora o Free Fire.** El fondo costero original se genera con dibujo 2D de bajo coste; el personaje central es el GLB 3D existente, todavía provisional.

## Integración real

- **Lobby**: fondo Aurora original de capas glaciares, costa y edificios; personaje 3D en el centro; panel lateral de nueve secciones; derecha con los **dos modos existentes** y botones que realmente lanzan entrenamiento y Battle Royale.
- **Progresión**: barra superior de **partidas/victorias leídas del registro local real**; estadísticas, mejor puntuación e historial de misiones desde `offline_match_records.gd`. Las secciones EVENTOS, PASE, TIENDA, SOCIAL y CUENTA indican su estado pendiente/offline, sin monedas, amigos o servidores inventados.
- **Ajustes**: conservar y acceder a sensibilidad de giro y ADS, guardada y recuperable. Tamaño de sus filas reducido para no recortarse en 1024×768.
- **HUD**: brújula con rumbo calculado del yaw real del jugador, radar físico existente, salud visible en la parte inferior, armas y munición a la derecha, controles interactivos existentes mantenidos. El punto de mira x2/x4/x8 y la pantalla sin punto de mira en aeronave siguen conectados al sistema real de apuntado, no a decoraciones.
- **Android**: paquete de depuración independiente `com.thedemianff.lastzone.nativepreview755`, ARM64 y número de versión 5; no modifica ni migra cuentas o registros de versiones anteriores.
- **Regresión**: nueva suite `v755_lobby_combat_qa.gd` revisa botones, secciones, anchuras 1024/1280/2712, brújula real, ocultación del punto de mira en avión y AWM x8. Se añaden a las suites existentes y se ejecutan también contra recursos exportados.

## Lo que **no** incluye esta fase

No constituye mapa 8×8 km, 100 jugadores, modo Duelo de Escuadras 4v4, multijugador, Lila definitiva, tienda funcional o conexión Google/Firebase. Son objetivos posteriores, no elementos que puedan declararse listos por existir en una ilustración conceptual.

## Criterios de aceptación

1. Comprobar las suites de escritorio y de recursos Android en los workflows de la rama. Una ejecución roja **no equivale a APK validada**.
2. Comprobar resolución 2712×1220 sin franjas negras y UI dentro de la zona visible.
3. Instalar APK firmada de prueba únicamente después de aprobar build, alineación de 16 KiB y hash SHA-256.
4. En Motorola Edge 60 Fusion validar que los nueve botones de menú cambien de sección, que ambos modos inicien, cámara y controles simultáneos, aterrizaje y victoria/derrota y que los resultados queden guardados localmente.

## Próximo trabajo real

- Rig y animaciones definitivas de Lila / operador masculino.
- Ciudad Puerto Aurora con modelos 3D detallados y colisiones transitables.
- Duelo de Escuadras 4v4 real como modo local antes de considerar online.
- Expansión de mapa, optimización y sistema multijugador autoritativo separado del prototipo offline.
