# THEDEMIAN: LAST ZONE — V75.61 Lila: física, movimiento y precisión

## Base y reglas de continuidad
Este hito se implementa **directamente sobre V75.60** (PR #61, HEAD `7befa88db2bfee554632d67fb938ae97016f2c9f`, GitHub Actions #43437848729 SUCCESS en la parte de código/Android; el HEAD posterior solo modificaba el documento de V75.60). Godot sigue siendo el motor principal; 1 solo APK **Android Vulkan Mobile ARM64**, versionCode **51**. No se modifica `v44-3-2-autosave-guest`, Unity, Firebase, el ID de paquete o certificado.

## Problemas solucionados en código real

### Lila ya no corre "sobre el sitio" cuando toca una pared
Antes, la animación de pies utilizaba `velocity.xz` solicitada, incluso si `move_and_slide()` bloqueaba el personaje contra una puerta, roca o cobertura. Ahora tanto la selección Walk/Run/Idle como el controlador de ritmo del rig usan **desplazamiento horizontal real tras colisión dividido por delta**.

- El desplazamiento vertical de un salto no genera pasos de carrera.
- NaN, infinito o delta 0 producen velocidad medible 0 y no rompen el árbol de animación.
- Un teletransporte o error de física no puede multiplicar indefinidamente el ciclo de animaciones: límite de medición igual a `RUN_SPEED * 1.20`.
- Los pasos se siguen espaciando según distancia física y dejan de sonar al llegar a una barrera.
- No se altera la posición de la cámara TPS ni la malla de Lila: conserva pelo lavanda, traje original parcial, AnimationTree, armas físicas y colisión.

### Saltos y respuesta del joystick
- Tap de salto móvil o teclado comparten **un buffer** de 0.14 s para tolerar el orden de eventos de los fotogramas y bordes de aterrizaje.
- Ventana coyote de 0.11 s para permitir saltar justo después de dejar de pisar una cornisa; **no permite doble salto libre**.
- El impulso real de salto continúa siendo 5.4 m/s, con gravedad física normal y sin teletransporte.
- El buffer se consume exactamente una vez y se elimina en `reset_controls`, reinicio de partida o pérdida del foco de aplicación.
- Control aéreo moderado a 9 m/s², sin multiplicación injustificada de velocidad durante el salto.
- Frenada de 21 m/s² cuando suelta el joystick y aceleración de giro de 19 m/s² en inversiones para no deslizar el personaje.
- Se respeta la habilidad original de Lila **Aceleración Táctica** por 4 segundos tras una eliminación física, con velocidad máxima consistente.

### Cámara y miras
- Correr no prevalece cuando la mira ADS está activa. Si el usuario apuntaba con sprint táctil activado, el toggle de correr se cancela y el HUD recibe la señal ya existente.
- Sensibilidades, zoom de x2/x4 y AWM x8, cámara trasera 360°, alcance del SpringArm/protección contra muros y controles multitáctiles existentes se conservan sin reescribir ni aproximar.
- No se modifican vuelo, caída libre ni paracaídas, transiciones críticas ya comprobadas en Motorola.

### Build limpio
- El preset de exportación Android todavía conservaba, por error histórico, el nombre de salida `OPENGL-MOTOROLA-DIAGNOSTICO.apk` aunque el renderer fuera Vulkan. Ahora `export_presets.cfg` **nombra directamente la única APK Vulkan** y el verificador de compilación exige dicha ruta, misma firma, paquete y versión.
- La CI Android ejecuta una sola exportación Mobile/Vulkan ARM64 y las pruebas de Godot vuelven a correr desde los recursos de esa APK.

## 20 verificaciones de aceptación del bloque de producción
Estos son **criterios de un bloque jugable**, no 20 sistemas comerciales independientes ni "1.000 mejoras finalizadas".

| # | Aceptación observable | Sistema |
|---|---|---|
| 1 | Se mantiene rig de Lila real y árbol de animaciones | Personaje |
| 2 | La velocidad real se mide después de las colisiones | Locomoción |
| 3 | No corre sobre el sitio cuando lo bloquea una pared física | Locomoción |
| 4 | No suena un ciclo infinito de pasos contra la pared | Audio |
| 5 | La caída vertical no se cuenta como velocidad de carrera | Física |
| 6 | NaN/infinito no rompen la medición de movimiento | Resiliencia |
| 7 | Velocidades instantáneas se limitan por presupuesto físico | Rendimiento |
| 8 | Corre a velocidad real en una plataforma transitable | Locomoción |
| 9 | Se detiene al soltar joystick en terreno físico | Controles |
| 10 | La frenada no produce pasos al detenerse | Audio |
| 11 | El salto móvil funciona por impulso físico | Saltos |
| 12 | Buffer temporal de salto funciona para tap táctil | Saltos |
| 13 | No puede ejecutar un segundo salto sin apoyo | Seguridad jugable |
| 14 | Puede saltar dentro de un breve margen al dejar una cornisa | Saltos |
| 15 | El buffer caduca y no genera saltos posteriores | Saltos |
| 16 | ADS cancela un sprint táctil sin romper el zoom | Cámara |
| 17 | El controlador de animación sigue activo tras cambio locomotor | Animaciones |
| 18 | El reinicio de BR limpia buffer, coyote, sprint, ADS y velocidad medible | Estado |
| 19 | La exportación por defecto no genera rutas con etiqueta OpenGL | Distribución |
| 20 | Toda la regresión antigua + QA nueva pasa en fuente y APK Vulkan | Calidad |

## Pruebas del motor real
Se añadió `v7561_lila_motion_precision_qa.gd`. Esta prueba instancia `Main.tscn` con un suelo y muro de `StaticBody3D` reales lejos de Puerto Aurora. Comprueba carrera en el terreno, bloqueo físico sin pasos falsos, frenada, foco ADS, salto, buffer, ventana coyote y restauración de partido, sin hacer afirmaciones falsas de FPS o estabilidad de teléfono.

El pase de CI **no** prueba la tasa de cuadros ni los gestos en un Motorola Edge 60 Fusion; el usuario autorizó continuar desarrollo sin hacer ensayos físicos hasta que él indique lo contrario.

## Próximo bloque vertical
Más allá de este hito: animaciones/IK de armas y transiciones detalladas de Lila, diferencia de silueta y LOD de rivales, interiores Puerto Aurora, arsenal físico y rendimiento de IA en 30 rivales. La meta de 1.000 tareas sigue auditable, no autodeclarada completa.
