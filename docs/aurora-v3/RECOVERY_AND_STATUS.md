# Aurora V3 — recuperación e integración desde V75.117

Estado integral: **PENDIENTE / BLOQUEADO**, no listo para publicación. Fecha: 16 de noviembre de 2026.

Base conservada: `89408684f423ac698c45ddd39fc2b25c0ac1b4fb`, rama `codex/v75-117-motorola-signed-test-build`. Se consultaron las 199 ramas existentes y las ejecuciones recientes. Esta base incluye el trabajo AWM/audio previo y tres commits posteriores de preparación y validación de la APK probada. Su ejecución anterior es [43948762228](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/43948762228). Esa evidencia anterior no valida este incremento.

Nueva rama: `codex/v75-118-aurora-v3-resource-integration`. [PR borrador #123](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/pull/123). Se mantienen los identificadores V75.117 de exportación: todavía no hay una nueva APK.

## Qué se encontró

El inventario V3 tiene **80 originales: 54 GLB, 25 MP3 y un ZIP**, 1.801.117.939 bytes en total y 75 SHA-256 distintos. Los duplicados son parte de la trazabilidad y se conservan como archivos individuales.

Se localizaron las 24 partes, inventario, mensaje maestro, licencias de los 54 GLB, asignaciones de audio, registro anterior de 80 hashes correctos, script original de reconstrucción y ambas adendas. Se leyeron esos documentos completos. Localizar el archivo y leer su inventario no equivale a descargar sus bytes. **En esta sesión no existe entorno local de ejecución**: no se ha repetido la reconstrucción de los paquetes ni la verificación de los 80 originales. El registro anterior es evidencia histórica suministrada, no una verificación nueva.

El árbol V75.117 contiene seis derivados de originales V3: SCAR, MP40, casco, chaleco táctico, chaleco pesado y jeringa. También contiene KRISS de V2, AR-7 con el AK74 anterior y una AWM generada por el proyecto. **La AWM existente no es el archivo `awm.glb` del inventario V3.** El modelo de botiquín y la Barrera Aurora existentes tampoco prueban integración de `simple_botiquin.glb` o del muro de referencia con marcas.

El constructor de SCAR extrae mallas y exporta sin skins ni animaciones. Sus cuatro clips originales no están retargeteados: el arma usa acciones actuales de Lila. MP40 no tiene clips originales; su recarga actual usa la acción de Lila y movimientos programados de cargador/cerrojo. Ninguno de estos hechos prueba agarre correcto de dos manos en todas las poses.

## Resultado actual

[Incremento verificado, ejecuciones y capturas reales](../AURORA_V3_VALIDATED_INCREMENT.md). El código validado se identifica por su SHA exacto; una actualización posterior de documentación no equivale a otra compilación. La recuperación de los 80 originales sigue bloqueada.

## Cambios de juego de este incremento

Al entrar a Entrenamiento real, aparecen cinco recogidas físicas al oeste del punto inicial: SCAR, MP40, KRISS, munición AR y SMG. Usan las mismas mallas, prueba de obstrucción, inventario, rayos de disparo y recarga que BR. No se regalan armas antes de recogerlas. El cargador SMG blanco sigue en 15 y la reserva MP40/KRISS es compartida.

La mesa no se crea al abrir el editor HUD desde el lobby ni durante BR. Comenzar BR la elimina y restaura el inventario inicial del modo. No se modifica el lobby, el avión, el paracaídas ni el número de participantes. La nueva regresión comprueba recogida automática, daño a un oponente físico, recarga y ausencia de filtración de suministros entre modos.

También se corrigen la orientación y los anclajes de SCAR/AWM, la posición de la SCAR en el botín y el apoyo de las cinco armas actuales sobre los brazos de Lila. Se mantiene el tamaño de los huesos; el arma debe quedar delante del torso. La corrección se libera para las acciones actuales de recarga/curación/vuelo. Las 45 poses muestreadas se revisaron en escritorio.

Esto facilita y mejora las armas ya integradas; **no incorpora las restantes familias del inventario ni recupera los clips originales descartados**. Las transiciones continuas, los dedos, todos los ángulos de cámara y el operador masculino necesitan aceptación adicional.

## Matriz y procedencia por recurso

- [Matriz legible de los 80 originales](INTEGRATION_MATRIX.md).
- [Matriz JSON con cada etapa y bloqueo](INTEGRATION_MATRIX.json).
- [Inventario original leído](AURORA_V3_INVENTARIO_80.json).
- [Relación de los seis derivados ya presentes](runtime_derivatives.json).

Cada registro conserva original, tamaño y SHA esperado, declaración de licencia, duplicados, ruta/escena, clips originales, estado de animación/sonido/función y pruebas. El auditor de derivados calcula sus hashes actuales y comprueba que `asset.extras.source_sha256` coincide con el inventario. Esto verifica la trazabilidad grabada en el derivado; **no vuelve a calcular el hash del original ausente**.

## Recuperación reproducible

Los ZIP son 24 archivos independientes, no volúmenes para concatenar. Los modelos grandes se reconstruyen desde `fragmentos/*.parteNNN`.

Colocar las 24 partes con sus nombres exactos en una carpeta de trabajo y ejecutar con Python 3.11 o posterior:

```bash
python3 native-godot/tools/recover_aurora_v3.py recover \
  --parts /ruta/partes-aurora-v3 \
  --output /ruta/aurora-v3-recuperado
```

El destino debe ser nuevo y quedar fuera de `native-godot`. El proceso verifica presencia de las 24 partes, rechaza rutas que escapen del destino y archivos ZIP conflictivos, conserva duplicados, ejecuta una copia sin modificaciones del `RECONSTRUIR_AURORA_V3.py` entregado y vuelve a comprobar tamaño/SHA de todos los originales. Solo publica el directorio final si termina correctamente. No modifica los ZIP ni sobrescribe recuperaciones anteriores.

Produce `RECOVERY_REPORT.json` y `RECONSTRUCTION.log`. Para repetir únicamente los hashes:

```bash
python3 native-godot/tools/recover_aurora_v3.py verify \
  --originals /ruta/aurora-v3-recuperado/originales
```

Las pruebas del recuperador utilizan archivos sintéticos para verificar corrupción, partes ausentes, duplicados, protección contra sobrescritura y rutas inseguras. **Que pasen no demuestra acceso a los 80 archivos reales.**

## Adendas y V2, fuera del conteo de 80

| Recurso | Evidencia existente | Integración y bloqueo |
|---|---|---|
| `siff.glb` | SHA fuente esperado `53e39259ccbcf83ce749da6f688e19bbdf0485fa1f10bd40371c9776bfaac2cb`, fijado en el constructor del gesto | El repositorio contiene un extracto retargeteado de 12 s para el lobby de Lila; no el GLB original completo ni un conjunto de animaciones de combate. Reconstrucción/revisión visual nueva pendientes. |
| `freesound_community-walking-46245.mp3` | SHA esperado `8bd34b2e6a38829e728eb3f65821dc1516992bd353db2781588c61c4c3b5b571` | Eventos de apoyo y conversor existentes; los recortes de audio no están en el repositorio. Licencia y bytes pendientes de revalidación. |
| `freeeverythingxx-running-on-concrete-268478.mp3` | SHA esperado `3ac5acd848e0c34808122b087a5f000893d100fc685122413279d67edd41fffe` | Misma separación entre eventos implementados y audio ausente. |
| `AURORA_GRANADA_EXPLOSION.ogg` | SHA esperado `f6a973a97bf366db7491283e13e1c63a9eb6a5830d014cb51972fc1c3cf49e0f` | Granada física, daño radial/oclusión y evento sonoro existentes; el OGG suministrado no está distribuido en GitHub. Hash del MP3 original pendiente de recuperar del manifiesto de adenda. |
| `AURORA_AVION_SOBREVUELO_TRANSICION.ogg` | SHA esperado `875bc4e8f50dcd00d9fd7e93e586e60bf2e2914a8bdf53eb8d6fa5a0a6065aa9` | Evento de una entrada en vuelo y cancelación al saltar existentes; OGG ausente. Es un barrido, no un motor en bucle. |
| `AURORA_LOBBY_MUSICA_LOOP_GODOT.ogg` | SHA esperado `9a8e3d5e3bd385cd8682a4789621d0fe74d1af87a4d0d65471cb759e01fe10f2` | Servicio de reproducción persistente existente; pista ausente. Permisos y constancia de descarga pendientes. |
| Aurora V2 | Localizadas ocho partes y leídos ambos mensajes maestros | V2 añade 33 archivos más el paquete previo. Sus vehículos, mapas, miras, ropa y C-17 no están en los 80 originales V3. |
| Toyota/BMW, pino, mapas V2 | Documentación declara geometría elevada; no nueva medición de bytes | Optimización, colisiones, conducción, cámaras y controles pendientes. No se consideran vehículos jugables. |
| C-17 V2/paquete anterior | Modelo visual descrito sin clips; no bytes recuperados aquí | Mantener avión actual; no sustituirlo hasta validar licencia, escala y rendimiento. |

Los dos documentos V2 difieren sobre qué optimización de texturas recibió el paquete. No se adopta una cifra como verificada sin inspeccionar los archivos y el manifiesto interno.

## Licencias

El inventario declara 50 GLB CC BY 4.0, dos CC BY-NC 4.0, uno CC BY-ND 4.0 y uno Sketchfab Standard. Los 25 MP3 y el ZIP de guantes requieren comprobación individual. Las declaraciones no son una revisión actual de las fuentes ni de derechos adicionales sobre marcas/personajes.

Los NC, la adaptación de la granada ND, el saludo Standard y los recursos con derechos de terceros pendientes permanecen retenidos para la distribución prevista. No se incorporan nuevos binarios de terceros en este PR. Se conservan los originales existentes; no se eliminan activos privados para resolver una licencia.

## Verificación y límites

El flujo `aurora-v3-integration.yml` prepara los recursos actuales de la base, importa Godot 4.7.2 y ejecuta la suite completa: cámara, combate, vuelo, paracaídas, HUD, colisiones, persistencia y regresiones anteriores. Genera 45 capturas reales de las cinco armas actuales sobre Lila y captura el lobby conservado. Usa renderizado de escritorio para evidencias. Android conserva Mobile/Vulkan.

Los logs, hashes de derivados, manifiesto de poses y capturas se publican como artefactos del commit exacto. Las capturas deben revisarse; un archivo PNG o un CI verde no cierran la aceptación visual ni el retarget masculino. No hay prueba física nueva en Motorola ni medición de FPS/VRAM Android en esta sesión. No se exporta APK intermedia.

| Bloque | Estado | Falta para cerrarlo |
|---|---|---|
| Base y documentación de recursos | HECHO | Conservar trazabilidad y revisar cualquier nuevo avance antes de integrar. |
| 80 SHA originales y adendas | BLOQUEADO | Entorno que pueda recuperar, descomprimir y leer los bytes. |
| Entrenamiento con armas actuales | HECHO | Recogida, disparo, recarga y aislamiento de BR verificados en Godot; evidencia en el informe del incremento. |
| Cinco armas actuales: orientación, anclajes y apoyo en poses revisadas | HECHO | Alcance de escritorio documentado; no certifica todas las animaciones ni Android. |
| Todas las familias y agarres en el bloque integral | PENDIENTE | Recuperación, selección, sockets, dedos y evaluación completa de poses/transiciones. |
| Clips originales y retarget Lila/masculino | PENDIENTE | Analizar canales/huesos y validar visualmente cada clip compatible. |
| Audios suministrados | BLOQUEADO | Recuperar archivos y comprobar permisos para distribución. |
| Vehículos/mapas/cosméticos/emotes restantes | PENDIENTE | Recuperar V2/V3, optimizar, implementar lógica y validar. |
| Motorola físico / rendimiento Android | PENDIENTE | Pruebas registradas en el dispositivo; no sustituibles por CI. |
| APK integral | BLOQUEADO | Completar y validar el bloque integral conforme al encargo. |
