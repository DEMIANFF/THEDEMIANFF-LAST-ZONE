# Lila Rev9 — 50 instancias visibles con LOD nativo

Base PR #214, commit 83dbe0ab7586568aa7ea9d22572e3ec367084731, CI 45830792180 success. Prueba local Godot 4.7.2 con escena privada Lila_Rev9_LOD_privada.scn SHA-256 236056e220607d9e8920b5be924e12ef84ba88e5a928edae5e46b43fe7b419e3. 50 instancias comparten el mismo recurso ArrayMesh, con rig de 56 huesos y 27 animaciones cada una. Diez personajes por plano a 15,30,60,100,150 m de profundidad, cámara 800x800 FOV40. No es un mapa o partida BR, no se simulan IA, físicas de combate, armas ni terreno. Se muestrean tres clips (reposo armado, carrera armada, agachado) con fases diferentes por columna, dos modos de render, seis capturas.

Godot viewport_get_render_info: 50 objetos y 50 draw calls en todos los casos. Control 4.794.250 triángulos; LOD nativo 3.835.170 triángulos; ahorro 959.080 (20,0058%). Conteo observado coincide con 30 personajes a 95.885 y 20 a 47.931 en las seis muestras; prueba pass true. Comparación RGB de la región de imagen y>=335 (tres filas cercanas): 28/33/36 píxeles con cambios de máximo 1 nivel de 8 bits por canal; no identidad exacta. Render software OpenGL llvmpipe, no benchmark FPS, no medición de memoria y no prueba Vulkan. Se conserva escenario privado fuera de GitHub. Evidencias entregadas en THEDEMIAN_LILA_REV9_50_INSTANCIAS_QA.zip.

Nueva herramienta local reproducible:
    godot --path native-godot --audio-driver Dummy --rendering-method gl_compatibility --script res://tools/aurora_motion/private_lila_crowd.gd -- /ruta/privada/Lila_Rev9_LOD_privada.scn /ruta/salida

CI pública comprueba sintaxis y mantiene regressiones existentes; no carga escenario privado. No se modifica el modelo activo ni la configuración Android, Firebase o firma; no se genera APK. Pendientes carga gráfica en el mapa real con IA, contacto anatómico de dedos y vestimenta, prueba en Motorola y derechos de distribución.
