# PROYECTO MAESTRO — THEDEMIANFF LAST ZONE: BATTLE ROYALE NATIVO Y REALISTA

**Versión documental:** V71 / fase fundacional. **Repositorio:** `DEMIANFF/THEDEMIANFF-LAST-ZONE`.
**Rama de reconstrucción:** `codex/v71-native-battle-royale-foundation`.
**Referencia estable de juego:** V70 `8355c833dbb1e3d308da50db8a70c0239095a59c`.
**Rama histórica protegida:** `v44-3-2-autosave-guest`. Nunca modificar.
**Fecha:** 7 de noviembre de 2026 (Colombia).

## 1. Objetivo del producto

Crear un battle royale Android **nativo 3D, con identidad original**: Base/Puerto Aurora, un archipiélago ártico irregular, glaciares, naturaleza bioluminiscente, ruinas tecnológicas y edificios transitables de aspecto creíble. Lila debe ser una operadora 3D **real** (malla orgánica, articulación corporal, materiales PBR, esqueleto y animaciones), no geometría cúbica. La cámara es en tercera persona con órbita libre de 360°, ADS con 2x/4x y AWM exclusiva 8x. La sensación de control será precisa, estable y responsive para táctil Android.

Inspiración de nivel de producto: Free Fire/Blood Strike (calidad de experiencia y funciones), **sin copiar recursos, marcas, código propietario o diseños exactos**. Se exige una identidad visual propia Aurora.

La meta final es el combate multijugador auténtico con cuentas, servidores, antitrampas, eventos y progresión, empezando con una versión offline con IA. **No afirmar que 100 humanos en red o un mapa de 8x8 km están listos hasta que estén implementados y medidos**.

## 2. Diagnóstico auditado de V70

La V70 actual es una app Android cuyo render principal corre en WebView con Three.js y un archivo HTML extenso. Tiene mecanismos útiles (controles, cámara, armas, inventario, IA, guardado Google/invitado, IDs, tienda y pase), pero el motor y la producción de contenido no son adecuados para prometer un battle royale fotorrealista.

Análisis de GLB **obtenidos de la APK V70**, no conjeturas:
- `lila-operator.glb`: 92.144 bytes; 52 mallas; 5.516 posiciones; **0 skins, 0 animaciones, 0 materiales e imágenes**. No satisface un personaje realista animable.
- `alternative-female-reference.glb`: 24.823.060 bytes; 497.400 posiciones; **0 skins y 0 animaciones**. No es un reemplazo animado ni un activo móvil optimizado; licencia y procedencia por comprobar.
- `ak74-tactical.glb`: 3.518.588 bytes; 2.619 posiciones; material e imágenes, **sin animaciones**.
- `weapons-pack.glb`: 745.776 bytes; 10.483 posiciones, 8 materiales y 3 imágenes. Requiere QA visual, escalas y derechos.

**Implicación:** no podemos transformar una malla rígida en una operadora con movimiento orgánico solo con código de cámara o CSS. Necesitamos pipeline de producción 3D, rig, clips y PBR.

## 3. Decisión técnica

**Motor objetivo: Godot 4.7.2 (GDScript) con renderizador Compatibility para el primer corte.** Evaluar `Mobile` (Vulkan) únicamente si el Motorola Edge 60 Fusion y la estación de desarrollo lo soportan satisfactoriamente. Motivos: exportación Android nativa, importación glTF/GLB, escena/física/animación del motor y editor Android experimental; configuración razonable en equipo portátil i3/4 GB (sin afirmar que toda la edición pesada sea viable allí).

Referencias oficiales:
- https://godotengine.org/download/android/
- https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html
- https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html
- https://docs.godotengine.org/en/latest/tutorials/rendering/renderers.html

Se evita sustituir V70 en el dispositivo hasta obtener APK nativa probada, **firmada con la identidad histórica cuando esté preparada la migración de datos**. Inicialmente la APK de Godot será un paquete interno de pruebas distinto, para no arriesgar el perfil Android existente.

## 4. Arquitectura modular del nuevo proyecto

```text
native-godot/
  scenes/        # escenas de juego originales y composición
  scripts/
    world/       # terreno continuo, biomas, streaming por sectores y cobertura
    player/      # CharacterBody3D, cámara, entradas multitáctiles y locomoción
    combat/      # armas, munición, proyectiles, hitboxes, ADS, retroceso
    ai/          # percepción, patrullas, investigación, flanqueos, combate
    match/       # lobby, avión, salto, planeador, zona, loot y condiciones de victoria
    ui/          # HUD, mochila, tienda, cuenta, misiones, pase y social
    net/         # futuro cliente de red; nada de falsos jugadores online
    qa/          # smoke tests, métricas, regresiones, dispositivos
  assets/        # activos originales o con licencia confirmada, PBR, LOD
```

**Código migrable:** reglas de juego y experiencia V70 como referencias de comportamiento, no pegar el controlador WebView y llamar a eso motor nativo. **Nuevas dependencias:** `CharacterBody3D`, `AnimationTree`, `Skeleton3D`, `Camera3D`, `NavigationServer3D`, `PhysicsServer3D`, `RenderingServer`, recursos y escenas Godot. Evitar lógica pesada de IA por frame; tick fijo, LOD de simulación, pooling e instancing.

## 5. Programa de implementación y criterios de aceptación

### F0 — V71: fundación de motor y arquitectura nativa (iniciado)

- [x] Proyecto Godot independiente, sin tocar Android V70 ni la rama protegida.
- [x] Malla de archipiélago irregular continua, colisiones físicas y agua.
- [x] Controlador `CharacterBody3D`, cámara TPS y entrada táctil separada.
- [x] Validación automatizada de importación y arranque de la escena en GitHub Actions.
- [x] Auditoría de mallas/skins/animaciones actualmente incluidas en APK V70.
- [ ] Primera sesión visual verificada en Motorola con motor Godot nativo.
- [ ] Diseño final de HUD 3D/HUD táctil, con botones dimensionados, y sin controles obstruidos.
- [ ] Ajuste visual de iluminación/materiales y escala del terreno por capturas reales.
**Salida de fase:** repositorio funcional en el motor nativo, no APK comercial.

### F1 — V72: operadora Lila, arma equipada y locomoción profesional

- [ ] Crear/obtener **Lila PBR original** con licencia clara, textura, esqueleto y malla orgánica. Importación GLB y escalas reales (1 unidad = 1 m).
- [ ] Clips de respiración/idle, marcha, carrera, sprint, giro, salto, caída, aterrizaje, agachado, disparo, recarga, daño, curación, arma al hombro y transición ADS; eliminar inclinación antinatural del torso.
- [ ] `AnimationTree` con blend de movimiento, pelvis/pies, IK/acople de armas y ADS adaptativo.
- [ ] Cámara sobre hombro libre 360°, colisión de cámara, suavizado independiente de delta, estabilidad con dos dedos, sin zoom molesto.
- [ ] HUD Android nativo mínimo jugable: joystick flotante, FUEGO, MIRA, correr, salto, agacharse, recargar, cambiar arma.
- [ ] Prueba real de 20 minutos en Motorola sin errores críticos. **Nada de humanoides `BoxMesh`.**
**Salida de fase:** slice visual jugable de Lila caminando/apuntando sobre terreno real.

### F2 — V73: combate táctico completo offline

- [ ] AWM con x8 fija, cerrojo **automático de 0,50 s** y un disparo por pulsación; AK/AR, DMR, SMG, escopeta, LMG con características propias.
- [ ] Modelos 3D originales con animación de disparo, retroceso, expulsión de vainas cuando rentable, sonido espacial y recarga coherente con calibre.
- [ ] Mira 2x/4x para no francotiradores, x8 AWM exclusiva; ADS estable, brazo/arma animados, crosshair solamente durante combate.
- [ ] Daño, hitboxes, línea de visión, coberturas, cabeza/cuerpo, dispersión, caída balística de francotirador si procede.
- [ ] Sensibilidad independiente general, ADS, giroscopio (si se aprueba), control de disparo arrastrado y multitáctil.
- [ ] Inventario con capacidad real por slots/stacks, recogida/suelta/equipamiento y botiquines/escudo.
- [ ] 8–20 rivales IA competentes como línea base; combate y colisiones probadas con edificios.

### F3 — V74: Base Aurora con arquitectura auténtica

- [ ] Diseño modular de **edificios 3D no cúbicos**: puertas, ventanas, escaleras, cubiertas, interiores, señalización, props, ruinas originales.
- [ ] Sustituir construcciones simples por modelos PBR y colisiones editadas, oclusión y navegación IA.
- [ ] Primer sector realista utilizable: Puerto Aurora, Bahía de Cristal y parte de Complejo Helios.
- [ ] Vegetación polar, rocas naturales, nieve, hielo, niebla y luz por ambientes sin postprocesos costosos.
- [ ] Suelo continuo con distintas costas, ríos/agua, desniveles, alturas y refugios, sin paredes invisibles.
- [ ] Streaming/Lod por distritos y empaquetado Android; **no generar 8x8 km enteros de golpe**.
- [ ] Validación de que casas tienen entradas suficientes y personaje/enemigos no se atascan.

### F4 — V75: ciclo completo de battle royale offline

- [ ] Lobby profesional, elección de modo, personaje, preset, tienda/eventos/misiones.
- [ ] Avión y ruta, cámara de vuelo, marcador de destino, salto, caída libre, planeador dorado, aterrizaje robusto.
- [ ] Zona que se cierra en fases, minimapa/mapa táctico, suministros, edificios saqueables, economía de partida.
- [ ] IA con patrulla, búsqueda, cobertura, retirada, comunicación por equipos, sonido, percepción, disparos entre rivales y comportamiento según roles.
- [ ] Último superviviente, fin de partida, tabla de estadísticas, recompensas y guardado.
- [ ] Incrementar población de IA solo tras medir FPS/CPU/batería; no prometer 100 agentes simultáneos en el Motorola sin evidencias.

### F5 — V76: cuentas, seguridad y persistencia sin pérdidas

- [ ] Mantener invitado y vinculación Google, Firebase Auth, respaldo/restauración, cuentas con ID secuencial numérico ya asignado.
- [ ] Contrato de datos versionado y migración de progreso V70→Godot; probar instalación encima o migración asistida **sin eliminar datos**.
- [ ] Identidad de APK, keystore y packageId revisados antes de dar APK de actualización; ejecutar tests de recuperación tras reinstalación.
- [ ] Operaciones server-side para recompensas y balances; no confiar en crédito editable desde el cliente.

### F6 — V77–V79: multijugador real por servidor dedicado

- [ ] Servidor **autoritativo**, separación de simulación/red/cliente, protocolo versionado y autenticación.
- [ ] Movimiento replicado con interpolación/predicción/reconciliación y latencia medida; daño, zona, loot y munición decididos por servidor.
- [ ] Salas privadas de 2–8 personas, luego 16–32, después 50 y **hasta 100 humanos si las pruebas de carga y el presupuesto lo permiten**.
- [ ] Matchmaking, amigos/escuadras, reconexión, antitrampas, reportes, moderación y observabilidad.
- [ ] Tests de carga y soporte a conexiones móviles inestables; costo de hosting/operación evaluado antes de prometer fecha.
**Nota:** esta fase no existe hoy en V70/V71.

### F7 — V80+: operaciones y lanzamiento

- [ ] Sistema original de cosméticos, pase por temporada, misiones, logros, eventos, tienda y equilibrio económico.
- [ ] Tutorial, accesibilidad, localización, ajustes gráficos, ajustes táctiles, privacidad, términos y clasificación por edades.
- [ ] Android AAB/APK Release, telemetría con consentimiento, crash reporting, distribución y actualizaciones con rollback.
- [ ] QA de sesiones largas, verificación de respaldo, rendimiento y acceso en múltiples teléfonos.

## 6. Arte y recursos: criterios obligatorios antes de integrar

Ningún humanoide compuesto de cubos como personaje publicable. Cada personaje debe tener: topología orgánica, material PBR (albedo/normal/ORM), UVs, `Skeleton3D` con deformación skin, clips de locomoción y disparo, proporciones coherentes, huesos de arma y mochila; LOD0/1/2 y versiones de texturas apropiadas para Android.

**Presupuestos iniciales orientativos**, sujetos al perfilador del Motorola: LOD0 operadora 20–35 mil triángulos; LOD1 alrededor de la mitad; LOD2 menos de 6 mil. Materiales limitados; texturas 1K para elementos comunes y 2K solo héroes/equipo crítico si memoria lo permite. Armas y edificios con instancing/occlusion/culling. El modelo `alternative-female-reference.glb` no se debe distribuir sin confirmar licencias y adaptación de rig/LOD.

Se exige **evidencia de origen y permiso** de cada asset; no se extraen ni copian modelos, audios, mapas, marcas o UI propietaria de Free Fire/Blood Strike.

## 7. Calidad de experiencia y rendimiento

**Dispositivo primario:** Motorola Edge 60 Fusion, orientación horizontal.
- Línea base **30 FPS sostenidos** bajo carga; objetivo deseado **60 FPS** mediante perfiles de calidad escalables si la medición lo permite.
- Medir frame time p95, picos, draw calls, triángulos, memoria, temperatura observada, consumo, recalentamiento y caídas de GPU durante ADS/disparo/daño.
- Tres pruebas esenciales: 20 minutos de marcha/rotación, 20 minutos con 20 enemigos IA, partida completa con avión y zona.
- Sin congelación de cámara al disparar, sin apuntado invertido, sin botones superpuestos ni disparos dobles accidentales.
- Multitáctil: movimiento+vista+disparo simultáneos; prioridad por puntero y recuperación tras pausar.
- Pruebas de errores de escena, importación de modelos y firmas automáticas **más** pruebas físicas; GitHub verde no equivale a móvil probado.

## 8. Riesgos, límites y dependencia de recursos

1. Modelos y animaciones realistas no aparecen por actualizar librerías: requieren producción 3D, autoría o licencias.
2. Un i3 con 4 GB y un celular permiten trabajos parciales, pero editar escenas grandes o hornear assets complejos exigirá mejores recursos o infraestructura externa.
3. La versión de Android de Godot editor es experimental, sin prometer una estación profesional táctil.
4. Un mundo 8 km × 8 km con muchos personajes exige streaming, servidores, memoria y pruebas; no se puede certificar hoy.
5. Plus ofrece mejores herramientas de asistencia, **no** recursos ilimitados de render, tiempo humano ni servidores gratuitos de alto tráfico.
6. Evitar modificar V70 firmado o la rama estable. No usar falsas capturas ni afirmar compilaciones o pruebas inexistentes.

## 9. Definición de terminado (DoD)

Una función solo se declara **IMPLEMENTADA** si está registrada en commit y rama correctos, con prueba automatizada pertinente. Una APK solo se declara **GENERADA** cuando Actions produce artefacto, verifica assets, versión y firma. Una mejora se declara **VERIFICADA EN DISPOSITIVO** solo tras evidencia de prueba real en Motorola; los objetivos visuales se revisan con captura y métricas.

**Prohibido:** entregar APK antigua renombrada, sustituir animaciones por cajas, marcar pantalla decorativa como funcional, afirmar online con IA desconectada o prometer 100 % sin pruebas.

## 10. Estado real después de este primer avance

**Implementado en rama V71:** estructura Godot, malla insular ondulada, agua y colisiones, cámara/locomoción TPS nativas, entrada táctil básica, test de arranque Godot headless.

**Pendiente:** activos profesionales finales de Lila, ciudad 3D PBR, HUD diseñado, armas nativas y ADS completas, IA completa, batalla offline nativa, puente de Firebase, exportación APK y multijugador real.

**El siguiente entregable imprescindible no es otra etiqueta de versión:** es un vertical slice **Lila realista + cámara + rifle + primer barrio auténtico**, compilado en Android y medido en Motorola.
