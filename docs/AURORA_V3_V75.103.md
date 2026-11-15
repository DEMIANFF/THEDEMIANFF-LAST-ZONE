# Aurora V3 · V75.103 de desarrollo

La rama de esta entrega parte de `5ab44bee86acf5a86858b75e84a355cb8d773628`. Esa revisión de Lila tiene suite nativa y capturas aprobadas. [PR de Lila #107](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/pull/107) · [Validación de la base](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/43676807606)

## Mecánicas del incremento

- El Battle Royale de 50 participantes ofrece una SCAR, una MP40, un KRISS Vector, un suministro SMG, una jeringa y seis suministros de protección. La recogida pasa por la misma comprobación de proximidad y obstáculos del resto del botín. Las partidas internas de QA con menos participantes conservan sus suministros anteriores.
- SCAR y AR-7 comparten reserva AR y tienen cargadores independientes. La MP40 y el KRISS de V2 comparten reserva SMG y tienen cargadores blancos de 15 separados. Las tres incorporaciones pasan por rayos físicos, daño, cadencia, recarga, inventario y HUD. El rifle AR-7 y el AWM conservan sus identificadores, cadencias, capacidades y ópticas.
- La MP40 usa una recarga de 1,85 s en el esqueleto de Lila. La mano izquierda lleva la malla del cargador y el cerrojo se mueve por separado. Extracción, inserción y cerrojo disparan efectos de sonido en el mismo progreso de la mecánica. La reserva sólo cambia al terminar. Cambiar de arma devuelve las piezas a reposo y cancela la reposición.
- Cascos y chalecos tienen niveles 1–3, integridad separada, reposición al recoger una pieza del nivel equipado y protección contra cambios a un nivel inferior. El casco actúa sobre impactos físicos en la cabeza. La tormenta afecta salud directamente. Los valores iniciales de integridad son 15/30/45 para el casco y 25/50/75 para el chaleco.
- La jeringa se activa desde el inventario y repone hasta 20 de vida en 1,35 s. Usa las interrupciones de la curación existente. Se descuenta del inventario al terminar y conserva el botiquín de 3 s.
- La eliminación definitiva del operador emite su propio efecto sonoro. El audio lejano de los rivales toma su posición del evento de un disparo real y usa el sistema existente de voces limitadas y paneo por bus. Los efectos de esta revisión proceden del sintetizador de audio del proyecto.

## Procedencia y optimización

Las 24 partes adjuntas produjeron 80 originales verificados por el script del envío. Se conservó una copia de cada original fuera del proyecto Godot. Las tres armas se derivan de recursos que declaran CC BY 4.0 en sus metadatos. Los GLB conservan autor, URL de origen, licencia, huella de entrada y descripción de los cambios.

| Modelo | Triángulos del original | Triángulos del juego | Mallas del juego |
| --- | ---: | ---: | ---: |
| MP40 | 27.076 | 5.556 | 3 |
| SCAR | 27.319 | 4.894 | 2 |
| KRISS Vector | 4.359 | 2.900 | 1 |

- **MP40** por barking_dogo. Se conservaron una sola configuración de arma y su cargador separado, se redujeron geometría y texturas y se añadió un cerrojo visual original. [Modelo fuente](https://sketchfab.com/3d-models/mp40-2bb4ae9ba1fe4cd0a7b09a15612e00bc) · [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
- **Animated Scar** por JUST. Se extrajo la geometría del rifle, se descartaron las manos de primera persona y los rótulos, y se usaron dos materiales originales Aurora. El rifle de juego se monta en Lila y usa sus animaciones de asalto. [Modelo fuente](https://sketchfab.com/3d-models/animated-scar-5e64d6245bba4a819b9fef578c34b3fe) · [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
- **KRISS Vector** de Aurora V2 por Ngakau Blake. Se combinaron las 51 mallas en una, se simplificó la geometría y se sustituyó el atlas por un material Aurora. [Modelo fuente](https://sketchfab.com/3d-models/kriss-vector-smg-1454b627e1bc4b50a87b2665ac41244e) · [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)

Para regenerar el derivado de armas, ejecutar Blender en modo trabajo por lotes.

```bash
blender -b --python native-godot/tools/build_aurora_v3_weapons.py -- /ruta/aurora-v3/originales native-godot/assets/weapons/aurora_v3 /ruta/aurora-v2/kriss_vector_smg.glb
```

El audio candidato de MP40 y los MP3/OGG de terceros se conservaron fuera del repositorio de publicación. Sigue pendiente confirmar los permisos de redistribución de cada fuente y revisar en escena una grabación completa de la recarga. Las mallas equipables de cascos y chalecos y la jeringa requieren ajuste visual a Lila. Las piezas de combate de la IA conservan su conjunto de armas anterior.

## Pendientes

- Validar mapas, ópticas y C-17 de V2 como incrementos separados. Confirmar licencias y rendimiento de cada recurso elegido.
- Revisar más armas y sus animaciones, efectos sonoros definitivos, el retargeting de SCAR desde su animación de primera persona y el conjunto de animaciones masculino.
- Completar emotes, recompensas permanentes y temporales, skins y tienda de diamantes. Las transacciones de diamantes requieren confirmación autoritativa y una política de canje antes de publicar.
- Completar granada, otros suministros y recargas por familia. Verificar manos, deformación y rendimiento de Vulkan en el Motorola Edge 60 Fusion antes del siguiente APK.

La validación de desarrollo emplea Godot 4.7.2. El flujo de exportación Android sigue reservado a ejecución manual, con el mismo identificador de aplicación y las mismas verificaciones de firma.
