# THEDEMIAN: LAST ZONE · Continuidad V75.105

Base exacta `ed5b70995e5d5b89d581416476c8fbb64ce9e52a`. Esta rama continúa con Godot 4.7.2, Android ARM64 y Vulkan Mobile. Versión `75.105.0-mobile-vulkan`, código `95`. [PR #109](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/pull/109) · [CI de V75.104](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/43751815669)

## Bloque implementado

- La apertura muestra la marca centrada y el progreso abajo, como establece la zona inferior izquierda de la primera imagen. La barra consulta el estado real de `ResourceLoader` mientras se carga `Main.tscn` en un hilo. El acceso aparece cuando Godot entrega la escena y el fallo presenta un reintento. Antes del lobby solo se montan controles 2D.
- El acceso agrupa Invitado, Google y juego local en una fila inferior. Cada acción conserva su ruta real. La vista indica cuándo el servicio está pendiente y mantiene el perfil local como acción utilizable. La validación automatizada de Firebase usa el puente existente sin contactar producción.
- El lobby entrega `INICIAR` al despliegue real de BR. Al solicitar una partida se libera el `SubViewport` de Lila antes de agregar el mundo al árbol. La construcción del mundo y de sus colisiones sigue en el hilo principal. Durante ese tramo, el indicador es indeterminado. Una solicitud cancelada queda invalidada aunque se inicie otra en el mismo fotograma.
- La prueba `v75105_aurora_entry_flow_qa` usa el evento táctil nativo para entrar al lobby, fuerza una ruta ausente para probar la recuperación y comprueba el retorno desde entrenamiento. Registra tiempo hasta el acceso y hasta la activación del mundo. Esas cifras corresponden al equipo que ejecuta la prueba. CI captura apertura, acceso y lobby con el motor en escritorio.

## Especificaciones recuperadas

| Lámina | Archivo original | SHA-256 |
| --- | --- | --- |
| 1 · Apertura, acceso y ajustes | `Imagen de ChatGPT 15 nov 2026, 14_42_46.png` | `7f6758c7d1aca54c0948209b898c43be2663ab613b86bc1a803f2e267f7645fc` |
| 2 · Lobby 3D, HUD y despliegue | `Imagen de ChatGPT 15 nov 2026, 14_43_11.png` | `d274db900d51a13172d4bed8a8dbc5a8cc57559cbe2ef1365358aeb656587a77` |
| 3 · Arquitectura funcional | `Imagen de ChatGPT 15 nov 2026, 14_43_24.png` | `2c17e1f02749da8cbc0e6c93460336d0ac9370c61cbf8ac245e7239ab48c98b3` |

Las imágenes están en la carpeta Imágenes del equipo del usuario y se usan como especificación. La rama contiene controles, escenas y recursos nativos del juego. Para los conflictos de contenido se conservó la decisión ya aprobada de un único BR offline de 50 participantes. El terreno actual mide 450 × 450 unidades de juego. El mapa de 8 × 8 km de la lámina 3 queda como objetivo de producción.

| Área | Disponible en esta base | Pendiente para cumplir la lámina |
| --- | --- | --- |
| Apertura y acceso | Marca, barra de progreso real, recuperación ante fallo, botones nativos y perfil local persistente | Acabado visual completo de la lámina 1, composición de acceso con operador y compañero, Facebook, enlaces y consentimiento a partir de documentos oficiales. Validación de Google e Invitado en un dispositivo con App Check configurado. |
| Ajustes y HUD | Categorías nativas, sensibilidad, gráficos, audio persistente y editor táctil con tamaño, opacidad y cuatro presets. HUD real de avión, caída, paracaídas y combate. | Composición del editor de la lámina 1 y distribución e iconos de la lámina 2. Validar gestos, resolución, zonas seguras, latencia y colisiones de toque en el teléfono. |
| Lobby y economía | Base Aurora 3D, Lila y centinela animados, barra inferior, acceso INICIAR, tienda por monedas locales, pase gratuito, misiones y logros del historial real. | Acabado del hangar, pose armada con socket, flujo de cosméticos completo, temporadas, eventos, ruleta, cartera de diamantes y confirmación de pagos. |
| Partida | BR offline de 50, avión, caída libre, paracaídas, zona, final, entrenamiento, IA, minimapa y equipo de V75.103. Se conservan granada, sobrevuelo y pisadas de V75.104. | Duelo 4v4, expansión de isla y ubicaciones, categorías pendientes de armas y otra medición de GPU/memoria en el Motorola Edge 60 Fusion. |
| Social | Entrada al panel del lobby y estado local verificable | Amigos, invitaciones, clanes, salas, equipo y multijugador real con servicios de cuenta y sincronización. |

## Personajes y recursos para retomar

- **Lila.** `native-godot/assets/characters/lila_aurora.glb` conserva SHA-256 `7b7a4916a928166b811f7c781a435c57be35b52f71457eaea5da5620a88892f5`. Tiene 56 articulaciones y 26 clips incluidos para locomoción, puntería, salto, vuelo, impactos, armas y curación. `native-godot/assets/animations/aurora_lobby_motion.tres` contiene el fragmento de `siff.glb` y solo se añade al reproductor del lobby. El siguiente pase de animación debe revisar pies, manos, muñecas, ropa, arma en el lobby y posturas de caída en dispositivo.
- **Candidato masculino.** Se comprobó `new_skin_cityhero_free_fire.glb` de Aurora V3. SHA-256 `716b623e257296cf19dd9ac4558cb7631810b4a24037597580de0aec559bcccf`. Tiene 84 articulaciones, 10 mallas, 10.887 triángulos y cero clips. Se identificaron `bone_Hips_00`, `bone_Head_030`, `bone_LeftHand_017`, `bone_RightHand_035` y anclajes propios para armas y mochila. Sus mallas incluyen vestuario, capa y efectos. El siguiente paso es validar el conjunto en movimiento, retargetear locomoción y acciones, y revisar los derechos del diseño antes de elegir un operador masculino distribuible. El candidato permanece en el inventario local.
- **Aurora V2 y V3.** Los paquetes originales siguen en el inventario de transferencia del equipo. La auditoría de 80 originales de V3 y los derivados jugables se enlazan desde la entrega de combate. El KRISS de V2 forma parte del BR. Mapas, ópticas y recursos restantes siguen inventariados para incrementos futuros. [Integración y atribuciones de V75.103](AURORA_V3_V75.103.md)
- **Adendas.** `AURORA_V3_ADENDA_PASOS_Y_LILA.zip`, `AURORA_V3_ADENDA_AUDIO_GRANADA_AVION.zip` y `AURORA_LOBBY_MUSICA_LOOP_GODOT.ogg` permiten reproducir la instalación local con hashes. El audio suministrado sigue en el proyecto local y el código público incluye el instalador. [Instalación y procedencia](AURORA_V75.104_ADENDAS.md)

## Límites de la entrega

Faltan la revisión visual completa contra las tres láminas, la integración de un operador masculino jugable y la validación en un Motorola físico. El CI de desarrollo conserva las comprobaciones de Godot y la exportación sigue reservada a ejecución manual. La entrega no genera APK ni despliega Firebase.
