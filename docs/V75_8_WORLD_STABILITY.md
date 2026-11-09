# V75.8 — Auditoría de estabilidad de THEDEMIANFF LAST ZONE (Godot)

**Base:** V75.7 `94953d7aa7193d2be30dee2d8459eeb7bbde840d`. **Rama:** `codex/v75-8-world-navigation-stabilization`. No modificar V75.6 estable de prueba, Unity, Firebase, certificados o `v44-3-2-autosave-guest`.

## Defectos prioritarios de las pruebas reales
1. `v753_navigation_qa`: la ruta del bot desde el muro trasero a la puerta de `CENTRO_DE_EXPLORACION` falla; cobertura inaccesible en cambios de terreno anteriores.
2. Escenario: nieve/pendientes atravesando habitaciones, edificios aparentemente flotantes y rutas exteriores deformadas.
3. En el Motorola, cámara bloqueada por interiores; aún pendiente de verificación física.
4. Audio integrado en V75.7 con disparo espacial y buses, pero no mezclado ni auditado acústicamente en teléfono.

## Correcciones integradas en esta rama
- Terreno: conservar la elevación natural de la V75.6 alrededor de los accesos y caminos anteriores. En lugar de trasladar la altura de una cresta a todo el solar, recortar **solamente los picos sobre el suelo interior** de una vivienda, con transición corta y sin elevar puntos bajos. El nuevo sector costero conserva su terraza independiente.
- Navegación: elegir varias anclas A* realmente alcanzables; una ancla cercana aislada no debe inutilizar todas las demás rutas. Aceptar exclusivamente segmentos que superaron las comprobaciones físicas existentes.
- QA: `v758_world_stability_qa.gd` comprueba las cuatro aproximaciones a edificios originales, su interior, las cuatro viviendas del barrio costero y recursos de sonido. Continúan intactas `v753_navigation_qa`, `v756_coastal_quarter_qa` y `v757_world_audio_qa`. **No se desactivan suites fallidas para obtener luz verde.**

## Validación sin generar APK
En esta fase ejecutar **solo** la regresión Godot del workflow `native-godot-foundation.yml`; no incorporar esta rama al workflow Android de exportación. Inspeccionar el log exacto de cualquier prueba fallida. No afirmar que errores de IA, colisiones ni sonido estén resueltos si el QA no terminó satisfactoriamente.

La siguiente revisión abordará el sombreado, la cámara y la integración artística de Lila y Puerto Aurora una vez estabilizados terreno y navegación. El proyecto sigue offline, con un jugador y ocho bots. No declarar mapa 8×8 km, 100 personas online o tiendas reales hasta implementarlos y probarlos.
