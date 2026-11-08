# Godot V75.4 — correcciones tras pruebas en Motorola

Base exacta: V75.3 `90d0a7d56a39f0743ebe07a684cd4961cce3d9c9`,
rama nueva `codex/v75-4-aim-animation-recovery`.

- Tramos visuales de balas de hasta 24 m y 0,075 s sin reducir hitscan
  de 250 m ni atravesar paredes.
- Eje del arma sincronizado con el yaw y pitch de la cámara y el socket de
  mano derecha antes de cada disparo.
- Retroceso aditivo y recuperable sin alterar manualmente el ángulo elegido.
- Gait procedural provisional con muestras adicionales, rodillas y tobillos
  articulados y leve transferencia de peso de pelvis.
- Nueva QA `v754_aim_pose_qa.gd`, captura de ADS y paquete Android independiente
  `com.thedemianff.lastzone.nativepreview754`.

**Límites:** no se han medido nuevos FPS ni se ha probado aún el nuevo APK en
Motorola; quedan pendientes animación profesional, Lila definitiva e IK de
ambas manos. V75.3, Unity V76, Firebase y certificados originales intactos.
Juego offline de 1 jugador y 8 bots. La subida de este archivo no implica que
la compilación Android ya haya aprobado las pruebas: consulte Actions.
