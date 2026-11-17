# Aurora V3 — Toyota Fortuner y BMW M4 reales: conducción y pruebas

**Estado:** código de conducción física integrado en el PR #123; dos modelos GLB originales recuperados de la Biblioteca y resguardados en un ZIP privado. La CI pública no contiene sus bytes. **NO se ha probado conducirlos en Motorola, ni se ha completado el nivel visual del conductor, ni existe APK nueva.**

## Fuentes recuperadas, verificadas y atribución

| Fuente | Autor atribuido en archivo | Licencia declarada | Bytes originales | Extensiones de malla medidas |
|---|---|---|---:|---|
| `toyota_fortuner_gen_3_offroad_mod_knitro_builds.glb` | [knitro_builds](https://sketchfab.com/3d-models/toyota-fortuner-gen-3-offroad-mod-knitro-builds-3ccacfd8826a497b9f080a6a7caf150c) | CC BY 4.0 | 51.878.376 | 3,45 × 3,13 × 8,05 unidades |
| `bmw_m4_modified_widebody_knitro_builds.glb` | [knitro_builds](https://sketchfab.com/3d-models/bmw-m4-modified-widebody-knitro-builds-6e325ec23a0f41c08366472b34b8f8c8) | CC BY 4.0 | 21.945.796 | 10,05 × 6,68 × 23,67 unidades |

SHA-256 del original Toyota: `7b3d2dfd5002c9beb167c35bb537452dae8e7936f205c24e594071163eef2ad0`.

SHA-256 del original BMW: `751c816b8ec140120a5a9a498db606a760cde8bdf3f2e98ff83781a6b6bd23ea`.

El ZIP privado `THEDEMIAN_AURORA_V3_TWOCARS_PRIVATE.zip` conserva ambos GLB sin alterar la geometría y un `AURORA_VEHICLES_PRIVATE_MANIFEST.json`. Está en Biblioteca:

`THEDEMIAN_LAST_ZONE_AURORA_V3_80_RECURSOS/VERIFICACION_REAL_2026_11_16/`.

**Derechos:** la declaración CC BY 4.0 procede de `asset.extras` en cada GLB, pero marca, distribución de modelo completo y atribución requieren revisión adicional antes de publicar, incluso si se usan en un videojuego comercial.

## Integración de juego (solo cuando la fuente real está instalada)

- `scripts/world/aurora_driveable_vehicle.gd`: `VehicleBody3D`, cuatro `VehicleWheel3D`, ruedas delanteras de dirección y traseras de tracción, chasis con `BoxShape3D`, suspensión, masa, gravedad, aceleración, frenado, marcha atrás y límites de velocidad. Se renderiza la malla original: no aparece una caja sustituta.
- Escala de carrocería medida desde los vértices del GLB y normalizada a un Toyota de aproximadamente 5 m o un BMW de 4,8 m de largo; la física se mantiene separada del visual.
- `scripts/match/sector_director.gd`: dos emplazamientos exteriores en BR clásico; un coche solo se genera si su `PackedScene` existe realmente; proximidad física y velocidad segura para acceder y salir, con comprobación espacial antes de bajar. Los vehículos se limpian entre rondas o durante el avión.
- `scripts/player/third_person_operator.gd`: el joystick existente controla dirección, marcha y frenado al conducir. El personaje conserva vida y estado de partida. Se evita colisión duplicada entre el chasis y el cuerpo, la cámara sigue al automóvil y hay bloqueo de fuego, ADS, curación y salto mientras se conduce. El operador se oculta temporalmente: **todavía falta una animación de sentado realmente autorizada y retargetada**.
- `scripts/ui/native_hud.gd`: botón `CONDUCIR/BAJAR` al estar junto a un coche, indicación de velocidad real en km/h, controles táctiles y preservación explícita del salto desde avión/paracaídas.
- `scripts/qa/v75122_real_vehicles_qa.gd`: en CI pública solo garantiza que no existen coches inventados cuando faltan modelos y que los controles móviles no quedan activos indebidamente. **En una copia privada con modelos staged** comprueba que existan las mallas y los cuatro objetos `VehicleWheel3D`, colisiones y estado de entrada/salida.

## Instalación local privada sin sobrescritura

Con `THEDEMIAN_AURORA_V3_TWOCARS_PRIVATE.zip` y una copia local del repositorio:

```bash
python3 native-godot/tools/aurora_v3/stage_private_vehicles.py \
  --pack /ruta/THEDEMIAN_AURORA_V3_TWOCARS_PRIVATE.zip \
  --project native-godot
# Instala solo después de revisar derechos y límites del hardware:
python3 native-godot/tools/aurora_v3/stage_private_vehicles.py \
  --pack /ruta/THEDEMIAN_AURORA_V3_TWOCARS_PRIVATE.zip \
  --project native-godot --install
godot --headless --editor --path native-godot --quit
bash native-godot/tools/run_qa.sh
```

El instalador validó en una carpeta temporal: 2/2 originales, 2 instalados en la primera llamada y 0 en la siguiente, sin reemplazar archivos distintos. Los modelos originales quedan excluidos de Git en `.gitignore`.

## Riesgos conocidos — NO declarar terminada esta función

Los GLB originales tienen mallas demasiado complejas para aprobar de inmediato su uso en el Motorola Edge 60 Fusion. Falta una optimización geométrica específica con LOD, límites de draw calls y texturas, desacople de ruedas visibles para animación fiel, sonido de motor, operador sentado, validación de posición de ruedas respecto del chasis y pruebas de suspensión/colisiones sobre casas, rampas y pendientes reales. Los sistemas de vehículos no equivalen a una simulación de multijugador online.

**No generar APK final, fusionar el PR ni anunciar conducción certificada en Android hasta cubrir estas pruebas.**
