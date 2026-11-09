# THEDEMIANFF LAST ZONE — Godot V75.6: Puerto Aurora 3D

## Dirección
Las dos ilustraciones seleccionadas son el objetivo visual y funcional, no evidencia de implementación. Free Fire y Nexora son referencias de experiencia; el arte y las marcas del juego siguen siendo originales.

## Sistemas realmente integrados
- Nuevo sector urbano Puerto Aurora, con cuatro viviendas de dos plantas junto al área jugable anterior.
- Fachadas con marcos, aberturas de puerta, arcos de piedra, ventanas, balcones y techos inclinados con miles de tejas curvas modeladas e instanciadas.
- Accesos con rampas de física, suelos, techos y paredes con colisión, jardineras como cobertura, plazoleta sobre la altura real del terreno y palmeras.
- Puntos de navegación/cobertura conectados al A* de IA y el combate con miras existente.
- Nuevo test de física: comprueba las cuatro puertas abiertas, obstáculos laterales sólidos, techos y compatibilidad del HUD AWM x8.
- Nueva captura real del motor Godot durante CI, separada de la ilustración conceptual.
- APK de prueba independiente Android ARM64, con paquete nativepreview756 y código 6; no migra automáticamente registros de otras APK.

## No implementado / no declarar completo
Este sigue siendo un sector pequeño offline con 1 jugador y 8 bots. Lila definitiva, personaje masculino final, nuevo arte PBR completo, Duelo de Escuadras 4v4, servidores para 100 jugadores, mapa real 8×8 km, tienda operativa, multijugador y cuentas Google en Godot son trabajo posterior. No prometer FPS en Motorola sin mediciones físicas.

## Pruebas de aceptación
- Ejecutar importación Godot y todas las regresiones, incluida v756_coastal_quarter_qa.gd.
- Capturar el entorno 3D y las pantallas 2712×1220 sin franjas negras; revisar aspecto real, no usar arte promocional como evidencia.
- Exportar ARM64, verificar firma v2/v3, 16 KiB y SHA-256 antes de ofrecer APK.
- En Motorola probar el recorrido por el sector, cobertura, paredes y tiros, comportamiento de IA, respuesta de cámara y controles, carga térmica y rendimiento.

## Trabajo prioritario siguiente
1. Integrar Lila definitiva y el personaje masculino con animaciones, rig y manos IK sobre armas.
2. Sustituir el material temporal por arte arquitectónico PBR, UV y LOD original o licenciado (viviendas, fachadas, pavimento, flora).
3. Completar lobby 3D con perfil, inventario, ajustes y paneles conectados a datos reales.
4. Diseñar Duelo de Escuadras 4v4 offline con reglas y rondas verificables.
5. Escalar mapa por sectores y diseñar el backend de partidas autoritativas; nunca llamar 100 jugadores a una escena offline.

## Seguridad de versiones
Base V75.5 75b5a3d; rama codex/v75-6-puerto-aurora-3d-district. Godot V75.5, Unity V76, Firebase, certificados originales y v44-3-2-autosave-guest permanecen sin cambios.