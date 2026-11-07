# THEDEMIANFF LAST ZONE — V60.0.0

## Alcance

Aplicación Android con WebView y Three.js que presenta una partida individual de Battle Royale contra rivales controlados por IA. Incluye Base Aurora, edificios e interiores, colisiones, botín, zona segura, avión, paracaídas, pantalla de resultados y lobby con perfil y progresión.

El arsenal contiene seis armas. La AWM conserva su mira x8 exclusiva. El inventario V60 comparte munición por calibre y añade mochilas de tres niveles con distinta capacidad. La partida no ofrece multijugador en línea.

## Cuenta y progreso

El proyecto conserva el acceso Google/invitado, Firebase Auth y Firestore, además del servicio de identidad identity-gas. El servicio requiere su despliegue y configuración para asignar IDs en producción. La progresión local usa el almacenamiento de la aplicación y el respaldo en la nube depende de la cuenta y configuración disponibles.

## Versión y firma

- versionName: 60.0.0-aurora-royale-integration
- versionCode: 173, superior al 158 de V58.2.1 y al 167 de V58.9.0.
- El flujo de compilación usa la configuración de firma permanente existente cuando está disponible. Este trabajo no cambia el keystore ni la firma.
- Una APK debug usa firma de desarrollo y no sustituye una instalación release.

## Compilar

Se requiere JDK 17, Android SDK 35 y Android Gradle Plugin 8.7.3. El flujo de GitHub Actions ejecuta las pruebas de identidad e integración, valida los recursos y compila APK. La APK release firmada solo se publica si el repositorio tiene configurado el secreto del keystore permanente; en otro caso el flujo publica una APK debug de prueba.

## Dispositivo y límites de verificación

El motor ajusta la resolución interna, el pixel ratio y las sombras para WebGL móvil y expone telemetría de rendimiento. Esta configuración se prepara para móviles como Motorola Edge 60 Fusion, pero no se declara una prueba física en ese teléfono sin evidencia directa. FPS, temperatura, cámara táctil, AWM, planeador y recuperación real de cuenta todavía deben validarse en el dispositivo.

El juego es una simulación local contra IA; no es un cliente de partidas multijugador en línea. Conserva Three.js 0.160.1 y el identificador Android com.thedemianff.lastzone.