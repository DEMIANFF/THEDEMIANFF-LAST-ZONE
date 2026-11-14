# THEDEMIAN: LAST ZONE — V75.75

**Objetivo de este hito:** construir el puente **real de código nativo** entre Godot y Android Firebase Auth/App Check como módulo aislado. No es un despliegue a Firebase ni una activación de cuentas en la APK móvil actual.

## Cambios
- Nuevo módulo `firebase-godot-bridge` con compilación Android Gradle AAR y clase `AuroraFirebasePlugin.java`, SDKs Firebase Authentication/Functions/App Check Play Integrity y Credential Manager.
- Sesión invitada real, Google con `linkWithCredential` cuando existe usuario anónimo, protección contra choque de cuentas, resolución asincrónica de ID usando `ensurePlayerIdentity` y lectura de nombre con `getPlayerProfile`; ninguna credencial se expone a GDScript.
- `aurora_firebase_bridge.gd` interpreta de forma estricta el estado de sesión, el ID de **cinco dígitos** y el estado de App Check. Rechaza datos sin token disponible, sin plugin o sin resultado del servidor.
- En **Lobby / Cuenta**, las opciones Invitado y Continuar con Google solo aparecen cuando el SDK nativo instalado está configurado y comunica token App Check listo; ambas opciones despachan peticiones asíncronas. El botón de Verificación muestra la sesión y el ID **únicamente si una respuesta del servidor los confirmó**.
- En preview no-Google el menú funciona en modo local, conserva partidas, monedas y nombre local, oculta las opciones no operativas y muestra ID pendiente.
- `v7575_native_auth_link_qa.gd` verifica este comportamiento en Godot sin conectarse a Firebase, junto con regresiones anteriores. La CI de gameplay mantiene Vulkan ARM64 y la misma firma y package, `versionCode=65`.
- Una CI separada compila el AAR Java con Gradle, verifica la clase y el manifest, sin registrar ninguna aplicación ni usar claves de Firebase.

## Pendientes obligatorios para tener cuentas reales en el Motorola
1. Registrar paquete `com.thedemianff.lastzone.nativepreview` en Firebase Console y las huellas del certificado de esta APK (SHA-1 y SHA-256). La app antigua `com.thedemianff.lastzone` no se sustituye.
2. Configurar Google, Anónimo y Play Integrity en el proyecto, respetando las condiciones para APK instaladas fuera de Google Play. Validar primero con un proyecto o app Android de pruebas.
3. Probar e integrar un **segundo preset Android Gradle**, cuyo `google-services.json` sea específico de la nueva app; incorporar el AAR y dependencias Maven al host Godot sin cambiar la preview estable.
4. Desplegar y verificar las callables `ensurePlayerIdentity`, `getPlayerProfile`, `setPlayerDisplayName` y `save/loadLocalProgressSnapshot` donde corresponda. No ejecutar migraciones ni despliegues automáticos en Firebase producción.
5. Probar Guest → Google conservando UID, dos cuentas separadas, fallos de red, App Check reales, reinstalación y respaldo de progreso sin permitir que monedas del cliente se conviertan en saldo online.

**Criterios de aprobación:** CI Android plugin SUCCESS, CI Godot juego SUCCESS, luego prueba auténtica de sesiones Firebase y App Check en Android. CI verde por sí sola no confirma los últimos pasos. Las 1.000 mejoras siguen como backlog pendiente.
