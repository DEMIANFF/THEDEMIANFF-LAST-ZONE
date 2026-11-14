# THEDEMIAN: LAST ZONE — V75.76 / Inicio de sesión Firebase desde Motorola

## Estado comprobable

**Rama** `codex/v75-76-motorola-firebase-gradle-integration-vulkan` (basada en V75.75). Se conserva en el mismo código el motor Godot, el mapa, HUD, controles, Lila, combate, monedas locales y perfil. Android ARM64 Vulkan Mobile.

La primera compilación Android es **la preview habitual**, sin Firebase: APK `THEDEMIAN-V75.76-MOTOROLA-VULKAN.apk`, package `com.thedemianff.lastzone.nativepreview`, certificado pinneado y `versionCode=66`.

El segundo producto, **APK Gradle con plugin Firebase** `THEDEMIAN-V75.76-MOTOROLA-FIREBASE-GRADLE.apk`, se genera por otra secuencia de CI desde el mismo checkout, usando Android Build Template **Godot 4.7.2**, el AAR real `AuroraFirebase` y las dependencias Firebase Auth, Firebase Functions, App Check Play Integrity y Google Credential Manager.

- El complemento se instala en un **checkout temporal** de GitHub Actions y el archivo `export_presets.cfg` se cambia solamente en ese checkout. El repositorio NO guarda la plantilla Gradle, archivo JSON ni credenciales.
- El APK de Gradle solo puede mostrar **login habilitado** si el paquete coincide con un registro Firebase, el SDK genera un token válido de App Check y el backend recibe la petición autenticada. Sin configuración Firebase se genera explícitamente un **APK diagnóstico**, sin inicio real de sesión; nunca un login simulado.
- El archivo `AURORA_NATIVE_GOOGLE_SERVICES_B64` es un **GitHub Actions repository secret opcional** que contiene el JSON del nuevo paquete Android codificado en Base64. El script valida que exista exactamente un registro para `com.thedemianff.lastzone.nativepreview`, un ID de aplicación, sender ID, API key y el **web OAuth client ID** para Credential Manager. Se escriben los recursos Android equivalentes al plugin de Google Services en el checkout temporal. El script no los imprime ni los confirma si el paquete no coincide.
- La firma debe coincidir exactamente con el certificado previo. Si no coincide, el pipeline falla en lugar de emitir una APK que sustituya incorrectamente a la instalada.
- Este hito **NO despliega Cloud Functions ni cambia Firebase Authentication/App Check en producción**. Tampoco vincula automáticamente el nombre local con el perfil remoto ni importa monedas locales como saldo online.
- No se aceptan pruebas con un supuesto ID `00001` arbitrario: solo se muestra un número cuando el SDK confirma Auth, Firebase Functions responde `ensurePlayerIdentity` y el adaptador valida cinco dígitos.

## Acciones necesarias en Firebase Console, a realizar por el propietario antes de probar inicio real

1. Entrar en **Firebase Console** con el proyecto `thedemianff-last-zone` → Configuración del proyecto → Tus aplicaciones → **Agregar Android**, sin borrar la app Android histórica `com.thedemianff.lastzone`.
2. Registrar EXACTAMENTE `com.thedemianff.lastzone.nativepreview` y las huellas públicas **SHA-1 y SHA-256 del certificado de firma de la APK preview Godot**. Las verificamos en `vulkan-verification/signature.txt` de la [CI V75.74 aprobada](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/43598406656):
   - **SHA-1:** `B9:1E:EA:C8:C4:6C:EB:5E:64:E3:27:0A:86:A9:23:48:C2:1F:0A:CD`.
   - **SHA-256:** `60:39:06:83:C6:89:EA:73:76:DB:A5:39:24:50:92:9E:30:04:45:89:18:9C:9A:20:0D:4D:B5:48:06:F4:A6:53`.
   - **Certificado:** `CN=THEDEMIANFF Aurora QA Preview Only` — prueba, NO firma de publicación.
   No usar huellas de la WebView antigua si tiene otra firma. Jamás compartir el keystore o su contraseña.
3. En Authentication → Sign-in method: habilitar **Anónimo** e **Google**. Si Google genera configuración OAuth adicional, descargar nuevamente el `google-services.json` de la **nueva aplicación Android Godot**, que incluya el cliente Web OAuth.
4. En Google Cloud Console/Firebase **App Check → Play Integrity**, habilitar la API Play Integrity, registrar `com.thedemianff.lastzone.nativepreview` y la SHA-256 correspondiente. Revisar política para APK **instalada fuera de Google Play**. No activar un enforcement global que bloquee la aplicación antigua.
5. Guardar el JSON correcto mediante **GitHub → Settings → Secrets and variables → Actions → New repository secret** como `AURORA_NATIVE_GOOGLE_SERVICES_B64` (contenido Base64 del JSON). No publicarlo en issues, commits, ni capturas. El pipeline comprueba el registro y, si falla, detiene la compilación. No agregar `google-services.json` al repositorio.
6. Las funciones `ensurePlayerIdentity`, `getPlayerProfile` y `setPlayerDisplayName` deben existir en el **Firebase project correcto**. Las nuevas funciones V75.72/73 del repositorio **no se desplegaron**; antes de pruebas reales se requiere validarlas y desplegarlas a un entorno Firebase de pruebas controlado. No desplegar producción sin autorización separada.

## Primera prueba en Motorola

**No desinstalar la APK del juego** para no perder datos `user://`. Instalar como actualización solo si la versión firmada y package coinciden. Para la prueba de Firebase:

- Abrir Lobby → **Cuenta** → **Verificar Firebase / App Check**. Si falta configuración se indicará error; **no se mostrará** inicio en invitado/Google.
- Si el plugin, Auth y token App Check funcionan, aparecen **Entrar como invitado** y **Continuar con Google**.
- Probar invitado: verificar UID/sesión y que Firebase asigne un número verdadero; luego Google: probar **vinculación** conservando el mismo UID. Verificar que `getPlayerProfile` devuelva nombre y el ID asociado.
- Probar nuevamente con red desconectada, regreso a red, cierre y reapertura; no se conceden monedas online por resultados locales.
- Solo después, y tras confirmar una copia remota real del progreso, plantear prueba de reinstalación y recuperación con Google.

## Condiciones de aceptación

1. CI de Godot y QA completa **SUCCESS** sobre commit final; versiónCode 66 y SHA256 del certificado de firma pinneado.
2. CI de Gradle crea **APK real con clases DEX que contienen `AuroraFirebasePlugin`** y dependencias SDK Android; firma y ABI verificados.
3. App Check: comprobar autenticidad en consola de Firebase y respuesta de Cloud Functions; el mero SDK instalado **no** prueba aceptación del servidor.
4. Verificación en Motorola Edge 60 Fusion: invitado → Google conserva UID, número del servidor y nombre; conexión entre reinstalaciones **aún no probada**.
5. Conservar copias y progreso actual. La versión Godot **no es online / Clasificatoria** sin servidor de partidas autoritativo.

Documentación: [Godot Gradle Android](https://docs.godotengine.org/en/4.7/tutorials/export/android_gradle_build.html), [Godot plugins v2](https://docs.godotengine.org/en/4.7/tutorials/platform/android/android_plugin.html), [Firebase App Check Play Integrity](https://firebase.google.com/docs/app-check/android/play-integrity-provider).
