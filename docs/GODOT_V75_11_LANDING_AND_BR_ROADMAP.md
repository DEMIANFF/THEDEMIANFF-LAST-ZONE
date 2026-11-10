# THEDEMIANFF LAST ZONE — Godot Battle Royale: integración y aterrizaje

Base comprobada: `codex/v75-11-aurora-gait-coastal-detail` @ `dd4aca947cfe8ef8aab90371350a1b4766495b9c`.
Rama correctiva: `codex/v75-11-landing-stability-fix`.
Motor: Godot 4.7.2; objetivo de prueba: Motorola Edge 60 Fusion.

## Estado verificado y límites de calidad

- El sector Godot existente es **offline**, con 1 persona + 8 bots, mapa Aurora/Puerto Aurora; no es un Battle Royale online de 50/100 personas.
- V75.11 registró fallo de CI en la QA de zancada/carrera; la exportación ARM64 no llegó a ejecutarse. No se declara una APK funcional hasta tener las pruebas verdes.
- Usuario reporta cierre al caer desde el avión. **Causa real todavía no confirmada con logcat del dispositivo**.
- Esta rama cambia la entrega de touchdown para no instanciar botín/combate/física dentro de la señal lanzada por `CharacterBody3D._physics_process`; añade 90 ticks post-aterrizaje a la QA. Es una mitigación técnica sometida a validación, no garantía de corrección definitiva.
- La QA de pisadas mantiene colisiones reales en las cajas del barrio; comprueba locomoción en un piso físico aislado para evitar interferencia de barricadas.

## Mecánicas solicitadas y adaptación original a Godot

| Sistema | Contrato final deseado | Estado al crear esta rama |
|---|---|---|
| Battle Royale | 50 jugadores iniciales (arquitectura escalable a 100), solo/dúo/escuadra 4, sesión 9–11 min, avión, salto, caída, aterrizaje, saqueo, anillos y victoria | Offline 9 participantes; infraestructura online y escalabilidad pendientes |
| Movimiento | Caminar, correr, saltar, agacharse, tumbarse, deslizarse, disparar mientras se mueve; AnimationTree con clips completos | Caminar, correr, salto, agacharse, cámara y clips parciales; tumbarse/deslizarse pendientes |
| Armamento | Rifles, SMG, escopetas, AWM x8, melee y arrojadizos; retroceso, dispersión, ADS, recarga y cambio | AR y AWM x8 son actuales; resto por implementar y validar |
| Cobertura táctica | Barrera instantánea **original** de hielo Aurora con inventario, colisión, vida, límite, despliegue y destrucción | Pendiente; nunca copiar la apariencia de paredes de terceros |
| Botín y equipo | Chalecos, cascos, mochilas niveles 1–3, botiquines, energía, granadas de humo/fragmentación | Botín sector y botiquines iniciales; niveles/otras categorías pendientes |
| Personajes | Lila y operador masculino, esqueletos/retargeting con jerarquía correcta, habilidades activa y pasiva con mejoras | Lila/rig existente provisional; habilidades y personaje masculino final pendientes |
| Escuadras | Reanimación con límite por jugador/etapa, equipo, marcadores, comunicación | Requiere modelo de escuadras y autoridad de servidor; pendiente |
| Zona | Fases temporizadas y alto daño al final, transiciones visuales y sonido | Círculo decreciente y daño funcionales en sector offline; ampliar |
| HUD y cámara | Joystick izq.; cámara independiente 360°; disparo-drag der.; botones salto, crouch, prone, habilidades y cobertura; layout editable/compartible, sensibilidad general y por mira | HUD, cámara y disparo-drag funcionales parcialmente; editor HUD y nuevos controles pendientes |
| Modos | 4v4 por rondas con economía, competitivo por rangos, editor de mapas original | Pendientes |
| Mapas | Base Aurora glaciar + Puerto Aurora y biomas originales complementarios; optimización LOD/chunks | Sector actual pequeño; mundo objetivo 8×8 km no generado aún |
| Cuenta | Invitado y Google con restauración Firebase e ID legible | Preservar Firebase y verificar conexión Godot de extremo a extremo antes de declarar sincronización |

## Orden técnico de integración

1. **Bloqueante: cierre al aterrizar**. Reproducir avión → caída libre → paracaídas → aterrizaje → 90+ ticks → primera bala/botín → regreso lobby en editor y APK Motorola. Prohibido declarar corrección final solo por CI.
2. **Seguridad de fase**. Maquina de estados para avión/caída/paracaídas/suelo, transición idempotente y diferida, controles/restablecimiento correctos; guardar `phase`, posición y últimas señales para diagnosticar cierre físico.
3. **Combate/cobertura**. Barrera original Aurora destructible con colisión contra raycasts de jugadores y bots, cooldown e inventario auténticos; nuevas armas con balance/retroceso y ADS.
4. **Animación**. Lila y operador masculino: retarget de rigs, locomoción y reacción de impactos, deslizamiento, prone, jump/land, weapon IK. No exigir arbitrariamente “206 huesos”: calidad de rig y deformación medible es el criterio.
5. **HUD móvil**. Área libre de cámara, joystick de disparo direccional, minimapa, mochila y blindaje, editor y códigos de HUD; varias resoluciones y dos dedos simultáneos.
6. **Mundo y rendimiento**. Arquitectura original Aurora/urbano/biomas, colisiones precisas, coberturas navegables, LOD, instancing, texturas compactas, profiler y FPS/temperatura/memoria reales en Edge 60 Fusion.
7. **Squads y online**. Replicación con servidor autoritativo, matchmaking, reanimación, conteo fiable de escuadras, reglas de antitrampas y persistencia; primero prueba pequeña con dispositivos reales, después escala.
8. **Otros modos**. Combate 4v4, Ranked y editor de mapas creados por usuario; pase/tienda/economía y progreso con persistencia.

## Criterios de aceptación

- No introducir assets, marcas, mapas, personajes ni interfaces copiadas de Free Fire/Blood Strike: usar únicamente referencias funcionales y diseño propio.
- Sin ramas protegidas modificadas: `v44-3-2-autosave-guest`, Unity V76, Firebase y certificados originales siguen intocables.
- Cada entrega precisa `branch`, `SHA`, QA ejecutada, resultado de Actions y una lista explícita de funciones faltantes.
- Firma y namespace debug de preview **separados** de Android de producción; prueba física Motorola obligatoria antes de fusionar.
