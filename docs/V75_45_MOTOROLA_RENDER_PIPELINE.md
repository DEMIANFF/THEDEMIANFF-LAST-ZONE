# THEDEMIAN: LAST ZONE — V75.45 | Renderizado móvil y estabilidad

## Continuidad

Base exacta V75.44, PR #49, GitHub Actions 43304814013 SUCCESS, commit d6c36819da7538bdf333c97fafeb879ece541400. Conservar estable v44-3-2-autosave-guest, Unity, Firebase, firma permanente y paquete Android nativepreview. Un solo parche V75.45 Android code 39.

El usuario probó presencialmente en Motorola Edge 60 Fusion los modos de 20 y 30 participantes y reportó funcionamiento correcto. Estas partidas siguen siendo offline con rivales IA (1 humano + 19 o 29 bots), no multijugador humano. No se conoce aún FPS numérico de estas pruebas.

## Diagnóstico técnico

La isla ya es una malla continua y las coníferas ya son MultiMesh. El problema principal evitable en esta fase: docenas de MeshInstance3D por casa y material, agua de 910×910 m con alpha blending, cámara con profundidad innecesariamente larga y ausencia de un governor de escalado 3D. La APK pequeña o grande no determina por sí misma su rapidez ni fidelidad.

## 1. Agrupar geometría estática

El script aurora_static_mesh_batcher.gd agrega primitivos BoxMesh, CylinderMesh y SphereMesh de UN edificio y UN material en una malla ArrayMesh con SurfaceTool.append_from. Mantiene transformaciones; los MeshInstance3D originales siguen inspeccionables y quedan invisibles. No modifica StaticBody3D, CollisionShape3D, fachadas transitables, rampas, interiores, botín, tejados de tejas MultiMesh ni personajes animados. Se aplica a las 8 villas costeras y los 4 edificios anteriores. Reduce el número estructural de draws; NO se declara FPS adicional hasta probar hardware.

## 2. Escalado 3D por presupuesto

El nodo AuroraRenderBudget opera sobre el viewport en Godot GL Compatibility con escalado BILINEAR real. En AUTO empieza a 0.94 y baja a 0.86 y 0.78 sólo tras FPS bajos sostenidos Y CPU sin saturación; recupera calidad después de una ventana mayor para prevenir oscilaciones. Las opciones CLARIDAD 1.0, EQUILIBRADO 0.90 y FLUIDEZ 0.78 se guardan y modifican desde Ajustes > Pantalla incluso durante partida. El escalado no aplica al CanvasLayer de controles 2D. Al regresar al lobby restaura la escala completa. No se atribuyen FSR, ray tracing ni funcionalidades de Vulkan.

## 3. Menos sobrecarga gráfica

El mar pasa de alpha-blended a material opaco con Z-buffer para evitar sobrecoste de fragmentos en Android. Cámara: near 0.08 m y far 680 m, suficiente para la diagonal jugable y vistas de avión, con mayor precisión de profundidad. Conserva flujo avión, caída, paracaídas, cámaras y mira ADS.

## QA de V75.45

v7545_mobile_render_pipeline_qa.gd verifica la presencia de los 8 edificios, los meshes combinados, las colisiones de pisos/techos/rampas, los tejados originales, los cuatro perfiles persistentes de render, la calidad sin escalar HUD, el mar opaco y cámara. Se integra a la batería histórica completa fuente y exportado. Build ARM64 versionCode 39 y misma firma preview. PR draft hasta CI verde y pruebas físicas.

## Cómo evaluar con el Motorola

Comparar la misma escena con 9, 20 y 30 combatientes y misma duración; anotar FPS medio, P10 y mínimo al acabar, especialmente interiores, apuntado AWM, avión/salto, ciudad y monte. Contrastar AUTO, CLARIDAD, EQUILIBRADO y FLUIDEZ, temperatura, batería y posibles cierres. Sólo esos datos permiten afirmar si la V75.45 es mejor en hardware. El arte original más detallado, materiales PBR, mapas complejos y animaciones finales de Lila siguen siendo trabajo pendiente.
