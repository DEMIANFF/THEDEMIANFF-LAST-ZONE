# THEDEMIAN: LAST ZONE — V75.109 · Reconstrucción de entrada y lobby nativo

Base estricta: `codex/v75-108-aurora-interactive-operator-lobby`, commit `0f449e170c162a94fe4fb2aebe0270d3952fce62`, PR #113, CI `43768627834` aprobado. Godot 4.7.2, Android ARM64, Vulkan Mobile, versionCode **99**, versionName **75.109.0-mobile-vulkan**.

## Objetivo y criterio de diseño

Las tres imágenes aportadas por el usuario se utilizan como **especificación de producto** (pantalla de carga/acceso/ajustes, lobby/HUD, arquitectura), no como imágenes estáticas para reemplazar las funciones reales. Este incremento reconstruye controles Godot y capas 3D/UI, conservando la funcionalidad offline de 50 participantes, Firebase existente, el HUD real, Lila y sus animaciones, la música del lobby y los controles de V75.108.

## Implementación comprobable en el código

1. **Carga real:** se conserva `ResourceLoader.load_threaded_get_status` y `WorldLoadProgress`, pero ahora la presentación tiene barra dorada, superficie navy/cian, estado por fase y tipografía acotada. Reintentar y cancelar siguen conectados a sus métodos reales.
2. **Inicio de sesión:** nuevo `AuroraEntryGlassPanel` con tres acciones de Godot organizadas Google → Invitado → Sin conexión, en un panel derecho. Encabezado y subtítulo, área de misión y diagnóstico discreto. Cada botón conserva su ruta real: Firebase no puede atribuir identidad o pagos sin conexión. Los proveedores dejan de estar comprimidos horizontalmente en paisajes pequeños.
3. **Ciclo de login/lobby:** al regresar a login, se ocultan completamente la barra de comercio y los paneles del lobby que antes podían quedar visibles, y se libera el `SubViewport` del personaje. Al volver a JUGAR se reconstruye la escena 3D real.
4. **Lobby:** corrección de orden real de render (`_surface.move_child(...,_page.get_index())`) para que header, paneles de comercio y tarjeta BR no queden detrás del SVG. Columna de misiones/tienda mejor enmarcada, panel social separado, botón INICIAR más prominente, barras coherentes navy/cian/dorado, regiones ajustadas a 964×434 en horizontal.
5. **Lila 3D:** ampliación del área `SubViewport`, brillo de ambiente y luces del rig real (no superponer PNG). Los botones de giro, encuadre, gesto, skins y retorno al lobby siguen conectados.
6. **Pruebas:** `v75109_production_entry_lobby_qa.gd` valida progreso real, inicio de sesión con acciones verticales, integridad de hitboxes, capas UI visibles sobre el arte, Lila con esqueleto, iluminación, INICIAR real, tienda distinta al modo BR, y ausencia de fugas visuales al volver a login. `v75105_aurora_entry_flow_qa.gd` conserva las comprobaciones de toque real adaptadas al nuevo orden vertical.

## Pendientes relevantes: no presentar como terminados

- Las tres láminas **aún no están implementadas al 100%**: acabado artístico final de pantallas, iconografía propia, HUD idéntico en función y presentación, escenas adicionales, tienda/pase/ruleta y social autenticados, backend de diamantes reales y pagos, modos 4v4 online, rig masculino completo, IA y optimización móvil final.
- Lila y el modelo masculino exigen retarget rig y validación en dispositivo físico para todas sus animaciones.
- Los OGG locales y activos originales no deben incluirse automáticamente en una APK pública hasta verificar permisos, empaquetado y atribución.
- Las capturas de CI usan software OpenGL en escritorio, y nunca sustituyen una prueba física Vulkan Mobile en Motorola Edge 60 Fusion.
- Sin APK en esta entrega; el trabajo en rama/PR queda como **draft** hasta CI y aprobación humana.

## Invariantes de seguridad

No se alteran `v44-3-2-autosave-guest`, rama main, Firebase productivo, certificado de aplicación, identificador ni instalación oficial. No fusionar ramas antiguas ni inventar éxito de tests o integración que no ocurrieron.

## Próxima prueba de aceptación

Abrir `AURORA-LOBBY` en Motorola Edge 60 Fusion; comprobar que la barra de carga avanza cuando realmente termina la precarga, que Google/Invitado se habilitan solo con servicios disponibles, que Lila entra y se puede girar, que la música continúa en Tienda/Pase/Ajustes, y que JUGAR → entrenamiento → regreso nunca deja paneles del login superpuestos.
