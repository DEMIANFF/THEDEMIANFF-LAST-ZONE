# THEDEMIAN: LAST ZONE — V75.108 · Operador interactivo y vestuario 3D

Motor: Godot 4.7.2, Android ARM64, Vulkan Mobile. Incremento aislado sobre **V75.107**: `622fed366aed6e64dfa8fda8486d77a0ad361ed1`, PR #112 y CI **43765776843** aprobado. No mezclar automáticamente ramas estables.

## Funciones implementadas en el código real

- **Giro de Lila mediante controles táctiles nativos:** botones `LilaTurnLeft` y `LilaTurnRight` con interpolación de la raíz 3D del GLB (no rotan imágenes ni alteran el AnimationTree de combate). Conservan arrastre libre y pausa temporal del giro automático. Hitboxes pensadas para al menos 40 px de alto en ventana 964 × 434.
- **Cambio de encuadre 3D:** `LilaCameraFrame` interpola el FOV y la posición de la cámara real del `SubViewport`, alternando vista completa/acercamiento. No crea segunda cámara ni segunda instancia del rig. Se restablece al salir al login o entrar a una partida.
- **Personajes con previsualización de vestuario:** el mismo `AuroraLocalSkinSelector` de la Tienda también aparece en `PERSONAJE`. Las variantes `aurora_base`, `aurora_glacier` y `aurora_ember` se aplican al mesh real de Lila. En Personajes los botones de comprar/equipar **no aparecen**, y la vista previa no modifica dinero, compras ni personaje equipado; al salir se restaura el traje realmente equipado.
- **Conservación del ciclo de vida:** temporizadores/tiempo de rotación y tweens de cámara se cancelan antes de liberar el visor 3D; botones y escenas previas se destruyen antes de instanciar el mundo pesado de BR. La música persistente del lobby conserva su configuración y comportamiento.
- **QA específico:** `scripts/qa/v75108_interactive_operator_lobby_qa.gd`. Comprueba rotación y restauración reales, cámara FOV con transición, hitboxes Motorola, selector 3D sin compra, regreso a JUGAR, ausencia de falsa economía y limpieza al cerrar sesión. Se ejecuta antes de toda la batería V75.107 y anteriores.
- `version/name=75.108.0-mobile-vulkan`, `version/code=98`. No se genera APK por defecto; la exportación firmada sigue manual.

## Imágenes exigidas por el usuario
Las tres láminas adjuntas son **especificaciones de implementación**, no fondos ni renders para colocar como reemplazo de funciones. Los SHA-256 están documentados en `docs/AURORA_V75.105_CONTINUIDAD.md`. La meta es un lobby con carácter 3D, carga/login/ajustes y HUD funcionales. Este PR **solo completa el bloque de controles del operador y vestuario**; no constituye toda la reproducción de las tres láminas.

## Pendientes: prioridades técnicas
1. Capturas comparadas de pantalla de carga, acceso, tienda, personaje, ajustes y BR en Motorola físico. Revisar tap targets, legibilidad y superposición de los menús en 964 × 434 y 2712 × 1220, además de las pruebas headless.
2. Rig y animaciones profesionales de Lila (IK de manos/pies, locomoción, salto, curación y un arma visible en el lobby que coincida con sus sockets).
3. Modelo masculino: el paquete `new_skin_cityhero_free_fire.glb` contiene **84 articulaciones y cero clips**; su integración funcional y sus derechos están por verificar. No declarar personaje jugable sin rig compatible, locomoción, combate y pruebas de equipamiento.
4. Lobby, tienda, eventos, ruleta y social completos con backend autenticado y cartera real (no inventar saldo ni pagos).
5. Auditoría de performance Vulkan ARM64 y fase vuelo/paracaídas en Motorola Edge 60 Fusion.

**Protecciones:** sin modificar `v44-3-2-autosave-guest`, Firebase productivo, claves, firma, rama `main` ni contenidos del PR #112. Dejar el PR en borrador hasta pruebas y aceptación visual física.
