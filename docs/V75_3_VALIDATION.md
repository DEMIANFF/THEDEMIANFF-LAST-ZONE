# V75.3 — cambios verificables y aceptación

Base obligatoria verificada: `codex/v75-2-motorola-recovery`, commit `3a61df64b59de94bf1fb8ffad4b8bbf3a538e851`, checkout inicialmente limpio. Trabajo exclusivo en `codex/v75-3-battle-royale-improvements`.

## Defectos y correcciones

| Prioridad | Evidencia reproducida | Corrección / regresión |
|---|---|---|
| P0 | Una cámara sobre cobertura baja dañaba al enemigo: 100 → 74 aunque el arma estaba bloqueada. | Selección óptica más rayos pecho–cañón y cañón–objetivo. La misma prueba conserva 100 detrás de cobertura y produce 74 con paso libre. |
| P0 | Inmunidad de disparos anulaba el daño de la zona: salud permanecía en 100. | Canal ambiental independiente; la prueba obtiene 94 y mantiene la inmunidad frente a balas. |
| P1 | Entrada elevada detenía al personaje antes de la puerta. | Rampas con dos tramos sobre el rellano y la cimentación; prueba de caminata sin salto en los cuatro edificios. |
| P1 | Altura continua estimada no coincidía con los triángulos físicos del terreno. | Interpolación de la misma malla y caché de alturas; comparación con rayos físicos. |
| P1 | La IA solo esquivaba localmente y confundía pendientes transitables con paredes. | Grafo A* compartido, aristas comprobadas con cápsula, rutas almacenadas y evitación que distingue suelo de pared. Un bot rodea el edificio y entra por la puerta mediante movimiento físico. |
| P1 | Recarga AR solicitaba reposo; acciones completas podían sustituir el movimiento de piernas. | AnimationTree con capa superior filtrada, recarga AR/AWM ajustada a su duración, disparo e impacto. Locomoción y agachado siguen activos. Cancelación al cambiar arma o perder control. |
| P1 | Inventario de cinco botiquines consumía otra recogida sin añadir unidades. | Rechazo con inventario lleno, reintento por proximidad al liberar espacio y comprobación de obstáculos para recoger. |
| P2 | Cada bala creaba malla, material, nodo y temporizador. | Ocho trazadores reutilizados; prueba de 500 activaciones sin aumentar nodos. |
| P2 | No existía ajuste de sensibilidad en el cliente nativo. | AJUSTES del lobby: giro y ADS independientes, escritura diferida, archivo temporal y respaldo, recuperación y rechazo de valores no finitos. |

Se conservan cámara panorámica e independencia en avión/paracaídas, joystick analógico, caminar/correr, disparo con arrastre, multitáctil, miras AR x2/x4 y AWM x8, colisiones de tejados y registro recuperable de resultados de V75.2.

También se añaden seis coberturas físicas, reacción de IA al atacante correcto, búsqueda de cobertura cuando está herida y disparos de IA con dispersión y colisión real. Los indicadores de enemigos y botín respetan la profundidad. La construcción del grafo se reparte entre fotogramas; la cámara y la evitación reutilizan sus consultas.

## Validación automatizada

La base V75.2 aprobó 14/14 suites antes de las modificaciones. La suite V75.3 contiene esas 14 y cuatro nuevas: `v753_combat_regression_qa`, `v753_navigation_qa`, `v753_animation_settings_qa`, `v753_frontend_qa`.

`tools/run_qa.sh` exige importación correcta, código de salida cero, marcador final de cada prueba y ausencia de errores de Godot. `tools/run_exported_qa.sh` extrae los recursos de la APK y ejecuta esas mismas suites sobre los `.gdc` exportados, con perfil local aislado. Esto valida recursos y lógica empaquetados en el motor de escritorio; no ejecuta Android ni prueba el teléfono.

Los workflows de esta rama generan los modelos necesarios antes de las pruebas. El de APK renderiza interfaz real con OpenGL por software, comprueba resoluciones panorámicas y rechaza columnas negras. Produce la APK ARM64 únicamente después de aprobar las puertas anteriores. `verify_android_apk.py` verifica CRC, identificador/versionado, ABI único, firma v2/v3, alineación ZIP de 16 KiB y segmentos ELF AArch64 de 16 KiB.

Los resultados de una ejecución concreta están en sus logs y artefactos; la existencia de este documento no sustituye esas comprobaciones. El SHA del commit, motor y Blender se guardan en `BUILD.txt`, y el hash del APK en `SHA256SUMS.txt`.

## Límites y pruebas físicas pendientes

- Partidas offline de nueve participantes. No hay servidor autoritativo, cien jugadores, matchmaking ni cuentas Godot conectadas a Firebase.
- Operadora CC0 provisional. Las acciones esqueléticas son de desarrollo; Lila definitiva, IK completa de ambas manos y calidad de animación final siguen pendientes.
- Armas hitscan con trazadores visuales; no se presenta este sistema como balística física de proyectiles.
- Navegación peatonal por grafo para el sector estático. No implica escalada, navegación automática en todos los tejados ni resolución de cualquier bloqueo dinámico.
- Las optimizaciones reducen asignaciones observables; todavía no hay medidas de FPS, temperatura, memoria ni latencia táctil en Motorola.
- La APK de depuración V75.3 tiene paquete propio y no migra automáticamente el registro local de V75.2. La instalación anterior puede conservarse.

Aceptación en Motorola Edge 60 Fusion: abrir/reabrir y rotar a ambas orientaciones horizontales; comprobar bordes, recorte y gestos del sistema; caminar/correr/disparar/apuntar con tres dedos; girar en avión, salto y paracaídas; usar x2/x4/x8; recargar caminando y agachado; recorrer las cuatro entradas y aterrizar en tejados; terminar victoria y derrota, regresar al lobby y reiniciar; registrar FPS y temperatura durante una partida completa. No se declaran aprobados estos pasos sin ejecutarlos en el dispositivo.

## Alcance protegido

Sin cambios en `v44-3-2-autosave-guest`, Unity V76, certificados originales ni configuración Firebase. Sin fusión del PR #12. Los commits se publican solo en la nueva rama de desarrollo.
