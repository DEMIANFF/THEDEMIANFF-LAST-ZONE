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

El [inventario por original](aurora-v3/INVENTARIO_FUENTES_Y_DERIVADOS_113.csv) cruza los 33 nombres de `AURORA_AUDITORIA_33_ASSETS.csv` y las 80 entradas de `AURORA_V3_INVENTARIO_80.json` con los SHA de `COMPLETE_ASSET_LEDGER_148.json`, los manifiestos de derivados y los archivos de esta revisión. Contiene 113 filas y 108 SHA distintos. Los nombres de las pruebas señalan qué verificar. Los SHA originales provienen de las auditorías de recuperación. Una ruta opcional con el GLB ausente tiene ese estado explícito. El audio de disparo asignado a la P90 es `dennish18-machine-gun-129928.mp3`; falta acreditar el archivo y revisar el audio propio de recarga. La adenda de la canción y la del avión/granada se auditan fuera de estas 113 entradas.

## Revisión de referencia

La [revisión descargada de V75.189](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/45692175634) recalculó el SHA-256 de la APK y reunió seis posturas del juego. En la vista lateral de AWM el arma se mantiene horizontal. De frente se distingue la separación de los pies. Con la MP40 agachada el tronco queda muy inclinado y la pelvis alta; esta imagen justifica el cambio de postura de V75.190. Las imágenes proceden de Godot de escritorio.

## Próxima tarea exacta

Se añadió descenso de pelvis al modificador de contacto con compensación de ambas piernas en la misma pasada, separación gradual del arma respecto al torso de pie y muestreo de cabeza en el esqueleto final. La regresión conserva el mínimo de 0,35 m. La captura del lobby recorre todos los modelos instalados y comprueba el recurso mostrado, incluidos KRISS y P90. Las capturas de combate parten del personaje apoyado en el terreno. Se conserva el GLB publicado de Lila.

La [segunda batería](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/45691404802) alcanzó 199 de 200 pruebas. Pasaron la separación de muñeca y el descenso de cabeza. La pelvis bajó 0,356 m y el torso quedó a 20,28 grados de la vertical. La rodilla derecha midió 44,13 grados frente al intervalo aceptado de 60 a 150. El modificador ahora limita esa compresión con un desplazamiento del tobillo a lo largo del apoyo, conservando la altura sobre el plano de contacto. Ambas rodillas se registran en la QA.

Histórico [45691404802](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/45691404802), correspondiente a `41210c10278c84b3a20044745306cd26c47e35d9`, en el PR #188. Revisar la siguiente ejecución de la misma rama y sus capturas y contrastar las seis armas en la APK. Verificar la APK firmada con su nombre de paquete, versión, ABI, firma y SHA-256 antes de entregar. Tras cerrar esa compilación, continuar con el cargador superior de la P90 y el siguiente modelo con procedencia y permiso de distribución comprobados.

Trabajar en ramas de desarrollo con PR en borrador. Preservar la estable, la identidad y firma de Android, los datos de jugadores y los presets HUD. Validación de Firebase sin despliegues a producción. El BR mantiene sus 50 participantes.
