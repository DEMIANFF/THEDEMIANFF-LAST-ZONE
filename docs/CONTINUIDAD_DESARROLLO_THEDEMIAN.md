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
