# V75.43 — THEDEMIAN: LAST ZONE / Puerto Aurora

## Rama y alcance

Nueva versión ÚNICA sobre V75.42, PR #47 y ejecución GitHub Actions #43263488176 (success). Rama codex/v75-43-map-lobby-brand-awm-polish, PR #48. Conserva Godot, animaciones, avión, paracaídas, viviendas, inventario, editor HUD, ajustes, zona e IA. Mantiene sin cambios la rama estable v44, Unity, certificados, paquete Android preview y Firebase.

## Identidad: sin FF

- El nombre público ahora es THEDEMIAN: LAST ZONE.
- El nombre del mundo sigue PUERTO AURORA y el lema EL ÚLTIMO HORIZONTE.
- El nombre se presenta en metadatos Godot, pantalla de inicio y perfil del lobby.
- Nuevo PNG de carga con el nombre corregido y el emblema LZ, con pantalla de carga Godot a tamaño completo.
- El SVG del icono LZ sigue siendo original y sin referencias a terceros.
- El paquete firmado de pruebas conserva com.thedemianff.lastzone.nativepreview para compatibilidad de instalación. No se modifica ese identificador ni la configuración de Firebase: el renombre es de cara al jugador, no migración de cuentas.

## Mapa táctico: corrección visual y funcional

- Textura topográfica derivada de la altura física real del terreno: 160 × 160 muestras una sola vez, en lugar de 35 × 35 bloques dibujados cada actualización.
- Mar, playas, alturas, cerros y costa de Puerto Aurora mediante color de altura; mantiene la geometría que se juega.
- Caminos del barrio costero, el centro y los accesos dibujados sobre las coordenadas del mundo.
- Los doce puntos físicos aparecen sin doce rótulos superpuestos. Se muestran únicamente sectores principales con fondo legible y detección de solapamiento.
- El mapa conserva la posición real del personaje, línea de vuelo, círculo seguro, zoom, arrastre, marcadores y distancia.
- Marca amarilla **AWM** enlazada a la ubicación real del arma, no un indicador decorativo.

## Arma AWM: localizable y recogible

- Se conserva el total de 25 objetos para evitar regresiones de partidas y pruebas.
- La única AWM obtenible en Battle Royale se trasladó desde el lejano muelle oeste hasta la plaza central, coordenadas X 8 / Z 24.
- Se señala con una baliza ámbar vertical, un texto grande y el símbolo AWM en el mapa.
- El lobby muestra la dirección en la pestaña ARMAS. En entrenamiento la AWM se puede probar con el cambio de arma existente.
- En BR no se regala desde el inicio: el jugador debe recoger el objeto real y después equiparlo.

## Lobby / interfaz

- En la pantalla inicial el emblema dejó de tapar los controles de entrada y diagnóstico.
- En el lobby se desplazó al extremo superior derecho, sin cruzarse con las estadísticas del perfil.
- Lila aparece orientada de frente al entrar al lobby; se mantiene el control de rotación 360 grados con el dedo.
- Se conserva el perfil local y solo se muestran partidas/bajas/victorias registradas, sin inventar cuentas online.

## Pruebas de aceptación

- Se mantiene la suite de regresión V75.2–V75.42 en fuente y bytecode exportado.
- Nueva v7543_map_brand_awm_qa.gd comprueba mapa conectado al mundo y textura de resolución mayor, ubicación real y posición del loot, modelo/baliza, colección y equipamiento de la AWM, nombre público, splash PNG, posición del logo y dirección del arma en lobby.
- Android ARM64 preview V75.43, versionCode 37, mismo paquete y firma.
- GitHub CI no es prueba física. Se requiere probar la APK en Motorola Edge 60 Fusion: contraste, iconos, título de carga, HUD, recogida real de AWM y FPS.
- La partida todavía es offline (un jugador y ocho bots); no se ha implementado todavía 50 jugadores online.
