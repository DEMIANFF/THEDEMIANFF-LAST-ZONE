# V73.2 — Controles TPS / Fuego con arrastre / Miras

## Evidencia en video del Motorola
El usuario envió `148899.mp4` (34 s) y una captura externa mostrando una distribución táctil de referencia. En la grabación del juego nativo se observan:
- operadora mirando de frente a la cámara en lugar de mostrar la espalda en TPS;
- botón de disparo sin arrastre direccional;
- obstáculos que llenan el encuadre y pérdida del objetivo en algunos giros;
- salto entre vista libre y ADS sin retícula óptica visible;
- HUD todavía sin control funcional para agacharse.
Se ven enemigos de entrenamiento, pero IA no equivale a jugadores humanos ni comportamiento táctico completo.

## Cambios implementados
1. **Tres fuentes de cámara:** paneo libre con el lado derecho libre del HUD, paneo durante el disparo con dedo propietario `DirectionalFirePad`, y ADS con sensibilidad graduada. Las tres se acumulan sobre una sola orientación deseada; suavizado con delta time.
2. **Independencia de giro:** cámara orbita al jugador quieto; el cuerpo gira al moverse, ADS o disparar. `CameraPivot` compensa la rotación corporal para evitar dobles yaw.
3. **Dirección visual corregida:** rotación de la malla CC0 para orientar el frente del avatar hacia -Z, dejando la espalda frente a la cámara posterior. Sigue siendo **modelo provisional**, no la Lila de las ilustraciones.
4. **Disparo real con arrastre:** control de fuego `Control._gui_input`, índice de dedo propio, botón presionar y mantener para AR, arrastrar para afinar ángulo, soltar para cesar fuego. Cámara libre con otro dedo no invade el espacio de botones; el joystick izquierdo mantiene su propietario independiente.
5. **Miras:** AR x2→x4→libre; AWM x8→libre. Retícula se sincroniza con el centro óptico del `Camera3D`, con sensibilidad reducida al aumentar zoom. Se mantiene un disparo AWM por pulsación y cerrojo 0,5 s.
6. **Obstáculos:** cámara intenta recortar su distancia mediante raycast a paredes para no atravesarlas. Debe verificarse con geometría real y cerca de edificios.
7. **Agacharse:** botón alternable que reduce cápsula, velocidad y altura de cámara; la animación de agacharse/IK queda pendiente. El cambio provisional de escala visual **no** se considera una animación final de calidad.
8. **AK-74:** intento de anclar el rifle al hueso `RightHand`; si el rig importado carece de ese hueso se mantiene soporte provisional con advertencia. Se necesitan ajustes y verificación visual de manos y arma antes de aprobarlo.

## Pruebas
- `camera_fire_qa.gd`: libre sin rotación involuntaria del cuerpo, zoom por arma, pulso y arrastre, liberación del gatillo y agacharse.
- Persisten `smoke_test.gd`, `combat_rules_test.gd`, `motorola_control_audit.gd` y `mobile_touch_routing_test.gd`.
- **Las pruebas headless no certifican multitouch Android real, FPS, ni fidelidad visual.** Se requiere video de dispositivo y benchmark.

## Pendiente
Modelo Lila original con rig propio y transiciones naturales; ADS exacto con IK de hombro y soporte dual de manos; sonido/efectos y retroceso calibrado; cobertura y navegación de IA; escenarios y materiales de calidad; optimización; ciclo completo de battle royale. Proteger V70 y su guardado Firebase. No usar iconos/recursos extraídos de Free Fire: reproducimos patrones generales de interacción con diseño original.
