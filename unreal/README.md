# THEDEMIANFF LAST ZONE — Unreal Foundation

## Estado
Base de proyecto **sin compilar ni validar en el editor**. No contiene todavía el mapa Aurora, assets 3D ni APK Unreal. El juego Three.js sigue independiente.

## Requisitos
- Equipo Windows/Linux/macOS compatible con Unreal Engine 5.6, instalado mediante los canales oficiales.
- Toolchain C++ compatible; Android SDK/NDK/JDK para empaquetar Android.
- Abrir `THEDEMIANFF.uproject` y generar los archivos del proyecto cuando se disponga de editor.

## Desde Android
Usar Termux y Git para editar los archivos fuente. **No ejecutar** Unreal Editor dentro de Termux: Android no es una plataforma de editor oficial.

## Próximos hitos
1. Verificar apertura y compilación en un host UE5.6 real.
2. Crear nivel vertical slice de Complejo Helios con arquitectura modular, materiales PBR y navegación.
3. Controlador tercera persona con Enhanced Input y HUD táctil.
4. Bots, disparos, inventario y streaming del mapa Aurora.
5. Empaquetar Android y medir FPS en hardware real.

## Rendimiento
Objetivo configurable 30/60/90/120 FPS, sujeto a soporte y pruebas reales. 120 Hz de pantalla no garantiza 120 FPS.

## Git
Esta rama parte de `main` y conserva el código legado como referencia; el nuevo proyecto está aislado en `unreal/`.
