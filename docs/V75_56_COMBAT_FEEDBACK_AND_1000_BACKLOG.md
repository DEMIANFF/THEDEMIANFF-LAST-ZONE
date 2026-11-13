# THEDEMIAN: LAST ZONE — V75.56 / Hito de combate verificable

## Estado de partida
El usuario desea avanzar hacia 1000 mejoras reales, sin interrumpir el desarrollo con pruebas en Motorola hasta que él las solicite. Este hito parte exclusivamente de **V75.55**, rama `codex/v75-55-unified-battle-royale-integration-vulkan`, commit `59db2f44393aed569b47dabbc3d28fb2fb210e89`, cuya CI #43347654639 terminó SUCCESS. No retroceder a V75.28, a Unity ni a versiones HTML.

**Motor Android:** solo Vulkan Mobile; una APK ARM64, código de versión 46. **No** compilar APK OpenGL; el editor Linux puede seguir usando Compatibility para pruebas headless. No cambiar la firma preview, el paquete `com.thedemianff.lastzone.nativepreview`, Firebase, perfiles ni la rama estable `v44-3-2-autosave-guest`.

## Cambios integrados en código para V75.56

### Combate e inventario
1. Contador real de disparos del jugador, por cada acción que consume munición.
2. Contador separado de impactos de jugador que realmente restan salud a CharacterBody3D enemigo.
3. Porcentaje de precisión = impactos confirmados / disparos reales; protección de división por cero.
4. Añadir precisión a instantánea del inventario existente (no persistencia inventada).
5. Añadir precisión al panel de resultados de supervivencia.
6. Guardar tiempo/munición de recarga en un único temporizador de AR y AWM.
7. Barra de progreso visual dependiente de tiempo real para recarga.
8. Barra de recarga sigue posición/opacidad/escala del botón editable de HUD.
9. Cancelar la barra de recarga al cambiar de arma, acabar el combate o perder el control.
10. Recarga solo transfiere munición de reserva al terminar el tiempo establecido.
11. Registrar recargas efectivamente completadas y restablecerlas entre partidas.
12. Pulsar disparo sin cargador ni reserva rechaza la acción, sin cambiar munición.
13. Mantener fuego presionado sin balas no emite cientos de avisos o tiros falsos.
14. Iniciar recarga automática al disparar con cargador vacío y reserva disponible.
15. Mostrar advertencia de munición baja en color ámbar.
16. Mostrar agotamiento total en rojo con «SIN BALAS».
17. Mostrar el estado real del blindaje de Lila según `armor_points`.
18. Actualizar ese blindaje cuando absorbe impactos físicos y cuando se equipa el chaleco.
19. Mostrar número de puntos de salud que perdió un bot por un rayo real.
20. Distinguir visualmente daño confirmado de eliminación confirmada.

### Eliminaciones y zona
21. Cola de eliminaciones cuando un rival real muere (señal de CharacterBody3D).
22. Diferenciar bajas del jugador, IA contra IA y daño ambiental sin atribuir bajas falsas.
23. Utilizar índices de rivales reales, no IDs ficticios de participantes en línea.
24. Limitar a cuatro mensajes en pantalla, para no crear sobrecarga de draw/UI.
25. Tiempo de vida máximo de cada mensaje de eliminación y expiración automática.
26. Restablecer el historial de eventos por partida, sin filtraciones entre encuentros.
27. Avisar por distancia real en metros cuando Lila sale del radio de zona.
28. Al volver al círculo, borrar inmediatamente el aviso persistente.
29. Emitir solo un aviso de incursión por cruce en lugar de repetir alertas cada daño.
30. No sustituir los avisos de disparo, botiquín y arma por avisos de zona repetidos.
31. Mantener daño real por segundo fuera de zona, sin alterar la intensidad.
32. Mostrar daño, precisión y botín en los resultados del encuentro.

### Eficiencia y verificabilidad
33. Progreso de recarga actualizado cada 100 ms como máximo; no recalcular layout por frame.
34. La cola de eliminaciones usa un límite fijo; no retiene centenares de nodos visuales.
35. La cola reutiliza un único `Label` en el HUD, sin crear un `Label` por evento.
36. Los indicadores no capturan eventos táctiles ni bloquean el joystick o la mira.
37. Mantener el editor persistente de controles y la cámara 360° existente.
38. Mantener las 25 posiciones de botín inicial y las tres reposiciones por fase.
39. Mantener V75.49 curación de 3s con interrupciones y mochila real V75.55.
40. Mantener IA V75.50 con cargador, recarga, cobertura y trazadoras.
41. Mantener cámara/paracaídas, colisiones de puertas, HUD y Firebase sin modificaciones.
42. Nueva QA de integración `v7556_combat_feedback_qa.gd`, sin simulación de FPS.
43. QA fuente y QA exportada sobre una sola APK Vulkan ARM64 firmada.
44. Medir métricas en el Motorola **solo cuando el usuario autorice la prueba**.

Las líneas anteriores son **criterios verificables de este hito**, no 44 nuevas armas, escenarios o sistemas independientes. No afirmar que las 1000 mejoras ya fueron completadas.

## Programa de 1000 mejoras: 20 bloques de 50, todos pendientes de auditoría individual

Esta es una **estructura de planificación**, no 1000 cambios completados ni un compromiso de ejecutarlos de forma asíncrona. Las futuras tarjetas solo se contabilizan al modificarse código/activos reales y verificarse con QA.

| Bloque | 50 criterios de aceptación por especialidad | Estado |
|---|---|---|
| 01 | Lila: animaciones, transición y esqueleto | En desarrollo |
| 02 | Cámara, ADS, scopes y multitouch | En desarrollo |
| 03 | Disparo, balística, sonido e impactos | En desarrollo |
| 04 | Armas, munición, recargas y equipo | En desarrollo |
| 05 | Inteligencia táctica individual | En desarrollo |
| 06 | Coordinación, patrulla, coberturas y navegación IA | En desarrollo |
| 07 | Zonas, botín, avión y resultados | En desarrollo |
| 08 | Viviendas y colisiones habitables | En desarrollo |
| 09 | Puerto Aurora: escala y entornos nuevos | Pendiente |
| 10 | Materiales, animación ambiental e iluminación Vulkan | Pendiente |
| 11 | Audio espacial y retroalimentación visual | Pendiente |
| 12 | Optimización CPU, GPU, batería y calidad adaptable | En desarrollo |
| 13 | HUD, sensibilidad, accesibilidad y personalización | En desarrollo |
| 14 | Progresión, recompensas y economía justa | Pendiente |
| 15 | Perfiles, autenticación, guardado y recuperación | Parcial |
| 16 | Infraestructura de servidor autoritativo | Pendiente |
| 17 | Jugadores humanos online y sincronización de combate | Pendiente |
| 18 | Dúos, escuadras, reanimación y emparejamiento | Pendiente |
| 19 | Seguridad, anti-trampas, moderación y observabilidad | Pendiente |
| 20 | QA hardware, localización, publicación y operaciones | Pendiente |

**Regla de calidad**: no llamar 'battle royale online completo' a partidas locales 1 jugador + 8/19/29 IA; 50 jugadores humanos requerirían servidores y QA multiplayer independiente.

## Aceptación del hito
No fusionar hasta que fuente, regresiones históricas y QA exportada pasen en CI. No pedir al usuario instalar APK ni hacer pruebas físicas hasta que él lo autorice. El juego sigue en desarrollo; la validación Linux no prueba 60 FPS reales ni ausencia de cierres en Motorola.
