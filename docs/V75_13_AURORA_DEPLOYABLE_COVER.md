# THEDEMIANFF LAST ZONE — V75.13: Barrera Aurora original

**Base:** Godot V75.12 `codex/v75-12-per-scope-mobile-settings` y hotfix de aterrizaje V75.11.  
**Rama de trabajo:** `codex/v75-13-aurora-deployable-cover`.  
**No fusionar** hasta CI verde y prueba real en Motorola Edge 60 Fusion.

## Implementación funcional, no botón simulado

- `scripts/combat/aurora_deployable_cover.gd`: cinco prismas helados originales con una colisión `StaticBody3D` real; **220 HP**, vida máxima **48 s** y destrucción cuando su salud llega a cero.
- `scripts/combat/training_combat.gd`: el jugador puede situar una barrera en la dirección horizontal de la cámara, a 3,6 m delante; valida el espacio libre con `PhysicsShapeQueryParameters3D`, consume una carga solo si se coloca, e impone **9 s** de espera entre barreras. Máximo cuatro activas por combate.
- La partida comienza con **2 cargas**; algunas cápsulas físicas de botín reponen una, hasta **3 en inventario**. Las cargas, la salud de la pared y los objetos del mundo desaparecen al finalizar la partida, sin contaminar el historial persistente.
- `scripts/ui/native_hud.gd`: nuevo botón táctil **BARRERA**, visible en combate real, oculto durante avión/caída/paracaídas. Se deshabilita por falta de cargas o cooldown.
- `scripts/ai/aurora_bot.gd`: los enemigos detectan la pared en raycasts, no disparan atravesándola y pueden reducir la resistencia de esa cobertura. Casas y otras colisiones siguen bloqueando el fuego normalmente.
- `scripts/match/sector_director.gd` y `scripts/match/aurora_loot.gd`: dos de las 16 cápsulas de botín son ahora cargas Aurora con rotulado y color propios, sin fabricar resultados ficticios.
- `scripts/qa/v7513_aurora_cover_qa.gd`: prueba de bloqueo de despliegue en entrenamiento, inventario limitado, HUD, colisión contra raycast de arma, daño, destrucción, botín y limpieza en fin de partida.

## Riesgos / criterio de aceptación

- Es una mecánica **offline** del sector actual de 1 jugador + 8 IA; no es todavía una habilidad replicada en servidor.
- La superficie visual actual utiliza geometría procedimental ligera; futuras texturas, daños por etapas, animación de materialización y efectos visuales requieren revisión artística/performance en hardware real.
- Para aprobar: regresiones anteriores (incluida avión → caída → paracaídas → suelo), nueva suite V75.13, exportación APK arm64-v8a con namespace `com.thedemianff.lastzone.nativepreview7513`, firma/verificación y prueba del usuario en Motorola.
- No se cambió Firebase, Unity V76, certificados originales ni `v44-3-2-autosave-guest`. Se conserva Base/Puerto Aurora y el sistema TPS/ADS.
