# V55.4 — Registro gratuito de IDs permanentes

## Objetivo y límites

Esta versión ofrece una ruta sin Cloud Functions/Blaze para asignar IDs públicos consecutivos a cuentas Google de Firebase Authentication. Usa un Google Apps Script que se ejecuta con la cuenta propietaria y una hoja privada de Google Sheets.

- Firebase Authentication sigue siendo la autoridad que valida al usuario.
- Android envía únicamente un Firebase ID token. Nunca envía un UID ni un ID de jugador.
- Apps Script valida el token con el endpoint Identity Toolkit del mismo proyecto Firebase y obtiene el UID de la respuesta validada.
- La hoja de registro y su contador solo son accesibles por la cuenta propietaria del script.
- Un bloqueo global serializa cada consulta y asignación.
- El mismo UID conserva su número; los siguientes usuarios reciben el próximo entero.
- Los IDs van de 1 a 99999 y se muestran como cinco dígitos (00001, 00002, ...).
- Antes de devolver un ID existente o emitir uno nuevo, el servicio audita todas las filas: UID no vacío y único, número entero y estrictamente consecutivo según la posición, fecha presente y contador exactamente alineado. Si encuentra duplicados, huecos, filas reordenadas o valores alterados, falla de forma segura. Solo recupera una fila final completa y consecutiva tras validar primero todo el prefijo; no reconstruye ni reinicia historiales dañados.
- Las cuentas invitadas no reciben un ID público permanente hasta vincular una cuenta Google de Firebase.

Esto es una solución inicial y de bajo volumen. Google Apps Script tiene cuotas por cuenta y puede limitar o suspender temporalmente el servicio si se superan. No se debe tratar como infraestructura para miles de solicitudes simultáneas o como garantía de disponibilidad comercial. Para cuentas personales, la documentación publica actualmente un límite de 20.000 llamadas URL Fetch al día y 6 minutos por ejecución; Google puede cambiar esas cuotas.

## Instalación del servicio (una sola vez)

La persona propietaria del proyecto debe hacer estos pasos desde su propia cuenta de Google. No compartas contraseñas, tokens de sesión, códigos de verificación ni la hoja privada.

1. Abre https://script.google.com/home/start y crea un proyecto independiente llamado THEDEMIANFF Player Identity.
2. Reemplaza el contenido de Code.gs por el archivo [identity-gas/Code.gs](../identity-gas/Code.gs) de esta rama.
3. En Firebase Console, abre el proyecto thedemianff-last-zone → Project settings → General → Web API Key. También se puede consultar en app/google-services.json en el campo current_key. Es una clave de configuración del cliente Firebase, no una contraseña de administrador. No hace falta enviarla a ChatGPT.
4. En Apps Script → Project Settings → Script Properties, crea FIREBASE_WEB_API_KEY con el valor Web API Key del proyecto Firebase correcto.
5. Activa la visualización del archivo de manifiesto appsscript.json en Project Settings y sustituye su contenido por [identity-gas/appsscript.json](../identity-gas/appsscript.json). Guarda el proyecto.
6. En el selector de funciones elige setupRegistry y pulsa Run. Autoriza los permisos solicitados. Se creará la hoja privada THEDEMIANFF — Registro privado de jugadores, con la pestaña players, encabezados y contador inicial 0. No compartas esa hoja con jugadores.
7. Abre Deploy → New deployment → Web app. Selecciona Execute as: Me y Who has access: Anyone (acceso anónimo a la URL). Publica y copia la URL que termina en /exec.
8. Abre la URL /exec en el navegador. Debe mostrar JSON y status: ready. Si dice setup_required, revisa Script Properties y ejecuta setupRegistry solo si el registro todavía no existe.
9. En el chat del proyecto, comparte únicamente la URL pública de despliegue /exec. No compartas la hoja, la Web API Key, el token Firebase ni datos personales. Esa URL se añadirá a identity-gas/endpoint.txt en esta rama; Android descargará ese archivo de configuración sin requerir otra compilación.

El endpoint es públicamente accesible para que la APK pueda llamarlo, pero no acepta una petición de identidad basada solo en UID. Requiere un ID token Firebase vigente con Google vinculado y correo verificado. Apps Script verifica ese token contra thedemianff-last-zone antes de asignar un número. La URL pública no es una credencial: la hoja y sus propiedades deben permanecer privadas.

Importante: actualizar `identity-gas/Code.gs` en GitHub no actualiza el proyecto Apps Script ya desplegado. Después de copiar la versión revisada a `script.google.com`, crea una nueva versión del despliegue web y conserva la URL `/exec` que ya usa la APK. El código de GitHub y el servicio publicado son dos artefactos separados.

## Prueba de aceptación después de publicar

1. Instala la APK V55.4 o posterior creada desde esta rama.
2. Entra con la primera cuenta Google verificada de Firebase. Debe recibir 00001.
3. Cierra y abre el juego e inicia sesión con la misma cuenta. Debe conservar 00001; no se debe consumir otro número.
4. Inicia sesión con una segunda cuenta Google distinta. Debe recibir 00002.
5. Repite llamadas o pulsa REINTENTAR ID para comprobar que la misma cuenta conserva el mismo número.
6. Comprueba que la hoja permanece privada y que contiene una fila por UID. Los IDs son identificadores públicos, no credenciales de acceso.
7. Comprueba por separado el respaldo de progreso: el ID y el guardado en la nube son dos sistemas distintos.

No se declara la función lista para jugadores hasta completar esas pruebas desde la APK real. Los tests unitarios simulados no sustituyen la prueba con una cuenta Firebase real.

## Pruebas automatizadas

Desde identity-gas/:

    npm test
    npm run check

Los tests comprueban la verificación simulada del token Google, el rechazo de UID proporcionado por el cliente, la idempotencia, números consecutivos, solicitudes inválidas, contador/filas inconsistentes, duplicados de UID o número, huecos, filas reordenadas, valores numéricos guardados como texto, el límite 99999 y la recuperación segura de una escritura interrumpida. Son pruebas automatizadas simuladas; no prueban el despliegue real ni una cuenta Firebase de producción.

## Facturación y privacidad

Esta ruta no requiere habilitar el plan Blaze ni desplegar Cloud Functions. No se ejecutó ninguna operación de facturación. El propietario de Apps Script debe mantener privada la hoja y no editar manualmente sus filas o contador. Si el registro se corrompe, detén las altas y realiza auditoría antes de reparar; no reinicies el contador.

El código anterior de Cloud Functions se conserva como alternativa futura, pero esta versión Android ya no necesita la dependencia cliente firebase-functions.

## Documentación oficial

- [Apps Script web apps](https://developers.google.com/apps-script/guides/web)
- [Apps Script manifest: web app access and execution](https://developers.google.com/apps-script/manifest/web-app-api-executable)
- [Apps Script LockService](https://developers.google.com/apps-script/reference/lock)
- [Apps Script quotas](https://developers.google.com/apps-script/guides/services/quotas)
- [Firebase Identity Toolkit — accounts:lookup](https://cloud.google.com/identity-platform/docs/use-rest-api)
- [Firebase Cloud Functions pricing and billing FAQ](https://firebase.google.com/docs/functions/faq-and-troubleshooting)