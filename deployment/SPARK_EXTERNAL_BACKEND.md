# Backend de cuentas sin Blaze (pruebas, no despliegue realizado)

Conservar el proyecto Firebase Spark y los proveedores Google/anónimo. No activar facturación. El servicio externo usa las mismas transacciones de identidad y perfil, verifica ID token de Firebase y App Check para la app preview exacta. No se exponen escrituras de resultados. El transporte usa el SDK callable con URL HTTPS incluida en la compilación; no hay endpoint ficticio ni entrada URL por parte del jugador.

## Render Free (sujeto a elegibilidad y cuotas)
Crear un Web Service **Free**, sin agregar tarjeta ni activar recursos pagos, conectado a la rama actual de desarrollo. Root Directory: functions. Build Command: npm install --omit=dev. Start Command: npm start. Health Check Path: /healthz. Node 22. No base de datos Render requerida: usar Firestore Spark existente.

Variables privadas del servicio: AURORA_FIREBASE_APP_ID (ID de app Firebase Android preview exacta, NO package name), GOOGLE_APPLICATION_CREDENTIALS=/etc/secrets/firebase-admin.json. Registrar el archivo secreto firebase-admin.json directamente en el panel de hosting usando una cuenta de servicio de privilegios mínimos para Firestore y verificación de usuarios revocados. No subirlo a GitHub, ChatGPT, APK ni registros. Si no se permite generar esa credencial o el proveedor exige pago, detener despliegue. El servidor inicia el contador únicamente si está ausente y no hay identidades, nunca lo reinicia.

Una vez que el servicio sea accesible por HTTPS y /healthz devuelva ok, configurar la variable del repositorio AURORA_BACKEND_ORIGIN con el origen exacto del servicio propio (https://nombre.onrender.com, sin barra final). Reejecutar CI y entregar únicamente la APK de ese run. Sin esa variable el cliente muestra backend_origin_missing, conserva Auth y no inventa acceso. El primer arranque del servicio gratuito puede tardar; comprobar en Android real.

AURORA_MATCH_SIGNING_KEY es opcional mientras se prueban perfiles: sin clave y salas públicas, matchmaking falla cerrado. No desplegar Godot en el pequeño servicio de cuentas ni declarar 50 humanos online. La infraestructura de partidas sigue pendiente. Vigilar cuotas Spark y Render; nunca habilitar pago automáticamente.
