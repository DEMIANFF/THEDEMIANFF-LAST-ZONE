# THEDEMIAN: LAST ZONE — V75.58 | Disparos críticos con colisión física

## Continuidad y alcance real
Base exacta: `codex/v75-57-ten-minute-match-ledger-vulkan`, PR #58; GitHub Actions #43354950676 terminó SUCCESS. Mantener intactas la cuenta Firebase, la firma de APK preview, el ID de paquete, la rama estable V44, la zona progresiva de diez minutos y todos los controles existentes. Un único APK ARM64 con Vulkan Mobile, versionCode 48.

El usuario fijó 1.000 mejoras como meta de trabajo acumulativo, sin pedir ensayos físicos de su Motorola hasta que él lo autorice. No asumir tests de dispositivo ni confundir bots offline con humanos conectados.

## Implementado y verificable
- Clasificación por región **únicamente del contacto que devuelve PhysicsServer** con un `CharacterBody3D` rival vivo.
- La cápsula `OpponentCollider` existente mide 1.74 m, con base a aproximadamente 0.01 m de los pies del agente. Región crítica local: 1.43–1.78 m de altura.
- Contactos sobre el modelo visual fuera de la colisión, apuntar sobre la cabeza o disparar contra una pared **no** dan daño crítico.
- AR-7: daño estándar 26; daño crítico = 26 × 1.85 = 48.1 antes de limitarlo por vida restante del enemigo.
- AWM: daño estándar 115; crítico = 115 × 1.65 = 189.75 antes de limitar por vida.
- La salud real recibida es la única fuente de daño mostrado. Si al enemigo le quedaban 20 HP, la estadística solo contabiliza 20, nunca los 189.75 teóricos.
- Las bajas físicas siguen emitiendo la misma señal existente; zonas o combates bot-bot no se atribuyen al jugador.
- Separación de `shots_fired_total`, `shots_hit_total`, `headshots_total` y `damage_dealt`.
- La mochila conserva el rótulo RECOGIDOS esperado por QA antigua e incorpora `TIROS A LA CABEZA`.
- El HUD distingue marcador de daño normal y `CABEZA` / `CABEZA / BAJA`, con caducidad temporal.
- Pantalla final: precisión y total de impactos críticos, sin inventar logros.
- `headshots` opcional incorporado al diario local `offline_match_records` bajo SCHEMA=1, sin migración destructiva de los archivos anteriores.
- Validación de integridad: `headshots<=hits<=shots`, límites de contadores, hash SHA256 de carga y backup atómico existentes.
- Reseteo de críticos, cargadores, impactos y estadísticas al iniciar otra partida.
- Respeta rayos desde cámara y segundo rayo desde boca del arma para que edificios y coberturas sigan bloqueando disparos.

## QA física automatizada V75.58
`v7558_physical_headshot_qa.gd` ejecuta `Main.tscn`, posiciona enemigos reales en un espacio abierto y verifica:
1. Región del casco de colisión y contactos inválidos.
2. Fórmulas de daño AR/AWM normales y críticos.
3. Raycast físico a altura cabeza y daño real contra un bot `CharacterBody3D`.
4. Raycast a altura torso; sin bonificación crítica.
5. Ausencia de recuentos por colisiones vacías, terreno o contacto NaN.
6. Un rayo físico nuevo confirma la eliminación del mismo rival.
7. Recuento real en inventario y precisión.
8. Registro de críticos en pantalla final y diario local SHA256.
9. Rechazo de registros imposibles con críticos mayores que impactos.
10. Reinicio de partida sin transferir las estadísticas ni la AWM.

La nueva prueba se incorpora al historial de QA nativa y **al QA completo de recursos exportados** dentro de la única APK Vulkan.

## Política de aceptación
No declarar Android probado ni FPS=60 sin ensayo en Motorola Edge 60 Fusion. No dar por finalizadas las 1.000 mejoras por haber redactado un backlog. La entrega sigue en forma de PR borrador hasta CI verde.
