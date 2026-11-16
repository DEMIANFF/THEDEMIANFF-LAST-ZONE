# THEDEMIAN: LAST ZONE — V75.113 · Reconstrucción de carga, acceso y lobby

## Propósito

La UI de V75.112 superaba CI, pero las capturas reales demostraron defectos de composición: cielo e iluminación demasiado planos, carga genérica con barra aislada, acceso sin presencia de marca, lobby con vacíos sociales, botones homogéneos y personaje rodeado de elementos que competían visualmente. Una prueba de integración verde no implica calidad artística terminada. V75.113 es una **reconstrucción incremental del frontend Godot real**, no un mockup ni una compilación Android publicada.

**Origen:** PR #117, `codex/v75-112-aurora-login-responsive-polish` HEAD `2bef2318d91158194982132920fa7d7756af3e27`. Motor Godot 4.7.2, Android ARM64 Mobile/Vulkan. Conservar `main`, `v44-3-2-autosave-guest`, firma, Firebase productivo, ID del paquete preview y guardados.

## Cambios de código

### 1. Escena 3D Base Aurora

- Sustituida la paleta de pista azul plana por acero, hielo y nieve de contraste más sobrio, con materiales PBR originales creados por Godot.
- Añadidos canal central, chevrones de aterrizaje, luces de aproximación, reflectores, marcos de acceso al hangar y matriz de señalización, como **mallas reales** en `aurora_lobby_stage_3d.gd`. Radar, torre, pinos, hangares, radar móvil y auroras quedan intactos.
- Se mantiene un solo `SubViewport`, el rig skinned Lila y la cámara de cuerpo completo V75.111. El 3D se libera antes de entrar a una partida.

### 2. Pantalla de carga

- Nueva consola `AuroraLoadingConsolePlate`, franja dorada, leyenda `AuroraLoadingChapter`, marcadores de fase y jerarquía de título/progreso para que el flujo tenga presencia propia.
- Barra vinculada a `ResourceLoader.load_threaded_get_status` (progreso verdadero), sin contadores ni tiempos inventados; conserva reintentar y cancelar según fase. Paneles Godot nativos, no captura insertada como UI.
- El archivo `aurora_winter_base.svg` ha sido **reilustrado dentro del repositorio**: cielo polar nocturno, auroras y bruma, tres distancias de montañas, hangares con marco iluminado, pista perspectiva, pasarelas, antenas, radar y 125 estrellas originales. Esta ilustración vectorial se rasteriza como un recurso Godot. El logo y los estados de carga siguen siendo componentes reales por encima de ella. No hay descargas de arte externo ni reutilización de propiedad de terceros.

### 3. Acceso Google / Invitado / Sin conexión

- Composición izquierda `AuroraEntryHeroPanel` con capítulo de operación, título y subtítulo, contraste propio y acento dorado; mejor marco `AuroraEntryGlassPanel` en columna derecha.
- Conservados botones `WelcomeGoogleSignIn`, `WelcomeGuestSignIn`, `EnterButton`, estados de App Check y mensajes honestos del acceso real. Botones con objetivo táctil de al menos 40 px.
- Se mantiene `AuroraMissionBriefing` de V75.112 solo en proporciones donde no invade los tres proveedores; el acceso no arranca un viewport 3D antes de iniciar sesión.

### 4. Lobby Battle Royale

- Panel de operación `AuroraLiveOperationRibbon` a la izquierda del rostro, sidebar retocado, encabezado de identidad, barra inferior y tarjeta de partida prioritaria. Botón **INICIAR** sigue siendo único principal de BR.
- `AuroraFourMemberSquad`: cuatro casillas nativas. Primera casilla representa el operador local; las otras tres vacías. No inventan amigos, invitaciones, juego en red ni clasificación online.
- Mejorada la jerarquía visual (tipografía, anclas, tonos de paneles, accesos, bordes, modo de partida) y la legibilidad del escenario; se mantienen las nueve rutas lógicas y los botones de tienda, misiones, pase, inventario, armas, personajes, perfil, HUD y social.
- Se mantiene Battle Royale **local de 50 participantes (1 humano +49 IA)**. Online real permanece fuera del alcance de esta revisión.

## QA y aceptación

- `v75113_premium_frontend_rebuild_qa.gd` se ejecuta al principio de `run_qa.sh` y comprueba carga nativa, login 1280×720/964×434/2712×1220, navegación y salida, placa de operación, Lila y entorno 3D, 4 casillas honestas y acceso real a TIENDA e INICIAR.
- Regresiones V75.112–V75.1, render OpenGL software bajo Xvfb, capturas versionadas desde el preset, prueba de paracaídas en OpenGL y responsive sin barras laterales forman el gate CI.
- `versionName=75.113.0-mobile-vulkan`, `versionCode=103` conservando paquete/firma. Exportar APK solo mediante `workflow_dispatch` después de revisar CI/capturas; no instalar sobre otro paquete ni tocar producción.
- Antes de aprobar, revisar **capturas reales** de carga, acceso, lobby, cuenta y skins en dos tamaños. Corregir cualquier pantalla desorganizada y comprobar en Motorola Edge 60 Fusion las áreas seguras, 120Hz, VRAM, perfil y partida completa.

## Pendientes transparentes

El rig Lila sigue siendo un activo de base CC0 adaptado; el escenario de acceso utiliza un **nuevo arte SVG original estilizado**, que aún requiere una evaluación visual a las resoluciones del teléfono. El conjunto necesita revisión estética con las referencias del usuario y pruebas físicas; ni QA verde ni esta rama demuestran que el frontend esté al nivel artístico final de un título comercial. Los modos online, cuentas Firebase productivas y nuevo operador masculino tampoco se consideran terminados.

## Protección contra «listo por cumplir»

Antes de afirmar que esta interfaz cumple la referencia del usuario, el PR debe aportar las capturas reales de `loading`, `login`, `lobby` en Godot y comparar legibilidad, personaje completo, composición y contención en 964×434 y 1280×720. **Un test CI en verde no sustituye la evaluación estética ni la prueba física del Motorola**. Ninguna APK se genera automáticamente durante las iteraciones visuales. El PR es borrador hasta que los criterios se cumplan.

## Capturas objetivas del teléfono

El workflow usa además `capture_motorola_frontend_qa.gd` con Xvfb **964×434**, exportando `aurora-v75-113-motorola-loading.png`, `-login.png` y `-lobby.png` al mismo artifact de imágenes. El script verifica dimensiones del píxel real, renderiza botones/GLB nativos y anota que **no es** una prueba física de Vulkan. En 434 px la pantalla de acceso prioriza Google, Invitado y Sin conexión; se ocultan solo el overline decorativo y el botón de diagnósticos para mantener áreas táctiles. El diagnóstico sigue accesible en la interfaz amplia.
