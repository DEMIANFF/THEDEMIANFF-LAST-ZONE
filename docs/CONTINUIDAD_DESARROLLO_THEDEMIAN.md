# Continuidad de THEDEMIAN: LAST ZONE

Actualizado el 25 de noviembre de 2026. Proyecto `native-godot/`, Godot 4.7.2, Android ARM64 con Vulkan Mobile. Dispositivo de referencia Motorola Edge 60 Fusion.

## Punto de recuperación

| Versión | Rama y revisión comprobadas | PR | Compilación | Resultado comprobado |
|---|---|---|---|---|
| V75.188 | `codex/v75-188-operator-weapon-transition` · `25861973b7e5cd08dd916244394e496bb2a72e7f` | [#186](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/pull/186) | [45671650639](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/45671650639) | Última entrega aprobada al recuperar la sesión. |
| V75.189 | `codex/v75-189-lila-body-contact-performance` · `6a304691a22460a8276545d26fedb8e889a905cc` | [#187](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/pull/187) | [45684774492](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/45684774492) | CI verde, incluida la exportación y la verificación firmada. Se usa para comparar la postura con V75.190. |
| V75.190 | `codex/v75-190-p90-original-armory` · `3971048b4140c28625efb7eb1d96554244d74738` | [#188](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/pull/188) | [45685705379](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/45685705379) | V75.189 es ancestro directo de la serie, con tres commits adicionales y cero detrás. La importación y las dos pruebas nuevas pasaron. La batería completa detuvo la exportación. |

## Regresiones que impiden cerrar la V75.190

- `weapon_visual_qa` midió 0,04269 m desde el centro de la cápsula hasta la mano. Comprobar la mano respecto al pecho real y conservar una guarda para la postura de pie.
- `v752_regression_qa` midió 0,27291 m de descenso de la cabeza frente a los 0,35 m exigidos. Conservar la flexión de piernas, el apoyo de los pies, el torso erguido y los agarres. Contrastar el descenso con la altura de colisión.
- Las QA específicas `v75189_lila_body_performance_qa` y `v75190_p90_original_qa` pasaron en ese mismo job. Este run terminó antes de capturas, firma y exportación.
- Se mantienen como pendientes el contacto visual de las extremidades, la P90 en la armería del lobby y la comprobación física de FPS, temperatura y controles en el Motorola. La observación física comunicada es de 20 FPS.

## Recursos y trazabilidad

Los archivos de referencia son `AURORA_V3_INVENTARIO_80.json`, `MENSAJE_MAESTRO_WORK_AURORA_V3.md`, `THEDEMIAN_INVENTARIO_AURORA_V2_V3_148_2026-11-19.md`, `THEDEMIAN_RECUPERACION_AURORA_V2_V3_113_ORIGINALES.md` y `THEDEMIAN_PROYECTO_MAESTRO_1000_MEJORAS.pdf`. La recuperación del 20 de noviembre documenta 33 entradas V2 y 80 V3, con 108 huellas distintas en el conjunto. El inventario de 148 incluye material documental. Se localizaron los 24 ZIP V3 y los 8 paquetes V2 en la máquina actual. La verificación de los originales y la de sus derivados se registran por separado.

| Recurso | SHA-256 de la fuente | Procedencia y derechos registrados | Ubicación y función | Evidencia |
|---|---|---|---|---|
| Lila | `62da843e0649b4274f5af4dfc75dfa3fa557d094224922c002498d5c28e15cbd` | Original aportado para el proyecto, fijado en `tools/build_lila.py`. Conservar el original privado y la malla aprobada. | `native-godot/assets/characters/lila_aurora.glb`, avatar de lobby y combate. 56 huesos. | QA de identidad, animación y contacto corporal. Revisión visual pendiente en esta revisión. |
| Modular P90 Tactical | `3daa1c9d1596a223a95ef873271adb961cbf6d75bfcdebf59f6a71b434e1a67e` | Aurora V2, doomsentinel, CC BY 4.0. Enlace y atribución en `assets/weapons/aurora_v2_optional/README.md` y en Ajustes. | `native-godot/assets/weapons/aurora_v2_optional/aurora_p90.glb`, subfusil de 50 en el catálogo, inventario y combate. Fuente estática. | `v75190_p90_original_qa` comprueba geometría, agarre, recarga, reserva y créditos. Falta comprobar la ruta del lobby. |

El catálogo incluye rutas opcionales que solo representan integración si el GLB está presente, se importa, se usa en el juego y pasa su prueba. El audio dedicado de la P90, las licencias de los candidatos y la aparición de cada modelo en armería y combate deben comprobarse individualmente.

El [inventario por original](aurora-v3/INVENTARIO_FUENTES_Y_DERIVADOS_113.csv) cruza los 33 nombres de `AURORA_AUDITORIA_33_ASSETS.csv` y las 80 entradas de `AURORA_V3_INVENTARIO_80.json` con los SHA de `COMPLETE_ASSET_LEDGER_148.json`, los manifiestos de derivados y los archivos de esta revisión. Contiene 113 filas y 108 SHA distintos. Los nombres de las pruebas señalan qué verificar. El 25 de noviembre se leyeron los 24 ZIP V3 y los ocho ZIP V2. Se reconstruyeron en orden los archivos partidos. Coincidieron los SHA-256 recalculados para los 80 originales V3 y los 11 originales incluidos en estos ZIP V2. En las otras 22 filas V2 figura la huella de la auditoría anterior. El inventario conserva los ZIP y miembros exactos, el tamaño verificado y la evidencia por fila. Una ruta opcional con el GLB ausente tiene ese estado explícito. El audio de disparo asignado a la P90 es `dennish18-machine-gun-129928.mp3`; falta acreditar el archivo y revisar el audio propio de recarga. La adenda de la canción y la del avión/granada se auditan fuera de estas 113 entradas.

## Adendas comprobadas en los archivos recuperados

| Archivo | SHA-256 medido | Uso y estado |
|---|---|---|
| `AURORA_AVION_SOBREVUELO_TRANSICION.ogg` | `875bc4e8f50dcd00d9fd7e93e586e60bf2e2914a8bdf53eb8d6fa5a0a6065aa9` | Conversión verificada en el ZIP. El instalador es opcional y el medio está ausente de la revisión pública. |
| `AURORA_GRANADA_EXPLOSION.ogg` | `f6a973a97bf366db7491283e13e1c63a9eb6a5830d014cb51972fc1c3cf49e0f` | Conversión verificada en el ZIP. El instalador es opcional y el medio está ausente de la revisión pública. |
| `freesound_community-hq-explosion-6288.mp3` | `aca0d73a429c99709c42d3f310a4a2baecaab2bf962c4c973e6540a7c313a7ae` | Original del efecto, cotejado con el manifiesto de granada y avión. |
| `storegraphic-deep-long-air-transition-311051.mp3` | `f70ea2b63b16b092f09d2298529adf8ef2bd3165df9d0bdf5d1c1cf0599c9487` | Original del efecto, cotejado con el manifiesto de granada y avión. |
| `freesound_community-walking-46245.mp3` | `8bd34b2e6a38829e728eb3f65821dc1516992bd353db2781588c61c4c3b5b571` | Grabación de pasos de la adenda. El juego dispone de lógica de reproducción y mezcla de reserva. |
| `freeeverythingxx-running-on-concrete-268478.mp3` | `3ac5acd848e0c34808122b087a5f000893d100fc685122413279d67edd41fffe` | Grabación de pasos de la adenda. El juego dispone de lógica de reproducción y mezcla de reserva. |
| `siff.glb` | `53e39259ccbcf83ce749da6f688e19bbdf0485fa1f10bd40371c9776bfaac2cb` | Modelo de la adenda con 141 articulaciones. El operador del juego conserva el original rigged-model.glb. |


La [MP5 de JUST](https://sketchfab.com/3d-models/animated-mp5-19278d5f4a334f4abf320bc303ff9be1) identifica a tnnv como autor de la malla. La [ficha del original de tnnv](https://api.sketchfab.com/v3/models/25c2dac7d675420a9511e040f2a8e462) declara CC BY-NC 4.0. Se retiene la entrada privada de inventario. La SCAR instalada procede de [JUST](https://sketchfab.com/3d-models/animated-scar-5e64d6245bba4a819b9fef578c34b3fe) con geometría de [notcplkerry](https://sketchfab.com/notcplkerry), CC BY 4.0. El derivado combina materiales, simplifica la malla y excluye los brazos de primera persona.

La fuente del [HK416 de r4m](https://api.sketchfab.com/v3/models/a16768f0ffa24737a4fe324a411cfbd9) y la del [VSS de DOSOWERT](https://api.sketchfab.com/v3/models/82fc1c6264434ede987079a834b1994b) declaran CC BY 4.0. Los nombres opcionales del catálogo se conservan hasta montar y validar los derivados correspondientes.

El PDF maestro de 13 páginas, edición del 13 de noviembre, organiza 1.000 entregables en 20 áreas. Su base histórica era V75.59. La guía de 29 apartados es otra orden de trabajo. Los ocho apartados finales de esa orden siguen pendientes de recuperar palabra por palabra. La instrucción de continuidad del 25 de noviembre mantiene el ámbito vigente, incluida la validación física, el servicio multijugador y la protección de las ramas.

## Revisión de referencia

La [revisión descargada de V75.189](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/45692175634) recalculó el SHA-256 de la APK y reunió seis posturas del juego. En la vista lateral de AWM el arma se mantiene horizontal. De frente se distingue la separación de los pies. Con la MP40 agachada el tronco queda muy inclinado y la pelvis alta; esta imagen justifica el cambio de postura de V75.190. Las imágenes proceden de Godot de escritorio.

## Próxima tarea exacta

Se añadió descenso de pelvis al modificador de contacto con compensación de ambas piernas en la misma pasada, separación gradual del arma respecto al torso de pie y muestreo de cabeza en el esqueleto final. La regresión conserva el mínimo de 0,35 m. La captura del lobby recorre todos los modelos instalados y comprueba el recurso mostrado, incluidos KRISS y P90. Las capturas de combate parten del personaje apoyado en el terreno. Se conserva el GLB publicado de Lila.

La [segunda batería](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/45691404802) alcanzó 199 de 200 pruebas. Pasaron la separación de muñeca y el descenso de cabeza. La pelvis bajó 0,356 m y el torso quedó a 20,28 grados de la vertical. La rodilla derecha midió 44,13 grados frente al intervalo aceptado de 60 a 150. El modificador ahora limita esa compresión con un desplazamiento del tobillo a lo largo del apoyo, conservando la altura sobre el plano de contacto. Ambas rodillas se registran en la QA.

Histórico [45691404802](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/45691404802), correspondiente a `41210c10278c84b3a20044745306cd26c47e35d9`, en el PR #188. Revisar [45694204319](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/45694204319) en `92a85aaf16b2ba7516aab69cc7057c9be6317aa1` y sus capturas y contrastar las seis armas en la APK. Verificar la APK firmada con su nombre de paquete, versión, ABI, firma y SHA-256 antes de entregar. Tras cerrar esa compilación, continuar con el cargador superior de la P90 y el siguiente modelo con procedencia y permiso de distribución comprobados.

Trabajar en ramas de desarrollo con PR en borrador. Preservar la estable, la identidad y firma de Android, los datos de jugadores y los presets HUD. Validación de Firebase sin despliegues a producción. El BR mantiene sus 50 participantes.

## Continuidad V75.191 — 25 de noviembre de 2026

V75.190: CI completa aprobada en `92a85aaf16b2ba7516aab69cc7057c9be6317aa1`, [45694204319](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/45694204319), APK firmada [15062318657](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/45694204319/artifacts/15062318657). Los dos commits posteriores hasta `154d5d3d76106ce2094a45ff558d4e01e7ef6d9e` son documentación/inventario. El usuario aportó dos capturas y vídeo de 10.6 segundos: postura de lobby desequilibrada, rodilla levantada durante crouch inmóvil y 24 FPS. La versión instalada no está identificada. V75.191 corrige la diferencia verificable del idle de lobby: conserva brazos sin arma y usa postura inferior estable de AuroraArmedIdle, local a la instancia; elimina emote automático y conserva interacción explícita. Amplía QA de crouch inmóvil en 8 muestras durante 120 ticks físicos. No cambia el GLB ni el IK de combate aprobado hasta reproducir el defecto en la versión exacta. Pendiente CI, prueba física y perfil de rendimiento.

## V75.192 — presupuesto de zona y percepción

V75.191 aprobada: `55d6cbaaf5bbdb98cef258efde7c2454a33ee277`, CI [45716371937](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/45716371937), APK [15072007168](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/45716371937/artifacts/15072007168). V75.192 reutiliza direcciones, colores, índices y material del anillo, reduce sondeos de altura de 176 a 88 por reconstrucción, calcula una sola vez la siguiente zona para todos los rivales y evita cálculos repetidos de rango de percepción. Conserva geometría, 50 participantes, shortlist de cinco y rayos reales. QA histórica ampliada con comprobaciones de geometría y comparación de candidatos contra fuerza bruta. No se afirma mejora de FPS medida; CI y dispositivo pendientes. Próximo: perfilar datos reales del Motorola, revisar postura física y continuar recarga P90 y recursos licenciados.

## V75.193 — gesto de recarga P90

Base V75.192 aprobada `858babda67310e0ab86b0eb42169a665ebbfe519`, [CI 45721532056](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/45721532056), [APK](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/45721532056/artifacts/15073778459). V75.193 añade objetivo de mano superior aproximado dentro de las dimensiones de la P90 original y trayectoria procedural de ida/retorno, sincronizada con los 1.8 s del temporizador de recarga y resuelta por el IK real de ambos brazos. No hay clip original ni extracción de cargador: identificar la malla de cargador y comprobar animación/audio visual sigue pendiente. QA verifica conservación de munición, alcance IK y cancelación al cambiar arma. CI y prueba física pendientes. Próximo: validar recarga visual, identificar malla original del cargador y recuperar HK416/VSS autorizados.

## V75.194 — audio sincronizado P90

Base V75.193 aprobada `5c52770cd8c642b184f41b3f21072e9fce515fe7`, [CI 45727641930](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/45727641930), [APK](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/45727641930/artifacts/15077212733). V75.194 añade disparo P90 diferenciado y tres efectos procedurales originales sincronizados con el gesto de recarga a 12%, 32%, 82%; reutiliza banco PCM y voces existentes, sin DSP durante combate. Reinicia eventos al cancelar y evita duplicar audio genérico. QA comprueba eventos ordenados, cancelación, transferencia de munición y recursos de audio. Registra nombres y límites de ocho mallas reales para identificar el cargador en la siguiente auditoría. La descarga de blob GLB falló por decodificación UTF-8 en el conector; no se afirma que se haya identificado o animado el cargador. CI y prueba física pendientes. Próximo: revisar registro de partes, integrar originales licenciados HK416/VSS si están disponibles.

## V75.195 — presupuesto de dibujo del minimapa

Base V75.194 aprobada `18cc97016a5132097a0e540a674f276363f7174b`, [CI 45733239403](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/45733239403), [APK](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/45733239403/artifacts/15079327607). V75.195 reutiliza 64 direcciones y polígono de pantalla; UVs cambian solo con posición, orientación o alcance, rotación con una base por disco. Agrupa segmentos visibles de cada zona en un comando CanvasItem; caché limitada a ocho resoluciones. QA compara proyecciones y segmentos contra cálculo original, comprobando movimiento, giro, redimensionamiento y tamaño de caché. Sin cambios de daño, mapa, radar táctico ni participantes. HK416/VSS siguen ausentes en inventario de rama; malla de cargador P90 no identificada. CI y rendimiento físico pendientes.

## V75.196 — locomoción de Lila

Continúa de V75.195 `5d66a9695f5e267d9b45a5d44363ccbc3681a84b`, CI 45740132673 aún en curso al abrir la rama dependiente. Última base plenamente aprobada V75.194. Corrige prioridad de salto/caída sobre postura ADS/agachada y usa velocidad física de referencia del clip final (crouch walk, strafe, backpedal, walk/run), mientras poses estáticas, salto y aterrizaje mantienen reproducción 1x. No altera velocidad física, colisiones, esqueleto ni datos. Amplía QA física de movimiento con crouch y salto ADS. Ambas CI y revisión física pendientes; si falla V75.195, corregir y preservar cambios en V75.196 antes de aprobar APK. Próximo: medir FPS en Motorola, animaciones y recuperar originales autorizados.

## V75.197 — presupuesto de audio espacial

Base de trabajo V75.196 `1fc00a350f7b536c577f5945f404dbf950409fd7`, CI 45740405243 en ejecución al comenzar; V75.195 también pendiente. V75.197 evita escrituras repetidas de paneo y atenuación al mezclador: umbral .005 de paneo y .10 dB respecto al último valor aplicado, refresco obligatorio al reutilizar voz. Conserva 5 voces de disparos, 6 efectos posicionales, curva de atenuación y barrera AudioServer.lock/unlock introducida por cierres Android históricos. QA verifica 120 actualizaciones idénticas sin nuevas escrituras y respuesta al desplazamiento/reutilización. Biblioteca: se localizaron los 24 ZIP V3 y adendas; los MP3 requieren verificación de permisos según AURORA_V3_ASIGNACIONES_AUDIO.md. HK416/VSS originales V2 no localizados por búsqueda nominal. No se publicaron bytes externos. CI y prueba física pendientes; si una dependencia falla corregirla antes de aprobar APK.

## V75.198 — recuperación V2 y animación de cargador P90

Base dependiente V75.197 `497439dd3e6c022b829c2239025879ef030ec579`, CI anteriores aún en curso al abrir rama. Recuperado de Biblioteca `THEDEMIAN_AURORA_V2_TRES_ARMAS_GODOT_PRIVATE.zip` (10,791,012 bytes); los tres GLB preparados coinciden con SHA-256 del manifiesto: HK416 `dae024ca21a784553c3c588f67c9c6dc64f0ef2309b2a1d9a81b59bbc09c237d`, VSS `57decf52b1ed0c661786c13192a414f2e9b5ef59b72a6976f94e210080578576`, P90 de staging `0560b555ce3c01014d9fb689b93bd48cf2a600b2a66b844ec8db94f29406308c` (no sustituye P90 móvil actual). Son derivados estáticos, no originales sin procesar. El GLB P90 inspeccionado contiene MagazineLPB001_Magazine_0 y MagBody_Magazine_0, ambos material Magazine. V75.198 anima conjuntamente esas dos mallas originales mediante recorrido visual procedural de .045 m y objetivo IK vinculado, con retorno exacto en final/cancelación. QA comprueba dos piezas, desplazamiento y geometría restante intacta. No se han publicado los binarios privados HK416/VSS: requieren transferencia desde contenedor al repositorio y revisión de derechos adicionales (CC BY 4.0 declarada). CI y comprobación física pendientes; revisar todas las dependencias antes de aprobar APK.

## Recuperación selectiva de armería V2 (rama de herramientas, sin incremento de versión)

Base V75.198 `2bcb41d1297579091173ca785a085de2192fc3be`. CI V75.195–198 en curso al iniciar. Inspección efectiva del ZIP privado recuperado: HK416 3,701,616 bytes, VSS 1,300,744 bytes, P90 7,695,924 bytes; los tres SHA-256 coinciden con manifiesto. El instalador histórico se bloquea ante la P90 posterior ya existente. Se añade `--models HK416 VSS`, valida todo el archivo antes de escribir y omite destinos excluidos. QA de Python comprueba preservación de la P90 nueva, rechazo de corrupción incluso en miembro excluido y ausencia de escrituras ante conflicto. No se modifica la APK ni se transfieren binarios privados. CI ligera separada para no interrumpir las cuatro compilaciones Android. Pendiente ejecutar instalación en copia Godot real y comprobar licencias adicionales, agarres y dispositivo.

## Prisma3D — banco privado de animaciones

V75.198 aprobada CI 45741063833; V75.195–197 y QA privada de armería también aprobadas. Base de herramientas PR #197 `1b81f9574554e3f240eb9565f7fa3f057305bcd1`. Se inspeccionó Modelo del usuario, recuperó el GLB original de Lila y generaron localmente 13 clips candidatos (9 ventanas completas y 4 variantes de piernas), conservando geometría, 56 huesos y longitudes; todos los 2568 frames originales incluidos. Banco y GLB permanecen privados: licencia del archivo Prisma no declarada, aún sin prueba visual en Godot ni física. Se publica solo herramienta de incorporación selectiva a copia privada y QA sintética; no se reemplazan clips activos ni se altera versión, firma o Firebase. Detalles: docs/aurora-v3/PRISMA_PRIVATE_MOTION_REVIEW.md. Próximo: verificar permiso y revisar visualmente ciclos, agarres, suelo y movimiento antes de activar candidatos.

## Prisma3D — ciclos privados de locomoción

Base PR #198 `ace462e1f9af30bc231fc812f627e929125fa4db`, CI 45745687864 verde. Se reabrió banco privado SHA verificado y analizaron posiciones reales de tobillos/dedos mediante cinemática directa. Seleccionados cuatro ciclos de piernas A/B/C/rápida, 23/55/46/18 intervalos. Se añade opción `--gait-cycles` al instalador de revisión, conserva los 13 anteriores y animaciones del destino, cierra diferencia numérica de extremos, rechaza costuras grandes; tres pruebas nuevas. No activa gameplay ni publica datos privados. Sin prueba Godot/Motorola ni licencia aclarada. CI ligera pendiente.

## Lila Aurora reconstrucción 2K — revisión privada 1

Base PR #199 `ef24ad63192fa8e4388ac661becbf3ae4d26f074`, CI 45750532632 verde. Se reconstruyeron pesos anatómicos y matrices de bind sobre la malla original del usuario, recolocando muñecas y dedos, tobillos y puntas; 52 deformadores, 30 dedos con pesos, 56 huesos, 93.572 vértices, 95.885 triángulos conservados, dos mapas 2048². 57 clips corregidos y 11 nuevos candidatos procedurales (479 fotogramas). Comparativa offline 160010/1371 incidencias de aristas >10x en 25 poses antiguas (99,14% reducción); cero incidencias de ese umbral en los 479 nuevos fotogramas. GLB privado SHA `1c6c4c8bf3fb1d36624e95d5041cf222c55b003f9ffcfd2c6e9bb0b0c409e3a1` entregado al usuario junto a scripts y auditorías. Se publica verificador de integridad y QA sintética; no se reemplaza modelo activo. Falta revisar dedos parcialmente fusionados, clipping, optimización de geometría, adaptar Prisma al rig corregido y validar en Godot/Motorola. Ver docs/aurora-v3/LILA_REBUILD_2K_PRIVATE_REV1.md.

## Lila Rev2 — contrato de animaciones

# Lila 2K Rev2 — candidato privado compatible con nombres Aurora
Base Rev1 SHA 1c6c4c8bf3fb1d36624e95d5041cf222c55b003f9ffcfd2c6e9bb0b0c409e3a1. CI de PR #200 45753994669 verde. Candidato Rev2 generado localmente: SHA ab0df204ebe5cdbd2c9472af22eb672eac6cc9cec3818e6859baf1d884c3aa12, 20.060.196 bytes frente a 23.740.256 en Rev1 (15,50% menos). No es reducción de polígonos: conserva exactamente 95.885 triángulos, 93.572 vértices, todos los pesos, matrices de bind, nodos, texturas 2K. Se seleccionan 27 acciones nuevas con nombres del AnimationTree, se añade TEXCOORD_1 de vestimenta siguiendo fórmula de build_lila.py, se compactan 1.351 pistas constantes y se deduplican accessors. Los 68 clips de Rev1 permanecen en su archivo independiente. Las acciones son procedurales candidatas, no captura Prisma retargeteada ni aprobadas por gameplay.

Auditoría offline de los 924 fotogramas de las 27 acciones: cero incidencias >10x en aristas de referencia >0,0003 unidades; máximo 9,433; separación lateral mínima de tobillos 0,114 unidades del rig. 13 ciclos cierran extremos. Se corrigieron inicialmente postura de paracaídas y separación de pasos laterales. No se verificó clipping de suelas o arma, rendimiento ni importación Godot. Se publica gate de SHA y script de revisión Godot local real; este último todavía NO ejecutado. Usar:

    python3 native-godot/tools/aurora_motion/validate_lila_runtime_private.py /ruta/privada/Lila_Aurora_2K_Rev2_Runtime_PRIVADA.glb
    godot --headless --path native-godot --script res://tools/aurora_motion/private_lila_runtime_review.gd -- /ruta/privada/Lila_Aurora_2K_Rev2_Runtime_PRIVADA.glb

No sustituir el modelo activo ni publicar APK. Pendientes permisos, importación local, IK manos, colisiones, cabello/dedos parcialmente fusionados, ajuste de contacto con suelo, prueba física y reducción real de polígonos. Los binarios y scripts de generación/auditoría se entregan en paquete privado.

# Lila Rev3 — corrección privada de altura de apoyo

Base Rev2 SHA ab0df204ebe5cdbd2c9472af22eb672eac6cc9cec3818e6859baf1d884c3aa12. CI PR #201 45809931230 verde (fixtures sintéticos). Rev3 SHA b3fd330483756a16d2a5022776428e54db39f916404ec70438b64de37932b896, 20.079.776 bytes. Se modificaron solo las pistas verticales de pelvis de 24 acciones no aéreas. Se calcularon posiciones de 11.557 vértices de la región inferior de las botas mediante skinning lineal, cinemática directa e interpolación SLERP. Todas las influencias ponderadas descienden de Hips; la corrección de pelvis traslada la malla sin alterar sus deformaciones relativas. Se insertaron 1.246 claves de pelvis y se evaluaron 2.468 muestras incluyendo intermedios. Error máximo de altura del vértice inferior respecto al plano de bind: 0,02532049 unidades (Rev2, claves de corrección) y 0,00161441 (Rev3, incluyendo intermedios), reducción 93,62%. Las cifras son unidades del rig, no metros del juego. Se verificó identidad exacta de geometría, UV, pesos, matrices inversas, rotaciones, materiales, imágenes 2K, y de las tres acciones aéreas Jump/Freefall/Parachute. Se conservan 27 clips. No se certifica contacto de toda la suela, deslizamiento horizontal, pendientes, recorte ni estabilidad de IK en runtime.

Paquete privado entregado al usuario THEDEMIAN_LILA_2K_REV3_CONTACTO_PRIVADA.zip incluye GLB, ground_lila_rev3.py, dependencias y ground_report.json. Se amplía el gate y la revisión Godot existentes a ambas SHA explícitas. No se ejecutó importación Godot, no se publica binario, ni cambia la APK, Firebase o firma. Falta comprobar IK real, dedos, optimización de geometría, derechos y Motorola. No sustituir el personaje de producción.

## Lila Rev4 — optimización conservadora y auditoría individual de dedos

# Lila Rev4 privada — almacenamiento exacto, orden de índices y respuesta de dedos

Base Rev3 bf7ad33e63d665e4638b709ebd699039ee2efc3b, CI PR #202 45811169727 verde. GLB fuente SHA b3fd330483756a16d2a5022776428e54db39f916404ec70438b64de37932b896. El ensayo de simplificación conservadora (colapso de aristas internas, preservando costuras UV y las regiones de rostro/cabello/manos/botas) redujo solo 82 triángulos, 95885 a 95803, por lo que se descarta como candidato de producción. No se afirma reducción de polígonos en Rev4 final.

El candidato final usa exactamente los 95885 triángulos y 93572 vértices de Rev3. Reordena triángulos sin cambiar sus índices individuales ni winding; convierte JOINTS_0 de uint16 a uint8 (todos los valores <56). Todos los demás bufferViews se verifican idénticos byte a byte. Pesos, UV, normales, posiciones, matrices de bind, texturas 2K y 27 acciones incluida corrección vertical de pelvis intactos. SHA final 2a4c00e4ec9afcfcc7d529d73dadb85e57b94f80e2b59a6e25c7f599b5289c7d; 19.705.684 bytes (20.079.776 antes, 374.092 bytes menos). Simulación LRU de vértices de 16 entradas: 121655→99689 fallos; 32 entradas: 110069→95935. No son resultados de GPU, FPS ni memoria real en Godot.

Prueba de skinning lineal offline de cada uno de los 30 huesos de dedos con rotación aislada +20 grados local X: todos producen algún desplazamiento (>1e-5 unidades de rig), ningún vértice de la mano contraria afectado. Tres falanges terminales tienen solo 2–3 vértices con influencia positiva (LeftHandRing3, RightHandMiddle3, RightHandRing3); LeftHandThumb3 tiene 10. Se mantiene la limitación de dedos parcialmente fusionados: no se afirma separación anatómica, agarres válidos ni calidad visual aprobada. No modificar los pesos solo para aumentar conteos. Se requiere reconstrucción de topología y revisión física.

Paquete privado THEDEMIAN_LILA_2K_REV4_RUNTIME_PRIVADA.zip incluye candidato final, scripts reproducibles, informe de ensayo descartado y auditoría por dedo. Gate Python y script de importación Godot aceptan Rev2/3/4 con SHA exacta; nueva prueba sintética valida encoding y límites de índices de huesos. Todavía no se ejecutó Godot con el GLB real. Sin publicar binarios privados, cambio de APK, firma ni Firebase. Pendientes: derechos, anatomía dedos, agarres, optimización geométrica de calidad visual demostrada, prueba física Motorola.

## Lila Rev5 — corrección de manos y auditoría de deformación

# Lila Rev5 privada — ajuste anatómico de pivotes y pesos de manos

Base Rev4 PR #203, CI 45812085494 success, SHA GLB 2a4c00e4ec9afcfcc7d529d73dadb85e57b94f80e2b59a6e25c7f599b5289c7d. Se analizaron las superficies reales de cada mano por separado y se ajustaron 30 pivotes de falanges mediante secciones robustas de la geometría, recalculando matrices inversas de bind. Las curvas locales guían las influencias; se suavizan sobre aristas conectadas, sin introducir nueva influencia fuera de la región de manos. Cambian pesos de 1090 vértices (546 posiciones soldadas). Normalización máxima 1.19e-7; error de reposo de región probada 2.27e-8 unidades.

Prueba aislada +20 grados X local: LeftHandRing3 3→137 vértices con peso positivo, RightHandMiddle3 2→117, RightHandRing3 3→103; mínimo de los 30 dedos 33 vértices directos y 31 desplazados por encima de 1e-5 unidades. Ninguna mano contraria afectada. Auditoría de todos los tiempos de clave distintos de cada uno de los 27 clips: 1500 muestras, 3430 aristas de la región de manos y SLERP/traslación lineal. Estiramiento máximo de arista 1.659612→1.270104; cero >3x o >10x antes y después en región probada. Geometría, UV, triángulos, normales, texturas 2K y pistas de animación idénticas. No se separan los dedos fusionados ni se prueba contacto de armas. No es medición de FPS.

GLB candidato c9b755349a4dc2692f45f3bec1918001d72a05f01b3bcad4aff406c743afb74b, 19.706.572 bytes, 95.885 triángulos, 93.572 vértices, 56 huesos, 27 clips. Paquete privado THEDEMIAN_LILA_2K_REV5_MANOS_PRIVADA.zip contiene GLB, scripts reproducibles y auditorías reales. Gate Python comprueba SHA, índices compactos, pesos normalizados e influencia directa en los 30 dedos. Script de revisión Godot incluye verificación de soporte positivo tras importación (no ejecutada). CI usa fixtures sintéticos. Godot no instalado en entorno local; descarga del motor bloqueada por resolución DNS. No se cambia modelo de producción, APK, Firebase ni firma. Pendientes separación anatómica, IK de armas, permisos, importación Godot y prueba Motorola.
