# THEDEMIAN: LAST ZONE — V75.111 · Encuadre 3D real de Lila

Base: PR #115, rama `codex/v75-110-motorola-touch-loading-safe`, commit `1767d0857aadc58f03b1bacb9df966c9bddd1293`. Godot 4.7.2; Android ARM64/Vulkan Mobile. Solo modifica encuadre y verificación del lobby 3D; ninguna alteración en partida, animaciones del BR, Firebase ni firma.

## Defecto confirmado visualmente

Se recuperaron las capturas renderizadas en CI de V75.109: [ejecución 43772969543](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/43772969543), artefacto `THEDEMIAN-V75.109-LOBBY-ACCOUNT-PREVIEW`. En `aurora-v75-109-lobby.png` la cabeza de Lila queda tras la franja superior y sus pies invaden la navegación inferior. La cámara vertical de **38 grados** a z=3.07 hacía que un rig de ~1.96 m ocupara casi toda la altura útil.

## Corrección

- Cámara real `PreviewViewport/AuroraCharacterStage/LobbyPortraitCamera`: FOV vertical por defecto de **54°**, misma perspectiva, manteniendo la malla y las animaciones reales de Lila.
- El botón `VISTA` cambia a retrato con **45°** y lente elevada a y=1.48 (z=2.95), para que la cabeza permanezca visible, y recupera la posición/fov de cuerpo completo al regresar.
- QA V75.108 conserva la prueba de cambio real de cámara con los nuevos valores; QA V75.111 proyecta los AABB de los meshes visibles del GLB a la cámara del SubViewport y revisa el margen vertical en **964×434 y 1280×720**.
- El script `run_qa.sh` ejecuta la prueba nueva antes de la batería original. Versión Android `75.111.0-mobile-vulkan`, `versionCode=101`; APK manual solamente.

## Validación antes de fusionar

1. CI Godot aprobado; revisar capturas nuevas, lado a lado con V75.109, para comprobar cabeza, cabello, pies, centinela, tarjetas y accesos táctiles.
2. Ajustar cámara si la nueva captura muestra encuadre vacío, si el retrato tapa la cara o si cualquier control se solapa; no utilizar una imagen estática como sustituto.
3. Probar realmente el lobby y la transición a BR en Motorola Edge 60 Fusion, con FPS/VRAM y cierre/reapertura de cuenta.
4. Mantener borrador hasta esas pruebas. Un CI verde en OpenGL software **no valida** Vulkan Mobile ni equivalencia completa a las imágenes de referencia.

Conservar `main`, `v44-3-2-autosave-guest`, `com.thedemianff.lastzone`, Firebase productivo, firma y perfiles.


## Corrección de regresión del QA histórico V75.79

GitHub Actions run `43775997906` detuvo la batería en `v7579_premium_lobby_stage_qa.gd`: el test exigía `camera.fov <= 40.0`, un valor anterior a la corrección de V75.111. Las QA V75.111, V75.110, V75.109, V75.108 y anteriores inmediatas habían pasado antes de esta condición obsoleta.

El QA V75.79 ahora conserva sus comprobaciones del escenario invernal, cuenta, botón INICIAR, social, monedas y límites de pantalla, pero reemplaza el umbral de FOV por una comprobación **geométrica del modelo real** a 964×434: proyecta los ocho vértices AABB de cada mesh visible de Lila mediante `Camera3D.unproject_position`, exige al menos 42% de ocupación vertical y mantiene cabeza y pies fuera de las bandas superior/inferior. No se ha cambiado el gameplay, la cámara de V75.111 ni el sistema de animación para satisfacer un número obsoleto.

**Verificación del parche:** nueva ejecución integral de CI y revisión de la captura V75.111 antes de declarar la regresión resuelta; prueba física Motorola aún pendiente.

## Fallo de captura de CI: rutas de imágenes obsoletas

En la ejecución [43805595358](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/43805595358), la batería nativa llegó al paso de captura de Godot. `capture_frontend_preview.gd` y `capture_real_skin_variants.gd` obtienen el tag de `export_presets.cfg` mediante `aurora_capture_version.gd`, por lo que V75.111 produce archivos `aurora-v75-111-*.png`. El workflow seguía exigiendo nombres `aurora-v75-109-*.png`: `test -s` devolvía 1 aun después del marcador `AURORA_FRONTEND_RENDER`. El warning de V-Sync con Mesa llvmpipe y la advertencia ObjectDB no demostraron ser la causa.

Corregido en `.github/workflows/native-godot-preview-apk.yml`: resuelve `AURORA_CAPTURE_TAG` del preset y utiliza ese valor tanto en los `test -s` como en las rutas de ambos artefactos, incluido el flujo de exportación manual. No modifica rig, gameplay ni renderizado Vulkan. Una nueva ejecución debe confirmar que las imágenes reales existen antes de llamar a esto resuelto.
