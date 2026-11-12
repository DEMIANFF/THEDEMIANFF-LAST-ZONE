# V75.29 — Sincronización de la zona con IA y regresión física de seis viviendas

## Base verificable
Continúa **exactamente** desde V75.28, commit `6d3baea3f0af885fd6e5bd04fd18048f95a0e686`, PR #41. V75.28 cuenta con GitHub Actions run #43155428795 finalizada correctamente. Esta rama no modifica la estable V44, Unity, Firebase, ni las claves de producción.

## Cambios reales
- El director de partida comunica a cada enemigo vivo la posición y radio **actuales** de la zona en cada paso de juego, en vez de actualizar a la IA solo durante la cadencia de 0,33 s del HUD. El anillo visible, el daño fuera de zona y las decisiones de escape comparten el mismo radio.
- Al reiniciar el Battle Royale, el radio de seguridad de todos los enemigos se restablece inmediatamente al radio inicial de **112 m**. Evita que un enemigo recién reiniciado conserve temporalmente los **12 m** del cierre final de la partida anterior.
- Las pruebas V75.28 de recorrido físico se amplían a **las seis casas** de Puerto Aurora, no únicamente a las dos añadidas en esa versión. Se comprueban las puertas, las rampas, el mobiliario colisionable y el desplazamiento efectivo del personaje por la entrada.
- También se comprueba cada uno de los **seis suministros interiores**, a su altura de suelo real, con recolección efectiva. Se verifican los radios de la IA tanto en la primera fase como inmediatamente después de acelerar la segunda, sin esperar al refresco del HUD.
- APK de diagnóstico ARM64 V75.29: `versionCode=31` y paquete `com.thedemianff.lastzone.nativepreview`, conservando el certificado de identidad de la rama precedente.

## Aceptación y límites
- CI deberá ejecutar Godot headless, la batería completa de QA, exportación Android, firma, alineación y QA desde bytecode exportado. La ejecución física en Motorola Edge 60 Fusion sigue siendo imprescindible y **no se considera sustituida por CI**.
- El proyecto mantiene 1 jugador y 8 bots offline. No hay servidor autoritativo ni multijugador real de 50 participantes en esta versión.
- Se mantienen las reparaciones del audio WAV de V75.24, la cámara móvil V75.26, el lobby/editor HUD de V75.27 y los edificios/botín/zona de V75.28.
