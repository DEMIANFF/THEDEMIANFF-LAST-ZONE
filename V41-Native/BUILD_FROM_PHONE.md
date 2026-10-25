# V41 — compilación Android desde un teléfono

## Estado real (24 octubre 2026)
El proyecto nativo está versionado, pero aún **no se ha compilado ni ejecutado en Unity 6**. La verificación sin licencia de GitHub Actions **no** sustituye la compilación.

## Bloqueo principal: licencia Unity
El workflow manual `.github/workflows/v41-unity-android.yml` usa GameCI Unity Builder v4. Para Unity Personal, GameCI pide un archivo de activación **.ulf** obtenido con Unity Hub, además de las credenciales de la cuenta Unity. De acuerdo con la documentación actual de GameCI, la activación de Personal se realiza localmente desde Unity Hub. Los métodos viejos para subir un archivo .alf a la página de activación manual no son una solución general vigente para Personal.

Una cuenta gratuita de GitHub y un teléfono con Termux por sí solos **no generan** el archivo de licencia ni proporcionan Unity Editor. No uses licencias de terceros ni compartas contraseñas, tokens o contenido .ulf en chats, issues, commits o capturas.

Cuando tengas acceso a una máquina con Unity Hub, activa una licencia Unity Personal válida y lee https://game.ci/docs/github/activation/ para ubicar tu .ulf. Puedes usar temporalmente una máquina prestada con autorización; no necesitas comprar una licencia Pro por este motivo si calificas para Personal.

## Configuración de secretos (solo tú en GitHub)
1. Repositorio > **Settings** > **Secrets and variables** > **Actions**.
2. Crea `UNITY_LICENSE` con el **contenido íntegro** del archivo .ulf activo.
3. Crea `UNITY_EMAIL` y `UNITY_PASSWORD` con las credenciales de tu cuenta Unity, como indican las instrucciones de GameCI. No los pongas nunca en el repositorio.
4. Abre **Actions** > **V41 Unity Native Android APK** > **Run workflow** y elige `v41-native-unity-rebuild`.
5. Examina los pasos del workflow. Si tiene éxito, descarga el artefacto `THEDEMIANFF-V41-UNITY-NATIVE-APK` que contendrá el APK de prueba. Si falla, revisa logs (sin divulgar secretos).

## Antes de una compilación definitiva
- Unity 6000.0.60f1 y módulo Android Build Support.
- Asignar el activo de URP en Graphics/Quality para renderizado URP real.
- Ajustar **Active Input Handling: Both** porque los scripts usan la API antigua Input.
- Resolver cualquier error de compilación revelado por Unity.
- Instalar APK, revisar Logcat, táctiles y FPS en Motorola Edge 60 Fusion.

## Trabajo que sí podemos completar ahora desde Termux
- Implementar y revisar scripts y lógica; sincronizar Git y usar GitHub Actions sin licencia para verificaciones estáticas.
- Preparar escenas, configuraciones, assets y documentación Unity para una compilación posterior.
- Probar V40 con su APK; esa prueba **no valida V41**.

Comandos:

```bash
cd ~/THEDEMIANFF-V41
git pull --ff-only origin v41-native-unity-rebuild
git status --short
find V41-Native/Assets -name '*.cs'
```
