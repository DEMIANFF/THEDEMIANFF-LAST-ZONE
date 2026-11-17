# Aurora V3 — verificación efectiva de originales (16-nov-2026)

## Alcance y base protegida

Continuación de la rama de trabajo `codex/v75-118-aurora-v3-resource-integration` / PR #123 sobre V75.117 probada, **sin modificar** `v44-3-2-autosave-guest`, Firebase productivo, firmas, almacén de claves, IDs ni datos.

Se usaron los **bytes reales** de la carpeta de Biblioteca `THEDEMIAN_LAST_ZONE_AURORA_V3_80_RECURSOS` en un entorno local aislado. No se usaron fixtures para esta evidencia.

## Resultado verificado

- 24/24 archivos `AURORA_V3_ASSETS_NN_DE_24.zip` transferidos y abiertos con éxito; prueba CRC de cada ZIP correcta.
- Los 24 ZIP se extrajeron sin conflictos de rutas ni sobrescrituras divergentes.
- 7 originales grandes recompuestos desde sus fragmentos.
- **80/80 originales**: tamaño y SHA-256 iguales a cada entrada de `AURORA_V3_INVENTARIO_80.json`.
- **1.801.117.939 bytes** verificados; **75 SHA-256 diferentes** (duplicados conocidos conservados).
- 54 GLB, 25 MP3 y 1 ZIP identificados.
- La lectura independiente de los 54 encabezados GLB 2.0, JSON y listas de animaciones coincidió con el inventario. **33 GLB tienen al menos un clip registrado**; que exista no acredita retargeting ni reproducción con Lila.
- **25 GLB** superan 16 MiB y requieren revisión de memoria/optimización móvil.
- Derechos de 54 GLB según metadatos declarados: **50 CC BY 4.0**, **2 CC BY-NC 4.0**, **1 CC BY-ND 4.0**, **1 Sketchfab Standard**. Los **25 MP3** requieren verificar permisos propios. Ninguna declaración de licencia implica por sí misma autorización comercial final.

### Evidencia de integridad local

- SHA-256 del `SOURCE_AUDIT_80.json` generado: `b3259dcf4ffe8b2bd9d7ce3d3528aa75464ca9e0b687449aea6e0585128e8202`.
- SHA-256 del registro de extracción/verificación `RECOVERY_RUN.log`: `f76b28ea3b34c8e9f24db0f1265463aa9046c971bad6aebf76164c850bc88cb8`.
- Auditor reproducible agregado: `native-godot/tools/aurora_v3/audit_source_glb.py`.
- El inventario conserva las 80 huellas individuales; no se publican binarios de terceros ni archivos de firma en este commit.

### Otros paquetes reales recuperados

- 8/8 ZIP `AURORA_V2_PARTE_NN_DE_08.zip` extraídos con **44 entradas únicas**. Contienen 13 modelos de armas móviles anteriores, C-17 móvil, animaciones FPS y 11 candidatos V2, incluido `base01full_reupload.glb`. El documento `CONTENIDO_Y_PENDIENTES.json` explica que **22 recursos V2** (incluidos Toyota/BMW y otras armas) NO están incluidos en esos ocho ZIP; no declarar sus bytes recuperados.
- Adenda de pasos/Lila y adenda de granada/avión: **7 archivos fuente/derivados** comparados con los SHA-256 de sus manifiestos. Sus eventos pueden existir en código sin que los OGG se hayan incluido en APK.
- El ZIP original `siff.glb` de la adenda se verificó en bytes; su clip no se confunde con un paquete de combate.

## Qué esto NO demuestra

**No se han añadido los 1,80 GB de originales al repositorio ni a la APK**; esta es recuperación íntegra en un entorno local de auditoría. Los modelos aún requieren selección por permisos, presupuesto de polígonos/texturas, ejes, huesos, LOD/retargeting, sockets y prueba con la escena real. Los efectos de audio precisan autorización y enlace a eventos, no reproducción de bucles completos por cada disparo.

**El PR #123 sigue en borrador.** Las últimas dos CI verdes verifican las correcciones de código anteriores, no la importación de los 80 originales ni el comportamiento físico Motorola. Tampoco significan que el juego online o la persistencia Firebase estén terminados.

## Siguientes gates técnicos (sin convertir tareas pendientes en hechos)

1. Incorporar únicamente derivados optimizados y con permisos verificados, conservando trazabilidad al SHA del original.
2. Para cada arma, probar pose de dos manos, longitud visual, muzzle, primer/tercer plano, recarga, audio, daño, botín, IA y regreso de inventario entre BR/Entrenamiento.
3. Retarget de clips de arma/FPS a los rigs Lila y masculino sin sustituir locomoción ni controles.
4. Revisión visual a 964×434 / 1280×720 y prueba de 30/60/120 FPS en Motorola según dispositivo y escena.
5. Sin otra APK hasta que se completen los gates aprobados.

Este documento sustituye **solo** el bloqueo anterior de *acceso/reconstrucción de bytes V3*, no el bloqueo de implementación integral.
