extends Node3D
## Small offline Aurora sector elimination match. NOT a 100-player/server match.
## Owns the real shrinking hazard, alive counter, victory/defeat and sector loot.

signal round_ended(victory: bool)

const LOOT = preload("res://scripts/match/aurora_loot.gd")
const ZONE_VISUAL = preload("res://scripts/match/aurora_zone_visual.gd")
const DROP_SEQUENCE = preload("res://scripts/match/airdrop_sequence.gd")
const MATCH_RECORDS = preload("res://scripts/persistence/offline_match_records.gd")
const INITIAL_RADIUS: float = 112.0
const FINAL_RADIUS: float = 12.0
const SHRINK_DURATION: float = 280.0
const CENTER: Vector2 = Vector2(0.0,-24.0)
const TICK: float = 1.0
const PHASE_COUNT: int=4
const PHASE_SECONDS: float=SHRINK_DURATION/float(PHASE_COUNT)
const PHASE_HOLD_SECONDS: float=12.0
const PHASE_RADII: Array[float]=[INITIAL_RADIUS,84.0,53.0,28.0,FINAL_RADIUS]

var player: CharacterBody3D
var combat: Node3D
var terrain: StaticBody3D
var hud: CanvasLayer
var mode: String = "training"
var match_ended: bool = false
var elapsed: float = 0.0
var radius: float = INITIAL_RADIUS
var zone_phase: int=0
var zone_seconds_remaining: int=0
var _damage_clock: float = 0.0
var _ui_clock: float = 0.0
var _loot: Array[Area3D] = []
var _zone_visual: Node3D
var _flight: Node3D
var _aircraft_paused_navigation: bool=false
var _records: RefCounted
var _match_id: int=0
var last_match_saved: bool=false
var _pending_result: Dictionary={}
var _save_clock: float=0.0


func _ready() -> void:
    _records=MATCH_RECORDS.new()
    _zone_visual=ZONE_VISUAL.new()
    _zone_visual.name="AuroraClosingZone"
    _zone_visual.terrain=terrain
    _zone_visual.world_center=CENTER
    add_child(_zone_visual)
    _zone_visual.visible=false
    _flight=DROP_SEQUENCE.new()
    _flight.name="AuroraDeployment"
    _flight.player=player
    _flight.terrain=terrain
    _flight.hud=hud
    add_child(_flight)
    _flight.touchdown.connect(_on_airdrop_landed)
    player.landed_from_airdrop.connect(_flight.landed)
    hud.jump_pressed.connect(_flight.request_jump_or_parachute)
    hud.start_battle_requested.connect(begin_aircraft_phase)
    player.player_eliminated.connect(_on_player_eliminated)
    hud.set_sector_state("ENTRENAMIENTO",4,0.0,0)
    hud.set_battle_button("INICIAR BR")


func begin_aircraft_phase() -> void:
    if not retry_result():
        return
    if mode=="aircraft" or mode=="freefall" or mode=="parachute":
        return
    if not _ready_for_round():
        return
    combat.end_sector_battle()
    # There is no ground combat or pathfinding in the aircraft. Do not keep
    # the animated bot world, 3D gun rigs or navigation shape sweeps running
    # while the renderer is still preparing the full island on Android.
    var nav: Node3D=combat.get("navigation") as Node3D
    _aircraft_paused_navigation=nav!=null and nav.is_physics_processing()
    if _aircraft_paused_navigation:
        nav.set_physics_process(false)
    # Preserve CollisionObject3D membership in PhysicsServer. Disabling the
    # whole node's process_mode removes child bodies from the physics space
    # and causes "body->get_space() is null" in existing movement tests.
    combat.set_process(false)
    combat.visible=false
    hud.reset_controls()
    mode="aircraft"
    match_ended=false
    hud.clear_match_result()
    hud.set_battle_button("DESPLIEGUE")
    hud.set_sector_state("AERONAVE / AURORA",9,INITIAL_RADIUS,0)
    _flight.begin()


func _on_airdrop_landed() -> void:
    if mode!="aircraft":
        return
    start_sector_battle(true)


func start_sector_battle(from_airdrop: bool=false) -> void:
    if not retry_result() or not _ready_for_round():
        return
    # A repeatable elimination round, not an endless training target spawner.
    for old in _loot:
        if is_instance_valid(old):
            old.queue_free()
    _loot.clear()
    mode = "sector_battle"
    match_ended = false
    # Restore combat and navigation BEFORE spawning/enabling any bots.
    combat.visible=true
    combat.set_process(true)
    var nav: Node3D=combat.get("navigation") as Node3D
    if nav!=null and _aircraft_paused_navigation:
        nav.set_physics_process(true)
    _aircraft_paused_navigation=false
    # One unique completed match ID is committed only after actual victory
    # or defeat. Abandoning a round does not fabricate completed statistics.
    _match_id=_records.next_match_id()
    last_match_saved=false
    elapsed = 0.0
    radius = INITIAL_RADIUS
    zone_phase=0
    zone_seconds_remaining=int(PHASE_SECONDS)
    _zone_visual.visible=true
    _zone_visual.set_safe_radius(radius,true)
    hud.set_sector_zone(CENTER,radius)
    _damage_clock=0.0
    _ui_clock=0.0
    player.begin_sector_battle(from_airdrop)
    combat.begin_sector_battle()
    # The previous round can end with a 12 m radius. Reset every bot's
    # strategic radius NOW, before its next physics tick, rather than
    # allowing stale values to drive several escape/cover decisions.
    _sync_bot_safe_zone()
    hud.clear_match_result()
    hud.reset_controls()
    hud.set_match_controls(true)
    _spawn_loot()
    hud.set_battle_button("EN PARTIDA")
    hud.set_sector_state("BATALLA SECTOR",combat.active_fighter_count(),radius,0)
    hud.impact("BATALLA AURORA / SOLO - "+str(combat.active_fighter_count())+" PARTICIPANTES")


func _ready_for_round() -> bool:
    if not _records.reload() or not _records.retry_pending():
        hud.impact("REGISTRO LOCAL PENDIENTE DE RECUPERAR")
        return false
    return true


func _process(delta: float) -> void:
    if match_ended and not last_match_saved:
        _save_clock-=delta
        if _save_clock<=0.0:
            _save_clock=1.0
            retry_result()
    if mode != "sector_battle" or match_ended:
        return
    elapsed += delta
    var state: Dictionary=zone_state_at(elapsed)
    radius=float(state["radius"])
    zone_phase=int(state["phase"])
    zone_seconds_remaining=int(state["remaining"])
    _zone_visual.set_safe_radius(radius)
    # Bot hazard decisions are made in physics; they must never lag behind
    # the actual damaging ring just because HUD updates are rate-limited.
    _sync_bot_safe_zone()
    _ui_clock-=delta
    if _ui_clock<=0:
        _ui_clock=.33
        hud.set_sector_zone(CENTER,radius)
        var status: String="ZONA FINAL" if zone_phase>=PHASE_COUNT else             "ZONA %d/%d · %ds"%[zone_phase+1,PHASE_COUNT,zone_seconds_remaining]
        hud.set_sector_state(status,combat.active_fighter_count(),radius,int(elapsed))
    _damage_clock+=delta
    if _damage_clock>=TICK:
        _damage_clock-=TICK
        _check_hazard_damage()
    if player.royale_eliminated:
        _finish(false)
    elif combat.active_fighter_count()==1:
        _finish(true)


func _sync_bot_safe_zone() -> void:
    for bot in combat._targets:
        if is_instance_valid(bot) and bot.health>0:
            bot.safe_center=CENTER
            bot.safe_radius=radius


## Four actual scheduled storm phases, beginning wide enough to cover both
## new north-coast entrance ramps. Each has a short stable loot window,
## followed by a smooth contraction, then a tighter damage/visibility stage.
## Radar, terrain ring and hazard radius all read the same returned radius.
func zone_state_at(seconds: float) -> Dictionary:
    var time: float=clampf(seconds,0.0,SHRINK_DURATION)
    if time>=SHRINK_DURATION:
        return {"radius":FINAL_RADIUS,"phase":PHASE_COUNT,"remaining":0}
    var phase: int=clampi(int(floor(time/PHASE_SECONDS)),0,PHASE_COUNT-1)
    var within: float=time-float(phase)*PHASE_SECONDS
    var progress: float=clampf((within-PHASE_HOLD_SECONDS)/
        (PHASE_SECONDS-PHASE_HOLD_SECONDS),0.0,1.0)
    var eased: float=progress*progress*(3.0-2.0*progress)
    return {
        "radius":lerpf(PHASE_RADII[phase],PHASE_RADII[phase+1],eased),
        "phase":phase,
        "remaining":maxi(0,int(ceil(PHASE_SECONDS-within)))
    }


func is_outside_zone(position: Vector3) -> bool:
    return Vector2(position.x,position.z).distance_to(CENTER)>radius


func _check_hazard_damage() -> void:
    var damage: float=6.0 if zone_phase<=0 else 8.0 if zone_phase==1         else 10.0 if zone_phase==2 else 13.0
    if not player.royale_eliminated and is_outside_zone(player.global_position):
        player.receive_training_hit(damage,true)
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
    combat.end_sector_battle()
    player.end_sector_battle()
    hud.reset_controls()
    hud.set_match_controls(false)
    _pending_result={"id":_match_id,"victory":victory,"kills":combat.eliminations,"seconds":int(elapsed)}
    retry_result()
    hud.set_sector_state("VICTORIA AURORA" if victory else "ELIMINADA / AURORA", combat.active_fighter_count(),radius,int(elapsed))
    hud.set_battle_button("REINICIAR BR")
    hud.show_match_result(victory,combat.eliminations,int(elapsed))
    hud.impact(("¡VICTORIA DEL SECTOR!" if victory else "PARTIDA TERMINADA / REINTENTAR") if last_match_saved else "ALERTA: NO SE GUARDO EL RESULTADO")
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
        "cover_charge","ammo_ar","medkit","ammo_awm",
        "ammo_ar","medkit","ammo_ar","cover_charge"]
    for i in range(spots.size()):
        _make_pickup(spots[i],categories[i],"AuroraLoot"+str(i+1))
    # Preserve the original 16 outdoor pickups, plus one true AWM pickup
    # at the west-quay pedestrian approach. It unlocks the second weapon slot.
    _make_pickup(Vector2(-47,54),"weapon_awm","AuroraAWMWeaponPickup")
    # Furnished villas add eight indoor supplies. Their height
    # follows the raised indoor floor, not the terrain underneath a villa.
    var coastal: Node3D=get_parent().get_node_or_null(
        "PuertoAuroraCoastalQuarter") as Node3D
    if coastal!=null:
        var interior: Array[Vector3]=coastal.interior_supply_spots
        var indoor_types: Array[String]=[
            "medkit","ammo_ar","ammo_awm",
            "cover_charge","medkit","ammo_ar",
            "armor_plate","backpack"]
        for i in range(interior.size()):
            var at: Vector3=interior[i]
            _make_pickup(Vector2(at.x,at.z),indoor_types[i%indoor_types.size()],
                "AuroraInteriorLoot"+str(i+1),at.y)


func _make_pickup(at: Vector2,kind: String,pickup_name: String,
        floor_height: float=NAN) -> void:
    var pickup: Area3D=LOOT.new()
    pickup.name=pickup_name
    pickup.pickup_type=kind
    pickup.player=player
    pickup.combat=combat
    pickup.terrain=terrain
    pickup.world_spot=at
    pickup.surface_height_override=floor_height
    add_child(pickup)
    _loot.append(pickup)


func get_loot_remaining() -> int:
    var count: int = 0
    for pickup in _loot:
        if is_instance_valid(pickup) and not pickup.collected:
            count += 1
    return count

func retry_result() -> bool:
    if _pending_result.is_empty():
        return true
    var result: Dictionary=_pending_result
    if not _records.retry_pending():
        hud.impact("GUARDADO PENDIENTE / REINTENTANDO")
        return false
    if _records.next_match_id()<=int(result.id):
        last_match_saved=_records.record_result(int(result.id),bool(result.victory),int(result.kills),int(result.seconds))
    else:
        last_match_saved=true
    if last_match_saved:
        _pending_result.clear()
        hud.impact("RESULTADO GUARDADO")
    else:
        hud.impact("GUARDADO PENDIENTE / REINTENTANDO")
    return last_match_saved
