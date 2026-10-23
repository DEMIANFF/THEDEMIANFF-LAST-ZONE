# V40 — Auditoría de los recursos 3D recibidos

Se verificaron las cabeceras GLB 2.0 y estructuras glTF directamente de los cuatro archivos entregados por Daniel.

| Recurso proporcionado | Tamaño | Mallas | Materiales | Texturas | Esqueleto (skins) | Animaciones |
|---|---:|---:|---:|---:|---:|---:|
| LILA_V22_Operadora_Futurista.glb | 92 144 bytes | 52 | 0 | 0 | 0 | 0 |
| mujer_sexy_anime_angel_3d__modelo_glb.glb | 24 823 060 bytes | 8 | 1 | 1 | 0 | 0 |
| pack_de_armas.glb | 745 776 bytes | 8 | 8 | 3 | 0 | 0 |
| fusil_-_ak-74_tactico.glb | 3 518 588 bytes | 1 | 1 | 4 | 0 | 0 |

## Integración

- El juego espera actualmente **`app/src/main/assets/models/lila-operator.glb`**; el archivo V22 de 92 KB contiene nodos `leftArm`, `rightArm`, `leftLeg`, `rightLeg`, `leftHair`, `rightHair`, compatibles con los pivotes animados por JavaScript.
- Este GLB V22 carece de esqueleto y de animaciones glTF. Su articulación existente es jerárquica, no un rig de huesos; **no es todavía** el modelo realista definitivo que muestran las referencias.
- El modelo femenino de 24,8 MB tiene textura, pero no rig ni animaciones; requiere evaluación estética, licencia y optimización para Android antes de considerarlo.
- El pack de armas y AK-74 tienen texturas; separar, escalar, orientar y montar en manos / espalda antes de activarlos en juego.
- **Los modelos no se consideran integrados en la APK hasta estar presentes como binarios en la rama y comprobar su carga en Android.** La API de escritura textual del repositorio no equivale a subir los archivos binarios recibidos.
- Verificar los permisos/licencias de reutilización y distribución de los modelos obtenidos externamente.

## Pruebas de aceptación pendientes

1. Archivo Lila presente, cargado y visible en lobby y partida.
2. Movimiento y posiciones sin deformaciones (caminar, correr, saltar, agacharse, disparar, recargar).
3. Arma equipada en la orientación correcta, sin atravesar la mano/cuerpo.
4. Memoria RAM, FPS y carga inicial verificados en Motorola Edge 60 Fusion.
5. Conservación de mecánicas aprobadas V39.8 y compatibilidad offline.
