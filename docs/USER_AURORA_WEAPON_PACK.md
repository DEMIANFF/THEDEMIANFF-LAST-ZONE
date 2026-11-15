# THEDEMIAN: LAST ZONE — paquete Aurora de 13 armas del usuario

**Base de trabajo:** V75.102 (PR #105); esta rama es paralela y no modifica el trabajo de Lila en Work.

## Fuentes auditadas
- `all weapons.obj`, `all weapons.fbx`, `all weapons1.blend`, `all weapons1.x3d` y MTL: **13 piezas originales**; 20.806 triángulos. El MTL no referencia texturas ni suministra licencia.
- `fps_character_animation_pack_pistol.glb`: **11 clips** (Equip, Idle, Aim Idle, Walk, Aim Walk, Run, Aim Fire, Fire, Reload, Change, Hold), **dos skins/esqueletos** (13 y 106 joints). El propio archivo indica autor **Cristian David Duque Camacho**, licencia **CC BY 4.0** y URL original de Sketchfab. Conservar atribución al reutilizar.

## Artefacto exportado fuera del repositorio

`AURORA_13_ARMAS_GODOT_OPTIMIZADAS.zip` contiene 13 GLB individuales, una ficha JSON, una pistola con sus mapas 1024 px y las condiciones de uso. Cada GLB individual se ha normalizado a metros, con cañón hacia `-Z` y nodos `AuroraGrip`, `AuroraMuzzle`, `AuroraSight` y `AuroraEjection`.

**Los binarios del paquete aún no forman parte de este PR**. Copiarlos a `native-godot/assets/weapons/user_pack/` después de revisar los derechos de la colección. La compilación usa las armas originales hasta entonces.

## Integración segura preparada

- W04: visual opcional en la ranura real de AR, **sin inventar** una tercera arma jugable.
- W11: visual opcional en la ranura real de AWM, preservando adquisición de botín, mira 8× y cadencia.
- Si existe `AuroraMuzzle`, el disparo toma el extremo real del cañón; si no, se conserva el offset verificado del GLB original.
- Las otras 11 armas **son recursos visuales**, no armas con lógica de inventario, daño, recargas y HUD aún.
- El rig UE5 del pack de pistola **no es compatible directamente con el esqueleto de Lila**; requiere retargeting, no reasignación ciega de huesos.
- La lista de skins, acciones médicas, Firebase, firma, cámara y paracaídas permanece intacta.

## Pruebas y aprobación pendientes

1. Importar deliberadamente los 13 GLB y ejecutar `bash native-godot/tools/run_qa.sh`.
2. Verificar en Godot que los `Node3D` de los marcadores se conserven tras importación.
3. Probar con Lila nueva la mano derecha, espalda, deslizamientos, disparo y posición del fogonazo.
4. Medir FPS/memoria en Motorola Edge 60 Fusion Android ARM64 Vulkan Mobile.
5. Confirmar derechos de redistribución de las 13 armas antes de cualquier APK pública.

La QA se diseñó para no bloquear el juego cuando faltan estos recursos de usuario; indica explícitamente cuántos modelos están importados.
