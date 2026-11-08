# THEDEMIANFF LAST ZONE — dirección artística Lila y Base Aurora
**Estado:** especificación visual basada en las ocho referencias facilitadas por el usuario el 7 de noviembre de 2026. **NO es una malla 3D ni funcionalidad ya implementada.**
**Rama de integración:** `codex/v73-1-motorola-fixes`.
**Prioridad ejecutiva:** corregir suelo/joystick/salto/cámara en Motorola ANTES de ampliar contenido artístico.

## 1. Referencias del usuario
| Referencia | Descripción y finalidad |
|---|---|
| `138682.jpg` | Lámina con Lila al disparar, caminar, agacharse, de espalda y poses de combate. Tomar poses y equipamiento como referencia, no como animaciones existentes. |
| `138671.png` | Vista frontal de cuerpo completo: cabello lavanda, ojos violeta, chaqueta clara, arnés y detalles azules, pantalón corto táctico, guantes, zapatillas. |
| `138673.png` | Espalda: melena lavanda, arnés/mochila tecnológica negra-azul, símbolo luminoso y detalles del traje. |
| `138672.png` | Vista lateral: volumen de cabello, perfil del equipo, silueta de chaqueta, correas, calzado. |
| `130286.png` | Presentación de Lila con poses, accesorios, AK-74 y lista de animaciones (caminar, correr, saltar, agachar, apuntar, disparar, recargar y derrota). |
| `130297.png` | Hoja ampliada con poses, accesorios, expresiones, habilidad de aceleración táctica y ejemplo del HUD en tercera persona. |
| `130635.png` | Concepto de mapa Aurora: archipiélago de hielo y tecnología con 8 zonas, clima, biomas, puertos, rutas, ruinas y botín. |
| `138819.png` | Hoja de personaje con equipamiento, armas, emotes, vista in-game y estilo de lobby. |

**Derechos y procedencia:** no añadir estas ilustraciones a un build público/comercial sin verificar los derechos de reproducción. Su uso aquí es descriptivo para un desarrollo original, no extracción de modelos, texturas o diseño de terceros.

## 2. Lila — objetivo visual
- Mujer adulta estilizada tipo anime, no representación humana fotorrealista; cabello largo y abundante lila/lavanda, ojos violeta, rostro expresivo.
- Proporción visual de referencia de personaje a escala humana (1.68 m en la ficha conceptual), **sin cambiar la cápsula de colisión hasta calibrar la malla importada**.
- Chaqueta táctica blanca y negra con acentos azules, arnés, correa/arnés pectoral, guantes oscuros, equipamiento de cintura, correas y fundas de muslo, calzado deportivo futurista azul-blanco.
- Panel tecnológico dorsal/mochila de color oscuro con luz azul y emblema original del juego; mantener silueta reconocible en vista TPS.
- El equipo y color deben ser coherentes en frente, perfil, espalda y 3/4; evitar piezas flotantes, interpenetraciones y variaciones de indumentaria entre vistas.
- Al correr, saltar o apuntar, el cabello y equipo secundario deben acompañar el movimiento sin clipping pronunciado ni simulación costosa.
- Skin estilizada y materiales PBR con perfil móvil, evitando materiales plásticos sin rugosidad ni iluminación adecuada.
- Referencias de arma: AK-74 táctica, arma corta y francotirador AWM; diseño y licencias auditados. Armas reales en manos, no cilindros o piezas superpuestas.

## 3. Entrega 3D real — criterio obligatorio
Una imagen 2D (incluidas fichas generadas con IA) **no es un GLB, rig ni animación**. Para llamar a Lila funcional hace falta:
1. Malla 3D original con topología, UV y texturas; variantes LOD para Motorola Edge 60 Fusion.
2. Esqueleto humanoide articulado, skinning correcto, poses anatómicas, dedos y columna.
3. Animaciones comprobadas: idle, caminar, correr, sprint, saltar/subir/bajar, aterrizar, crouch, ADS, fuego, recarga AR/AWM, daño, derrota y emotes; transiciones, blend trees y sincronización de pies con suelo.
4. Retarget/IK de manos para sostener **cada** arma; la izquierda agarra guardamanos, derecha empuñadura, control de miras en línea visual; no brazos en T ni rifle flotando.
5. Cámara TPS estable, sin ocultar objetivos ni hacer zoom con la malla; prueba con movimiento libre 360°, ADS x2/x4 y AWM x8.
6. Control de rendimiento: registro real FPS/frame time, memoria y calentamiento en Motorola. 30 FPS estables como primera meta de aceptación; 60 FPS solo si el hardware y la escena lo validan.
7. Capturas de escena Godot y grabación física Android. Ninguna cifra de calidad o logro visual se considera aprobada solo porque CI compiló.

**Estado actual:** V73 utiliza temporalmente una operadora femenina CC0 y corrige postura a partir de un FBX; no es la Lila de estas referencias. No renombrarla «Lila final».

## 4. Base Aurora — dirección ambiental
**Propuesta visual:** archipiélago glaciar irregular, futurismo ártico, naturaleza lumínica, ruinas civiles, antenas e instalaciones; variación real de costas, terrenos, interiores, rutas, puentes, elevación, materiales, atardecer/auroras, visibilidad táctica.

Ocho destinos del concepto:
1. Cráter Aurora — núcleo geológico/tecnológico, verticalidad.
2. Bahía de Cristal — hielo translúcido, mar, muelles y vehículos.
3. Bosque Lumínico — vegetación luminosa, cobertura y senderos.
4. Complejo Helios — industria, laboratorios, interiores, loot.
5. Glaciar Espejo — campo de nieve, largas vistas y riesgo de exposición.
6. Valle de los Ecos — cañones, barrancos, cascadas y combate en altura.
7. Puerto Vórtex — asentamiento portuario, contenedores, embarcaciones.
8. Santuario de Hielo — arquitectura ceremonial glacial y botín de alto riesgo.

El mapa conceptual marca **8 × 8 km / 100 jugadores**, una META de producción; el terreno Godot actual tiene dimensiones y alcance inferiores. No afirmar que los 8 km, 100 jugadores, Unreal Engine 5, vehículos o clima dinámico ya existen.

Por fases: reconstruir primero **un sector de Puerto Aurora jugable** con altura de puertas/escaleras a escala del jugador, interiores, colisiones, luz y navmesh; luego expandir por sectores con streaming, LOD, optimización de sombras, materiales PBR y vegetación instanciada.

## 5. Sistema de combate y estilo de HUD
- Lobby original limpio, navegación de personajes, equipamiento, eventos/misiones/logros, pase de batalla y cuenta Firebase. Referencias de otras franquicias sirven para sensaciones de uso, no copiar recursos protegidos.
- Interfaz horizontal táctil: joystick real con área dedicada, correr alternable, saltar, agacharse, cámara libre en mitad derecha, disparo/recarga/ADS/arma, vida/escudo y estados legibles.
- AWM: zoom x8 exclusivo, ciclo automático de cerrojo **0.5 segundos** (un disparo por pulsación); AR/SMG usar aumentos compatibles como x2/x4; pruebas de estabilidad y FPS durante ADS y bajo fuego.
- Bots: recorrer terreno con navegación real, línea de visión, cobertura, daño/impacto, señales legibles, muerte/reaparición en entrenamiento; luego ciclo BR completo offline. Servidor de 100 usuarios es posterior.

## 6. Bloqueadores técnicos conocidos (video Motorola V73 148892.mp4)
- **Física:** triángulos del terreno invertidos provocaban caída a través del suelo. Corregir winding en `island_terrain.gd`; prueba de Godot debe validar `is_on_floor`, distancia caminada y altura de salto.
- **Joystick:** el indicador `◯` original era decorativo; incorporar `virtual_joystick.gd` real con señal de vector, propiedad del dedo y liberación, correr y mirar en paralelo. Pruebas headless no sustituyen prueba Android.
- **Movimiento/cámara:** avatar T-pose aparente, rifle no alineado, ADS y cámara insegura. No afirmar corrección visual hasta ver captura y prueba física.
- **IA:** bots caían también; los cuatro necesitarán nuevo test en dispositivo de ubicación, disparos y navegación.
- La versión de prueba debe empaquetarse como **app separada** de V70, preservando su firma y datos de Firebase; no entregar APK antigua con una etiqueta nueva.

## 7. Aceptación por etapas
1. **V73.1:** iniciar escena, mantener contacto con suelo, joystick/correr/saltar/mirar simultáneamente, 4 bots visibles y daño real. Pasar CI y **confirmar en Motorola**.
2. **V74:** malla original de Lila y pruebas de rig/anatomía, arma sujeta a ambas manos, caminar/correr/ADS/recarga/salto visualmente correctos.
3. **V75:** Puerto Aurora de calidad con interiores reales, cubiertas, navmesh, bots que interactúan y benchmark móvil.
4. **V76+**: sistemas completos offline BR; cuentas respaldadas; después multijugador en infraestructura real, probado incrementalmente.

**Regla:** no convertir ilustraciones en promesas de assets o funciones que aún no se han implementado.
