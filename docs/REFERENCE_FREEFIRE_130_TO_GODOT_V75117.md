# THEDEMIAN: LAST ZONE · Auditoría de referencia técnica FF 1.30.0 (2019) e integración V75.117

**Procedencia de análisis:** `THEDEMIAN_ANALISIS_FREEFIRE_130.pdf` (10 páginas, 16-nov-2026) y `THEDEMIAN_EVIDENCIAS_FREEFIRE_130.zip` de la biblioteca del usuario. El ZIP adjunto es una compilación de índices y resúmenes; la fuente es un cliente Unity IL2CPP antiguo, incompleto para efectos de mecánicas de servidor. Los datos proceden de análisis estático **no oficial** y de un paquete potencialmente modificado. No los tratamos como código fuente, derechos de uso de activos, especificaciones actuales de Garena ni fórmulas de jugabilidad comprobadas. **No se copia ningún clip, audio, malla, textura, texto extenso, script o código binario ajeno.**

**Base comprobada:** `codex/v75-116-aurora-arctic-airfield`, commit `45531e42e7ad72a5502f5afd0b55443f6fb7e28a`, GitHub Actions `43925675877` SUCCESS. Motor Godot 4.7.2; objetivo ARM64 Mobile/Vulkan; Motorola Edge 60 Fusion. Stable `v44-3-2-autosave-guest` y Firebase productivo NO se modifican.

## Evidencias relevantes de los informes (no funciones ya implementadas)

| Área observada en el archivo de 2019 | Evidencia concreta | Equivalencia y alcance en THEDEMIAN |
| --- | --- | --- |
| Cámara/controles | Controladores FollowCamera, SkydivingCamera y FreeCamera; offset dentro/fuera de interiores; identificador de dedo TouchFinger y limpieza TouchData | `third_person_operator.gd` ya tiene cámara por estado de vuelo, ADS y sensibilidad x2/x4/x8; hay que certificar gestos simultáneos en Motorola y liberación de dedos al cerrar menús |
| Animación por capas | Base Layer 57/58 estados, UpperBody 18/18, UpperBodyAdditive 5/5; Parachute_Open y Parachuting son estados distintos | `operator_animation.gd` ya superpone acciones de torso a locomoción; exigir rig Lila, pies, manos y torso coherentes durante salto, recarga y daño, sin importar clips de Unity |
| Francotirador | Sustituciones de estado Fire_AWP y nombres de audio AWM Fire/Bolt/ChangeClip; eventos PlayPullBoltSound | **V75.117 integra un evento ORIGINAL de cerrojo 0.28 s después de cada disparo AWM consumado, dentro del bloqueo de 0.50 s**. Genera sonido propio distinto de disparo/recarga y cancela al cambiar arma, recargar, finalizar o reiniciar partida. No es un audio ni fórmula de Free Fire |
| HUD y minimapa | InGameHudConfig, 33 controles con Anchor, btnScale, ShowAlpha y Locked. El análisis no prueba que todos se muestren simultáneamente | El proyecto dispone de 13 controles editables en `hud_layout.gd`, presets 1-4 y navegación de ajuste. Ampliar progresivamente **solo** controles que existan realmente, adaptar anclas a safe rect; no copiar coordenadas originales |
| Combate/partida | Estados de avión, caída, paracaídas, inventario, daño, derribo, reanimación y SafeZone; fórmulas de daño desconocidas | `sector_director.gd` tiene zona de 4 fases y partida local con 1 jugador y 49 IA. Separar progresivamente un modelo autoritativo de datos, sin confundirlo con un servidor online |
| Mundo/streaming | 2.549 escenas incluyen 2.530 sectores; LODGroup 2.561; WorldStreamer y ColliderStreamer con límites de carga | Nuestro entorno Godot requiere un gestor propio de sectores/colisiones y LOD/carga incremental bajo presupuesto de VRAM. **No** copiar tamaños de chunk ni reclamar que las 2.549 escenas sean mapas distintos |
| Ajustes gráficos | Perfiles Simple/Standard/Beautiful; sombras, shader LOD y nivel de niebla | Revisar `aurora_render_budget.gd` y medición real en Motorola; 120 Hz del panel no garantizan 120 FPS ni se deben cambiar a Compatibility |
| Red | Identificadores de PlayerNetwork y mensajes tcp/proto; código y autoridad del servidor NO recuperados | Planear Godot dedicated server, validación de acciones críticas y backend separado, sin afirmar que Firebase Authentication por sí sola habilite multiplayer |
| Audio | 393 AudioClip indexados, pero no medios originales en paquete de evidencias | Mantener SFX originales/generados o con licencia. Los cues deben dispararse desde eventos reales, no por supuestos eventos de paquetes antiguos |

## Bloque de código que SÍ entrega V75.117

1. `training_combat.gd` usa el disparo físico existente, cuenta una bala y programa un único evento `awm_bolt_cycled` a 0.28 s. Mantiene `AWM_BOLT_SECONDS=0.50`, impidiendo una segunda bala dentro de ese tiempo. Cambio de arma, recarga, muerte/vuelo/final de combate y nueva partida cancelan ese cue pendiente.
2. `aurora_audio.gd` produce una señal original de deslizamiento y bloqueo del cerrojo (`awm_bolt`) con dos transitorios metálicos distintos del disparo y la recarga; no usa medios de Free Fire.
3. `main.gd` vincula el evento de juego confirmado a un reproductor de audio existente, sin otro hilo ni recursos durante física.
4. `v75117_awm_bolt_timeline_qa.gd` inicia el mundo real, recoge el arma física, comprueba la bala única, la cadencia y el sound cue, y verifica cancelación ante recarga, cambio y fin de partida. Se añade al `run_qa.sh` sin eliminar regresiones antiguas.
5. Versionado preview `75.117.0-mobile-vulkan`, código `107`. La exportación de APK sigue manual mediante `workflow_dispatch`.

## Siguientes bloques — pendientes, NO realizados en esta versión

1. **Cámara y 4 dedos:** prueba física de movimiento+mirada+disparo+ADS en avión, caída, paracaídas y combate, limpieza al abrir HUD/mapa y conservación de yaw/pitch.
2. **Rig de Lila:** acciones aditivas e IK/manual sockets verificados, cerrojo con animación esquelética específica original (V75.117 sincroniza sonido y bloqueo; **aún no añade un clip bolt dedicado**), salto y apertura del paracaídas con transiciones visuales.
3. **HUD completo:** inventario real de controles existentes, bloqueo individual y configuración del tamaño/opacidad sin destruir presets; retorno al origen (lobby vs partida).
4. **Sistema de sectores:** colisiones antes de activación, carga/descarte con radios propios y LOD, y garantías de botín sobre terreno; medir draw calls y memoria.
5. **Estado de partida:** modelo explícito de transiciones y única fuente de verdad para daño, munición, zona y resultado; motor offline hoy, autoridad remota futura.
6. **Servidor propio:** servidor dedicado Godot, simulación autoritativa, predicción, reconciliación, matchmaking, equipamientos y persistencia. **No existe online funcional demostrado por el archivo de 2019.**

## Aceptación y límites

- Pruebas estáticas y simulaciones temporales con avance de reloj determinista no equivalen a probar un teléfono. Ejecutar todos los QA y revisar CI. Exportar la única APK de prueba solo cuando el usuario lo indique; en Motorola verificar audio, tiempo de cerrojo, sensibilidad y rendimiento.
- Las cifras del documento de referencia (928 clips, 33 controles, 2.530 sectores, etc.) son descripciones del cliente 2019, no metas de replicación literal ni activos importables.
- Los nombres propietarios de Free Fire no se incorporan a las pantallas ni al contenido del juego. Todo comportamiento se diseña con código y presentación original THEDEMIAN.
