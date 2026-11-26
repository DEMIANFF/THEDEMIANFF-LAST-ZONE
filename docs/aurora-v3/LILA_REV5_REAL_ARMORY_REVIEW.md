# Lila Rev5 — revisión de agarres con el jugador real

Base Rev5 PR #204 (CI 45813000721 success); GLB privado SHA c9b755349a4dc2692f45f3bec1918001d72a05f01b3bcad4aff406c743afb74b.
Auditoría local mediante cinemática directa de las 27 acciones y 1500 tiempos de clave distintos. Se define una referencia esquelética de palma (punto medio entre la muñeca y la media de los cuatro nudillos proximales Index/Middle/Ring/Pinky). No es una prueba de contacto con la superficie ni una nueva posición objetivo. Con la escala estimada por fit_operator_visual (altura 1,76 m; modelo 1,000423 unidades): muñeca a referencia izquierda 0,020030 m y derecha 0,019534 m, distancia constante en las muestras; longitud de antebrazo estimada 0,198492 m ambos lados. El IK de producción comprueba errores de muñeca respecto a sus objetivos; no equivale a contacto anatómico de los dedos o palma. No se modifica el objetivo sin prueba física.

Nueva herramienta private_lila_armory_review.gd instancia el CharacterBody real de producción, AnimationTree, WeaponVisuals y SkeletonModifier3D reales en plataforma física aislada. Usa approved_operator_scene existente para inyectar en memoria el GLB privado por SHA, sin sobrescribir el activo. Matriz de AR-7, AWM, SCAR, MP40, Vector y P90 × idle armado, apuntado, agachamiento y caminar armado; registro de errores de muñeca, referencia palma, anclaje real de apoyo y Grip cuando existe. La tolerancia histórica 0,045 m corresponde solo a los errores del solucionador. La distancia palma-anclaje se registra, no se usa como certificación anatómica. No prueba inventario, disparo, recargas ni terreno de BR. CI nueva usa Godot 4.7.2 y modelo público de producción para calibrar el harness, no el GLB privado. No se inicia exportación Android.

Ejecución privada en copia de trabajo con importación y recursos preparados:
```bash
export XDG_DATA_HOME="$(mktemp -d)"
godot --headless --path native-godot --script res://tools/aurora_motion/private_lila_armory_review.gd -- --candidate /ruta/privada/Lila_Aurora_2K_Rev5_Manos_PRIVADA.glb
```
La rama no publica datos binarios, no cambia juego, firma, Firebase ni versión de APK. Candidato real no ejecutado dentro de Godot por falta del motor local y transferencia de binario; falta confirmar permisos, anatomía de dedos, colisiones de malla y funcionamiento del agarre en Motorola.
