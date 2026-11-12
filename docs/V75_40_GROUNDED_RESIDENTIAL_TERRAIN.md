# V75.40 — Puerto Aurora: viviendas asentadas en terrenos planos

## Base
Continúa desde V75.34 integrada (PR #44, commit `343c5c7d630405e57c0a48db272cb54154ab4d81`). No sustituye animaciones, inventario, IA, avión, zona, HUD ni Firebase. Protege estable V44, Unity y las claves de producción.

## Problema confirmado en código
Antes, las ocho casas costeras se construían a la altura del **punto más alto entre el centro y cuatro esquinas** del terreno natural. En laderas esto elevaba los suelos completos, dejando huecos visibles bajo esquinas y rampas. Además, el extremo del acceso calculaba la altura en un punto de mundo que **ignoraba la rotación** real de cada casa; las semillas de navegación del acceso también ignoraban esa rotación.

## Corrección integrada
1. **Fuente única para parcelas:** `coastal_residential_layout.gd` contiene las ocho posiciones, anchos, profundidades y rotaciones usadas por el generador del terreno y por el constructor de casas.
2. **Urbanismo sobre terreno físico:** `island_terrain.gd` crea una plataforma residencial nivelada a **7 m** mediante transición suave de 8 m hacia los cerros. El plano se aplica a las alturas de los vértices **antes** de generar tanto la malla visible como su `Trimesh` de colisión. No son pisos flotantes de decoración. Los terrenos naturales fuera de las parcelas permanecen montañosos.
3. **Parcelas niveladas completas:** el área plana abarca las esquinas y el corredor de aproximación de **7,5 m** delante de cada puerta, con un margen especial para la malla de 4,6875 m por celda del terreno. Se colorea el terreno residencial con un matiz cálido mediante vertex-color, sin texturas de gran resolución ni llamadas de dibujo adicionales.
4. **Reubicación real:** vivienda 6 desde **(-52,44) → (-55,60)** y vivienda 7 desde **(72,50) → (68,48)**, evitando el borde del cerro y conservando las ocho dentro de la primera zona BR con sus accesos.
5. **Cimientos apoyados:** casas asentadas en la altura central de su **plataforma plana** en vez de levantarse sobre la esquina más alta. Nuevo remate visual enterrado de mampostería, sin añadir colisiones invisibles que bloqueen las puertas.
6. **Rampas y rutas corregidas:** altura del extremo exterior desde su posición global **realmente rotada**; las semillas de navegación del acceso se calculan con `to_global`. Se conserva la apertura física de puertas de V75.34.
7. **QA especializado:** `v7540_residential_terrain_qa.gd` verifica las ocho casas (parcelas, esquinas, corredor, cimientos y cuerpos convexos de rampas), su radio dentro de la primera zona, e invariabilidad de las cuatro ubicaciones del distrito histórico y las montañas alejadas. Se ejecuta junto a todas las pruebas de movimiento, cámara, inventario y partida en fuente y bytecode exportado.

## Android
Una sola APK de diagnóstico V75.40, `versionCode=34`, ARM64, `com.thedemianff.lastzone.nativepreview`, con certificado de preview fijado para permitir actualizar V75.34. Se preservan los respaldos y la identidad existente; no modifica Firebase.

## Condición de aceptación
CI debe superar prueba de terreno, recorrido físico de las ocho puertas, combate/avión/paracaídas, QA del APK y verificación de la firma. Aun cuando CI apruebe, la estabilidad y el aspecto visual en Motorola Edge 60 Fusion solo se confirman tras prueba física con captura de pantalla o video. Sigue siendo un Battle Royale offline de 1 jugador y 8 bots; no se afirma aún multijugador online.
