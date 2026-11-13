# THEDEMIAN: LAST ZONE — V75.63 · Curación animada real de Lila

## Base y continuidad
**Base exacta:** V75.62 `codex/v75-62-tactical-bot-medicine-vulkan`, PR #63. Su CI GitHub Actions [#43460995681](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/43460995681) terminó **SUCCESS**. No modificar `v44-3-2-autosave-guest`, Firebase, firmas, respaldo, paquete, Unity o las transiciones de vuelo que ya fueron comprobadas. Se exporta **una sola** APK Android ARM64 Vulkan Mobile, versionCode 53, versionName `75.63.0-mobile-vulkan`.

## Hito jugable, no pantalla simulada

### Animación 3D auténtica (Blender + Godot)
- Se añade la acción original **`AuroraHeal`** al generador Blender existente: 90 fotogramas a 30 fps (3 segundos), integrados en el mismo `aurora_operator.glb` compartido por lobby y partida.
- Ambos brazos y antebrazos realizan poses de curación con keyframes en articulaciones del rig real, y el torso inclina ligeramente la pose durante el canal.
- `operator_animation.gd` clasifica `AuroraHeal` como **one-shot no repetible** que se mezcla encima de Idle y posturas, sin convertir la curación en una animación de caminar o destruir el AnimationTree.
- No se presenta como captura conceptual ni como cinemática: es animación que el motor usa realmente cuando Lila consume un botiquín.

### Inyector Aurora: prop 3D reutilizable
- Se incorpora un inyector táctico original con cuerpo PBR blanco, tapa metálica, ventana de dosificación azul iluminada y símbolo de medicina en relieve.
- El objeto se ensambla una sola vez al crear al personaje (cinco MeshInstance3D de geometría ligera), **no** durante cada fotograma.
- Se adjunta al hueso **LeftHand** real mediante `BoneAttachment3D` y compensa la escala del GLB original, de la misma forma que las armas ya usan huesos de manos/espalda.
- Solo es visible durante curación activa. No aparece en lobby, avión, caída, paracaídas, correr, combate ni después de terminar una partida.
- El objeto es visual: **no da salud por sí mismo**, no crea suministros ni altera colisiones o peso físico.

### Integración con inventario y salud física
- La misma función `_on_heal()` existente sigue siendo la fuente única de verdad para tiempo real de curación, salud, botiquines, coste y HUD.
- Al comenzar los 3 segundos activa simultáneamente la animación y el inyector 3D.
- Recibir daño real, mover el joystick, disparar, activar mira ADS, recargar, cambiar de arma o pulsar nuevamente CURAR cancela el canal **y** oculta el dispositivo sin descontar una carga.
- Únicamente la finalización real restaura hasta 45 HP, consume un botiquín y retira el prop 3D; el temporizador no puede aplicarse dos veces.
- Nuevo BR, muerte, abandonar el combate y transición a aeronave limpian la animación y no dejan un inyector permanente adherido a la mano.

## 20 criterios de aceptación verificables
1. El GLB exportado contiene `AuroraHeal` (no animación vacía).
2. Duración de `AuroraHeal` aproximadamente 3 segundos.
3. AnimationTree incorpora `AuroraHeal` como upper-body one-shot sin loop.
4. Lila conserva su rig original con esqueleto articulado.
5. El objeto médico tiene cinco componentes geométricos reales.
6. El color/ventana Aurora utiliza material 3D y no un icono flotante.
7. El inyector está bajo `BoneAttachment3D` sobre `LeftHand`.
8. El inyector conserva posición finita y cercana a Lila.
9. El objeto comienza invisible sin curación.
10. El canal empieza solo mediante la curación real autorizada.
11. Lila reproduce el clip importado con `AnimationNodeOneShot`.
12. Salud y consumibles no cambian durante los segundos parciales.
13. El botón CURAR puede cancelar sin gastar botiquín ni dejar inyector.
14. Daño físico cancela animación, HUD y canal al mismo tiempo.
15. Movimiento de joystick cancela el uso y retira el inyector.
16. Finalizar el canal aplica 45 HP máximos y consume exactamente uno.
17. El inyector desaparece cuando termina la curación real.
18. Reiniciar partida limpia animación, HUD y medkits del encuentro.
19. En avión y transición aérea no queda un inyector colgado.
20. Pasan pruebas históricas de fuente y paquete Android Vulkan exportado.

Nueva prueba `v7563_lila_real_medkit_qa.gd` sobre `Main.tscn`, personaje real y botín real. La CI valida además que el GLB producido por Blender contiene la nueva animación y que la APK exportada vuelve a superar todas las pruebas existentes. El PR permanece draft hasta pruebas verdes.

## Limitaciones abiertas
La cara y parte del cuerpo de Lila siguen sobre una base CC0 provisional, aunque ya lleva peinado lavanda y uniforme Aurora original parcial. El nuevo inyector no sustituye una animación con IK avanzado para manos, ni acredita por sí mismo 60 FPS en el Motorola. El juego continúa offline contra bots; **no son 50 humanos conectados**. La meta de 1.000 mejoras es un plan acumulativo auditable y no una cifra declarada terminada.
