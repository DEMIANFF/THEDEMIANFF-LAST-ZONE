# V44.5 — Registro seguro de jugadores (preparación)

Estado: Firestore creado por el administrador; **ninguna reserva de nombre o ID ha sido ejecutada**.

## Arquitectura requerida
- Firebase Authentication valida el UID de Google.
- Un backend de confianza (Cloud Functions + Admin SDK) asigna identificadores y nombres.
- En transacción atómica: crear `playerNames/{normalizedName}` con UID, crear `players/{uid}` con ID asignado y actualizar contador `metadata/playerSequence`. No permitir escrituras de cliente a estos documentos.
- Normalizar apodos con reglas definidas de Unicode/casefold y restringir caracteres, longitud y nombres reservados; no confiar en validación HTML.
- El ID 000001 y el apodo Daniel deben asignarse **solo al UID autenticado del fundador**, tras verificación de titularidad por el administrador. No fijar UID en repositorio sin confirmación.
- Antes de abrir registros, desplegar reglas restrictivas, función de registro y pruebas de concurrencia. Los documentos no se crean al añadir este archivo.
- La sincronización del progreso requiere diseño separado, control de integridad y resolución de conflictos; iniciar sesión no sincroniza datos.
- El archivo `firestore.rules` se versiona en GitHub, pero **no se aplica automáticamente** a Firebase Console.

## Estado de seguridad
Las reglas propuestas deniegan acceso cliente a todos los documentos hasta que el backend esté listo. No sustituirlas por reglas abiertas de modo de prueba.
