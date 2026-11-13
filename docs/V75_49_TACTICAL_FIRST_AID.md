# THEDEMIAN: LAST ZONE — V75.49 | Botiquines tácticos integrados

## Continuidad confirmada
Base directa: `codex/v75-48-vulkan-only-real-battle-loot`, SHA `29585b4523f7a27df5adfa6d9bb0ecb54c5bbbf0`. Se preservan avión, caída, paracaídas, cámara 360°, controles multitáctiles, IA y botín de rivales, perfiles y FPS, equipo, HUD persistente, cuentas y Firebase. Protegida la estable `v44-3-2-autosave-guest`.

**Android: una única APK firmada ARM64 Mobile/Vulkan**. OpenGL permanece solo en el editor Linux para QA headless; no se produce segunda APK. Mismo ID preview `com.thedemianff.lastzone.nativepreview` y mismo certificado, versionCode 43.

## Función de combate entregada
- Botiquín táctico de 3 segundos (`HEAL_APPLY_SECONDS`), con salud +45 aplicada solo al terminar.
- No se gasta el botiquín si se cancela o recibe daño durante la aplicación.
- Pulsar de nuevo CURAR cancela voluntariamente.
- Comenzar a mover el joystick, correr, saltar o desplazarse lejos del punto de inicio interrumpe la acción.
- Daño real recibido (incluida la zona) cancela la curación; no se oculta bajo la invulnerabilidad temporal anterior.
- Disparo, cambio de arma, ADS, recarga y despliegue de barrera cancelan una curación activa.
- No se permite empezar si el jugador está corriendo, moviéndose, disparando, recargando, eliminado, sin botiquines o con vida completa.
- Comenzar a curarse desactiva la mira ADS; mirar la escena con la cámara libre no corta la acción.
- Interrupción limpia al terminar/reiniciar la partida y al perder foco de la app.
- Barra visual `AuroraFirstAidProgress` en la interfaz Android, adjunta al botón CURAR para respetar el editor y la posición personalizada del HUD.
- Botón muestra `CANCELAR` durante la aplicación y vuelve a `CURAR N` al terminar.
- La señal real de curación y el audio existente se emiten al completar la aplicación, nunca al inicio.
- Preservados consumibles, botín físico, 9/20/30 rivales IA locales, físicas 60 Hz y variantes de calidad Vulkan.

## QA de aceptación
`v7549_tactical_first_aid_qa.gd` instancia la escena Godot y prueba:
1. Inicio con daño efectivo.
2. No hay curación instantánea ni gasto prematuro.
3. Barra de progreso persistente adjunta al HUD.
4. Cancelación manual con devolución de consumible.
5. Interrupción por movimiento táctil.
6. Interrupción por daño real.
7. Cancelación al utilizar una mira.
8. Curación de +45 solo tras completar el tiempo.
9. Sincronía del inventario físico y HUD.
10. Reinicio limpio de partida y consumibles.
11. Mobile/Vulkan continúa como único destino Android.

El circuito histórico de Godot se ejecuta en la fuente y de nuevo sobre los recursos de la APK exportada. No se considera verificado en teléfono hasta instalar y jugar en Motorola Edge 60 Fusion.

## Objetivo general
La aspiración de 1000 mejoras sigue siendo un programa por sistemas reales. Los siguientes bloques deben priorizar precisión cámara/armas, cobertura IA, animación corporal, botín, inventario, física, arte original, rendimiento y red autoritativa de hasta 50 usuarios humanos. No etiquetar bots IA como jugadores humanos ni llamar completo al BR offline hasta implementar esos sistemas.
