# THEDEMIAN: LAST ZONE — V75.64 · Saqueo auténtico de rivales caídos

## Base verificada
La rama se creó **directamente sobre V75.63**, PR [#65](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/pull/65), ejecución [#43468013982](https://github.com/DEMIANFF/THEDEMIANFF-LAST-ZONE/actions/runs/43468013982) = SUCCESS. El usuario confirmó una prueba física positiva de la versión V75.63 en Motorola, sin haber reclamado una auditoría exhaustiva de rendimiento.

Godot sigue siendo motor principal. Una APK ARM64 **Vulkan Mobile exclusivamente**, versionName `75.64.0-mobile-vulkan`, versionCode **54**. No modificar `v44-3-2-autosave-guest`, Firebase, claves, identidad, respaldo de jugador o ajustes de cámara/animación de Lila.

## Funcionalidad real integrada

### Botín basado en el estado real del rival
- Cada enemigo ya posee una munición real `_magazine` de máximo 18 y un inventario de botiquines consumibles `_field_medkits` gestionado por su IA. La V75.64 utiliza esos valores **cuando el personaje CharacterBody3D muere físicamente**.
- La caja AR suelta **las balas que quedaban realmente en el cargador**, entre 1 y 18, nunca 45 balas generadas sin explicación.
- Cuando un rival se queda sin munición pero aún conserva un botiquín, deja una caja de **un botiquín físico**.
- Para recompensar eliminaciones del jugador, cada tercera caja de combate puede elegir el botiquín *solo si el rival lo tenía realmente*. Si ya se curó y gastó el único botiquín, no lo recupera mágicamente.
- Si el enemigo gastó todo, no deja un objeto ficticio; se registra su muerte para evitar duplicar recompensas por notificaciones repetidas.
- Se conserva el límite de **12 cajas adicionales por partida** para no disparar colisiones ni draw calls cuando hay 30 bots físicos.
- Se conserva el descarte de cajas si el rival murió fuera de la zona segura; los rivales eliminados por IA también dejan botín físico si lo conservaban.
- El cálculo es determinista y comprobable, sin simulación de jugadores online, monedas, cofres falsos ni loot RNG opaco.

### Cantidad visible y aplicable
- Cada `Area3D` de muerte contiene `quantity` real; el rótulo indica por ejemplo **«RIVAL / MUNICION AR x7»**.
- `collect_sector_loot(kind,quantity,from_opponent)` preserva la cantidad estándar original de los botines de mapa, casa, fase y AWM cuando no hay override.
- Las cajas de enemigos suman exactamente la cantidad recuperada, limitada por la capacidad real de inventario/mochila. Si la bolsa está llena, la caja permanece para otro intento, sin cambiar estadísticas.
- Se incrementa `opponent_caches_collected` solo al tomar una caja real; también está disponible en el inventario/snapshot junto al total de botín para futuros resultados.
- Un objeto ya recogido no se duplica aunque `_collect` sea invocado varias veces o el enemigo emita más de un evento de muerte.
- Cada partida nueva limpia contadores, fuentes de loot, inventario de combate y los pickups de la partida anterior.

### Sistemas preservados
Lila con cabello lavanda y traje Aurora, soporte de AR-7/AWM, curación 3D/animación `AuroraHeal`, ADS y cámara, salto, avión/paracaídas, navegación, IA que se cura y recarga, ring de zona, lobby/guardado y Firebase. La etapa de **pulido profundo de animaciones** se pospone conforme a la instrucción del usuario; no se editó el Blender ni el sistema de esqueleto.

## 20 criterios de aceptación
1. La escena `Main.tscn` conserva enemigos reales `CharacterBody3D`.
2. Un bot de siete balas suelta siete, no 45.
3. Una caja de 12 balas muestra «x12» dentro del mundo.
4. El jugador recibe exactamente el número permitido de balas de la caja.
5. El bot con 0 balas y un medkit puede dejar dicho medkit.
6. La muerte IA contra IA crea botín real sin atribuir baja al jugador.
7. Las cajas no se generan fuera de la zona segura.
8. El bot con 0 balas y 0 medkits no crea una recompensa.
9. La misma víctima no crea cajas duplicadas.
10. Cada tercera baja del jugador puede priorizar un medkit existente.
11. El bot que ya usó el botiquín no recupera uno al morir.
12. El número de municiones se limita al cargador máximo real del bot.
13. Una mochila llena impide consumir munición no transportable.
14. Una reserva de botiquines llena no destruye una caja pendiente.
15. Cuando queda espacio, se puede recoger dicha caja.
16. El botín de casas y mapa conserva las cantidades históricas.
17. La AWM física no se transforma en arma gratuita ni en pólvora.
18. `loot_collected` y `opponent_caches_collected` proceden de colecciones reales.
19. Reiniciar una partida limpia cajas, municiones y estadísticas anteriores.
20. La suite completa (nativa/exportada de Android Vulkan) debe pasar antes de aprobar.

## Validación implementada
`v7564_opponent_inventory_loot_qa.gd` instancia las escenas y personajes reales, verifica cantidades, señales de bajas, munición, botiquines, reintento de caja llena, QR de botín, límites y reinicio. La CI exige la firma del APK, ARM64 y el marcador `V7564_REAL_OPPONENT_LOOT PASS` en la exportación.

**Pendiente de la versión:** completar visualmente las cajas, inteligencia de enemigos para saquear, múltiples armas originales adicionales, sistema online autoritativo de 50 jugadores humanos y otras metas del backlog de 1.000 tickets. No se declara «Battle Royale final» por aprobar un solo bloque.
