# Aurora V3 — Cinco armas animadas y música del lobby

## Integración de código vs. material realmente instalado

**Estado:** PR #123 en borrador. Hay **13 tipos de arma definidos en código** (ocho anteriores + cinco nuevos) y un servicio de música del lobby ya conectado a las transiciones del frontend. Los cinco nuevos modelos y la pista son material **privado en Biblioteca**, no están empaquetados en la CI pública. Sin importar el resultado verde, una APK que no incluya esos binarios no puede mostrar ni animar estas armas.

Ruta en Biblioteca:
`THEDEMIAN_LAST_ZONE_AURORA_V3_80_RECURSOS/VERIFICACION_REAL_2026_11_16/THEDEMIAN_AURORA_V3_ARMAS_MUSICA_PRIVADO.zip`.

### Modelos fuente y atribución

| Acción | Archivo original | Autor declarado | Clips de fuente |
|---|---|---|---:|
| Escopeta | `animated_shotgun.glb` | [JUST](https://sketchfab.com/3d-models/animated-shotgun-e048ba220f9e49c29a3e808cddc22a0a) | 7 |
| Pistola Magnum | `animated_magnum.glb` | [JUST](https://sketchfab.com/3d-models/animated-magnum-643b9d61ff49407b84ead78eaf815252) | 5 |
| Cuchillo | `animated_knife.glb` | [JUST](https://sketchfab.com/3d-models/animated-knife-7bee900b43f24ed9b3d48304362d5599) | 4 |
| MP5 | `animated_mp5.glb` | [JUST](https://sketchfab.com/3d-models/animated-mp5-19278d5f4a334f4abf320bc303ff9be1) | 3 |
| Sniper | `fps_animations_sniper_rifle.glb` | [Cransh](https://sketchfab.com/3d-models/fps-animations-sniper-rifle-c15ae8393d824f5b929e3f69691cdd31) | 6 |

Los GLB originales **declaran CC BY 4.0** en `asset.extras`. Los derivados disminuyen la resolución de imágenes incrustadas y desactivan la renderización de las mallas FPS de manos/brazos/mira cuando las hay; **mantienen los datos del esqueleto y los 25 clips**. No afirman retargeting a Lila. La verificación definitiva de autorización, derechos ajenos y atribución debe quedar cerrada antes de distribuir una APK con las mallas.

El archivo de granada aportado `fps_guns_4k_-_frag_granade.glb` declara **CC BY-ND 4.0**: no se adapta ni publica. El juego usa en cambio su objeto físico original Godot, ahora con malla procedimental de fuze/cuerpo/pin/palanca, que no utiliza terceros.

### Música del lobby

- Original aportado: `ikoliks_aj-gaming-gaming-music-614619.mp3`.
- Autor: [ikoliks_aj — Gaming - Gaming Music](https://pixabay.com/music/video-games-gaming-gaming-music-614619/), pista publicada bajo licencia de contenido de Pixabay, con **Content ID registrado**; verificar compatibilidad de uso, conservar evidencia y evitar reclamos antes de distribuir.
- Derivado privado: `native-godot/assets/audio/aurora_v3_addendum/aurora_lobby_loop.ogg`, 140,5 segundos, normalizado a -18 LUFS y codificado Vorbis para Android.
- `AuroraLobbyMusic` ya dispone de los métodos `enter_lobby()`, `leave_lobby()`, suspensión/reanudación y control de volumen; no se introduce un reproductor duplicado ni música ficticia.

### Funciones nuevas en rama (pendientes de CI final)

- `MP5`: automático, reserva SMG, cargador independiente.
- `ESCOPETA`: semiautomática, ocho rayos físicos con dispersión, alcance limitado a 22 m, cartuchos propios. Los impactos reciben daño solo contra colisionadores reales y cuentan una descarga como una única oportunidad de acierto.
- `MAGNUM`: revólver semiautomático, cargador y reserva de pistola independiente.
- `CUCHILLO`: golpe de proximidad con raycast físico (2,3 m), sin gasto de balas, sin recarga ni mira.
- `SNIPER`: tiro semiautomático, reserva compartida con AWM, miras x2/x4. La AWM histórica sigue siendo la única con mira x8.
- Los cinco modelos nuevos tienen recogidas condicionales en Entrenamiento y BR, equipamiento, HUD y etiquetas de botín. Si no se instala un archivo privado **no debe aparecer su recogida**.
- La granada conserva su objeto físico con trayectoria, rebotes, fusible y daño por explosión con protección de obstáculos; nuevo detalle visible de seguro, palanca y anillo.

### Instalación *solo en una copia privada de prueba*

```bash
python3 native-godot/tools/aurora_v3/stage_missing_weapons_music.py \
  --pack /ruta/THEDEMIAN_AURORA_V3_ARMAS_MUSICA_PRIVADO.zip \
  --project native-godot
# Si las seis huellas son correctas y existe permiso para uso local:
python3 native-godot/tools/aurora_v3/stage_missing_weapons_music.py \
  --pack /ruta/THEDEMIAN_AURORA_V3_ARMAS_MUSICA_PRIVADO.zip \
  --project native-godot --install
bash native-godot/tools/run_qa.sh
```

El instalador comprueba seis SHA-256 y un manifiesto fijo, rechaza rutas inesperadas, no sobrescribe otros modelos ni toca datos guardados. Los seis archivos están en rutas ignoradas por Git. Esto no constituye ninguna prueba física en Motorola.

### Trabajo pendiente no declarado completo

Retarget manual a Lila y operador masculino; manos y mira para cada arma, recarga escalonada de escopeta, calibración de FPS/VRAM y movimiento con carga completa; efectos autorizados para pistola/escopeta/cuchillo; colocación y colisiones del mapa candidato; vehículos Toyota/BMW con LOD, física, controles, sonidos; legalidad de algunos modelos y música; login Firebase online; APK firmada y prueba física Motorola Edge 60 Fusion.

La lista de **148 entradas de origen** (incluye duplicados, documentación y derivados) está en `COMPLETE_ASSET_LEDGER_148.md`. No interpretar 148 como 148 objetos jugables.
