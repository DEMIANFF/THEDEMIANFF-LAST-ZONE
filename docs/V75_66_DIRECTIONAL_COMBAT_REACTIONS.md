# THEDEMIAN: LAST ZONE — V75.66 · Respuestas de impacto y retroceso AWM

## Continuidad
Base real: V75.65, PR [#67](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/pull/67), CI [#43485140537](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/43485140537) **SUCCESS**. Avanzar exclusivamente desde esta rama; no modificar la rama estable `v44-3-2-autosave-guest`, perfiles, Firebase, certificados o ID Android. El usuario autorizó comenzar ya la mejora profunda de las animaciones. Godot, una sola APK Android ARM64 Vulkan Mobile (`75.66.0-mobile-vulkan`, versionCode **56**).

## Cambios originales y verificables
### 1. Reacciones de impacto 3D en cuatro direcciones
- El exportador real de Blender del operador añade `AuroraHitFront`, `AuroraHitBack`, `AuroraHitLeft`, `AuroraHitRight` al GLB usado por Lila en partida y lobby.
- Cada una anima rotación del torso, hombros y cuello en el esqueleto original, con impulso temporal que se recupera sin tocar caderas o velocidad física. No se usan sprites ni movimiento de cámara para fingir el golpe.
- La dirección se calcula desde la **posición real del atacante**: vector mundial transformado al espacio local del personaje. Una cámara que gira independientemente de Lila no invierte izquierda/derecha.
- Si el daño procede de la zona o no hay posición de atacante verificable, se conserva `AuroraHit` genérico: sin inventar un rival ni marcador direccional.
- Se conserva la inmunidad original temporal a impactos consecutivos y el daño real con absorción de escudo. Las animaciones no agregan daño ficticio.
- Una recarga, curación o acción superior todavía activa con más de 0,24 s pendientes no es cancelada por la reacción menor; el daño sí se aplica.
- El sistema guarda solo el nombre de la última reacción y un contador local de eventos efectivamente representados para pruebas, y se limpia en el reinicio de partida. No modifica estadísticas persistentes de jugador.

### 2. Retroceso distinto de la AWM en el personaje
- Nuevo clip original `AuroraFireAWM` (12 fotogramas a 30 fps) con mayor retroceso de hombros, antebrazos y torso. El AR-7 mantiene `AuroraFire`, más corto y contenido.
- El evento ya existente de **disparo físico** conserva `ammo[]`, recuperación de cámara, raycast, munición, balística, impacto, cooldown de cerrojo AWM de 0,50 s y audio.
- `play_weapon_action("fire")` selecciona el clip correcto según el arma realmente equipada, sin cambiar la cantidad de balas ni disparar una segunda bala.
- Todos los clips nuevos se ejecutan como acciones de **parte superior** superpuestas a caminar, correr, mirar ADS, desplazamiento lateral y retroceso esquelético V75.65. El filtro sigue excluyendo la pelvis y las piernas.
- El AnimationTree da a todos los nuevos disparos/impactos el modo one-shot, sin bucles que dejen a Lila retrocediendo indefinidamente.

### 3. Cobertura de regresiones
Nueva QA `v7566_directional_hit_awm_recoil_qa.gd`: crea `Main.tscn` verdadero, Lila con Skin y Skeleton3D, rivales físicos, inventario real de armas, pickup AWM, señales de daño y HUD. Comprueba impactos frontal/trasero/izquierdo/derecho, orientación tras rotar el personaje, impactos sin origen, protección de recarga, tiro real AR, tiro real AWM, restauración de partida y presencia de los clips originales exportados. Se integra en la suite histórica de Godot **tanto en fuente como en recursos extraídos de la APK**.

El workflow también comprueba nombres de clips del GLB en su fase Blender, antes de que Godot empaquete el archivo. Cualquier fallo queda registrado y requiere corregirse antes de aprobar.

## Aceptación de producción
1. Cinco nuevos clips reales de animación en el GLB (4 impactos y 1 AWM).
2. Cuello, hombros y columna animados; la cápsula de física conserva su tamaño y posición.
3. Izquierda/derecha se evalúan respecto al cuerpo, no al eje mundial ni al dedo.
4. Frente/espalda se distinguen tras rotación de Lila.
5. La zona no genera una reacción direccional falsa.
6. La inmunidad y la absorción de daño originales se conservan.
7. Un impacto durante recarga no crea disparos ni cancela su acción superior prematuramente.
8. Las balas AR producen `AuroraFire` con munición real.
9. La AWM recogida de un pickup dispara con `AuroraFireAWM` y cerrojo real.
10. No aparecen armas sin recoger ni recursos duplicados.
11. Los pasos laterales y la cámara ADS mantienen sus clips y filtros.
12. Al reiniciar el Battle Royale desaparece todo estado visual de impacto/recoil.
13. El material original de Lila, cabello lavanda y arnés Aurora siguen siendo el mismo GLB.
14. El APK Android mantiene ARM64, firma v2/v3, Vulkan, certificados y número de versión correctos.
15. La batería completa y la prueba V75.66 pasan en código fuente y paquete exportado.

**Límites:** esta versión no representa captura de movimiento AAA, ni animaciones definitivas de 206 huesos, ni prueba física de Motorola. El rostro/cuerpo original de Lila sigue provisional CC0, y el multijugador real de 50 personas permanece pendiente. El hito no se contabiliza automáticamente como 15 mejoras de las 1.000: cada criterio requiere su prueba y registro.
