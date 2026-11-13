# THEDEMIAN: LAST ZONE V75.57 — Ciclo de zona 10 minutos e historial real

## Base obligatoria
Continuación **exclusiva** de `codex/v75-56-combat-feedback-quality-vulkan` (`a86d00a75f80781ad854fa1349fe7bfb7bd527f9`), aprobada en GitHub Actions run #43353279611. Mantener Vulkan Mobile como único export Android ARM64, paquete y certificado preview actuales, Firebase/autenticación y `v44-3-2-autosave-guest` sin cambios. El usuario pidió no instalar ni probar el juego en el teléfono hasta que lo indique; CI se ejecuta para prevenir regresiones.

## Cambios de jugabilidad implementados
- Calendario de zona de **600 segundos (10 minutos)**, reemplaza 280 segundos; duración objetivo de la contracción, **no duración mínima garantizada** de una partida (si hay una victoria anticipada, termina antes).
- Cuatro fases de 150 segundos, cada una con **24 segundos de preparación**, seguidos de reducción suave y continua del radio.
- Radios de círculo [112, 84, 53, 28, 12] m conservados, sin desincronizar radar, zona visible, IA y daño real.
- Reposiciones físicas introducidas a los 150, 300 y 450 s; no cambiar el número inicial de 25 botines ni hacer spawn en cada fotograma.
- Test de casas y zona de V75.28 adaptado para consultar los parámetros reales del motor, evitando pruebas atadas a fechas de versiones anteriores.
- Tabla de resultados conserva posición, bajas, daño, precisión, munición, botín y tiempo existentes.
- Persistencia **atómica real** de resultados detallados dentro de `offline_match_records`, con `rank`, `participants`, `damage`, `accuracy`, `loot`, `shots`, `hits`, `reloads`. Un éxito o derrota guarda las métricas del objeto `TrainingCombat`; no se estiman FPS ni se inventan jugadores.
- `record_result` conserva compatibilidad con los **cuatro argumentos antiguos** y con todos los registros que no tienen estas claves opcionales.
- `SCHEMA=1` permanece igual, sin migración destructiva. Sumas de jugadas, victorias, bajas, duración y mejor marca siguen intactas.
- Validación de límites y coherencia: 1<=posición<=participantes, impactos<=disparos, porcentajes 0..100 y contadores no negativos.
- El sobre SHA-256 y la promoción `.tmp`/backup `.bak` mantienen protección de integridad, recuperación tras escritura interrumpida y operaciones idempotentes por ID de partida.
- Las estadísticas de la ronda se capturan antes del commit, para que no se pierdan cuando el jugador reinicia.
- Nuevo test `v7557_ten_minute_ledger_qa.gd`: cronograma de zona, apertura de 24 s, últimos radios, 4 fases, escritura antigua, nueva escritura, lectura de detalles, rechazo de datos inconsistentes, backup recuperable y conexión real con la señal de derrota del jugador.
- La suite completa continúa incluyendo todas las pruebas antiguas y se repite desde recursos empaquetados en la única APK Vulkan.

## Restricciones de producto
- **Offline**: hasta 1 jugador + 8/19/29 rivales IA físicos. El objetivo de 50 humanos reales **requiere** infraestructura de networking/matchmaking/servidor autoritativo. No afirmar online funcional todavía.
- **Rendimiento**: una zona más larga no demuestra 60 FPS ni estabilidad del Motorola. CI valida integridad; el ensayo físico queda pospuesto por deseo del usuario.
- **1000 mejoras**: documento de objetivos por 20 bloques de 50 en V75.56; este hito añade implementación y aceptación verificables, no declara toda la cifra terminada.

## Criterios de aceptación
1. En t=0 el radio inicial es 112m y el estado fase0.
2. En t=600 el radio final 12m y fase4.
3. t=0..600 radio no aumenta ni retrocede fase.
4. Cada fase mantiene su radio en la preparación y después reduce de manera suave.
5. Casas costeras y ocho suministros interiores siguen transitables y recogibles.
6. La zona afecta a IA y jugador por el mismo radio de daño que dibuja el terreno.
7. Nueva partida inicia exactamente con 25 suministros.
8. Un resultado antiguo de cuatro argumentos se abre y persiste con SCHEMA1.
9. Una partida nueva guarda métricas extendidas comprobables tras reiniciar la sesión.
10. No se puede guardar doble vez el mismo ID ni un rango imposible.
11. Restauración tras JSON corrupto reabre backup válido y permite continuar secuencia.
12. El evento real de muerte del jugador termina y guarda el encuentro.
13. Ninguna variante Android OpenGL se genera en la CI.
14. Pruebas fuente, paquete Android exportado y firma v2/v3 deben finalizar PASS.

## Próximas prioridades reales
Optimización de movimiento/IA con 30 rivales, arsenal adicional con activos originales, zonas menos predecibles, progresión y finalmente escuadras/servidores; preservar el avance acumulativo.
