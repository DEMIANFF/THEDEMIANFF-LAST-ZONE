# Aurora V3 — equipo 3D original de Biblioteca (protección y primeros auxilios)

Se recuperaron los cuatro archivos GLB **reales** del inventario Aurora V3; no se utilizaron figuras sustitutas para preparar estos derivados. Se redimensionaron las texturas embebidas sin alterar la geometría, los materiales de referencia ni los buffers de vértices (verificación byte a byte de todos los bufferViews no relacionados con imágenes).

| Elemento | Fuente entregada | Derivado privado | Original (bytes) | Derivado (bytes) |
|---|---|---|---:|---:|
| Mochila militar | `mochila_militar.glb` | `AuroraMilitaryBackpackPrivate.glb` | 4.008.804 | 4.008.824 |
| Botiquín | `simple_botiquin.glb` | `AuroraFirstAidPrivate.glb` | 9.415.936 | 563.100 |
| Chaleco | `tactical_plate_carrier_vest_-_game_ready.glb` | `AuroraTacticalCarrierPrivate.glb` | 8.247.172 | 390.604 |
| Casco | `tactical_helmet_with_headset_game-ready.glb` | `AuroraHelmetHeadsetPrivate.glb` | 7.308.040 | 1.456.736 |

- Paquete privado: `THEDEMIAN_AURORA_GEAR_FOUR_PRIVATE.zip`, SHA-256 `e2f626478fd64987d9250890781ec821e1ce3f381d2120e920128027af11159c`, **6.420.751 bytes**.
- Disponible en Biblioteca: `THEDEMIAN_LAST_ZONE_AURORA_V3_80_RECURSOS/VERIFICACION_REAL_2026_11_16/`.
- Los originales declaran licencia **CC BY 4.0** en sus metadatos; revisar autoría, marcas, restricciones y atribución antes de cualquier distribución pública. Los derechos no quedan aprobados solo por una etiqueta del archivo.
- Script verificable: `native-godot/tools/aurora_v3/stage_private_gear.py`. Comprueba **4 SHA-256 exactos**, manifiesto fijo, entradas inesperadas, corrupción y sobrescrituras. Se ejecutaron prueba sin instalar (4/4) e instalación en copia temporal (4/4).
- Rutas privadas: `res://assets/gear/aurora_v3_private/`; excluidas de Git mediante `.gitignore`.

## Integración en juego (condicionada a archivos instalados)

1. `aurora_protection_visual.gd`: monta casco y chaleco recuperados en los huesos de cabeza/espalda de Lila, respetando los niveles de protección, con los modelos Aurora preexistentes como respaldo.
2. `aurora_backpack_visual.gd`: coloca la mochila recuperada mediante `BoneAttachment3D` en el hueso Spine del rig, visible **solo después de recoger** una mochila real; se oculta al resetear el inventario BR.
3. `aurora_loot.gd`: presenta estos GLB y el botiquín original en sus recogidas físicas, conservando colisiones, etiquetas, alturas de suelo y recogida previa.
4. `third_person_operator.gd` y `training_combat.gd`: preservan lógica existente de capacidad, nivel de armadura, puntos de casco y curación; ningún modelo introduce daños, recompensas o estadísticas ficticias.
5. `v75120_private_gear_qa.gd`: cuando hay GLB importados, valida importación y geometría; sin ellos, solo comprueba la ausencia de instancias falsas y que se conserve la lógica previa.

### Instalación para Godot 4.7.2 (copia privada)

```bash
python3 native-godot/tools/aurora_v3/stage_private_gear.py \
  --pack /ruta/THEDEMIAN_AURORA_GEAR_FOUR_PRIVATE.zip \
  --project native-godot
python3 native-godot/tools/aurora_v3/stage_private_gear.py \
  --pack /ruta/THEDEMIAN_AURORA_GEAR_FOUR_PRIVATE.zip \
  --project native-godot --install
GODOT=godot bash native-godot/tools/run_qa.sh
```

**Limitaciones:** la CI pública no contiene esos cuatro GLB y no prueba la aceptación visual de sus accesorios ni el comportamiento físico Motorola con el nuevo contenido. La mochila actual posee un nivel funcional; aumentar niveles y capacidad requiere cambios de diseño y regresiones separados. Los vehículos, mapa candidato, recursos pesados y red online continúan pendientes. Ninguna fuente se incluyó en una APK o una rama pública de activos.
