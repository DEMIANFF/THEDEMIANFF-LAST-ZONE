# THEDEMIAN: LAST ZONE — V75.46 | OpenGL vs Mobile/Vulkan en Motorola

## Punto de partida protegido

V75.45, rama codex/v75-45-mobile-render-pipeline-budget, HEAD 3346ef053c2825274b893a59566c286b8fb3b7f7; GitHub Actions 43313277941 SUCCESS. No cambiar V44 estable, Firebase, Unity, firma preview ni el namespace com.thedemianff.lastzone.nativepreview. El motor sigue siendo Godot 4.7.2 para Android y CI.

## Dos APK REALES para comparación controlada

La rama V75.46 genera dos APK Android ARM64 sobre el mismo árbol de fuentes: THEDEMIAN-V75.46-MOTOROLA-OPENGL.apk (Compatibility/OpenGL) y THEDEMIAN-V75.46-MOTOROLA-VULKAN.apk (Mobile/Vulkan). Ambas conservan versionCode 40 y la firma existente; solo la configuración de render Android cambia. Las versiones visibles son respectivamente 75.46.0-compat-opengl y 75.46.0-mobile-vulkan. La plantilla del usuario recomendaba Mobile; lo tratamos como candidato que debe superar un ensayo real con Motorola Edge 60 Fusion, no como FPS demostrados.

El archivo configure_android_renderer.py aplica y comprueba de forma determinista rendering/renderer/rendering_method.mobile=mobile y rendering/rendering_device/driver.android=vulkan SOLO para el export Mobile. El renderer estándar y el editor headless siguen gl_compatibility para no invalidar miles de cálculos físicos QA ni capturas previas. El flujo vuelve después a Compat, sin mezclar binarios, certificados o identidades.

## Validación de verdad

CI exige 100% de las regresiones históricas Godot en las fuentes, además de QA de exportación en AMBAS APK: director del BR, 9/20/30 IA, cámara, avión/paracaídas, interior, AWM, rendimiento, etc. Verifica cada binario APK (ABI ARM64, versionCode, CRC, alineación 16KiB, firma v2/v3, certificado SHA256 fijado, contenido del proyecto exportado), y muestra dos artifacts separados. El test V7546_RENDER_AB comprueba que la configuración Android llegó al proyecto exportado de cada variante.

Godot puede activar un fallback en hardware que no acepte Vulkan. Por eso NO basta con la palabra VULKAN en el nombre del archivo: desde AJUSTES > PANTALLA se muestra el renderizador realmente activo, usando RenderingServer.get_current_rendering_method y get_current_rendering_driver_name. También se imprime AURORA_ACTUAL_RENDER en los logs de Android y se conserva el backend verdadero junto con FPS medios, percentil bajo, mínimo, participantes y escala 3D en el reporte local.

## Prueba justa que puede efectuar el usuario

1. Guardar cualquier configuración local importante antes de instalar variantes. Ambas versiones usan el MISMO identificador técnico, firma y versionCode; son actualizaciones intercambiables, no dos aplicaciones simultáneas. No desinstalar ni borrar datos para intercambiarlas; si Android impide sustituir una, comunicar el error en lugar de perder progreso.

2. Instalar OpenGL, entrar en Ajustes > Pantalla, anotar método REAL. Jugar una partida con 20 IA (1 humano + 19 bots), con la misma zona, calidad 3D y duración aproximada; anotar FPS promedio y P10 en PERSONAJE. Repetir con 30 IA si es estable.

3. Instalar la variante Mobile, comprobar que la pantalla dice MOBILE / VULKAN (o informar fallback real). Repetir mismos participantes, posición, trayectoria y calidad. Comparar FPS/P10, calentamiento, consumo de batería, tirones al cargar edificios y cierres. Mobile se acepta si calidad visual y estabilidad REAL superan o igualan OpenGL sin regresiones.

4. En cualquier fallo de Vulkan, regresar a la variante OpenGL firmada sin alterar el perfil local. V75.45 es el respaldo anterior ya aprobado.

## Lo que deliberadamente NO hicimos

No cambiar 60 Hz de física, cámara, IA, daños, HUD, appId, certificados, cuentas Google/Firebase ni controles. No introducir Forward+ en la APK móvil. No activar sombras caras, LightmapGI sin UV2 preparadas, ni compresión ASTC sin comprobar assets. No afirmar multijugador humano 20/30 ni FPS medidos antes del ensayo físico. Mobile/Vulkan NO hace que el contenido 3D de bajo detalle se convierta mágicamente en arte profesional.

## Próximas etapas tras el ensayo

Si Mobile/Vulkan funciona, generar materiales originales para casas y armas con UV normales/roughness, LOD por malla, texturas ASTC/ETC2 con mipmaps y luces estáticas preparadas; medir memoria, draw calls y frame timings. La variante de respaldo OpenGL debe seguir recibiendo regresiones de jugabilidad y una ruta de actualización compatible.
