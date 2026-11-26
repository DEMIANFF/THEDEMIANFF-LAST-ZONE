# Rev9 — revisión visual y entrada privada en Main

Base PR #212, commit 407ed5a7502a72d6751f7ca06c38d4b620029572, CI 45824269588 success. El GLB privado exacto se recuperó de la Biblioteca y su SHA se verificó (19c93a00c114246aba2dca99c3a53698990dea2b9c519fc50a61a159331c4d45). Se recuperó el kit de Godot oficial 4.7.2 del PR #211, verificando SHA de transporte, e importó el proyecto. No se publica el GLB.

Pruebas recuperadas de la sesión previa: importación 27 clips/135 poses; dos matrices de agarres de seis armas (48 combinaciones) y prueba P90 exit 0. Nueva revisión visual local: 24 capturas PNG de 800x800 (producción y Rev9, AR/AWM/P90, reposo armado/agachado, dos cámaras) con iluminación idéntica y modo experimental de palma. Ambos procesos exit 0, seis combinaciones cada uno. Mesa llvmpipe/OpenGL de escritorio para inspección exclusivamente; no se modifica exportación Android Vulkan ni se afirma rendimiento de GPU. Aún hay intersecciones y anatomía de dedos no aprobada. Las capturas privadas se entregan fuera del repo.

Main incorpora review_operator_scene: PackedScene no exportada, nula por defecto, asignada solo antes de entrar al árbol por la prueba local explícita. Conserva el flujo normal. La QA v75189 acepta opcionalmente --candidate /ruta/privada/Rev9.glb con SHA exacta; verifica escena inyectada y recuentos reales de malla esquelética (93572 vértices, 95885 triángulos). No copia el GLB al proyecto ni sobrescribe el modelo público. Primera ejecución detectó mallas accesorias en el recuento; filtrado por skin y repetición exit 0. Prueba física local Main: separación de tobillos 0,351807 m, diferencia de altura de dedos 0, pendientes +/-0,18 rad, errores de objetivo de tobillo inferiores a 1 micrómetro, descenso de pelvis agachada 0,302034 m, inclinación torso 4,6743 grados; ocho muestras de crouch sostenido, caminata agachada, cinco armas, ADS y liberación de contacto en aire. Las cifras de tobillos no son contacto de superficie de suela. Prueba no mide FPS ni un BR completo.

Comandos (proyecto importado, directorio de datos aislado):
    godot --headless --path native-godot --script res://scripts/qa/v75189_lila_body_performance_qa.gd -- --candidate /ruta/privada/Rev9.glb
    godot --path native-godot --script res://tools/aurora_motion/private_lila_visual_review.gd -- /ruta/salida --candidate-palm /ruta/privada/Rev9.glb

Sin exportación APK ni cambios de firma/Firebase/modelo público. Pendientes optimización geométrica, dedos parcialmente fusionados, contacto real, prueba Vulkan y Motorola, permisos de distribución.
