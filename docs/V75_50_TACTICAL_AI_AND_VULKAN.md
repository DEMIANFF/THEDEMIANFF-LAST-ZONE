# THEDEMIAN: LAST ZONE — V75.50 | IA táctica y combates de mayor calidad

## Base
Continuación directa y sin reconstrucciones desde V75.49, SHA `fdfa0ee25e824d1669adbc3a8fbe295d0d3e9f36`, PR #54, CI #43337794454 PASS. V75.49 fue exportada y probada en CI pero todavía requiere prueba física del Motorola; no confundir esa validación con 60 FPS reales.

**Render y protección:** una sola APK Android ARM64 Vulkan Mobile (versionCode 44), sin APK OpenGL adicional. El editor headless de Linux conserva el render compatible para ejecutar las pruebas. No modificar Firebase, respaldo Google, firma preview, paquetes, rama estable `v44-3-2-autosave-guest`, controles, física 60Hz ni Unity.

## Sistemas reales introducidos
### Combate de enemigos autónomos
- Cada enemigo tiene cargador limitado de 18 disparos y recarga de 2,25 s.
- Dispara ráfagas cortas de dos balas, con intervalo de 0,37 s y recuperación mayor entre ráfagas. Se acabaron los disparos infinitos a cadencia fija.
- El enemigo no puede disparar mientras recarga; reinicia munición y estado al comenzar una partida nueva.
- El enemigo puede intentar llegar a un punto de cobertura sólido al recargar o estar gravemente herido.
- Mantiene reacciones a ruido, daño, IA contra IA, barreras desplegables, combate con rayos físicos y comprobación de obstáculos.

### Movimiento y toma de decisiones
- Desplazamiento lateral de corta duración al mantener contacto visual, con dirección estable y cambio espaciado para no recalcular rutas en cada fotograma.
- Corrige huida de la zona: calcula un punto dentro del círculo seguro en lugar de hacer que todos los bots corran exactamente al centro.
- La adquisición visual ordena enemigos por distancia, prueba físicamente línea de tiro y limita a cinco rayos por exploración, sin buscar objetivos a través de paredes.
- Pequeña persistencia de objetivos confirmados, verificada con otro rayo; reduce cambios frenéticos entre rivales cercanos.
- No acepta daño negativo o NaN en agentes de IA.
- Al recibir daño, se acelera la próxima exploración visual.

### Rendimiento y efectos verificables
- Búsqueda de coberturas: candidatos por distancia y máximo ocho intentos costosos de rutas A*, manteniendo protección física y accesibilidad.
- Trazadoras enemigas rojizas ancladas a la trayectoria exacta de PhysicsServer. No hay disparos decorativos ni enemigos simulados.
- Ocho trazadoras de rivales reutilizables, independientes de las ocho del jugador: sin asignar mallas por disparo.
- Cota de longitud y duración de efectos, y limpieza al salir/reiniciar el encuentro.
- Entradas de sonido y daños ya existentes permanecen conectadas.

## Pruebas de aceptación
`v7550_tactical_ai_combat_qa.gd` instancia una partida real de 9 participantes locales y verifica:
1. Mobile/Vulkan como export Android.
2. Munición, temporizador y duración de ráfaga configurados.
3. Límite por exploración de cinco rayos de visión.
4. Límite de ocho rutas A* para puntos de cobertura.
5. Zona segura interior sin aglomerarse en el centro.
6. Combate físico IA contra IA con daño real.
7. Desplazamiento lateral táctico.
8. Trazadora visible al disparo físico, con mallas reutilizadas.
9. Cargador vacío y recarga iniciada tras disparar.
10. Ningún disparo mientras recarga.
11. Recarga de munición tras duración real.
12. Enemigos muertos ignorados en selección de objetivos.
13. Daño negativo / NaN rechazado.
14. Reinicio completo de munición, estadísticas y estado táctico.

El QA nuevo se incorpora al historial de 59 pruebas y se repite sobre recursos de la única APK Vulkan exportada. Las viejas pruebas de entrar a casas, aeronave/paracaídas, AWM, IA y curación deben seguir pasando.

## Qué no se afirma
- Estas mejoras están codificadas, pero necesitan CI completamente verde y ensayo Android en Motorola Edge 60 Fusion antes de declararse aprobadas en hardware.
- 9/20/30 incluye 1 jugador humano local y el resto enemigos IA físicos. No equivale a partidas online de 50 personas.
- No se han completado 1000 mejoras ni el BR comercial terminado.

## Siguientes hitos
Diseño de personaje masculino/animaciones, interacciones interiores, armas e inventario extendidos, economía y progresión, multiplayer autoritativo con escuadras, networking fiable, protección de cuentas y rendimiento Vulkan final.
