# THEDEMIAN: LAST ZONE — V75.59 | Lila Aurora, primera integración visual real

## Base técnica y protección
Deriva **solo** de la V75.58 `codex/v75-58-physical-headshots-vulkan`, PR #59, GitHub Actions #43356713558 = SUCCESS. Godot nativo y un único APK Android ARM64 Vulkan Mobile `75.59.0-mobile-vulkan`, versionCode 49, mismo paquete preview y certificado. No tocar la rama estable `v44-3-2-autosave-guest`, Firebase ni respaldos.

El usuario pidió comenzar de verdad con Lila y desarrollar mejoras en bloques de 20 o 50, sin pedir pruebas del Motorola hasta que él lo indique.

## Qué significa «Lila» en esta versión

El cuerpo 3D humanoide, la textura de piel y el cabello proceden **todavía** de una base femenina con licencia CC0 y deben reemplazarse posteriormente por arte completamente original. Esa base ya tiene esqueleto con articulaciones y animaciones jugables, y no se destruye ni se sustituye por una figura cúbica.

**Nuevo trabajo visual real:** `native-godot/tools/convert_operator.py` diseña y exporta un equipo táctico original de Aurora sobre la operadora, como un **solo Mesh skinned**, con 19 piezas y 3 materiales PBR compartidos. Queda unido a los huesos existentes, por tanto acompaña al modelo durante caminar/correr/agacharse, saltar, caída, paracaídas, apuntar y disparar.

### Las 19 piezas originales y sus anclajes
| # | Pieza del uniforme Lila Aurora V1 | Hueso |
|---|---|---|
| 1 | Arnés pectoral interior | Spine |
| 2 | Placa de identificación frontal | Spine |
| 3 | Barra de luz Aurora | Spine |
| 4 | Correa pectoral izquierda | Spine |
| 5 | Correa pectoral derecha | Spine |
| 6 | Hombrera izquierda | LeftArm |
| 7 | Hombrera derecha | RightArm |
| 8 | Consola de muñeca izquierda | LeftForeArm |
| 9 | Protector de muñeca derecha | RightForeArm |
| 10 | Radio rígido de espalda | Spine |
| 11 | Antena de radio | Spine |
| 12 | Cinturón utilitario | Hips |
| 13 | Emblema metálico del cinturón | Hips |
| 14 | Estuche de suministros izquierdo | Hips |
| 15 | Estuche de suministros derecho | Hips |
| 16 | Rodillera izquierda | LeftUpLeg |
| 17 | Rodillera derecha | RightUpLeg |
| 18 | Banda de identificación en la cabeza | Head |
| 19 | Insignia central de la banda | Head |

**Optimización:** únicamente 152 vértices base de armadura, 114 caras, 3 materiales, un solo MeshInstance3D y nueve grupos de huesos ponderados. Sin 19 MeshInstance3D adicionales por personaje ni nuevos AnimationPlayers. Las características visuales actuales incluyen tejidos azul oscuro, protecciones cobre y señales cyan en vez de copiar ropa de marcas ajenas. El coste efectivo de triángulos tras exportación se mide en CI.

## Integración y QA sin simulaciones
- El mismo `aurora_operator.glb` contiene la base femenina CC0, la armadura original y las animaciones. La partida y el lobby **cargan ese mismo recurso**.
- El lobby mantiene vista 3D con arrastre para girar, escena de hangar y avatar animado. Texto honesto: «Lila Aurora V1 • base CC0 provisional». No llamar final a la cara/cabello.
- El controlador conserva `CharacterBody3D`, cápsula de colisión 1.82 m, cámara detrás a 4.6 m, SpringArm/corrección de obstáculos, AnimationTree y blend de armas.
- Se mantienen Godot móvil Vulkan, bajada de detalle para 20/30 rivales IA y recursos locales liberados del lobby al entrar a partida.
- La CI valida **antes** del importado Godot que el GLB incluye un Mesh con nombre LilaAuroraSignature, un nodo skinned vinculado a armature, al menos 152 vértices de armadura y los tres materiales originales.
- Prueba `v7559_lila_rig_identity_qa.gd`: instancia la escena de juego y la escena de lobby, comprueba el mismo uniforme 3D animado, 3 materiales originales, skin con esqueleto real, clips de movimientos/combate, física, cámara y texto de divulgación.
- En la CI los tests históricos se vuelven a ejecutar desde archivos de fuente y desde los recursos de la **única APK Vulkan** exportada. La firma v2/v3 y versión se verifican sin renovar certificados.

## Limitaciones conocidas y próximos pasos necesarios
Estas 19 piezas **son el primer trabajo de identidad visual Lila**, no 19 personajes nuevos ni un escultor 3D original terminado. Para llegar a Lila definitiva faltan:
- Rostro, cabello, manos y proporciones de autoría propia, alta fidelidad y UVs.
- Vestuario orgánico con prendas realmente modeladas y deformación fina de tejido.
- Skinning más detallado, gestos faciales, animaciones corporales de mayor calidad, IK completo de agarre de armas y pulido técnico de equipamiento.
- Adaptación visual de rivales con atuendos distintos; hoy pueden compartir la base skinned con distinto LOD.
- Revisar el render real en Motorola cuando el usuario autorice una nueva prueba; CI no demuestra 60FPS en hardware.

## Regla del programa de 1000 mejoras
**Una pieza visual, un test y un commit no equivalen automáticamente a una mejora comercial independiente.** El conteo definitivo exigirá código/activo integrado y QA, y seguirán bloques de combate, IA, interiores, inventario y sistema online autoritativo. La cantidad 1000 sigue siendo un objetivo, no un avance falso.
