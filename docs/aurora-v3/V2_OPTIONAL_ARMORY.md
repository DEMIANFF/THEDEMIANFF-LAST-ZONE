# Aurora V2 — HK416, P90 y VSS (integración opcional real)

**Estado:** lógica de juego integrada en la rama del PR #123; modelos originales preparados en un paquete privado fuera de GitHub. Sin APK, render Android ni prueba física nueva.

## Modelo, derechos declarados y procedencia

| Arma | Original verificado | Derivado móvil (SHA-256) | Autor declarado |
| --- | --- | --- | --- |
| HK416 | `hk_416_a7_free_download.glb` | `dae024ca21a784553c3c588f67c9c6dc64f0ef2309b2a1d9a81b59bbc09c237d` | r4m |
| P90 | `modular_p90_tactical.glb` | `0560b555ce3c01014d9fb689b93bd48cf2a600b2a66b844ec8db94f29406308c` | doomsentinel |
| VSS | `vss_vintorez_gameready.glb` | `57decf52b1ed0c661786c13192a414f2e9b5ef59b72a6976f94e210080578576` | DOSOWERT |

Los tres originales declaran **CC BY 4.0** en `asset.extras`. Se conservan atribuciones de origen:
- HK416: https://sketchfab.com/3d-models/hk-416-a7-free-download-a16768f0ffa24737a4fe324a411cfbd9
- P90: https://sketchfab.com/3d-models/modular-p90-tactical-080897fc0366455884b1a916684313fe
- VSS: https://sketchfab.com/3d-models/vss-vintorez-gameready-82fc1c6264434ede987079a834b1994b

La declaración dentro del archivo **no sustituye** revisión de licencias vigentes, logos, marcas, símbolos y posibles derechos adicionales. No publicar los binarios ni un APK que los contenga hasta resolver estos permisos.

## Instalación únicamente en copia de pruebas

Colocar el paquete privado `THEDEMIAN_AURORA_V2_TRES_ARMAS_GODOT_PRIVATE.zip` en un directorio accesible. El código usa estos paths:

- `native-godot/assets/weapons/aurora_v2_optional/aurora_hk416.glb`
- `native-godot/assets/weapons/aurora_v2_optional/aurora_p90.glb`
- `native-godot/assets/weapons/aurora_v2_optional/aurora_vss.glb`

Antes de copiar binarios, comprobar SHA y conflictos con:

```bash
python3 native-godot/tools/aurora_v2/stage_optional_armory.py \
  --pack /ruta/THEDEMIAN_AURORA_V2_TRES_ARMAS_GODOT_PRIVATE.zip \
  --project native-godot
```

La copia solo se realiza cuando se añade expresamente `--install`. No sobrescribe archivos distintos; sus hashes están fijados en el script. No altera Firebase, firmas, ramas ni perfiles.

## Comportamiento de juego implementado

- Ranuras históricas 0–4 intactas; HK416=5, P90=6, VSS=7.
- Munición compartida: HK416 y VSS usan reserva AR, P90 usa reserva SMG; cada cargador es independiente.
- Si el GLB no existe o no contiene mallas válidas, el arma no se concede y no aparece ninguna recogida opcional falsa.
- Al existir, hay recogidas físicas en Entrenamiento; en BR de 50 también aparecen posiciones adicionales de botín. Mismo sistema de inventario, rayos físicos, daño, recarga y HUD.
- Los GLB tienen **cero clips embebidos**: recurren a las poses del operador y a sockets de apoyo, sin afirmar que haya animación específica original.
- Escalas originales muy diferentes (HK416 ~86 unidades, P90 ~1235, VSS ~0.89); el juego calibra longitud humana en el soporte, estima grip y muzzle. Requiere aceptación visual antes de considerarse terminado.
- Sonidos existentes de AR/SMG/DMR siguen disponibles; faltan samples propios licenciados por arma.

## Pruebas que faltan

La batería `v75118_optional_weapon_catalog_qa.gd` verifica invariantes del catálogo y rutas, y `v75118_training_armory_qa.gd` incluye el combate con armas opcionales **cuando los GLB estén presentes**. La CI ordinaria no incluye los binarios privados, de modo que **no valida sus mallas importadas**. El contacto mano/arma, muzzle real, cámara ADS y fps deben inspeccionarse en Godot con modelos instalados y finalmente en Motorola Edge 60 Fusion.

**No declarar la integración terminada ni liberar APK por el mero resultado verde de CI.**

## Recuperación selectiva posterior a V75.190

La P90 pública tiene un derivado móvil posterior y no debe sustituirse por el GLB de este paquete privado. Para preparar **solo HK416 y VSS** en una copia de pruebas actual:

```bash
python3 native-godot/tools/aurora_v2/stage_optional_armory.py \
  --pack /ruta/THEDEMIAN_AURORA_V2_TRES_ARMAS_GODOT_PRIVATE.zip \
  --project native-godot --models HK416 VSS
```

Añadir `--install` exclusivamente para efectuar la copia privada. El programa verifica los SHA de los tres miembros antes de escribir, pero comprueba destinos y copia únicamente los seleccionados. La P90 actual queda intacta; los GLB privados no se publican ni se consideran licenciados para distribución por esta operación. Ejecutar Godot y las QA de armería con ambos archivos presentes antes de liberar una APK. La verificación de permisos adicionales sigue pendiente.
