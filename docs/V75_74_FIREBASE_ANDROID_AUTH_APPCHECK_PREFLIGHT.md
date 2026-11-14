# THEDEMIAN: LAST ZONE — V75.74 | Puerta de integración Firebase Auth y App Check

## Estado de la compilación
- Se continúa desde **Godot V75.73 PR #76** y su corrección de navegación Clásico/Entrenamiento. No se vuelve a código anterior ni se modifica `v44-3-2-autosave-guest`.
- El APK móvil **V75.74 preview** mantiene Vulkan Mobile, ARM64, paquete `com.thedemianff.lastzone.nativepreview`, firma de pruebas y `versionCode=64`. La exportación tradicional continúa deliberadamente con `gradle_build/use_gradle_build=false`.
- La aplicación anterior de Firebase usa `com.thedemianff.lastzone`. Es una app Android distinta; **NO** se debe copiar a Godot su `app/google-services.json` ni su configuración OAuth por suponer que ambas comparten la identidad de paquete.
- Esta rama **NO habilita sesiones Firebase**: prepara el contrato, la UI de diagnóstico, el control de seguridad que falla cerrado y el informe read-only para que el siguiente cambio sea auditable.

## Cambios reales
1. `scripts/persistence/aurora_firebase_bridge.gd` ofrece un adaptador para un **futuro plugin Android v2** con singleton `AuroraFirebase`. Verifica plataforma Android, presencia de plugin, métodos requeridos, versión de API, configuración y disponibilidad de token App Check. Si falta algún componente, no inicia sesiones ni inventa UID o ID de jugador.
2. El contrato v1 contempla `getBridgeStatus() -> String` JSON, `beginGuestSignIn()` y `beginGoogleSignIn()`. `getBridgeStatus` debe informar `{"api_version":1,"configured":true,"provider":"play_integrity","app_check":"token_ready"}` **solo después de obtener un token real del SDK**. Obtener un token **no equivale** a que Cloud Functions lo haya validado; el backend debe comprobarlo en cada callable protegida.
3. `request_sign_in("guest"|"google")` solo despacha la petición si el adaptador está listo, y **siempre** responde `authenticated=false` hasta recibir y verificar la respuesta asíncrona nativa. Nunca almacena ni registra tokens.
4. En **Lobby → Cuenta**, el botón **VERIFICAR FIREBASE / APP CHECK** informa el bloqueo exacto sin botones de Google/invitado falsos, y se oculta fuera de Cuenta para no tapar los controles de juego.
5. `tools/audit_firebase_native_preflight.py` inspecciona sin editar el preset Godot, el estado Gradle, presencia de AAR y correspondencia del paquete Firebase. Solo muestra comprobaciones estructurales, **nunca** API keys, service account JSON, claves privadas, secretos, UID ni tokens.
6. `qa/v7574_firebase_bridge_preflight_qa.gd` comprueba el estado seguro sin plugin, rechazo de intentos de login, identidad no asignada, botón visible, diagnóstico honesto y tamaños de pantalla. Se ejecuta tanto en fuente como en recursos APK exportados.

## Configuración que necesita hacer el propietario en la consola (no realizada en este PR)

**Primero en proyecto Firebase de pruebas**, o mediante una segunda app Android independiente y sin activar políticas globales:

1. **Registrar** el paquete Android exacto `com.thedemianff.lastzone.nativepreview` en Firebase Console → Configuración del proyecto → Tus aplicaciones → Agregar aplicación Android. No cambiar el paquete antiguo `com.thedemianff.lastzone`.
2. Para **Google Login**, habilitar el proveedor Google en Authentication y registrar las **huellas SHA-1 y SHA-256 del certificado con el que se firma la APK Godot que vamos a instalar**. El alias/certificado de la APK preview y del futuro lanzamiento pueden diferir. No enviar al chat contraseñas ni keystore.
3. Para **Invitado**, habilitar el proveedor Anónimo. Al pasar Invitado → Google, usar `linkWithCredential` y comprobar que **se preserve el mismo UID/ID**; no hacer `signInWithCredential` como sustituto de vinculación. Gestionar explícitamente el caso de una cuenta Google ya existente para no perder el avance del invitado.
4. **App Check**: habilitar la **API Play Integrity**, vincular el proyecto Google Cloud correcto y registrar la app Android más su **SHA-256** en App Check con Play Integrity. Si instalamos APK directamente fuera de Google Play, revisar las opciones de reconocimiento `PLAY_RECOGNIZED`/distribución externa para que no bloquee la prueba legítima. La certificación final se verifica contra el SDK en un Motorola real.
5. Obtener un `google-services.json` cuyo registro Android **coincida exactamente con el paquete Godot** y ubicarlo solamente en el módulo Gradle Android correcto. Firebase documenta que es configuración de proyecto, no una clave privada, pero seguimos evitando mezclarlo con archivos de cuenta del juego antiguo.
6. **No habilitar enforcement global de App Check para Firebase Auth/Firestore ni Cloud Functions legacy** hasta verificar tasas de validez, clientes antiguos y nueva APK. Las callables V75.72/73 ya declaran `enforceAppCheck: true` y por eso permanecerán inaccesibles para el juego Godot hasta instalar y probar el plugin.

## Siguiente fase de ingeniería (tras preparar Firebase Console)
1. Crear plugin Android v2 **real** `AuroraFirebase` en Java/Kotlin y empaquetarlo como AAR con metadatos Godot v2, SDK Firebase Auth/App Check/Functions y flujo de Google Identity mediante Credential Manager.
2. Instalar plantilla Android Build Template de Godot y preparar **una nueva configuración de exportación Gradle** por separado de la preview Vulkan ya estable; compilar ambas, conservar firma y comprobar que no cambia la identidad de instalación por accidente. Godot 4.7 requiere Gradle para plugins v2.
3. Verificar token App Check y estado de Auth en el teléfono; activar botón real **Invitado**, **Continuar con Google** y **Vincular cuenta** únicamente si la respuesta del SDK lo confirma.
4. Ejecutar `ensurePlayerIdentity` con el UID autenticado, verificar respuesta numérica y presentar `00001` + nombre real en el lobby; recuperar nombre y progreso con callables V75.72/73, validando revisiones, permisos y restauración tras desinstalar.
5. Probar con dos cuentas distintas, repetición, cierres de sesión, revinculación, conflictos de progreso, pérdida de red, modo avión, reintentos idempotentes, recuperación después de reinstalar y App Check sin forzar bloqueo de clientes antiguos.
6. **Solo después** considerar despliegue a producción, políticas App Check de enforcement y economía online en servidor. Las monedas locales no pasan automáticamente a saldo premium.

## Fuentes oficiales consultadas
- Godot 4.7 Android Plugins v2: https://docs.godotengine.org/en/4.7/tutorials/platform/android/android_plugin.html
- Firebase Android setup: https://firebase.google.com/docs/android/setup
- App Check Play Integrity: https://firebase.google.com/docs/app-check/android/play-integrity-provider
- Firebase anonymous account linking: https://firebase.google.com/docs/auth/android/anonymous-auth

## Evidencia necesaria para aprobar este hito
- CI Godot QA/Vulkan ARM64 Android verde y marca `V7574_FIREBASE_PREFLIGHT PASS`.
- Auditoría `AURORA_FIREBASE_PREFLIGHT BLOCKED` intencional en esta rama hasta completar la configuración real.
- Ninguna prueba física de Firebase Auth/App Check se considera ejecutada solo porque el APK local compile.
- Las 1.000 mejoras continúan siendo backlog pendiente de aceptación por funcionalidad.
