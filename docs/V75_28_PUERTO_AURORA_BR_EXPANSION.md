# V75.28 — Expansión física de Puerto Aurora y Battle Royale offline

## Base segura
Partiendo de V75.27 (`codex/v75-27-lobby-hud-editor`), sin tocar la reparación del búfer WAV que eliminó los cierres en el Motorola, ni el editor del HUD, el sistema de cámara, Firebase o certificados.

## Cambios comprobables
1. Dos viviendas costeras adicionales en (-22,66) y (26,68), sobre el terreno 3D existente, cada una con malla/colisión de cubierta y puerta real de 2,65 m, rampa y cubierta de tejas en MultiMesh. El sector contiene ahora seis viviendas.
2. Seis interiores con mesas y cajas colisionables contra personaje/balas, detalles de metal y un **pasillo central abierto** para que el jugador pueda acceder sin atravesar objetos.
3. Una segunda plaza pavimentada en la zona norte, con geometría que reutiliza la cuadrícula del terreno y puntos físicos de navegación.
4. Seis cápsulas adicionales de botín real en los interiores, con munición AR/AWM, botiquines y carga de barrera. El director sigue colocando las 16 cápsulas exteriores originales. Total: 22 objetos en el sector.
5. Cada cápsula interior utiliza **la superficie de su suelo real**, evitando que aparezca bajo un piso elevado o flotando sobre el terreno. La recolección mantiene comprobación de proximidad/línea de visión y modifica las existencias de combate.
6. La zona segura implementa **cuatro fases de 70 segundos**, con 12 segundos de preparación por fase y reducción suavizada de 90 m a 68, 47, 27 y 12 m. HUD y radar usan el mismo radio que aplica daños, con contador de fase/segundos. El daño fuera de zona aumenta progresivamente 6/8/10/13.
7. Batería real Godot comprueba acceso físico caminando a las casas nuevas, su mobiliario colisionable, recuperación de botín interior, monotonía/temporización de las fases y compatibilidad con partida anterior.

## Límites
Sigue siendo BR **offline** con 1 jugador y 8 bots. No se anuncia una partida multijugador de 50 personas; el servicio de red y su sincronización faltan.

## Android
Mismo paquete `com.thedemianff.lastzone.nativepreview`; mismo certificado de prueba fijo gestionado por `AURORA_PREVIEW_KEYSTORE_B64`, `versionCode=30`, APK ARM64 directamente actualizable sobre V75.27. No modificar rama estable V44, Unity, datos de cuenta ni certificados de producción.

## Validación de aceptación
Primero la matriz automatizada Godot + OpenGL + APK y bytecode exportado. Después, prueba física en Motorola Edge 60 Fusion: navegar las seis viviendas sin colisiones en puertas, recoger botín interior, verificar zona del suelo con cuatro cierres y una partida completa sin cierre ni regresión en FPS.
