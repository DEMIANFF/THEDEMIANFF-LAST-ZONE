# Aurora V75.104 · Pasos, gesto de lobby y audio de partida

La rama parte de `a8272d4cd17ed161b1d1cfee4eaa3cf85159dd6e`. Sigue usando Godot 4.7.2, Android ARM64 y Vulkan Mobile. La versión de desarrollo es `75.104.0-mobile-vulkan` (`versionCode 94`). [PR #108](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/pull/108) · [CI de la base](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/43745705159)

## Mecánicas

- **Pisadas.** Se leen las fases de apoyo de los clips reales de locomoción. Los contactos solo se emiten si la física confirma suelo y desplazamiento. Cambiar de clip o quedar bloqueado no dispara pasos adicionales. Los bots cercanos usan el clip de marcha o carrera de su propia armadura y tres voces posicionales de corto alcance. La piedra y el pavimento usan los recortes de la adenda en el proyecto local. La nieve conserva el sonido original. El control `Pasos` usa su propio bus y configuración persistente.
- **Gesto de lobby.** De los 56,67 s de `Motion` se adaptó el tramo 9,5–21,5 s. El recurso pesa unos 118 KiB y contiene 11 pistas de rotación a 15 Hz. En el lobby se completan con la postura de Lila para mantener pelvis y pies en el podio. El gesto alterna con su reposo habitual. `siff.glb`, sus texturas, sus siete mallas y su esqueleto de 141 articulaciones permanecen fuera del proyecto. El GLB de Lila y sus animaciones de partida proceden del commit base.
- **Granada.** Se recoge en la partida clásica y se lanza desde la mochila. El proyectil rebota en la geometría y detona al terminar la mecha. Se resuelven destello, daño radial y rayos de cobertura en el mismo evento que el sonido. Hay tres voces espaciales dedicadas. Cada cola permanece después de que desaparezca el proyectil. Fin de ronda y salida del mundo cancelan proyectiles activos.
- **Avión.** El barrido empieza al aparecer el avión, una vez por entrada a la fase. Se detiene al confirmar el salto. Las transiciones a caída, paracaídas, combate o lobby no lo reactivan. La base tenía viento ambiental y lo conserva. No había una pista de motor dedicada.
- **Música.** Un servicio persistente de Godot con un reproductor y bus `Music` entra al lobby tras el acceso. La navegación, Configuración y el editor HUD conservan la posición. Entrenamiento y BR reales la detienen. Volver al lobby la arranca de nuevo. El deslizador `Música del lobby` guarda su volumen y el cero silencia el bus. El servicio conserva la posición al recibir las notificaciones de pausa y reanudación de la aplicación.

## Recursos y procedencia

Se cotejaron las huellas de las dos adendas y la del MP3 de lobby con la entrega. `install_aurora_addendum_audio.py` verifica las entradas antes de instalarlas, copia los tres OGG byte por byte y prepara seis pisadas de 185 ms a 22,05 kHz, mono. El repositorio es público. Los originales y derivados de audio suministrados se instalan localmente para evitar su redistribución como archivos sueltos. CI usa sonidos originales del proyecto para los efectos y una pista de prueba para comprobar la vida útil de la música. La pista de lobby elegida requiere instalar el OGG. [Condiciones de Pixabay](https://pixabay.com/service/terms/)

| Recurso | Origen y comprobación |
| --- | --- |
| `siff.glb` | Vasian-Digital3D. Atribución CC BY 4.0 declarada en el GLB original. La página no respondió durante la revisión. Se extrajo y adaptó el fragmento sobre otro esqueleto. [Modelo fuente](https://sketchfab.com/3d-models/siff-c25fe43594b64b0b847927f85748a130) · [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| Caminar | `freesound_community-walking-46245.mp3`. Coincidencia de título y número de catálogo. [Walking](https://pixabay.com/sound-effects/people-walking-46245/) |
| Correr | `freeeverythingxx-running-on-concrete-268478.mp3`. Ficha con atribución y licencia de Pixabay. [Running on concrete](https://pixabay.com/sound-effects/film-special-effects-running-on-concrete-268478/) |
| Granada | `freesound_community-hq-explosion-6288.mp3`. Coinciden autor, número y título. [HQ Explosion](https://pixabay.com/sound-effects/film-special-effects-hq-explosion-6288/) |
| Avión | `storegraphic-deep-long-air-transition-311051.mp3`. Coinciden autor, número y título. [Deep long air transition](https://pixabay.com/sound-effects/film-special-effects-deep-long-air-transition-311051/) |
| Música | «Gaming - Gaming Music» por ikoliks_aj, según la entrega. MP3 con SHA-256 `82ca0ab945a42e3b55a87d1c14551a0fb4add8525dbcb7aeec6ad5bfc7c55cd0`. El OGG instalado tiene SHA-256 `9a8e3d5e3bd385cd8682a4789621d0fe74d1af87a4d0d65471cb759e01fe10f2`. La ficha no respondió durante la consulta. La entrega informa un registro en Content ID. Conservar constancia de la descarga y revisar derechos antes de una publicación comercial. [Ficha indicada](https://pixabay.com/tr/music/video-oyunlar%C4%B1-gaming-gaming-music-614619/) |

Para preparar el proyecto local a partir de las dos adendas descomprimidas y el OGG adjunto, abrir Godot después de ejecutar este comando.

```bash
blender -b --python native-godot/tools/install_aurora_addendum_audio.py -- /ruta/a/adendas /ruta/AURORA_LOBBY_MUSICA_LOOP_GODOT.ogg
```

La adaptación de `Motion` se puede regenerar desde el hash de origen verificado.

```bash
python native-godot/tools/build_aurora_lobby_motion.py /ruta/siff.glb native-godot/assets/characters/lila_aurora.glb native-godot/assets/animations/aurora_lobby_motion.tres
```

## Validación

La suite `v75104_aurora_addendum_qa` verifica el recorrido de lobby, editor HUD, entrenamiento y BR, la aplicación del gesto sobre los huesos de Lila, los eventos de vuelo y la detonación física con cobertura, lanzamiento concurrente y cancelación. El mezclador de Godot reprodujo dos vueltas completas del OGG local de 137,434 s y devolvió señal en ambos empalmes. Se revisaron cinco poses renderizadas del gesto sobre Lila en escritorio.

La escucha del empalme, las transiciones de segundo plano de Android y el rendimiento acústico o gráfico en el Motorola Edge 60 Fusion físico quedan pendientes. La exportación del APK permanece reservada a ejecución manual.
