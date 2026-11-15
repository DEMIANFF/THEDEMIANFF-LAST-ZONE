# THEDEMIAN: LAST ZONE — V75.107 · Lobby 3D vivo e interacción con Lila

## Base comprobada
Base exacta: PR #111 **V75.106** commit `1957ee6667957437dceacf933e932e2bb62f9827`, CI aprobado `43763492982`. Rama aislada `codex/v75-107-aurora-live-lobby-polish`; no fusionar hasta CI final. Godot 4.7.2, Vulkan Mobile, Android ARM64, `versionCode 97`.

## Especificación visual precisa
- Lámina 1 apertura/login/ajustes: SHA256 `7f6758c7d1aca54c0948209b898c43be2663ab613b86bc1a803f2e267f7645fc`.
- Lámina 2 lobby/HUD: SHA256 `d274db900d51a13172d4bed8a8dbc5a8cc57559cbe2ef1365358aeb656587a77`.
- Lámina 3 arquitectura/modos: SHA256 `2c17e1f02749da8cbc0e6c93460336d0ac9370c61cbf8ac245e7239ab48c98b3`.
Estas imágenes son especificaciones reales: NO instalar una imagen plana como interfaz para declarar implementada la mecánica.

## Funcionalidades añadidas
1. **Base Aurora 3D dinámica**: la antena del radar rota alrededor de un pivote `AuroraRadarRotatingHead` en la escena efectiva del lobby; luz de hangar en tiempo real sin sombras, y baliza emisiva cuya intensidad oscila. La escena y su viewport se destruyen antes del despliegue a BR para ahorrar VRAM. No hay videos de sustitución.
2. **Gesto real de Lila**: botón táctil `LilaLobbyGesture` anima el `AnimationPlayer` de Lila con el clip retarget `aurora_lobby/Motion` y regresa a `AuroraIdle` con la lógica de animación existente. Solo funciona dentro del lobby; se oculta/destruye fuera del lobby. Cámara más cercana manteniendo la figura y el centinela en el viewport real.
3. **Trajes 3D en tienda**: el selector modifica realmente el material del mesh skinned `Lila_Aurora_Mesh`. Probar un traje nunca cambia el saldo, la propiedad, el traje equipado ni Firebase. Al salir de Tienda se restaura visualmente el equipado. Hay prevención de reaplicar shaders si la variante no cambió.
4. **Ajustes nativos**: panel de operaciones Aurora con contenedor de márgenes seguros, colores navy/cian/dorado, y navegación de seis categorías identificadas y resaltadas cuando se seleccionan. Conserva sliders, persistencia, editor HUD 4, audio, cuenta y controles.
5. **Prueba integrada adicional** `v75107_aurora_live_lobby_qa.gd`: verifica escena y giro del radar, gesto esquelético de Lila, vista previa visual de dos trajes, ausencia de transacciones falsas, restauración del look al volver a JUGAR, navegación funcional por categorías y salida de Ajustes sin dejar juego pausado. Se ejecuta primero y luego toda la batería original.

## Compatibilidad y límites
- No tocar `v44-3-2-autosave-guest`, producción Firebase, certificados, nombre de paquete ni llaves. PR en borrador.
- Los tres diseños de referencia siguen siendo **objetivos de implementación completa**, no una promesa de que todo su contenido ya exista. Los sistemas de juego de V75.103–106 se conservan.
- **Masculino**: `new_skin_cityhero_free_fire.glb` tiene 84 huesos y ningún clip en su armature; no es un operador funcional confirmado. Validación de licencia, retarget, locomoción, gameplay y equipamiento pendiente. No usar la figura como simple sustituto visual de Lila.
- Tienda diamantes, social y 4v4 requieren backend/entitlements o mecánicas no disponibles aún; no inventar transacciones ni ofrecer funciones ficticias.
- La captura de escritorio con `llvmpipe` es válida para verificar UI pero NO reemplaza una prueba real de GPU móvil. No generar APK sin la autorización del usuario.

## Aceptación y continuación
1. CI de importación Godot, nuevos tests, regresiones, capturas de viewport 1280×720, Motorola 2712×1220, canopy. Comprobar que `aurora-v75-107-*.png` existen.
2. Auditoría visual, screenshots y testing de identidad de Lila en Motorola (gestos, scroll y tamaño táctil); benchmark real.
3. Continuar con operador masculino **solo** cuando se verifique retarget sobre la armadura real y los derechos del modelo.
4. Continuar con pulido visual, UI y funcionalidades de las tres láminas sin fondos falsos.
