# THEDEMIAN: LAST ZONE — V75.114 · Base Aurora naturalizada y carga animada real

**Base auditada:** `codex/v75-113-aurora-premium-frontend-reconstruction`, commit `ac675a47331da564d8e591ab5c93dc28a9be5102`. [CI aprobada #43904386382](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/43904386382). PR anterior #118 permanece en borrador mientras se obtiene aceptación artística y Android física.

## Diagnóstico sustentado en capturas Godot V75.113

La captura real `aurora-v75-113-motorola-lobby.png` a 964×434 y la de 1280×720 muestran un lobby funcional, con el botón INICIAR libre y Lila completa. Sin embargo, las montañas repetidas de cuatro caras y cumbres blancas se parecen a triángulos rígidos y restan profundidad a Base Aurora. El sistema de carga posee progreso real y estilo mejorado, pero sus señales luminosas estaban estáticas.

## Código implementado

### 3D del lobby / escenario naturalizado

- `aurora_lobby_stage_3d.gd`: sustituida cada pirámide de 4 triángulos por una malla original determinista de **9 sectores y 27 triángulos por malla** (anillo periférico, hombro irregular y cumbre desplazada). No se importan activos de otras marcas ni se inventa un mapa de juego nuevo.
- **22 cordilleras** de dos capas y dos materiales por pico: **44 mallas** roca/nieve, con rugosidad PBR conservadora, tonos azules y cumbres de hielo más pequeñas, desplazadas y más altas. Las vistas de la pista, radar giratorio, hangares, luces, Lila GLB y centinela se conservan.
- Coste geométrico aislado: pasa de 4 a 27 triángulos por malla de montaña, aproximadamente **1.188 triángulos** en 44 mallas, todavía de bajo presupuesto; sin colisiones, sombras nuevas, texturas de Internet ni gastos en físicas durante el lobby. Es una mejora de silueta, no un reemplazo de producción del modelo 3D.

### Señal de carga real animada

- La franja dorada `AuroraLoadingGoldStripe` y la leyenda `AuroraLoadingChapter` tienen un pulso de opacidad de 2,6 segundos mediante `Tween`, sin shader de pantalla completa ni estimaciones falsas del tiempo restante.
- La barra de progreso mantiene el contrato `ResourceLoader.load_threaded_get_status`, incluyendo reintentar/cancelar; la señal se detiene y restablece al entrar a login/lobby para no conservar ciclos inútiles en Android. El contenido sigue siendo `Control` nativo Godot, no vídeo ni screenshot.

## Pruebas nuevas integradas

- `v75114_natural_polar_stage_qa.gd`: inspecciona buffers `Mesh.ARRAY_VERTEX` de las 44 mallas, 27 triángulos por malla, luminancia PBR, proporción roca/nieve y preservación/rotación del radar 3D.
- `v75114_loading_signal_motion_qa.gd`: verifica existencia y funcionamiento del tween, que no cambia el progreso y que se libera limpiamente al entrar a bienvenida/lobby.
- Ambas al comienzo de `native-godot/tools/run_qa.sh`, seguidas por todas las pruebas V75.113 y anteriores, capturas nativas de Godot/Xvfb 1280×720 y 964×434. **No declarar CI aprobado hasta ver el run de GitHub completado**.

## Android y límites explícitos

`version/name=75.114.0-mobile-vulkan`, `version/code=104`, renderer **Mobile/Vulkan**, **ARM64**, mismo paquete preview y firma. El APK se mantiene exclusivamente en `workflow_dispatch` para respetar el pedido de no generar compilaciones Android intermedias. No tocar `main`, `v44-3-2-autosave-guest`, Firebase productivo, certificados, claves, contadores ni progresión.

La referencia artística final exige además un modelo humano definitivo y dirección de arte de nivel comercial. Una CI verde en OpenGL software no demuestra FPS ni calidad final en Motorola Edge 60 Fusion; pruebas y capturas físicas siguen pendientes.
