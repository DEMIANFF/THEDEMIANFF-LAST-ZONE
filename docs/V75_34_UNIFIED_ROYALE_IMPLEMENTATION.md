# THEDEMIANFF LAST ZONE V75.34 — paquete único integrado V75.31–V75.34

## Base e identidad
Esta versión es una **sola actualización** sobre V75.30 (PR #43) — no cuatro APK ni cuatro prototipos. Los cambios de V75.24 (audio Android), V75.26 (cámara/joystick), V75.27 (editor HUD), V75.28 (seis casas/botín/zona), V75.29 (zona sincronizada con IA) y V75.30 (audición de disparos) permanecen. Estable `v44-3-2-autosave-guest`, Unity, Firebase y certificados de producción sin modificar.

## Mejoras integradas

### Animaciones de Lila y control
- Preservar el AnimationTree esquelético con las animaciones auténticas de correr, caminar, apuntar, agacharse, saltar, aterrizar y recargar de los GLB importados.
- La inclinación lateral del **modelo visual** acompaña los cambios diagonales de desplazamiento y se interpola con delta time. La cápsula CharacterBody y el eje de la cámara permanecen independientes: no se altera la dirección de bala, las colisiones ni la sensibilidad del HUD.
- La prueba de integración exige los clips esqueléticos de carrera/agachado y la histéresis que evita alternancias abruptas de gait.

### IA y combate
- Los bots conservan reacción auditiva V75.30 y combates entre sí.
- Un bot herido y bajo supresión recalcula una posición de cobertura real alcanzable y conserva la lógica existente para salud crítica; el daño por zona sigue teniendo prioridad de movimiento. La navegación existente aplica límites de consultas por fotograma.
- El sistema sigue comprobando la línea de visión antes del disparo y no permite atravesar paredes.

### Inventario, armas y equipo físico
- El BR comienza con **AR-7** en el primer hueco. La **AWM** se obtiene mediante un pickup 3D real al oeste de Puerto Aurora; antes de recogerla el cambio de arma no puede equiparla. Entrenamiento conserva las dos armas existentes.
- Ocho interiores aportan munición/botiquines/barrera y, en las dos viviendas nuevas, un chaleco y una mochila táctica.
- Chaleco: absorbe el 65% del daño de balas hasta agotar **75 puntos**; la zona causa daño directamente a la vida. La mochila amplía reserva AR de **180 a 360** y reserva AWM de **30 a 60**; rechaza loot cuando se supera el límite.
- Botón táctil **MOCHILA** con pantalla del inventario real (munición cargada/reserva, estado AWM, chaleco, botiquines, barreras); el botón participa en el editor HUD persistente anterior. Se cierra en avión, resultados o reinicio.
- Al reiniciar BR se restituyen las reservas y se exige recolectar de nuevo AWM/chaleco/mochila; el mapa repuebla los pickups sin duplicar progreso guardado.

### Puerto Aurora
- De seis a **ocho casas** con paredes/tejados/suelos/puertas y mobiliario físicos. Se agregan dos puntos residenciales en (-52,44) y (72,50), paseo oeste sobre la misma triangulación de terreno, jardineras y palmas.
- Conserva la zona segura de 4 fases sincronizada en el mundo, HUD e IA.
- Total del sector: **16 cápsulas exteriores previas + 8 interiores + 1 AWM = 25 pickups**.

## QA / aceptación
- `v7528_coastal_br_expansion_qa.gd` ahora recorre físicamente **8 casas** e intenta recoger los **8 suministros interiores**; sus radios no son simulaciones.
- `v7534_integrated_royale_qa.gd` comprueba compra/recogida física de AWM, chaleco, mochila, arma bloqueada antes de botín, absorción real de salud y daño ambiental, HUD actualizado, cambio de arma, reacción de IA y reinicio sin equipo filtrado.
- La batería `run_qa.sh` se aplica al proyecto nativo y al bytecode exportado. La CI Android verifica ARM64/firma/namespace, siempre que la ejecución finalice satisfactoriamente.

## Límites honestos
La compilación CI y QA headless no sustituyen prueba táctil/performance en Motorola Edge 60 Fusion. **Sigue siendo BR offline 1 jugador + 8 bots**, no multijugador de 50 jugadores, ni un juego ya completo para publicación. `versionCode=33`, nombre V75.34 y mismo paquete preview `com.thedemianff.lastzone.nativepreview`, sin reemplazar firma. No se debe fusionar el PR hasta superar CI y prueba física.
