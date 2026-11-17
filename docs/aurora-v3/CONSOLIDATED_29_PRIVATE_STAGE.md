# Aurora V3 — paquete consolidado de pruebas (29 recursos reales)

**Estado de entrega:** 29 archivos privados recuperados y verificados; ruta de instalación local añadida al PR #123. **No es una APK, no equivale al juego completo, y no autoriza distribución pública**. Toda compilación Android debe superar pruebas visuales y de rendimiento con el material realmente instalado.

## Contenido

- **10 GLB** (SCAR original con 4 clips; HK416, P90, VSS; MP5 con 3, escopeta con 7, Magnum con 5, cuchillo con 4, francotirador con 6; C-17 sin clips).
- **19 audios**: lobby musical Vorbis, seis pasos WAV y doce efectos OGG (disparos de escopeta/pistola, armas automáticas, impactos, recarga, explosión, sobrevuelo). La presencia de sonidos no sustituye ajustes de mezcla ni validación comercial.
- El paquete unificado combina las 21 fuentes privadas anteriores, seis nuevas (cinco modelos animados y música) y dos muestras de disparo que proceden de audios MP3 enviados por el usuario. Las etiquetas y rutas de archivo **no certifican permisos**.
- Tamaño ZIP **50.594.690 bytes**; SHA-256 del archivo `3126d54db81174f1466ff4240bc09b677ddacc96a940b2cfb58c3b1d76ccf88d`. Manifiesto interno `MANIFEST_29.json` SHA-256 `15daa974e8e956fa0f9e2c447ed245759f889d9669d87ea3bba683b1afd35bbf`.

## Ruta privada en Biblioteca

`THEDEMIAN_LAST_ZONE_AURORA_V3_80_RECURSOS/VERIFICACION_REAL_2026_11_16/THEDEMIAN_AURORA_V3_29_RECURSOS_INTEGRACION_PRIVADA.zip`

No versionar este ZIP ni los GLB sin revisar las licencias por recurso. La rama `codex/v75-118-aurora-v3-resource-integration` permanece draft.

## Instalación de una copia local de Godot

La fuente del instalador está en `native-godot/tools/aurora_v3/stage_consolidated_29_assets.py`. Desde raíz del repositorio:

```bash
python3 native-godot/tools/aurora_v3/stage_consolidated_29_assets.py \
  --pack /ruta/THEDEMIAN_AURORA_V3_29_RECURSOS_INTEGRACION_PRIVADA.zip \
  --project native-godot
# La segunda llamada solo instala cuando el manifiesto completo y
# las 29 huellas sean válidas:
python3 native-godot/tools/aurora_v3/stage_consolidated_29_assets.py \
  --pack /ruta/THEDEMIAN_AURORA_V3_29_RECURSOS_INTEGRACION_PRIVADA.zip \
  --project native-godot --install
bash native-godot/tools/run_qa.sh
```

En comprobación independiente se ejecutaron tres pasos sobre una carpeta de prueba: `verified=29`, `installed_now=0` sin instalación; después `installed_now=29`, y repetición idempotente `installed_now=0`. No se sobrescribieron archivos existentes.

## Calidad / límites

La suite GitHub CI ordinaria **no tiene acceso a los 29 binarios privados** y, por tanto, no representa una prueba de importación real de esas mallas ni de sus clips. El código puede contener 13 armas registradas, pero la APK pública no las mostrará si no se incluyen los GLB. Deben medirse escala, calidad de agarre/retarget, fps, triangulación, latencia de recarga, interfaz y estabilidad Vulkan/ARM64 en Motorola Edge 60 Fusion. La música requiere comprobar licencias/content ID; algunos MP3 disparos precisan verificación de permisos de terceros.

El inventario de **148 entradas de origen** (no 148 objetos jugables) está en `docs/aurora-v3/COMPLETE_ASSET_LEDGER_148.md`. El resto de armas, vehículos Toyota/BMW y mapa candidato no se han convertido todavía en contenido jugable: requerirán simplificación, físicas, animación y colisiones reales.
