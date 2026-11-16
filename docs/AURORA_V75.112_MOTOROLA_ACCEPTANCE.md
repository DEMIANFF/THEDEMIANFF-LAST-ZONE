# THEDEMIAN: LAST ZONE — aceptación Motorola Edge 60 Fusion (V75.112)

**Alcance:** verificar la APK de vista previa Android ARM64/Vulkan Mobile de V75.112, no la versión publicada ni el juego online terminado. Godot 4.7.2, `versionCode=102`, paquete preview `com.thedemianff.lastzone.nativepreview`. La rama fuente es `codex/v75-112-aurora-login-responsive-polish` (PR #117), basada en V75.111 CI verde.

## Puerta 1: artefacto correcto y no destructivo

- [ ] En GitHub Actions, comprobar CI nativo verde de la misma rama/HEAD y descargar las capturas Godot reales.
- [ ] Lanzar **manualmente** el workflow `.github/workflows/native-godot-preview-apk.yml` con rama V75.112. El workflow debe utilizar el certificado preview previamente fijado, verificar la firma y generar el APK ARM64/Vulkan; NO regenerar la clave.
- [ ] Comprobar archivo `THEDEMIAN-V75.112-MOTOROLA-VULKAN.apk`, `SHA256SUMS.txt`, `BUILD.txt` y los registros de `verify_android_apk.py`, además de las pruebas del paquete exportado. El paquete `nativepreview` es distinto del ID histórico de producción.
- [ ] Resguardar el perfil antes de instalar. Actualizar una instalación del **mismo paquete preview** sin borrar datos; verificar instalación/arranque sin usar una APK antigua. No reclamar que una APK de un paquete distinto actualice producción.

## Puerta 2: pantalla y entrada en el teléfono

- [ ] Landscape real y zonas seguras: ningún elemento bajo la cámara, notch o barras del sistema; asegurar 40px útiles en los controles.
- [ ] La precarga progresa en función de recursos; botón Cancelar/Reintentar visible, sin panel cortado y sin overlays del lobby.
- [ ] Google, Invitado y Sin conexión muestran el estado real. Probar el comportamiento tras cierre, relanzamiento y modo avión. No llamar «ID oficial» a identidades no confirmadas por Firebase.
- [ ] En el formato 2712×1220 ultrapanorámico físico, el briefing de escritorio no desplaza ni oculta los tres botones de acceso.
- [ ] Entrar a lobby y volver a login libera el visor 3D; no quedan texto, botones ni sonido de sesión anterior.

## Puerta 3: lobby, Lila, controles y perfil

- [ ] Lila aparece con cabeza y pies completos y mantiene la cámara de cuerpo completo; giro izquierda/derecha, arrastre y botón VISTA acercan sin recorte.
- [ ] El centinela, zona de Base Aurora, TIENDA, PASE, EVENTOS, MISIONES, LOGROS, CUENTA, AJUSTES, INVENTARIO, ARMAS, PERSONAJES, SOCIAL e INICIAR no se superponen.
- [ ] Vestuario Aurora base, glacial y fuego cambia el material real. Previsualizar sin modificar compras, saldo ni traje equipado; restaurarlo al salir.
- [ ] Persistencia del perfil local, HUD, monedas y configuración al cerrar/reabrir; Gmail/Google y backup requieren conexión real, nunca estado ficticio.

## Puerta 4: partida completa de 50 participantes locales

- [ ] 1 operador y 49 rivales físicos IA (no confundir con 50 humanos online), inicio desde lobby, avión, salto, caída libre, despliegue de paracaídas, aterrizaje, botín, combate, zona, resultado y regreso.
- [ ] Cámara tercera persona detrás, joystick, caminar/correr, agacharse, saltar, disparar arrastrando, ADS x2/x4, AWM x8 y sensibilidad estable; mira solo durante combate.
- [ ] Munición, recarga, intercambio de armas, MP40, KRISS, SCAR, AR y AWM, sonido asociado a cada evento. Audio definitivo MP40 pendiente de verificación de assets/licencias.
- [ ] Casco/chaleco, curación, botiquines, granadas, IA con obstáculos/zonas, enemigos contra enemigos y bajas contabilizadas; entrar/salir de las ocho casas.
- [ ] Terminar una partida completa (objetivo ~10 min) sin cerrar la app y registrar aparición de bots, zona, daños, victorias/derrotas y retorno correcto a lobby.

## Puerta 5: Android físico y rendimiento

- [ ] Medir FPS promedio, P10, temperatura, consumo, memoria/VRAM y carga de escenas en el Motorola real, con Vulkan Mobile. Comparar en lobby, avión, caída, combate contra numerosos bots y cierre de zona.
- [ ] Abrir panel de notificaciones, cambiar de app, recibir una llamada, regresar y comprobar estabilidad de audio/controles sin pérdida de perfil.
- [ ] Ante cualquier cierre, recopilar `adb logcat` / reporte del teléfono y correlacionar con `flight_blackbox`; no llamar un crash «resuelto» sin backtrace o nueva prueba real.
- [ ] No fusionar PR de UI sobre rama estable o producción sin la aceptación integral anterior.

**Nota:** Los tests headless/OpenGL de escritorio son pruebas de integración, no sustituyen esta matriz física. Los modos online, sistema de pagos, masculino jugable y sincronización completa permanecen sujetos a implementación y validación posteriores.
