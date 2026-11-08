# V74 — Auditoría del battle royale nativo y entrega de sector offline

Fecha de implementación: noviembre de 2026. Rama `codex/v74-aurora-offline-royale`, hija de `codex/v73-2-tps-fire-drag`.

## Alcance real de la versión
Esta entrega introduce un **modo de partida que comienza y termina** dentro de un sector 3D existente: **9 participantes simulados (jugadora + 8 bots offline)**. No equivale aún a la versión comercial deseada con 100 humanos y un mapa de 8×8 km.

### Jugabilidad
- Dos estados: entrenamiento anterior (4 bots con reaparición) y **Batalla Aurora** (botón «INICIAR BR»).
- Ocho bots Battle con colisión, percepción por raycast, disparos, daño entre bots, eliminación permanente, contador real de supervivientes y victoria cuando solo queda la jugadora.
- Derrota del personaje al llegar a 0 HP durante Batalla. En entrenamiento sigue la reaparición anterior.
- Zona circular de peligro: se reduce de 90 m a 12 m durante 280 segundos, causa daño gradual al quedar fuera y tiene barrera 3D siguiendo el relieve; el radar muestra el círculo.
- 16 suministros 3D del mundo, recogidos al entrar físicamente en su área (munición AR, munición AWM y botiquines), con contadores reales. Dos botiquines iniciales.
- Reinicio del mismo modo con salud, munición, armas, enemigos, zona, botín y marcador restaurados.
- Indicador de salud, destello de daño recibido, aviso de disparo, retícula centrada y panel de resultado con bajas y duración.
- Señal visual de tiros hitscan que no introduce discrepancia entre la dirección del daño y el raycast de la cámara.
- Controles TPS heredados V73.2: vista libre, FUEGO con arrastre, AR x2/x4, AWM x8, correr, saltar, agacharse, recargar, curar y cambiar arma.

### Mejoras visibles de mundo
- 110 pinos árticos y 62 cristales glaciares como objetivo de instancias GPU (la cantidad colocada depende de que el terreno esté emergido); colisiones de troncos cercanos y cartelería original sectorial.
- Cuatro edificios originales preexistentes con entradas, ventanas, tejados inclinados y colisión. Estas construcciones **todavía necesitan mejores mallas, materiales, muebles e interiores**.
- La captura del flujo Android activa «Batalla Aurora» antes del fotograma para verificar HUD y barrera en un modo real de partida.

## Errores encontrados y corregidos durante V74
- GitHub Actions: fallo de sintaxis YAML por dos puntos sin comillas en nombre de paso; corregido.
- Script Godot 4: se utilizó la inexistente función `powf()` en la interpolación de zona; sustituido por `pow()`.
- Bots eliminados que seguían teniendo colisión invisible: se desactiva la colisión al morir y se restaura al reaparecer/iniciar partida.
- Enlace entre elementos HUD y estado real: iniciar nueva partida limpia HUD de resultado y sincroniza salud, munición, enemigo, zona y botón de reinicio.
- CI previo solo comprobaba que el juego arrancara: se añade `sector_battle_qa.gd` para verificar botín, zona, daño, eliminaciones, victoria y reinicio.

## Pruebas automatizadas obligatorias (no equivalen a pruebas de teléfono)
- `smoke_test.gd`: escena, terreno, colisión, rig temporal y AK-74.
- `motorola_control_audit.gd`: suelo, caminar, correr y elevación de salto.
- `mobile_touch_routing_test.gd`: joystick visual de movimiento.
- `camera_fire_qa.gd` y `multitouch_combat_qa.gd`: cámara libre, arrastre disparo, miras y tres gestos simultáneos.
- `sector_battle_qa.gd`: nueve participantes, botín y munición, peligro y contracción, daño entre bots, eliminación, victoria, panel final y reinicio, relieve/vegetación, barrera visual sincronizada.
- CI APK: importación de GLB articulado, captura renderizada real, export Android ARM64 con paquete `com.thedemianff.lastzone.nativepreview74`, certificado de depuración, `aapt`, `apksigner` y SHA-256.

## Revisión visual y art asset gate (pendiente)
Las ocho imágenes de Lila y Aurora aportadas por el usuario están especificadas en `docs/V73_2_LILA_AURORA_ART_DIRECTION.md`. **Todavía NO se ha convertido ninguna imagen 2D en un GLB profesional**:
- El personaje femenino actual proviene de un rig provisional CC0 articulado, no de la Lila aprobada (cabello lila, outfit azul y blanco, rig propio, mochila y arma con IK).
- La postura de armas, running, crouch, recarga y salto necesita mocap/animaciones retarget profesionales, huesos correctos y estados de animación de alta calidad.
- El mapa visible mide unos cientos de metros, **no 8192×8192 m**; hacen falta ocho POI desarrollados, edificios realistas, interiores, rutas, navegación, cobertura, LOD, streaming, agua, vegetación y clima.
- Enemigos actuales usan persecución geométrica simple y LOS, no NavMesh/NavigationAgent3D completo.
- No se ha implementado el avión, caída libre/paracaídas, 100 enemigos, partidas online ni servidor dedicado en esta rama.
- El respaldo Firebase/Google y el ID numérico de jugador de V70 **no han sido migrados a Godot**. APK V74 no debe reemplazar V70 ni su instalación firmada.
- No se ha medido FPS, latencia, calentamiento ni errores de pantalla táctil en un Motorola Edge 60 Fusion con esta APK.
- El AK-74 GLB ya existía en el proyecto, pero deben auditarse sus permisos de redistribución comercial antes de publicación pública.

## Criterios para aceptar V74 en Motorola
1. Instalar en paralelo a V70/V73.x sin desinstalar ni limpiar datos.
2. Entrar en entrenamiento y comprobar suelo, cámara 360°, joysticks y los cuatro bots.
3. Pulsar INICIAR BR: 9 vivos, ocho bots, círculo 3D y radar coherentes.
4. Caminar/correr y saltar manteniendo disparo con arrastre simultáneamente, verificar cero dedos bloqueados.
5. Buscar y recoger botiquín y munición: cantidad real debe aumentar y el objeto desaparecer.
6. Probar disparo/ADS x2/x4/x8, daño enemigo, derrota y victoria. Reiniciar varias veces.
7. Caminar alrededor de casas y árboles: registrar clipping, colisiones y cámara paredes.
8. Registrar FPS promedio/mínimo, tiempo sin tirones y temperatura en ~10 minutos.
9. Capturar videos e indicar error reproducible + minuto/segundo para V75.

**Definición de avance:** publicar código + CI verde sin decir «100% funcional» ni «battle royale completo». Calidad móvil real se valida en el dispositivo.
