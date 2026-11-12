# THEDEMIAN: LAST ZONE — V75.47 | Rendimiento con Vulkan Mobile

## Continuidad y protección de datos
Se parte de **V75.46**, SHA `e0b3cee65ccb41aa6825679392648c52a8620caf`, PR #51, CI `43325630878` comprobada. El usuario confirmó que Vulkan se comporta mejor en el Motorola Edge 60 Fusion. Esta confirmación cualitativa no equivale a un benchmark con FPS.

No modificar rama estable `v44-3-2-autosave-guest`, motor Unity futuro, certificados preview, ni Firebase. El paquete preview mantiene `com.thedemianff.lastzone.nativepreview`; V75.47 incrementa `versionCode` de 40 a 41. Ambas APK se exportan con el mismo código y firma, diferenciadas solo por la opción de renderizador. No desinstalar ni borrar datos para cambiar la variante.

## Cambios de código realizados
1. Cap 30 FPS para jugadores que priorizan batería.
2. Cap 60 FPS respetado incluso con pantalla a 120 Hz.
3. Cap 90 FPS real como objetivo si el panel lo soporta.
4. Cap 120 FPS real como objetivo si el panel lo soporta.
5. Detección de Hz del panel Android.
6. Protección contra pedir 120 FPS en panel 60 Hz.
7. Límite conservador de objetivo a 120 FPS.
8. Distinción entre caída de FPS dominada por CPU/IA y caída asociada a render o controlador.
9. Prevención de reducciones de resolución cuando el problema es navegación/IA.
10. Periodo de calentamiento previo al ajuste para no penalizar carga inicial.
11. Escalado en pasos acotados y con histéresis.
12. Diagnóstico de rendimiento activo aun con calidad fija seleccionada.
13. Contador real de draw calls disponible en calidad manual.
14. Contador real de objetos renderizados disponible en calidad manual.
15. Métrica de FPS objetivo actual.
16. Métrica de frecuencia real del panel.
17. Métrica de milisegundos consumidos en lógica CPU.
18. Métrica de duración aproximada del fotograma.
19. Estado conservador de saturación visible en Ajustes > Pantalla.
20. Indicador de draw calls, objetos y escala 3D visible en Ajustes.
21. Mantenimiento del HUD 2D nítido sin disminuir su resolución.
22. Conservación de perfiles AUTO, CLARIDAD, EQUILIBRADO y FLUIDEZ.
23. Acotación de muestras de FPS a un máximo de 1800 muestras por partida.
24. Rechazo de valores de FPS no finitos.
25. Cálculo persistente de mediana FPS por partida.
26. Cálculo persistente de P90 FPS por partida.
27. Presentación de P50/P90 en ficha PERSONAJE.
28. Rechazo de duración de partida negativa.
29. Rechazo de duración de partida no finita.
30. Casos QA deterministas de refresco 30/60/90/120.
31. Casos QA de saturación CPU frente al coste de render.
32. Casos QA de estadísticas persistidas.
33. Integración del QA V75.47 en test de fuentes.
34. Integración del QA V75.47 en ambos paquetes Android exportados.
35. Continuidad de regresiones existentes V75.2–V75.46.
36. Producción reproducible de APK Vulkan con versionCode 41.
37. Producción reproducible de APK OpenGL de seguridad con versionCode 41.

**Interpretación:** los puntos anteriores son criterios de aceptación y subcambios, no 37 subsistemas independientes. El objetivo macro de 1.000 mejoras sigue abierto; no se declara completado.

## No cambiar sin ensayo de dispositivo
- No se altera el tick físico de 60 Hz, controles multitouch, trayectorias, armas, IA, casas, botín, guardado ni permisos Google.
- No se promete estabilidad de 90/120 FPS con 20/30 bots hasta medirla en el Motorola.
- No se activa Vulkan como renderer del editor headless; se construye mediante variante Android, conservando Compatibility para comparación y regresiones.

## Protocolo de prueba Motorola
1. Conservar un respaldo del progreso local; no desinstalar la aplicación.
2. Instalar Vulkan V75.47 sobre la preview firmada; revisar Ajustes > Pantalla.
3. Registrar método realmente activo, frecuencia, configuración y FPS media/P10 con 9, 20 y 30 participantes, junto a cierres, tirones y temperatura percibida.
4. Comparar contra la APK OpenGL de igual código si ocurre una regresión.
5. Aceptar Vulkan como opción principal solo si la prueba real respalda estabilidad y visuales.

## Programa para 1.000 mejoras verificables
Dividir en 20 bloques de 50 criterios como máximo, registrando archivos, commits, QA, capturas y ensayos en Motorola. Fases: fundamentos de rendimiento; movimiento/cámara/animaciones; IA táctica y navegación; interiores/botín/mapa; interfaz móvil y HUD; arma y combate; estado de partida; audio; arte original; cuentas/guardado; herramientas; red multijugador autoritativa (50 personas reales, no IA etiquetada); escuadras y partidas clasificadas; seguridad y lanzamiento. No se contabiliza como mejora terminada ninguna idea sin integración y validación.
