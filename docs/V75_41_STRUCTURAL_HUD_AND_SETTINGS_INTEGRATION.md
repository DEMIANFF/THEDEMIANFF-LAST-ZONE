# THEDEMIANFF LAST ZONE — V75.41 integral

Base V75.40 PR #45. Preserva Godot, Lila, controles, avion, salto, paracaidas, ocho villas, cuatro edificios antiguos, inventario, AWM, IA, zona, Firebase aislado y firma preview.

## Causas y correcciones

1. Nieve en edificios historicos: cuatro edificios viejos excluidos anteriormente del nivelado; las montanas atravesaban sus pisos. Ahora sus huellas y accesos se nivelan en la malla real y colision del terreno.
2. Techos interiores ausentes: 12 cielos rasos opacos con cuerpos de colision propios, y cubierta antigua visible por ambas caras. Se conserva techo exterior.
3. AWM bajo la casa: municion original ubicada en CENTRO_DE_EXPLORACION a x19,z-11 era tomada a altura del terreno, por debajo del deck. Ahora se usa el tope fisico de InteriorDeck de todo edificio historico cuando un pickup queda en su interior.
4. Loot: centro de cápsula a 0.50m de la superficie real y anillo a -0.41m; desplazamiento visual breve para evitar enterramientos y objetos flotantes.

## HUD circular y regreso al origen

Todas las acciones tactiles de combate (disparo/joystick ya circulares) usan superficies cuadradas con StyleBox circular: mira, recarga, arma, salto, correr, agachar, curar, barrera, mochila, ajustes y lobby. AJUSTES aparece en avion, entrenamiento y BR. Cuatro archivos HUD independientes; HUD 1 conserva datos viejos. Ajustes se puede editar con el editor persistente.

Desde lobby, cerrar editor HUD vuelve automaticamente al lobby. Desde entrenamiento/BR vuelve a esa misma partida, sin crear otra. No se reinician equipos ni la zona por abrir configuracion.

## Configuracion completa y coherente

Pantalla compartida en lobby y partida; overlay modal que pausa la escena y restaura exactamente su estado. Pestañas PARTIDA, PANTALLA, SONIDO, GRABACION, NOTIFICACION y CUENTA. Subpestañas HUD, CONTROLES, INFORMACION, SENSIBILIDAD y VIBRACION.

Funciones realmente conectadas: guardar general/red-dot/x2/x4/AWM-x8/ADS, actualizar camara activa, FPS 30/45/60/90/120 como limites (no medidas), ocultar FPS, radar rotatorio o norte arriba, efectos/ambiente AudioServer, vibracion breve Android, cuatro presets HUD, respaldo local de ajustes validado. Grabacion interna, logins Google nativos, voz, redes, amigos y privacidad online aun requieren integracion real y se muestran no disponibles, sin pantallas o cuentas falsas.

## Pruebas

v7541_house_loot_qa.gd verifica suelo de los cuatro historicos, doce cielos rasos, techos exteriores y soportes fisicos de municion/botin.
v7541_settings_context_qa.gd prueba lobby-modal-lobby, edicion HUD-lobby, entrenamiento/BR sin cambios de contexto, controles circulares, audio persistente, cuatro presets y boton Ajustes en avion.
Conservar todas las regresiones existentes de Godot fuente y bytecode APK, captura OpenGL y firma Android ARM64 antes de entrega.

Android preview V75.41 versionCode 35, mismo com.thedemianff.lastzone.nativepreview y firma. Prueba fisica Motorola Edge 60 Fusion pendiente; el BR continua offline con un jugador y ocho bots.
