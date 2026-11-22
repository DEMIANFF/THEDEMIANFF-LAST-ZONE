# THEDEMIAN: LAST ZONE — V75.153 | Gates reales hacia una entrega completa

**Base de trabajo:** V75.152 sobre V75.151–150–149 (cada una en PR draft). Solo V75.151 y anteriores estaban aprobadas al crear esta rama; comprobar el HEAD vigente de cada una en CI antes de promover.

## Hecho dentro de V75.153
- El selector rápido no intenta equipar una AWM inexistente cuando solo está disponible AR-7. Una vez recogida una MP40 real, el cambio entre armas vuelve a funcionar con sus slots históricos.
- Al terminar o comenzar partida se restauran las transformaciones originales de retroceso del GLB, cerrojo AWM, cargador MP40, las animaciones importadas y su velocidad. No quedan gestos o cargadores desplazados de la ronda anterior.
- QA usa **Main.tscn** con 49 rivales CharacterBody3D y el jugador (50), dos rondas reales, disparo que consume munición, cambio de arma solo después de botín auténtico y comprobación explícita de restos visuales.
- No se alteran inventario persistente, IDs, firmas, Firebase, rama estable, Vulkan/ARM64 ni el modelo de datos offline.

## Recursos Aurora V3 recuperados: disponibilidad NO equivale a integración

La Biblioteca de ChatGPT contiene **24 segmentos** `AURORA_V3_ASSETS_01_DE_24.zip` a `24_DE_24.zip`, el inventario de **80 originales** (**54 GLB + 25 MP3 + 1 ZIP**, 1.801.117.939 bytes originales) y documentos de procedencia. **Este PR no empaqueta ni publica esos binarios**. Antes de importar a GitHub/Android:

1. Reconstruir los 24 segmentos mediante `RECONSTRUIR_AURORA_V3.py`, verificar los SHA256 del inventario, y extraer solo los modelos seleccionados. Mantener duplicados fuera del runtime.
2. Auditar permisos y atribución: el inventario declara 50 CC BY, 2 CC BY-NC (no comerciales), 1 CC BY-ND (sin derivados) y 1 Sketchfab Standard. La declaración de metadatos no sustituye verificar permisos para distribución. No empaquetar los restringidos como activos comerciales. No importar marcas o iconografía ajenas.
3. Priorizar **animated_scar.glb** (fuente con 4 clips Idle/Reload/Shoot/Take), MP40 con malla ligera (sin clips propios), 3D/sonido que corresponda a los sockets reales de Lila. El código actual soporta un derivado privado de SCAR si está instalado, pero no se debe afirmar importación cuando no lo está.
4. Verificar presupuesto móvil de polígonos, texturas, memoria y derivación; por ejemplo la mochila cosmética `mochila_luivi.glb` requiere reducción de geometría antes de activarla (~956.938 triángulos en el inventario).
5. Escenarios/vehículos y mapas del usuario: sus datos pueden estar en Biblioteca, pero eso no significa que estén cargados en `Main.tscn` ni en APK. No simular presencia: cargar fuentes verificadas o mantener fallback original.
6. Medir Vulkan en **Motorola Edge 60 Fusion**, entrada multitáctil, vuelo→paracaídas→aterrizaje, combate, casas, botín, resultado y segundo inicio. El QA desktop OpenGL y el éxito de CI no demuestran rendimiento físico.

## Pendiente para afirmar «Battle Royale 100 % completo»

- Modelos/licencias y animaciones por arma realmente importados y validados en Lila.
- Paridad visual, cartografía legible y rendimiento medidos en dispositivo.
- Firebase Authentication/App Check/guardado verificados en Android real, sin cambios destructivos en la configuración productiva.
- Online y clasificatoria **con servidor real y pruebas de red**, no solo 49 bots offline.
- QA de sesión completa más pruebas físicas prolongadas, baterías de memoria y fallo de red.
- Checklist de publicación: derechos de assets, política de datos, firma release y tienda; la firma debug no certifica release comercial.

**Regla de entrega:** no confundir inventario, imagen renderizada, CI en escritorio, APK exportada y prueba física de juego. Son hitos distintos.
