# THEDEMIAN: LAST ZONE — V75.110 · Controles táctiles y carga segura

Base inalterada: PR #114 / `codex/v75-109-aurora-production-ui-rebuild`, HEAD de partida `58979ee092a28e57e12e9ce2a1959902ca43b3f6`. Godot 4.7.2, Android ARM64/Vulkan Mobile. Esta es una corrección incremental, no una reconstrucción del BR.

## Defectos comprobables en el código de V75.109

1. A 964×434, los botones superiores CUENTA / AJUSTES / SOCIAL usan anclas verticales de ~0.073, equivalentes a apenas **31–32 píxeles de alto**. Son objetivos táctiles demasiado pequeños en un dispositivo móvil.
2. Los seis accesos de la columna izquierda usan altura mínima de **30 px**. Se solapan en la práctica con gestos imprecisos y no cumplen el objetivo de al menos 40 px.
3. La región inferior de acciones de carga (de y=.66 a y=.965) ofrece solo **132 px de alto** a 434 px de pantalla. Con barra de progreso, textos y botón cancelar/reintentar, el contenido puede desbordar el rectángulo de la pantalla.

## Cambios en el código

- CUENTA/AJUSTES/SOCIAL pasan a un tramo vertical .025–.131 (~46 px a 434 px), sin mover el logotipo ni alterar los callbacks.
- Los seis accesos de comercio pasan a un mínimo de 40 px; el rail se amplía a .265–.866, con separación de 3 px, y se extiende el panel de fondo.
- La marca en la pantalla de carga termina en y=.50 y las acciones comienzan en .525 y terminan en .972: el área de acciones pasa a ~194 px. Se nombra el contenedor nativo `AuroraLoadingActions` para QA.
- Se incorpora `v75110_motorola_touch_loading_qa.gd` al principio de la batería nativa. Comprueba tamaños, ausencia de desbordes y dos rutas de **toque de pantalla real mediante Input.parse_input_event**, además del regreso del overlay.
- Versionado Android: `75.110.0-mobile-vulkan` / `versionCode=100`. Se conserva paquete, identidad, Firebase y firma.
- GitHub Actions reconoce la nueva rama; QA y capturas se ejecutan en push. **La exportación de APK permanece exclusiva de workflow_dispatch**: un CI verde no crea automáticamente una APK ni demuestra que se instaló en el Motorola.

## Criterios de aceptación pendientes

1. CI completo: importación de escenas, QA v75110 y regresiones previas sin errores GDScript; capturas de la UI renderizada en Godot.
2. Comparación visual de carga con botones visibles y accesibles en 964×434; confirmar las tres acciones de login, accesos de comercio, navegación inferior y tamaño de texto.
3. Prueba física Motorola Edge 60 Fusion: toque en CUENTA/AJUSTES/SOCIAL, los seis accesos del rail, cancelar carga y comenzar partida; verificar notch, latencia, VRAM, FPS y transiciones.
4. No fusionar, ni anunciar un BR terminado o una APK probada, hasta esas pruebas. La prueba headless no valida por sí sola Android/Vulkan ni fidelidad visual de las tres imágenes de referencia.

**Protecciones:** no modificar main, rama estable `v44-3-2-autosave-guest`, Firebase productivo, claves, firma ni datos del jugador.
