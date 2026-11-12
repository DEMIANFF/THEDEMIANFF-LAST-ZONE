# V75.42 — Mapa tactico original, transporte redisenado, operador armado y marca

## Base preservada
V75.41, PR #46, CI #43258866128 SUCCESS, commit b00e521b5bd990d7d7831814db8568072aafbec9. No modificar V44 estable, Unity, Firebase, certificados ni el package preview.

## Nombre y marca
THEDEMIANFF: LAST ZONE (nombre visible en carga, inicio y lobby), ubicacion principal PUERTO AURORA. Emblema LZ original con escudo, aurora boreal y montanas en SVG; integrado en Godot boot splash, Android icon y pantallas iniciales, sin copiar logotipos, mapas o modelos propietarios.

## Mapa real de Puerto Aurora
El radar de proximidad se preserva. Ahora el HUD tambien tiene boton MAPA, editable/persistente. Abre una vista tactica de la misma escena Godot, no una foto ficticia: dibujo basado en height_at del terreno real, cuadrícula, 12 ubicaciones, punto real del jugador, anillo de zona desde el director activo, ruta correcta del avion, icono de su posicion durante vuelo y navegacion mediante zoom, desplazamiento, seguimiento y marcadores en metros. La marca se guarda localmente y puede eliminarse. Incluye entrada funcional desde avion, descenso y batalla. No simula humanos de un equipo ni rutas online; equipo es offline.

## Avion
El transporte Aurora ya no usa BoxMesh para alas/cola/cabina: fuselaje de elipses con secciones decrecientes, superficies de alas trapezoidales y empenaje, cabina de vidrio oscuro, dos nacelas/indicadores de motor con tres palas cada una y franja original. Malla de triangulos con baja densidad, bajo materiales GL Compatibility. NO cambia la logica del flujo avion -> salto -> caida -> paracaidas estabilizada en versiones anteriores.

## Operador y armas
El arma se mantiene en hueso real de la mano; durante vista libre sigue al torso, no gira separada hacia la camara. Solo al apuntar/disparar se alinea al visor. Los clips FBX autorados diferencian disparos de los dos brazos y separan el punto de agarre y el guardamanos, para mostrar un manejo de fusil mas creible. QA valida posicion de montura y orientaciones, sin afirmar animacion profesional completa hasta prueba fisica.

## Lobby/carga
Se conserva la pantalla de inicio y la navegacion local, manteniendo diagnosticos necesarios para las pruebas Motorola. El escudo original aparece en inicio, lobby y splash Godot. Cambios de paleta para mas contraste y un titulo coherente. Sin monedas de pago o personas conectadas ficticias.

## QA
Nuevo v7542_map_aircraft_brand_qa.gd en origen/exportado; conjunto completo anterior tambien obligatorio. Requiere mapa conectado a terreno/personaje/director real, zoom/proyeccion/waypoint persistente, avion con mallas y motores reales, rifle alineado al hueso, UI marca en lobby e imagen de boot splash.
VersionCode=36, firma test preview y appId com.thedemianff.lastzone.nativepreview; sin tocar backups Firebase.
Se requiere probar graficamente y fisicamente en Motorola Edge 60 Fusion y registrar estabilidad/FPS. La partida sigue offline 1 humano + 8 bots; no se afirma multijugador real.
