# THEDEMIANFF LAST ZONE — Plan maestro de producción V75 → lanzamiento

**Estado:** documento técnico de requisitos y aceptación, no una declaración de que todos los sistemas ya están programados.
**Rama de desarrollo:** `codex/v75-br-flow-animations`, basada en V74.1. **Proteger** `v44-3-2-autosave-guest` y todos los datos/firma de V70.
**Motor vigente de la reconstrucción nativa:** Godot 4.7.2. Portar a Unreal sería otro proyecto; no afirmar que se está usando Unreal para el ejecutable actual.

## 1. Requisitos no negociables
1. **Jugador:** rigged character original de Lila según referencias lila/azul/blanco, cámara de tercera persona detrás de la espalda, movimiento y animaciones suaves, manos visibles en AK y AWM, espalda y ropa coherentes en todas las vistas.
2. **FPS multiplataforma:** perfiles gráficos bajo, medio, alto y ultra sin fijar toda la producción al Motorola. Mantener compatibilidad mediante LOD, atlas, calidad de sombras y streaming. Objetivos medidos por dispositivo, no prometer 60/120 FPS indiscriminadamente.
3. **Partida:** pantalla de carga real, inicio, lobby, elegir personaje y modo, personalización, eventos, misiones, logros, inventario, tienda, pase y cuentas; avión con ruta y marcador, salto a elección, caída controlable, paracaídas, loot, cobertura, ADS, zona, IA y enemigos, victoria/derrota, resultados y regreso al lobby.
4. **Sistema de armas:** AK-74, AWM con x8 exclusiva y cerrojo automático de 0.5 segundos, miras AR x2/x4, trazadoras, munición/recarga/daño coherentes, IK de ambas manos, recoil, efectos, sonido, botín y equipamiento.
5. **Mapa Aurora:** 8 km × 8 km como **objetivo final**, no confundir con el pequeño sector Godot actual. Cráter Aurora, Bahía de Cristal, Bosque Lumínico, Complejo Helios, Glaciar Espejo, Valle de los Ecos, Puerto Vórtex y Santuario de Hielo.
6. **Multijugador:** 100 personas reales requiere servidores autoritativos, sincronización, matchmaking, reconexión, antitrampas y pruebas de carga. Los bots offline no cuentan como humanos.
7. **Servicios:** Firebase Authentication/Google/invitado e IDs secuenciales seguros, respaldo/restauración por UID; conservar progreso tras reinstalar, con pruebas físicas de usuario y seguridad de Firestore.

## 2. Rig: 206 huesos anatómicos no son 206 joints de animación
Un adulto suele tener aproximadamente **206 huesos anatómicos**. Un esqueleto de personaje 3D tiene **joints virtuales**, que pueden agrupar varios huesos anatómicos o representar movimientos secundarios que no equivalen a huesos humanos (cabello, ropa, mochilas).

- La malla provisional V74 usa **52 joints** de un FBX CC0; no es Lila final. No insertar joints artificiales para presumir «206».
- **Nuevo rig original de alta fidelidad:** control completo de pelvis y columna, clavículas, cuello, cabeza, extremidades, muñecas, tobillos y todos los dedos; hombros y rodillas anatómicamente correctos, twist bones para antebrazos/muslos, cara expresiva con morph targets, ojos y párpados, cadena secundaria de pelo y ropa.
- La cifra final de joints se decidirá según deformación y comportamiento; 100–180 joints y blendshapes pueden superar con claridad un rig de 206 joints mal organizado. Podemos añadir más controles si la animación lo justifica.
- Para movimientos naturales: **mocap/animación artesanal de calidad**, locomoción mediante blend trees, sincronización de pisadas y root motion, IK de pies y manos por arma, retargeting, compensación de terreno, aim offsets, recoil y capas para brazos/torso.
- Tests: eliminar T-pose en juego, brazo correctamente alineado con el arma, muñeca derecha en empuñadura, izquierda en guardamanos, no clipping significativo, pies al suelo, transiciones caminar/correr/crouch/airborne/ADS, 60 s de cámara libre sin giro errático. Capturas 360° y video del teléfono.
- Licencia de mallas/texturas/pelo/armas original o verificada antes de publicar.

## 3. Arquitectura de juego por capas
- `AuroraFront` (UI original): bienvenida, lobby y navegación; muestra expresamente «en desarrollo» donde no existe backend. No simular compras, créditos ni Firebase.
- `AirDropSequence` (V75): aeronave, elección de salto, caída, apertura de paracaídas, control aéreo, aterrizaje y transición a la partida de sector. Es una **primera mecánica funcional, no un avión final**.
- `Operator`: controlador CharacterBody3D, locomoción y cámara libre; capas de animación y estados independientes. Evitar deformar malla entera al agacharse.
- `SectorDirector`: estados de partida, la zona segura, participantes y condición de fin. Un solo director es dueño del estado; interfaz lo refleja.
- `Combat`: armas, balística/impacto y daño con autoridad local offline; separar inventario, stats y pickups, en lugar de incrustarlo en el HUD.
- `World`: sectores originales con colisiones, portal/interiores/puertas reales, navegación, iluminación, materiales PBR, streaming y control de coste por dispositivo.
- `Backend`: sin dependencia de conexión para jugar offline; servidor autoritativo para partidas online, Firebase para cuenta/backups, no para simulación en tiempo real.

## 4. Etapas y criterios de aceptación
| Entrega | Implementación | Pruebas obligatorias para aprobar |
|---|---|---|
| **V75.0** | Pantalla de bienvenida y lobby originales, navegación honesta; entrenamiento separado de partida BR; secuencia aeronave/salto/paracaídas/aterrizaje; restablecer HUD de combate al aterrizar; clips básicos de caída/posición. | CI prueba bienvenida→lobby→entrenamiento→lobby→avión→caída→paracaídas→aterrizaje→sector, junto a pruebas V74.1 sin regresión. Luego Motorola real. |
| **V75.1** | Control por gestos y cámara aérea; ruteo multitáctil en avión y paracaídas; animaciones transicionales, colisiones y autoapertura de emergencia; menú de salida seguro. | 10 saltos físicos desde aeronave, 10 aterrizajes correctos; 0 controles desaparecidos/fijos; cámara 360 estable. |
| **V76** | **Lila original** modelada/rigged, materiales PBR y piel estilizada, cabello, equipo dorsal, clips de caminar/correr/saltar/caer/crouch/ADS/fuego/recarga/derrota, IK manos-pies. | Capturas frontal/espalda/lateral y video con AK y AWM en ambas manos; sin T-pose. LODs y profiling por perfil gráfico. |
| **V77** | Puerto Aurora 3D profesional: interiores, edificios proporcionales, vegetación, hielo/nieve, terreno, cobertura, zonas recorribles, navmesh, audio espacial. | Recorrido real de 20 min en teléfonos modestos y potentes, sin paredes falsas ni cuelgues; bots recorren interiores. |
| **V78** | Partida offline end-to-end: loot/botín, armas diversas, zona, minimapa, HUD personalizable, mochila, escudos, clasificación, victoria/derrota y resultados, misiones de entrenamiento. | 10 partidas completas, inicio desde lobby y regreso; registros de errores, impactos, inventario y métricas. |
| **V79** | Expansión de Aurora por chunks a 8 sectores, streaming, físicas y navegación por zona; progresión de número de bots. | Cargar/descargar sectores con límites de memoria, sin pop-in incompatible y colisiones incorrectas; mapa 8×8 solo cuando comprobado. |
| **V80** | Google/invitado y Firebase, IDs seguros, respaldos y restauración, cuenta y guardado. | Prueba real desinstalar/reinstalar y otro dispositivo, sin credenciales expuestas, sin pérdida de progreso. |
| **V81–V83** | Servidor autoritativo real, 20→40→60→100 humanos; matchmaking, sincronización y antitrampas, reconexión. | Pruebas de carga con usuarios reales y dispositivos reales, latencia, paquetes perdidos y calidad gráfica. |
| **Release** | Menús completos, configuraciones, eventos, misiones/logros, tienda y pase con reglas reales, accesibilidad, monetización y políticas, Android App Bundle, firma estable. | Actualización sin borrar cuentas, Play Store QA, permisos/privacidad, crash analytics, métricas de dispositivos. |

**Alcance de Free Fire:** usamos paradigmas de experiencia (lobby, botones táctiles configurables, avión/paracaídas, inventario, zona) como referencia funcional. **No copiamos personajes, skins, mapas, archivos, logos, texto, música ni la interfaz visual distintiva pixel por pixel.** Producimos un diseño propio para THEDEMIANFF.

## 5. Situación actual y riesgos
- V74.1: pruebas CI aprobadas para AK, AWM x8, cerrojo, cámara, loot y 9 combatientes offline. La grabación del Motorola mostró defectos visuales de brazos, armas, posición cámara y bots; la compilación verde NO contradice esa evidencia.
- V75.0 introduce pasos iniciales de lobby y despliegue; sigue usando el FBX provisional de 52 joints, un avión y paracaídas simplificados, el mismo sector de 9, y sin multijugador ni cuentas Godot.
- La meta «100% funcional y sin errores» es un **criterio de lanzamiento**: no es honesto asegurar ausencia absoluta de defectos ni cerrar las funciones sin pruebas completas.
- No modificar rama estable `v44-3-2-autosave-guest`, APK V70 ni sus certificados o datos. Cada APK de reconstrucción utiliza identificador Android de prueba independiente.
- Cada entrega debe incluir commit, CI, checksum APK, capturas y verificación humana en Motorola (y más dispositivos para tiers altos). No inventar FPS, pruebas o rendimiento.
