# THEDEMIAN: LAST ZONE — V75.106 · HUD Aurora y navegación de lobby

Base exacta: **V75.105 / PR #110**, commit `12cf2697d9710281c26d88d06eacac0dbcfe6907`. Motor Godot 4.7.2, Vulkan Mobile, Android ARM64. Rama `codex/v75-106-aurora-hud-real-layout`.

## Cambio real implementado

- **HUD Aurora táctil (espacio 4):** nuevo comando `APLICAR HUD AURORA / ESPACIO 4` en Ajustes → Partida → HUD. Distribuye los 13 controles existentes con coordenadas normalizadas dentro del área segura en paisaje Motorola; joystick/movimiento izquierdo, disparo por arrastre derecho, apuntar, recarga, cambiar arma, agacharse, saltar, barrera, curarse, mochila, mapa y ajustes. **Son los botones del juego ya conectados a gameplay**, no controles de ilustración.
- **Conservación y persistencia:** al aplicar el preset, la versión de usuario del espacio 4 solo se inicializa cuando está vacía; nunca sobrescribe sus ediciones posteriores, ni las de los espacios 1–3. Sigue disponible el editor real para mover, escalar, regular opacidad y guardar.
- **Regreso directo a JUGAR:** una nueva acción visible en la barra inferior devuelve al panel BR desde Tienda, Pase, Objetivos, Personajes o Social, usando el mismo escenario 3D y el mismo reproductor persistente de música. El botón INICIAR original sigue lanzando el BR y no se confunde con un enlace a otro menú.
- **Prueba automática específica:** `v75106_aurora_hud_reference_qa.gd` verifica la selección del espacio 4, sus 13 controles, no sobrescribir HUD 1, reelección no destructiva, coordenadas dentro de Motorola en paisaje, separación de joystick y disparo y navegación tienda→JUGAR con Lila en el mismo lobby.
- Se incrementó el **versionCode a 96**, `75.106.0-mobile-vulkan`. Exportación Android solo manual, sin APK en esta entrega.

## Relación con las tres imágenes del usuario

La imagen 2 define la disposición visual/táctil requerida: este incremento transforma una parte en una opción funcional de HUD editable y una navegación de lobby más clara. **No significa que el conjunto entero de las tres imágenes ya exista**. Pendiente: acabado completo de carga, login, ajustes, escenas del hangar, iconografía y distribución final, e integración real del operador masculino. La imagen 3 enumera modos/servicios futuros que no pueden declararse completos en offline.

## Seguridad y regresiones

No se modifican APK existentes, `v44-3-2-autosave-guest`, Firebase productivo, cuentas, firma ni identidad de la aplicación. Se preservan Lila, V75.103, V75.104 y el progreso de entrada V75.105. El PR debe mantenerse en borrador hasta pasar QA, CI y prueba física. Las pruebas headless no reemplazan la comprobación táctil en Motorola Edge 60 Fusion.

## Siguiente bloque funcional

1. Inspeccionar las tres imágenes junto a capturas reales, verificar solapes y corregir estética, jerarquía, tamaños y accesibilidad en pantalla de 964×434 y otros teléfonos.
2. Integrar y retargetear animaciones y acciones del personaje masculino, con selección de operador y persistencia (sin duplicar Lila, con revisión de derechos del modelo elegido).
3. Extender interfaces de tienda/pase/ruleta y su persistencia sin inventar diamantes o simular compras. No añadir pago real sin backend confirmado.
4. APK firmada Vulkan ARM64 para prueba Motorola solo tras confirmar exportación y checksum. Incorporar audios locales con permisos verificados.
