# Aurora V3 — montaje privado de 21 recursos y animación SCAR

**Base:** PR #123 / `codex/v75-118-aurora-v3-resource-integration`, heredada de V75.117 probada. No fusionar este PR ni generar APK hasta que la inspección visual real, el rendimiento y los derechos se aprueben.

## Qué existe ahora en código

- 3 armas opcionales HK416, P90, VSS con recogidas, lógica de munición y pruebas básicas; la CI pública no distribuye sus GLB.
- Avión de transporte C-17 opcional decorativo, conservando el vuelo/física/paracaídas establecidos.
- Disparos, pasos, explosión y sobrevuelo privados opcionales; si faltan, el juego conserva los sonidos procedurales.
- **SCAR animada fuente:** GLB derivado del original `animated_scar.glb` recuperado 80/80. Se preservan **cuatro clips esqueléticos reales** (`Akito Rig|Idle`, `Akito Rig|Reload`, `Akito Rig|Shoot`, `Akito Rig|Take`), el esqueleto, los nodos del arma y sus animaciones. Los nodos de malla FPS de manos/mangas originales se desconectaron de la escena activa sin recortar los canales.
- `weapon_visuals.gd` prefiere la SCAR animada si está instalada; si no, conserva la SCAR estática verificada y **no dice que las animaciones originales se reprodujeron**. Disparo/recarga/equipamiento llaman a `AnimationPlayer` de la SCAR fuente, separado del rig de Lila.

## Paquete de pruebas de origen y licencia

Archivo privado en Biblioteca:
`THEDEMIAN_LAST_ZONE_AURORA_V3_80_RECURSOS/VERIFICACION_REAL_2026_11_16/THEDEMIAN_AURORA_V3_21_RECURSOS_PRIVADOS.zip`.

El manifiesto del ZIP incluye los SHA-256 de **21 archivos**; SHA-256 del propio manifiesto: `6cba0b04d9aea0d2cea396b5c5f21033dcc2056e90b315ddc56b62e453c7f711`.

La SCAR animada tiene SHA-256 `799289d31fd6d55f64425f28367465e155aed36a0f2f2aae1fa4e22fd99b29e6` (16.067.644 bytes) y procede del original SHA-256 `d32f15d810ce1e0639ff6a833dd03299cc01cc3f4eb55e660293e04b0dc15267`.

Autor declarado: **JUST** — fuente <https://sketchfab.com/3d-models/animated-scar-5e64d6245bba4a819b9fef578c34b3fe> — licencia declarada **CC BY 4.0**. Conservar atribución; revisar derechos complementarios y uso de marcas antes de distribuir.

## Instalación local reproducible

Con una copia del repositorio y Godot 4.7.2, sin modificar el repositorio público ni perfiles, ejecutar desde la raíz:

```bash
python3 native-godot/tools/aurora_v3/stage_verified_21_assets.py \
  --pack /ruta/THEDEMIAN_AURORA_V3_21_RECURSOS_PRIVADOS.zip \
  --project native-godot
```

Solo comprueba. Para instalar después de verificar:

```bash
python3 native-godot/tools/aurora_v3/stage_verified_21_assets.py \
  --pack /ruta/THEDEMIAN_AURORA_V3_21_RECURSOS_PRIVADOS.zip \
  --project native-godot --install
bash native-godot/tools/run_qa.sh
```

El instalador comprueba 21/21 archivos y hashes contra el manifiesto inmutable, rechaza rutas o contenido inesperados, no sobrescribe archivos distintos, no modifica certificados, cuenta, Firebase ni datos `user://`. Las ubicaciones de los recursos privados figuran en `.gitignore`.

## No verificado todavía

La validación del ZIP y su copia en un proyecto de prueba temporal con **21 recursos reales** superó comprobaciones de integridad e instalación idempotente. Esto **no implica** que Godot haya renderizado, importado ni probado físicamente el paquete original: la CI pública todavía no incluye esos binarios. El código dinámico de SCAR tiene QA de importación/acción cuando la fuente está presente, pero su aceptación visual sobre Lila está pendiente.

No confundir estas cuatro animaciones del rig SCAR con retargeting automático a los 56 huesos de Lila: la animación propia del arma y el movimiento esquelético de Lila son canales distintos.

Quedan por integrar y probar los demás archivos de los 80 originales, modelos masculinos, gran parte de los vehículos y mapas, además de verificar el rendimiento Android y el acceso Firebase online. Los recursos CC BY-NC, CC BY-ND o con permisos no resueltos siguen excluidos de publicación.
