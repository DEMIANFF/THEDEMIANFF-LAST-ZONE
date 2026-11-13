# THEDEMIAN: LAST ZONE — V75.62 · Enemigos con botiquín limitado y recargas tácticas

## Continuidad obligatoria
Base: V75.61 `codex/v75-61-lila-motion-precision-vulkan`, GitHub Actions [#43457739440](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/43457739440) = SUCCESS. Esta rama no modifica la estable `v44-3-2-autosave-guest`, Firebase, perfiles, firma, paquete ni respaldos. Motor principal Godot. **Una sola APK Vulkan Mobile ARM64** versionName `75.62.0-mobile-vulkan`, versionCode 52. Pruebas Motorola físicas pendientes de autorización del usuario.

## Mejoras jugables reales
- Cada rival IA `CharacterBody3D` del Battle Royale obtiene **un botiquín de campaña en su equipamiento inicial**. No se regenera ni se concede por temporizadores o simulación de jugadores.
- El rival herido (HP ≤38) puede comenzar a curarse si no tiene un enemigo a la vista, no recarga al mismo tiempo y se encuentra dentro del círculo seguro real.
- La aplicación requiere **3 segundos completos** de física; no concede salud al pulsar un botón de menú ni al crear el personaje.
- Durante el canal se detienen sus disparos, el bot reduce velocidad de movimiento y utiliza el clip de postura de `AuroraCrouch` sobre su esqueleto.
- Un golpe real de jugador, otro enemigo o la zona interrumpe la curación. El botiquín sigue disponible para otro intento, pero hay una pausa de 1,25 s que evita bucles de curación instantánea.
- Una curación completa consume **exactamente uno** y recupera hasta 40 HP sin exceder 100. No existe salud infinita.
- El letrero 3D cambia a **«RIVAL / CURANDO»** solo mientras el estado es real; restaura «ENEMIGO IA» al terminar o ser interrumpido.
- La comprobación del canal usa el delta físico, compatible con el escalonamiento de frames de los enemigos distantes que ya existe para 20/30 bots.
- Los bots con ≤4 balas y sin objetivos visibles empiezan una recarga anticipada de su cargador físico de 18, respetando los 2,25 s existentes. Ante rivales visibles, priorizan el combate.
- La recarga, botiquines, avisos, impactos, heridas e inventarios se reinician sin filtraciones al comenzar otra partida o reaparecer en entrenamiento.
- Se mantienen navegación física, coberturas, persecución por sonido, límites de raycasts (≤5 por ciclo), IA contra IA, disparos físicos y botín al morir.

## Verificación integrada
Nueva QA `v7562_bot_medicine_tactics_qa.gd`, integrada en la suite existente de 66 pruebas aproximadamente, junto al proyecto fuente y recursos exportados en APK. La prueba instancia `Main.tscn` con los personajes y el terreno reales; valida:
1. Botín inicial de un solo botiquín y su rango de activación.
2. Inicio de canal con indicador 3D auténtico.
3. Ausencia de sanación antes de terminar los 3 segundos.
4. Interrupción inmediata por daño físico de un jugador.
5. Conservación del botiquín tras interrupción.
6. Pausa táctica de reintento.
7. Bloqueo de curación con un enemigo visible.
8. Bloqueo de curación fuera del círculo seguro.
9. Inicio autónomo desde `_physics_process()`.
10. Curación de HP real, con límite máximo.
11. Consumo unitario del medkit, sin duplicación.
12. Prohibición de regeneración cuando se acaba el medkit.
13. Recarga anticipada al quedarse con pocas balas y sin enemigo visible.
14. Cero disparos durante los 2,25 s de recarga.
15. Cargador completo y contador de recargas al finalizar.
16. La recarga no se inicia anticipadamente con rival visible.
17. Limpieza de estadísticas y medkit al reiniciar BR.
18. El algoritmo de percepción y física no requiere clientes online ficticios.
19. No se modifica ni el orden de las transiciones críticas de avión/paracaídas ni la configuración Firebase.
20. Tests nativos y de la APK Vulkan deben terminar PASS antes de declarar este avance aprobado.

**Limitación:** sigue siendo un Battle Royale offline con 1 jugador + 8/19/29 bots físicos. No se afirma multijugador real con 50 humanos ni que los 1.000 tickets ya estén resueltos. El botiquín inicial IA no es una malla visible en las manos durante el uso; el estado jugable se indica con animación de agacharse y rótulo 3D.

## Criterio de terminado
No fusionar el PR mientras CI de fuentes/Android exportado no sea verde. No considerar una prueba de escritorio Linux como medición del rendimiento del Motorola Edge 60 Fusion.
