# THEDEMIAN: LAST ZONE — V75.66 · Cerrojazo AWM, retroceso de armas y fogonazo 3D

## Continuidad técnica
Se desarrolla directamente sobre **V75.65** (PR #67), aprobada por [GitHub Actions #43485140537](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/43485140537). Godot es el motor principal; un único APK Android **ARM64 Vulkan Mobile**, versión `75.66.0-mobile-vulkan`, versionCode **56**. Mantener `v44-3-2-autosave-guest`, Firebase, identidades, respaldos, firma y paquete Android sin cambios. El usuario reportó V75.63 funcionando en Motorola; esta versión aún no tiene prueba física.

## Mejoras reales, no conceptuales

**Animación original de cerrojo AWM.** El generador Blender de Lila exporta `AuroraBoltAWM` como clip de **15 fotogramas a 30 FPS**. El modelo mueve hombro, codo, antebrazo, muñeca y torso con una reacción inicial al disparar y retorno del brazo al accionar el cerrojo, sin mover la raíz ni interferir con el collider. El `AnimationTree` lo registra como acción superior de una sola ejecución. Cada disparo físico de la AWM invoca este clip durante el mismo **cooldown de 0,50 s** que ya gobierna el arma. El AR-7 conserva `AuroraFire` de corta duración.

**Fogonazo 3D reutilizable.** `weapon_visuals.gd` crea una única vez una pequeña malla de ignición y dos destellos cruzados (tres mallas, materiales de sombreado simple, sin sombras ni nuevas luces). Solo se muestra brevemente tras un disparo real que disminuye munición. No se crean nodos ni materiales por bala. El efecto usa la posición de boca del arma, tanto AR como AWM, y se apaga después de 0,075 s.

**Retroceso visible distinto por arma.** El AR recibe 0,022 rad de retroceso y la AWM 0,092 rad por disparo, limitados a 0,14 rad y recuperados con `delta`; el disparo sucesivo no puede acumular descontroladamente la posición del modelo. El retroceso de muñeca/torso está animado por Blender; el retroceso del arma solo modifica visualmente su montura. Cuando se cambia de arma, se cura o se reinicia partida, el destello y el retroceso se limpian.

**Balística independiente de los adornos.** La munición, el daño, los headshots, la protección física de coberturas y el cálculo de impactos siguen usando el rayo preexistente. Se calcula y conserva el origen de boca en el espacio físico **antes del retroceso decorativo**; por tanto, el fogonazo no altera el origen del raycast ni concede precisión falsa. Los apoyos de mano y espalda existentes siguen anclados al esqueleto real.

## Pruebas y aceptación
El nuevo script `v7566_awm_bolt_visual_recoil_qa.gd` instancia el `Main.tscn` real, su `AnimationPlayer` y su `Skeleton3D`. Verifica:
1. El GLB posee `AuroraBoltAWM` con duración cercana a 0,50 s y pistas de hombro, antebrazo, mano y torso.
2. El filtro de animación superior está activo y la locomoción inferior no cambia por disparar.
3. La boca del AR permanece en el mismo lugar físico antes y después del retroceso decorativo.
4. Una bala real de AR causa exactamente un destello y una reacción visual pequeña.
5. El fogonazo se oculta y el arma se estabiliza sin crear partículas/nodos por disparo.
6. Pulsar con cargador/reserva vacíos no genera efectos de fuego falsos.
7. Cambiar de AR a AWM limpia destellos pendientes y conserva el modelo en mano.
8. La AWM conserva la mira exclusiva x8, una bala por pulsación y cerrojo de 0,50 s.
9. El disparo de AWM activa la animación esquelética propia y un retroceso visual mayor.
10. El retroceso de la AWM no cambia el rayo balístico físico.
11. El destello de AWM desaparece después de su vida útil.
12. Durante curación real el fusil pasa a la espalda y no puede generar destellos ficticios.
13. Cancelar curación restaura el fusil que realmente estaba equipado.
14. Cambiar de arma no conserva destellos ni retroceso del arma anterior.
15. Una nueva ronda de BR no conserva la AWM sin recoger ni los efectos anteriores.
16. Toda la suite histórica debe seguir pasando en código fuente y recursos exportados de la APK.
17. La CI certifica firma Android v2/v3, ARM64, alineación de 16 KiB y un solo APK Vulkan.

Estos son **criterios de aceptación**, no 17 mejoras independientes cerradas de la meta de 1.000. El clip de cerrojo es original generado con los huesos disponibles; no constituye todavía mocap AAA ni IK completo de dedos/gatillo. No se afirma rendimiento medido en Motorola ni 50 humanos online.

## No se modifica
Avión, caída libre, paracaídas, escala de mapa, zona, IA, botín, Firestore/Firebase/Google, backups, HUD configurable, sensibilidad, cámara TPS y la integridad del movimiento de Lila. El pulido adicional de manos, poses y materiales queda pendiente de resultados visuales e inspección en hardware.
