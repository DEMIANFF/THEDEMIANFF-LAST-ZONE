extends Node3D
## Small offline Aurora sector elimination match. NOT a 100-player/server match.
## Owns the real shrinking hazard, alive counter, victory/defeat and sector loot.

signal round_ended(victory: bool)

const LOOT = preload("res://scripts/match/aurora_loot.gd")
const ZONE_VISUAL = preload("res://scripts/match/aurora_zone_visual.gd")
const INITIAL_RADIUS: float = 90.0
const FINAL_RADIUS: float = 12.0
const SHRINK_DURATION: float = 280.0
const CENTER: Vector2 = Vector2(0.0,-24.0)
const TICK: float = 1.0

var player: CharacterBody3D
var combat: Node3D
var terrain: StaticBody3D
var hud: CanvasLayer
var mode: String = "training"
var match_ended: bool = false
var elapsed: float = 0.0
var radius: float = INITIAL_RADIUS
var _damage_clock: float = 0.0
var _ui_clock: float = 0.0
var _loot: Array[Area3D] = []
var _zone_visual: Node3D


func _ready() -> void:
    _zone_visual=ZONE_VISUAL.new()
    _zone_visual.name="AuroraClosingZone"
    _zone_visual.terrain=terrain
    _zone_visual.world_center=CENTER
    add_child(_zone_visual)
    _zone_visual.visible=false
    hud.start_battle_requested.connect(start_sector_battle)
    player.player_eliminated.connect(_on_player_eliminated)
    hud.set_sector_state("ENTRENAMIENTO",4,0.0,0)
    hud.set_battle_button("INICIAR BR")


func start_sector_battle() -> void:
    # A repeatable elimination round, not an endless training target spawner.
    for old in _loot:
        if is_instance_valid(old):
            old.queue_free()
    _loot.clear()
    mode = "sector_battle"
    match_ended = false
    elapsed = 0.0
    radius = INITIAL_RADIUS
    _zone_visual.visible=true
    _zone_visual.set_safe_radius(radius,true)
    hud.set_sector_zone(CENTER,radius)
    _damage_clock=0.0
    _ui_clock=0.0
    player.begin_sector_battle()
    combat.begin_sector_battle()
    hud.clear_match_result()
    _spawn_loot()
    hud.set_battle_button("EN PARTIDA")
    hud.set_sector_state("BATALLA SECTOR",combat.active_fighter_count(),radius,0)
    hud.impact("BATALLA AURORA / SOLO - "+str(combat.active_fighter_count())+" PARTICIPANTES")


func _process(delta: float) -> void:
    if mode != "sector_battle" or match_ended:
        return
    elapsed += delta
    var progress: float = clampf(elapsed/SHRINK_DURATION,0.0,1.0)
    radius = lerpf(INITIAL_RADIUS,FINAL_RADIUS,pow(progress,1.13))
    _zone_visual.set_safe_radius(radius)
    _ui_clock-=delta
    if _ui_clock<=0:
        _ui_clock=.33
        hud.set_sector_zone(CENTER,radius)
        hud.set_sector_state("ZONA EN CIERRE",combat.active_fighter_count(),radius,int(elapsed))
    _damage_clock+=delta
    if _damage_clock>=TICK:
        _damage_clock-=TICK
        _check_hazard_damage()
    if player.royale_eliminated:
        _finish(false)
    elif combat.active_fighter_count()==1:
        _finish(true)


func is_outside_zone(position: Vector3) -> bool:
    return Vector2(position.x,position.z).distance_to(CENTER)>radius


func _check_hazard_damage() -> void:
    var damage: float=6.0 if elapsed < SHRINK_DURATION*.58 else 11.0
    if not player.royale_eliminated and is_outside_zone(player.global_position):
        player.receive_training_hit(damage)
        hud.impact("ZONA AURORA / VUELVE AL CIRCULO")
    for actor in combat._targets:
        if is_instance_valid(actor) and actor.health>0 and is_outside_zone(actor.global_position):
            actor.take_training_damage(damage)


func _on_player_eliminated() -> void:
    if mode=="sector_battle" and not match_ended:
        _finish(false)


func _finish(victory: bool) -> void:
    if match_ended:
        return
    match_ended = true
    hud.set_sector_state("VICTORIA AURORA" if victory else "ELIMINADA / AURORA", combat.active_fighter_count(),radius,int(elapsed))
    hud.set_battle_button("REINICIAR BR")
    hud.show_match_result(victory,combat.eliminations,int(elapsed))
    hud.impact("¡VICTORIA DEL SECTOR!" if victory else "PARTIDA TERMINADA / REINTENTAR")
    round_ended.emit(victory)


func _spawn_loot() -> void:
    var spots: Array[Vector2] = [
        Vector2(6,-7),Vector2(-9,-18),Vector2(19,-11),Vector2(-27,-15),
        Vector2(-7,-38),Vector2(35,-34),Vector2(41,15),Vector2(-43,9),
        Vector2(20,34),Vector2(-57,-36),Vector2(53,-61),Vector2(0,-71),
        Vector2(65,8),Vector2(-33,-62),Vector2(12,63),Vector2(49,43)]
    var categories: Array[String]=[
        "ammo_ar","medkit","ammo_awm","ammo_ar",
        "medkit","ammo_ar","ammo_awm","medkit",
        "ammo_ar","ammo_ar","medkit","ammo_awm",
        "ammo_ar","medkit","ammo_ar","ammo_awm"]
    for i in range(spots.size()):
        var pickup: Area3D=LOOT.new()
        pickup.name="AuroraLoot"+str(i+1)
        pickup.pickup_type=categories[i]
        pickup.player=player
        pickup.combat=combat
        pickup.terrain=terrain
        pickup.world_spot=spots[i]
        add_child(pickup)
        _loot.append(pickup)


func get_loot_remaining() -> int:
    var count: int = 0
    for pickup in _loot:
        if is_instance_valid(pickup) and not pickup.collected:
            count += 1
    return count
