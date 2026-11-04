# V57.7 — desplazamiento de bots junto a paredes

## Cambio
- El movimiento de cada bot conserva el mismo radio de colisión que ya tenía.
- Cuando el paso diagonal choca con una pared, se comprueba cada eje por separado y se permite avanzar por el eje libre.
- En un contacto diagonal de esquina donde ambos ejes estén libres por separado, se prioriza el desplazamiento con mayor avance solicitado.
- Si ambos ejes están bloqueados, se conserva la detención segura y la recuperación táctica anterior.

## Validación
Se agregaron pruebas unitarias para camino libre, deslizamiento en ambos sentidos, contacto diagonal con esquina y bloqueo completo. GitHub Actions debe confirmar el conjunto de pruebas y la compilación de Android. La comprobación de movimiento real en el Motorola Edge 60 Fusion sigue pendiente de instalar y probar esta APK.
