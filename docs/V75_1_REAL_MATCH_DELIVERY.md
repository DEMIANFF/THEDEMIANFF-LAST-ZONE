# V75.1 — Partidas permanentes offline, fin de ronda y animación sin deformación

## Implementación real
**Base:** commit `beb1aaf8a777712033a0384213a4e76bdc5f7b7a` de V75.
**Rama nueva:** `codex/v75-1-real-match-progression`. V70 y `v44-3-2-autosave-guest` no se modifican.

El sector Aurora ya tenía 9 combatientes simulados (1 jugador y 8 bots), botín físico y zona con daño. Esta fase añade una capacidad **real, permanente e incorporable al producto final**: registros de partidas offline terminadas y estado de fin de ronda.

### Registro persistente
- `native-godot/scripts/persistence/offline_match_records.gd`: esquema versionado 1, guardado local de partida/victoria/bajas/supervivencia, mejores marcas y últimas 12 rondas.
- Escritura a archivo temporal, `flush`, copia de seguridad anterior y renombrado de archivo; lectura de respaldo cuando el principal está dañado.
- Identificador de resultado monotónico para evitar contar dos veces la misma ronda, y validaciones de campos.
- Los registros del modo entrenamiento o de partidas abandonadas **no** se cuentan falsamente como partidas BR terminadas.
- El lobby carga el registro local al volver y muestra victorias, partidas y bajas en PERSONAJE; la pestaña MISIONES muestra el último resultado y señala que las recompensas reales siguen pendientes.
- No se crean monedas, ID global, cuenta Google o almacenamiento Firebase ficticios. **user:// es almacenamiento del dispositivo/app y no sobrevive necesariamente a desinstalar.**

### Resultado verdadero de partida
- Al ganar o perder, se desactiva el disparo, se detienen los bots y se bloquea movimiento de ronda; botón de repetición restaura controles y revive bots.
- Un fallo del guardado muestra una alerta visible; **no** se anuncia persistencia exitosa por el mero hecho de mostrar la pantalla de resultado.

### Crouch/animación
- Se elimina la falsa solución de comprimir en escala Y toda la malla 3D al agacharse. Se utilizan las animaciones `AuroraCrouch`/`AuroraCrouchWalk` existentes, sin encoger cuerpo, armas y esqueleto.
- Para levantarse, `PhysicsShapeQueryParameters3D` comprueba que cabe la cápsula completa; no se atraviesa un techo bajo.
- El texto AGACHAR/LEVANTAR responde a la decisión real de la física, no solo al toque del botón.

### QA obligatoria
- `persistent_match_qa.gd`: ganancia + derrota y orden, ID único, recarga del perfil, mejores marcas y recuperación de respaldo ante JSON corrupto. Usa archivo distinto en `user://qa/` y limpia sus propios datos de CI.
- `sector_battle_qa.gd`: botín, daño, zona, eliminación, victoria, un solo registro y limpieza de bots, más reinicio sin enemigos congelados; usa un archivo QA separado.
- `crouch_collision_qa.gd`: sin squash, bloqueada la transición bajo techo, vuelve a estar de pie cuando desaparece el obstáculo, y HUD sincronizado.
- Se conservan las pruebas anteriores de cámara, ADS x2/x4/x8, AWM y salida aérea.
- APK de QA como **paquete independiente** `com.thedemianff.lastzone.nativepreview751`; firma debug verificada y SHA-256 desde Actions. V70/Google/Firebase intactos.

## No terminado / condición para siguiente fase
- **Lila original:** la operadora CC0 de 52 huesos no cumple todavía las ilustraciones. Se necesita producción real del nuevo personaje 3D, topología, materiales, esqueleto, IK de ambas manos, facial y clips profesionales. Insertar huesos ficticios hasta alcanzar 206 no mejoraría la animación.
- **Multijugador:** los bots offline actuales no representan 100 jugadores humanos; se necesita backend autoritativo, matchmaking, replicación, seguridad y pruebas de carga.
- **Mapa:** el sector actual es mucho menor que 8×8 km; se requiere streaming, navmesh y ocho zonas desarrolladas.
- **Progreso entre dispositivos:** esta persistencia local no equivale a respaldo Firebase. Firebase será otro hito con restauración probada tras reinstalación.
- **Aceptación de Android:** CI en verde demuestra software compilable y pruebas automatizadas, pero cámara/controles/performance y animación deben verificarse físicamente en Motorola Edge 60 Fusion y dispositivos de otras gamas.
- **Licencias:** conservar el control sobre cualquier asset importado; no copiar recursos ni interfaz distintiva de Free Fire.
