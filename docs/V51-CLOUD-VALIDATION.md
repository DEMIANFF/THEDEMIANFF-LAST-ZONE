# V51 — Validación del progreso Google/Firebase

Estado: implementación en pruebas. Una compilación verde no demuestra recuperación real tras reinstalar.

## Configuración obligatoria
- La APK debe tener google-services.json del proyecto correcto y huellas SHA-1/SHA-256 del certificado de prueba.
- Habilitar Google en Firebase Authentication y crear Cloud Firestore.
- Publicar firestore.rules con una sesión autorizada: `firebase deploy --only firestore:rules --project ID_REAL_DEL_PROYECTO`. GitHub Actions compila APK, pero no publica estas reglas.
- Nunca abrir reglas públicas para solucionar PERMISSION_DENIED. La colección player_backups/{uid} debe ser privada del UID autenticado.

## Pruebas antes de declarar Google Cloud Save funcional
1. Iniciar Google A y confirmar que Firestore creó player_backups/{uid_A} tras un mensaje de guardado confirmado.
2. Completar partida y verificar XP, créditos y estadísticas remotas tras el acuse del servidor.
3. Jugar sin Internet, reiniciar la aplicación y verificar progreso local pendiente.
4. Reconectar y verificar sincronización automática sin botones.
5. Desinstalar, reinstalar e iniciar la misma cuenta; comprobar XP, créditos, operadores y recompensas.
6. Cambiar a Google B y comprobar que no se mezclan datos entre cuentas.
7. Simular errores de permisos, red y documento corrupto sin sobrescribir progreso.
8. Probar conflicto remoto/local y conservar copia local antes de elegir.

## Limitaciones
El almacenamiento privado de Android suele desaparecer al desinstalar. El invitado requiere un archivo externo persistente y prueba real para prometer recuperación. El éxito de GitHub Actions solo valida compilación y pruebas automáticas, no Firebase en el Motorola.
