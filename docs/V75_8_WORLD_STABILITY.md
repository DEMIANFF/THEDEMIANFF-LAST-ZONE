# V75.8 — Auditoría de estabilidad de THEDEMIANFF LAST ZONE (Godot)

**Base:** V75.7 `94953d7aa7193d2be30dee2d8459eeb7bbde840d`. **Rama:** `codex/v75-8-world-navigation-stabilization`. No modificar V75.6 estable de prueba, Unity, Firebase, certificados o `v44-3-2-autosave-guest`.

## Defectos prioritarios de las pruebas reales
1. `v753_navigation_qa`: la ruta del bot desde el muro trasero a la puerta de `CENTRO_DE_EXPLORACION` falla; cobertura inaccesible en cambios de terreno anteriores.
2. Escenario: nieve/pendientes atravesando habitaciones, edificios aparentemente flotantes y rutas exteriores deformadas.
3. En el Motorola, cámara bloqueada por interiores; aún pendiente de verificación física.
4. Audio integrado en V75.7 con disparo espacial y buses, pero no mezclado ni auditado acústicamente en teléfono.

## Correcciones integradas en esta rama
- Terreno: **se conservó el relieve original del sector antiguo de V75.6** y se niveló únicamente la zona costera con transiciones y exclusiones alrededor de las cuatro construcciones previas. Esta separación restaura las rutas de bots y permite que las cuatro viviendas nuevas se asienten en la misma terraza de 7 m.
- Arquitectura: en Taller Helios y Estación Meteorológica se calculó la altura de suelo con muestras de los puntos ocupados, elevando la solera lo justo y **extendiendo las cimentaciones de piedra hasta el terreno original**, sin excavar el acceso exterior ni crear edificios suspendidos.
- Navegación: se recuperó la implementación A* de V75.6, que demostró superar el recorrido completo de bots detrás del Centro de Exploración. La variante de múltiples anclas no superó las pruebas de este terreno y **no se incluyó en el incremento aprobado**.
- QA: `v758_world_stability_qa.gd` comprueba las cuatro aproximaciones a edificios originales, su interior, las cuatro viviendas del barrio costero y recursos de sonido. Continúan intactas `v753_navigation_qa`, `v756_coastal_quarter_qa` y `v757_world_audio_qa`. **No se desactivan suites fallidas para obtener luz verde.**

## Validación sin generar APK
**Validación realizada:** 23 de 23 suites aprobadas en https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/42711676009, incluyendo `v753_navigation_qa`, `v756_coastal_quarter_qa`, `v757_world_audio_qa` y `v758_world_stability_qa`. Se ejecutó únicamente el workflow de QA de Godot. **No se generó APK** ni se verificó el rendimiento en Motorola.

La siguiente revisión abordará el sombreado, la cámara y la integración artística de Lila y Puerto Aurora una vez estabilizados terreno y navegación. El proyecto sigue offline, con un jugador y ocho bots. No declarar mapa 8×8 km, 100 personas online o tiendas reales hasta implementarlos y probarlos.
