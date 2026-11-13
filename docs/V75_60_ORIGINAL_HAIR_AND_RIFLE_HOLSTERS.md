# THEDEMIAN: LAST ZONE V75.60 — Identidad 3D de Lila y armas en la espalda

## Trabajo ejecutado
Basado en **V75.59** (GitHub Actions [#43360975642](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/43360975642): SUCCESS). Godot continúa como motor principal; la rama estable `v44-3-2-autosave-guest`, Firebase, perfiles y claves de firma preview no se modifican.

### 1. Peinado original y deformable para Lila
- Blender crea `LilaAuroraHairSculpt`: una sola malla con cuero cabelludo curvado, mechones posteriores, flequillo asimétrico, segmentos laterales recogidos y una atadura de cobre.
- **35 segmentos de cabello modelados** a partir de curvas interpoladas Catmull, volúmenes cónicos suaves y geometría cerrada. No son imágenes fijas ni planos 2D sobre el modelo.
- Tres materiales PBR originales: medianoche, petróleo y cobre; sin nuevas texturas descargadas o licencias externas.
- Los mechones cortos siguen el hueso real `rig:Head`; puntas de cabello largo usan ponderación gradual al hueso `rig:Spine` para acompañar las animaciones.
- Límite explícito: menos de 3.500 vértices authored, una malla skinned, tres materiales compartidos y **cero scripts de pelo por fotograma**.
- Usa el **mismo GLB** `aurora_operator.glb` en lobby 360° y gameplay. Se oculta exclusivamente el pelo original de Lila en los rigs rivales; los enemigos siguen siendo bots físicos con sus propios controles y LOD.
- **Importante:** el cabello geométrico es original Aurora, pero el rostro/cuerpo original CC0 continúa como base provisional. No declarar Lila definitiva o escultura facial AAA terminada.

### 2. Armas realmente colocadas en manos o espalda
- La clase `weapon_visuals.gd` mantiene el arma activa en `rig:RightHand`, con el **mismo** rayo, disparos, miras y montura de V75.59.
- Añade `SpineHolsterSocket` sobre el hueso real `rig:Spine` y `BackHolsterMount`; las armas secundarias acompañan animaciones de correr, agacharse, saltar y apuntar.
- AR equipada + AWM **poseída**: AWM aparece detrás de Lila; la mano conserva el AR.
- AWM equipada: AWM pasa a la mano y AR pasa a la espalda, sin desaparecer ni duplicar armas activas.
- AR equipada y AWM no recogida: ninguna AWM visible (ni en mano ni espalda). El equipamiento no puede saltarse el inventario.
- La propiedad se actualiza cuando se recoge de forma física la AWM del mapa y al reiniciar otra partida.
- Los modelos de rifle comparten sus GLB/recursos; por cada personaje se mantienen como máximo un arma activa y una secundaria visible. Sin efectos físicos, sonidos ni costes inventados.

### 3. Conservar lo ya logrado
- Cámara TPS, ADS x2/x4/AWM x8 y disparo arrastrable no se modifican.
- El arma en la espalda no cambia colisiones ni raycasts: solo geometría visible.
- Sin alteraciones de animation tree, FPS, paracaídas, botín de rivales, zona segura ni partidas locales.
- Los bots cercanos siguen usando su rig CC0 con LOD y colisiones; no usan la cabellera ni el uniforme exclusivo de Lila.

## Criterios verificables para el lote visual y de equipamiento

1. El GLB real incluye el peinado original nombrado `LilaAuroraHairSculpt`.
2. El nodo `LilaAuroraOriginalHair` aparece en el esqueleto de Godot con `Skin`.
3. Los tres materiales Aurora se exportan con nombres reconocibles.
4. Los vértices reales del pelo permanecen bajo presupuesto de GPU móvil.
5. El estilo contiene cap, flequillo, mechones posteriores y atadura lateral.
6. La deformación del peinado utiliza cabeza y torso existentes, no geometría estática.
7. Lila usa el mismo cabello en lobby y partida.
8. El lobby mantiene rotación táctil y escena 3D real.
9. Los rivales no muestran el peinado exclusivo de Lila.
10. Los rivales conservan Collider y LOD físico.
11. El AR sigue montado a la mano derecha.
12. El arma secundaria se monta en hueso Spine auténtico.
13. En entrenamiento ambas armas se consideran disponibles.
14. En Battle Royale la AWM no aparece antes de recogerla.
15. El AWM recogido aparece como arma secundaria en espalda.
16. Al equipar AWM, el AR original pasa a espalda.
17. Al volver a AR, la AWM vuelve a la espalda.
18. Al reiniciar partida no persiste una AWM no poseída.
19. Cámara y colisión del jugador permanecen intactas.
20. Fuente y APK exportada ejecutan todas las QA históricas y el nuevo ensayo V75.60.

> Estos son **20 criterios de aceptación de un hito integrado**, no 20 armas, personajes o versiones ni una certificación de las 1.000 mejoras. Cada criterio requiere evidencia real de CI.

## Validación automatizada

La CI del repositorio crea el GLB en Blender y valida nombres, `skins`, materiales PBR y límites de geometría antes de la importación en Godot. El test `v7560_lila_hair_holster_qa.gd` instancia `Main.tscn` y `Boot.tscn`, verifica Lila en lobby y partida, propiedad de armas, pickup físico, monturas, cambios, enemigos y reinicio. Se ejecuta en el proyecto original **y otra vez en recursos exportados** de una sola APK Android Vulkan Mobile ARM64, versionCode 50.

No se afirma que el aspecto ya sea fotorrealista o que se haya probado físicamente en Motorola. El usuario ha reservado la prueba manual para cuando él la autorice.
