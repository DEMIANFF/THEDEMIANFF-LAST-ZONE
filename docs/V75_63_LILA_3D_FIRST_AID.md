# THEDEMIAN: LAST ZONE V75.63 — Curación de Lila con objeto 3D y animación real

## Base comprobada y continuidad
Se desarrolla exclusivamente desde `codex/v75-62-tactical-bot-medicine-vulkan` (PR #63, CI [#43460995681](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/43460995681) SUCCESS). Godot es motor principal, APK Android ARM64 con **Vulkan Mobile exclusivamente**, versionName `75.63.0-mobile-vulkan`, versionCode `53`. Paquete y certificados preview, Firebase, identidades, guardado y estable `v44-3-2-autosave-guest` intactos. El usuario ha pospuesto las pruebas físicas del Motorola.

## Trabajo jugable en la misma escena real

### Botiquín Aurora diseñado y montado en la mano
- Nuevo `native-godot/scripts/player/aurora_medkit_visual.gd`, que genera una cajita de primeros auxilios original del universo Aurora con seis piezas 3D de geometría pequeña, en blanco hielo, azul y cian, con cruz visible. Son geometrías reales `BoxMesh`, no una ilustración ni textos que simulan un modelo.
- `LilaLeftHandFirstAidSocket`: montura `BoneAttachment3D` en el hueso `rig:LeftHand` del personaje animado, con compensación de escala FBX para que el botiquín no se vea como una partícula ni tan grande como Lila.
- Se crea una sola vez cuando se inicializa el combate; no se generan meshes nuevos en cada fotograma. No añade colisiones ni sombras costosas.
- El modelo **solo aparece** mientras el sistema real tiene una curación aceptada y activa; se oculta al cancelar, recibir daño, disparar, apuntar, caminar, usar cobertura, completar curación o reiniciar.

### Animación corporal verdadera
- En `native-godot/tools/convert_operator.py`, Blender exporta un nuevo clip `AuroraHeal` con brazos, antebrazos y torso coordinados alrededor del botiquín de la mano izquierda durante el periodo de tres segundos.
- El clip se reproduce a través del `AnimationTree` superior del personaje que ya usa miras, recarga y disparo: no crea un controlador de movimiento paralelo ni cambia la cápsula de física.
- Se detiene con la misma transición que interrumpe la acción médica, sin afectar la animación de locomoción subyacente.

### Armas e inventario coherentes
- La lógica de `training_combat.gd` mantiene idénticos los tres segundos de canal, la salud real que se recupera (45 HP), el descuento de un solo botiquín y las interrupciones originales.
- Mientras Lila se cura, `weapon_visuals.gd` guarda el arma activa en el soporte dorsal y la oculta de las manos; al finalizar/cancelar, la devuelve exactamente a la mano. Esto contempla el AR-7 y la AWM obtenida mediante el pickup físico; jamás concede una AWM que no pertenece al inventario.
- Si entra un golpe durante la acción, **no** se recupera salud y **no** se consume el botiquín. El HUD mantiene la barra, el botón Cancelar, el progreso y las cuentas reales.

## Verificación/criterios de aceptación
1. El juego inicia con un rig de Lila real con huesos.
2. El archivo GLB exporta `AuroraHeal` y el AnimationTree lo reproduce.
3. La montura está en `LeftHand` del esqueleto y no es un objeto fijo en cámara.
4. El botiquín tiene seis elementos `MeshInstance3D` con materiales originales de primera ayuda.
5. No hay sombras dinámicas o física adicional mientras el objeto está oculto.
6. El botiquín no se ve en lobby ni partida cuando no está curando.
7. Comenzar una curación válida hace visible el objeto e inicia el clip.
8. Durante el canal de tres segundos se guarda la pistola/fusil activo en espalda.
9. El jugador no recibe vida ni pierde botiquines al comenzar.
10. La barra del HUD coincide con el tiempo consumido.
11. Pulsar Curar otra vez cancela, oculta la malla y restaura el arma.
12. Mover el joystick cancela el tratamiento.
13. Recibir daño físico cancela el tratamiento.
14. Apuntar o cambiar arma cancela el tratamiento.
15. Curación completa aumenta vida real, máximo 100.
16. Solo el fin del canal descuenta exactamente un botiquín.
17. El HUD refleja el botiquín restante y oculta la barra de progreso.
18. Una AWM recogida físicamente también se guarda/restaura sin perder propiedad.
19. El reinicio de ronda devuelve armas, temporizadores y accesorios al estado inicial.
20. Se ejecutan todas las QA históricas y `v7563_lila_medkit_visual_qa.gd` tanto en fuente como dentro del APK Android exportado.
21. Se comprueban firma, ARM64, alineación y renderizador Vulkan en una sola APK.
22. Las pruebas del runner Linux no se presentan como pruebas de FPS ni resultado físico en Motorola.

## Alcance que aún falta
- El rostro y el cuerpo base de Lila siguen CC0 y provisionales. La animación es original de Blender, pero no se declara captura de movimiento profesional.
- El botiquín no tiene aún movimiento de tapa articulada, aplicaciones de venda sobre el torso ni estados de lesiones por zonas.
- No se crean clientes ficticios de red, ni se afirma multijugador con 50 humanos. La meta de 1000 mejoras permanece abierta.
- El equipo real Motorola Edge 60 Fusion se utilizará cuando el usuario autorice las pruebas de calidad y rendimiento.
