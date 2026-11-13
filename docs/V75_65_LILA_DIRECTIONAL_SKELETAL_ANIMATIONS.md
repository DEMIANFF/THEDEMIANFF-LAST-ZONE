# THEDEMIAN: LAST ZONE — V75.65: animaciones tácticas direccionales reales de Lila

## Continuidad y límites
Base directa: **V75.64**, PR #66, CI [#43473576674](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/43473576674) = SUCCESS. Godot 4.7.2, **Android ARM64 Vulkan Mobile exclusivamente**, `versionCode 55` y una sola APK firmada. Conservar `v44-3-2-autosave-guest`, certificados de preview, Firebase/Auth, respaldos y el paquete Android existente. El usuario ha confirmado buena jugabilidad en Motorola para V75.63; no afirmar pruebas físicas de esta versión.

## Trabajo verdadero de animación 3D integrado
1. **Tres secuencias esqueléticas originales** generadas con Blender desde el mismo rig de Lila: `AuroraArmedStrafeLeft`, `AuroraArmedStrafeRight`, `AuroraArmedBackpedal`. Son clips con claves para los huesos de pierna, rodilla, pie, pelvis y brazos, no sprites, traslaciones arbitrarias del modelo o cambios de textura.
2. **Contactos de pies y movimiento lateral**: se reutiliza el solver real de muslo/tibia de la locomoción actual. Los objetivos de pies se desplazan a lo largo de X al esquivar y a lo largo de -Z al retroceder; el centro de masa se ajusta de manera ligera sin mover el cuerpo de colisión.
3. **Dirección ligada a la física**: `third_person_operator.gd` calcula el desplazamiento después de `move_and_slide()` y lo convierte al marco local del personaje, diferenciando izquierda, derecha, retroceso y avance. Cuando una pared bloquea el movimiento, ningún paso lateral se muestra artificialmente.
4. **Tercera persona y miras**: al apuntar con ADS o mantener disparo, los pasos laterales y atrás conservan la dirección del fusil y de la vista; al dejar ADS, vuelve la locomoción clásica en la dirección del movimiento. No hay nueva cámara que reemplace la que funcionaba en Motorola.
5. **Fases de pies sincronizadas**: el `AnimationTree` conserva sincronización temporal entre `AuroraArmedWalk`, `AuroraArmedRun`, ambos pasos laterales y el retroceso. Transiciones con crossfade del modelo real en lugar de reiniciar los pasos y provocar saltos en las piernas.
6. **Recarga y armas mientras se desplaza**: las animaciones de recargar/disparar/curar siguen funcionando por encima de las piernas con el filtro superior existente, de modo que Lila puede recargar mientras camina lateralmente. El HUD, las armas AR-7/AWM y el soporte dorsal no se sustituyen.
7. **No interferir con fases sensibles**: avión, caída libre, paracaídas, aterrizaje, agacharse, salto, colisión, Firebase y guardado permanecen intactos.

## Criterios de aceptación
- El GLB real contiene las tres animaciones esqueléticas con nombres y duración coherentes, no objetos estáticos.
- El AnimationTree incluye y reproduce los tres clips mediante el estado de locomoción.
- El personaje se desplaza realmente a izquierda y derecha sobre suelo con colisión y muestra la animación que corresponde.
- Mientras se desplaza hacia atrás y apunta, utiliza el retroceso en lugar de caminar hacia delante.
- Caminar hacia delante con ADS sigue usando la animación existente; no se altera velocidad ni alcance de cámara.
- La pierna de Lila presenta rotación real durante el paso lateral, sin congelar muslo/rodilla.
- Recargar arma AR/ AWM conserva el blend superior sin bloquear las piernas.
- El jugador inmovilizado por una colisión no genera pasos ficticios.
- Salir de ADS devuelve la orientación y el movimiento anteriores; no aparece temblor del giro.
- Restablecer la partida limpia ADS, sprint y estados de locomoción; el AnimationTree se mantiene activo.
- Toda la suite histórica debe seguir pasando en código fuente y en los recursos extraídos de la APK, sin borrar pruebas regresivas.
- La compilación Android debe ser Vulkan Mobile ARM64, firmada y actualizable conservando el package.

## QA reproducible
Archivo añadido `native-godot/scripts/qa/v7565_tactical_strafe_animation_qa.gd`. Instancia `Main.tscn`, usa un suelo `StaticBody3D`, el modelo real `Skeleton3D` de Lila y movimiento táctil/ADS. Valida la selección desde desplazamiento, las piernas articuladas, la recarga superpuesta, los controles, la cámara y el reinicio. Se vuelve a ejecutar en fuentes y en recursos exportados Android.

**Estado**: este documento describe el cambio implementado. La V75.65 solo se declarará aprobada cuando GitHub Actions termine en SUCCESS. No equivale a animación final de captura de movimiento, IK dos manos pulido ni a las 1.000 mejoras terminadas.
