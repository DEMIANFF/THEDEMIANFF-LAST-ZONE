# Revisión privada Prisma3D — Lila

Archivo del usuario Modelo (7z): SHA-256 e5c9d2fde4385c6315a3230cdb047405a98b81bdbf5e009aa8ca323fe7d7cbe0.
GLTF extraído Nuevo Proyecto.gltf: SHA-256 178ff358c80acd44d33880c4d2047108e56ea75fa0053e5e82fa536fa522e393.
31 huesos, 40 canales, 2568 muestras, 85.56667 s, sin licencia declarada.

Se recuperó el GLB original de Lila SHA-256 62da843e0649b4274f5af4dfc75dfa3fa557d094224922c002498d5c28e15cbd (56 huesos, 57 clips originales). Se calcularon direcciones articulares por cinemática directa, se conservaron los 40 canales en un banco privado, se eliminaron 54.4 m de desplazamiento horizontal de pelvis de las candidatas, y se adaptaron direcciones a 18 articulaciones con longitudes originales. Resultado privado: nueve ventanas de cuerpo completo y cuatro variantes de piernas, 13 clips. No es una transferencia exacta de torsión de muñeca o dedos; se conserva la pose de dedos original. Las ventanas son candidatas de revisión, no ciclos aprobados. Se verificaron direcciones, cuaterniones, tiempos y preservación byte a byte de geometría y rig. No se ha ejecutado Godot ni probado en el Motorola.

Banco de 13 clips Lila_Prisma_Clips_13.json SHA-256 4f5f890a8403ff4981b31b7e3d98c9a0cc7da003ff79525443472d1d2fde18f1. GLB privado de revisión SHA-256 9f456cd6e8ecffc451459487602df2ba2c7589987de34e5403b58e7cfb34292b. Los datos derivados y el modelo de origen permanecen fuera del repositorio público.

La herramienta stage_prisma_review.py permite anexar los 13 clips a una copia privada del GLB actual sin reemplazar ninguna animación Aurora, geometría, malla ni hueso. Solo permite las pistas de rotación seleccionadas y pelvis vertical. Los nombres ReviewPrisma_ no entran en el state machine Aurora existente. No publicar ni exportar APK con el banco hasta verificar permisos, revisar poses y contacto con suelo, seleccionar ciclos, adaptar agarre armado y aprobar QA física.

Uso privado desde una copia del repositorio:
    python3 native-godot/tools/aurora_motion/stage_prisma_review.py --bank /ruta/Lila_Prisma_Clips_13.json --target native-godot/assets/characters/lila_aurora.glb --output /ruta/privada/Lila_Review.glb

La herramienta no escribe el GLB original ni inicia otra compilación Android.

## Ciclos de locomoción — segunda revisión

Cuatro ventanas cerradas extraídas de las pistas de piernas, sin publicar datos: A 91–114 (23 intervalos), B 70–125 (55), C 15–61 (46), rápida 22–40 (18). Aprox. 0.767, 1.833, 1.533 y 0.600 s respectivamente. Se comprobaron direcciones y posiciones articulares mediante cinemática directa sobre el rig de Lila: separación lateral de los tobillos y alternancia de z; diferencia máxima entre extremos de rotación <0.025 grados y posiciones de tobillo/dedo <0.000001 unidades de rig. No son medidas de deslizamiento en movimiento real ni de contacto de suela con suelo. El código `--gait-cycles` agrega cuatro clips candidatos con siete pistas cada uno, sin pisar los 13 clips de revisión anteriores ni los clips originales del destino. Cierra únicamente el error numérico de la última clave, rechaza costuras >0.25 grados o pelvis >0.0001 unidades. Los clips no se conectan al AnimationTree ni se exportan en APK pública. Pendiente inspección en Godot y prueba de velocidad de desplazamiento, apoyo, agarre y derechos.
