# Godot V75.9 — Cámara TPS en interiores

## Base comprobada

Rama anterior `codex/v75-8-world-navigation-stabilization` (commit `c9135b40de30f119103101446e9ba2989f670e86`), con las **23 suites de regresión aprobadas** en la ejecución https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/42711676009. Su PR #17 permanece en borrador, no fusionado.

## Defecto específico

En los interiores, la cámara TPS de hombro derecho podía retroceder hasta el pivote al tocar una pared, mostrando el cuerpo del personaje u ocultándolo antes de que la cámara realmente recuperara distancia. En ADS x8 el modelo local nunca debe tapar la retícula. La solución NO cambia la posición panorámica normal a campo abierto.

## Cambios integrados

- Proyección de colisión real con esfera del mismo tamaño y máscara física existente, ajustando opcionalmente su eje lateral.
- Si la cámara está muy obstruida, comprueba primero la línea central; solo cuando es físicamente más despejada desplaza el hombro a ese eje. Si no sirve, prueba el hombro opuesto. Sondeos adicionales únicamente cuando la cámara necesita contraerse; se conserva el coste bajo del caso normal.
- El zoom se contrae inmediatamente ante paredes y se aleja con suavizado temporal al liberar el camino, evitando atravesar colisiones.
- El personaje local se oculta según la **posición actual** de la cámara, no el valor objetivo futuro, y se oculta siempre durante AWM x8. En cuanto el espacio real lo permite, recupera su representación, sin afectar a los enemigos ni a las colisiones del personaje.
- Nueva suite `v759_camera_obstruction_qa.gd`: crea obstáculos físicos de verdad en la escena, comprueba contracción, ausencia del cuerpo delante de la lente, recuperación tras eliminar la pared, cambio de hombro, retorno al hombro normal y transición ADS AWM x8.

## Sin afirmaciones prematuras

No se ha realizado prueba física en Motorola; el resultado de GitHub Actions se consulta en la rama. No se ha creado ninguna APK. No se modificaron Unity, Firebase, firmantes originales ni `v44-3-2-autosave-guest`. Los modelos artísticos definitivos de Lila y Puerto Aurora, sonido comercial masterizado y multijugador siguen siendo objetivos posteriores.

## Criterio de aceptación

El workflow de QA de esta rama debe aprobar las 23 suites anteriores y la nueva suite de colisiones de cámara, sin desactivar las pruebas existentes para conseguir verde.
