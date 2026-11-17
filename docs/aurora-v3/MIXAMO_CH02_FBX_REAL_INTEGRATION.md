# Ch02 Mixamo — recuperación real de cuatro FBX y vista 3D opcional

**Base:** rama de Aurora V3 del PR #123. La última base CI aprobada antes de esta integración fue `66061637120191cab9e92426773bee05a6b93564` (run #43998470185). No se modifica `v44-3-2-autosave-guest`, Google/Firebase productivo, firmas, ni datos del usuario.

## Los cuatro originales realmente inspeccionados

Se abrieron **los bytes reales** que el usuario adjuntó el 16-nov-2026. Todos son FBX Binary **7700**, poseen **65 huesos Mixamo con los mismos nombres**, **seis mallas** y **315 curvas** por archivo. Cada tamaño y SHA-256 se comprobó de forma independiente:

| Archivo | Bytes | SHA-256 | Duración medida en curvas KeyTime |
|---|---:|---|---:|
| `Ch02_nonPBR.fbx` | 50.037.840 | `6a390659d923ebd1e80b6275490334d23cca593ec928db55669beeab81310e85` | 0,033 s (pose de referencia) |
| `Jump.fbx` | 50.409.472 | `54ba333c8946d401bcfeba1c610522cc38e233f869012e1aa83d1ac5adf452c7` | 2,167 s |
| `Start Walking.fbx` | 50.492.992 | `805643560b696a1929202a04a78d126dbc34b735e3296807104178f82b550ad0` | 2,933 s |
| `Jogging.fbx` | 50.466.080 | `1f572e771f605c6cb14b2f8079403029dd0572c0eecdefba711f81134e224663` | 2,550 s |

La duración se calculó a partir de los arreglos originales `KeyTime` de AnimationCurve (unidades FBX de 46.186.158.000 ticks/s); no es una medida visual de FPS ni una prueba de importación Godot.

## Recuperación y transformación

Paquete privado original: `THEDEMIAN_MALE_MIXAMO_4_FBX_PRIVATE.tar.zst` (SHA-256 `a06020a8086706f35122e0c25530cb178f6deabf4a83e7b2a2cf2aa2e682e804`). Archivo guardado en Biblioteca:

`THEDEMIAN_LAST_ZONE_AURORA_V3_80_RECURSOS/VERIFICACION_REAL_2026_11_16/MIXAMO_CH02_4_FBX/`

1. `native-godot/tools/aurora_mixamo/stage_mixamo_sources.py` verifica **4/4 SHA-256, FBX 7700 y correspondencia de 65 huesos**; `--install` copia solo los originales verificados a `native-godot/out/private_mixamo_sources/` (ignorados por Git), sin sobrescribir bytes distintos.
2. `native-godot/tools/aurora_mixamo/build_male_glb.py` es un conversor diseñado para **Blender 4.x**; importa la única malla base Ch02, copia las tres Action originales del mismo rig, las empaqueta en pistas NLA, reduce texturas grandes a 1024 px sin eliminar los pesos/rig, y exporta solo un `AuroraMaleMixamo.glb` a `native-godot/assets/characters/aurora_male_mixamo/`.
3. La ruta de destino del GLB está **excluida de Git**; no se publican FBX de terceros ni una APK sin revisión de uso.
4. El código del lobby `aurora_frontend.gd` ofrece el botón **CH02** exclusivamente cuando el GLB importado existe; alterna con Lila en el mismo SubViewport3D y permite reproducir caminar, trotar y saltar, con selección táctil. De lo contrario no aparece ese control ni se toca la operadora existente.
5. La QA `v75120_mixamo_source_qa.gd` exige 65 huesos, una malla válida y clips reales **solo cuando** el GLB está presente. En CI pública comprueba exclusivamente el fallback. Una QA verde sin GLB **NO** significa que se probaron sus animaciones.

### Ejemplo reproducible en una copia local con Blender y Godot

```bash
python3 native-godot/tools/aurora_mixamo/stage_mixamo_sources.py \
  --archive /ruta/THEDEMIAN_MALE_MIXAMO_4_FBX_PRIVATE.tar.zst \
  --project native-godot --install

blender -b --python native-godot/tools/aurora_mixamo/build_male_glb.py -- \
  --project native-godot --texture-limit 1024

godot --headless --editor --path native-godot --quit
GODOT=godot bash native-godot/tools/run_qa.sh
```

Los primeros pasos se comprobaron localmente con los originales, incluido ZIP/tar de entrada, hashes e instalación idempotente. **El paso de Blender y la importación real del GLB en Godot NO se han podido ejecutar en el entorno de esta sesión**. No suponer que un script de conversión demuestra que el personaje está visible en el Motorola.

## Alcance y límites honestos

Los FBX aportados contienen el personaje masculino y tres movimientos. **No incluyen clips específicos de disparar, recargar, curar o agarrar dos armas**; tampoco incluyen conducción de Toyota/BMW, mapas optimizados, o infraestructura online. Por eso **la selección masculina es una vista previa 3D** y no sustituye la física, armas ni animaciones probadas de Lila en una partida.

Faltan la exportación Blender comprobada, revisión visual y técnica del modelo único, retarget/combat del operador masculino, licencias de todos los recursos destinados a distribución pública, mejora de mochilas y vehículos, integración de mapa candidato y prueba de rendimiento/estabilidad Vulkan en Motorola.

**No fusionar el PR ni generar una APK final por el mero resultado verde de CI.**
