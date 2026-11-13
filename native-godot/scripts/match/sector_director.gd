extends Node3D
## Small offline Aurora sector elimination match. NOT a 100-player/server match.
## Owns the real shrinking hazard, alive counter, victory/defeat and sector loot.

signal round_ended(victory: bool)

const LOOT = preload("res://scripts/match/aurora_loot.gd")
const ZONE_VISUAL = preload("res://scripts/match/aurora_zone_visual.gd")
const DROP_SEQUENCE = preload("res://scripts/match/airdrop_sequence.gd")
const MATCH_RECORDS = preload("res://scripts/persistence/offline_match_records.gd")
const PERFORMANCE=preload("res://scripts/persistence/aurora_performance_report.gd")
const INITIAL_RADIUS: float = 112.0
const FINAL_RADIUS: float = 12.0
const SHRINK_DURATION: float = 280.0
const CENTER: Vector2 = Vector2(0.0,-24.0)
const TICK: float = 1.0
# Max 15 minutes of sparse FPS samples at two measurements per second.
const MAX_PERF_SAMPLES: int=1800
# Physical supplies from actual combat eliminations, capped for mobile GPU/CPU.
const MAX_OPPONENT_DROPS: int=12
const PHASE_COUNT: int=4
const PHASE_SECONDS: float=SHRINK_DURATION/float(PHASE_COUNT)
const PHASE_HOLD_SECONDS: float=12.0
const PHASE_RADII: Array[float]=[INITIAL_RADIUS,84.0,53.0,28.0,FINAL_RADIUS]
# Physically accessible supply coordinates on the established Aurora island.
# Three supplies maximum, introduced only as the existing ring contracts.
const RESUPPLY_SITES: Array[Vector2]=[
    Vector2(8.0,-6.0),Vector2(-11.0,-17.0),Vector2(5.0,-35.0)]
const RESUPPLY_TYPES: Array[String]=["ammo_ar","armor_plate","medkit"]

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
var _perf_clock: float=0.0
var _perf_samples: Array[float]=[]
var _opponent_drops_spawned: int=0
var _dropped_opponents: Dictionary={}
var _phase_supplies: Dictionary={}
var _was_player_outside: bool=false
var _zone_entries: int=0


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
    combat.bot_eliminated.connect(_on_opponent_eliminated)
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
    hud.set_zone_threat(false,0.0)
    mode="aircraft"
    match_ended=false
    hud.clear_match_result()
    hud.set_battle_button("DESPLIEGUE")
    hud.set_sector_state("AERONAVE / AURORA",int(combat.get("encounter_size")),INITIAL_RADIUS,0)
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
    _perf_clock=0.0
    _perf_samples.clear()
    _opponent_drops_spawned=0
    _dropped_opponents.clear()
    _phase_supplies.clear()
    _was_player_outside=false
    _zone_entries=0
    hud.set_zone_threat(false,0.0)
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
    hud.impact("BATALLA AURORA · 1 JUGADOR + "+
        str(combat.active_fighter_count()-1)+" IA · OFFLINE")


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
    # Sample measured hardware FPS twice per second. Store only at the
    # actual match end, avoiding file writes during interactive combat.
    _perf_clock-=delta
    if _perf_clock<=0.0:
        _perf_clock=.5
        if DisplayServer.get_name()!="headless":
            var fps: float=float(Engine.get_frames_per_second())
            if is_finite(fps) and fps>0.0 and fps<360.0 and _perf_samples.size()<MAX_PERF_SAMPLES:
                _perf_samples.append(fps)
    var state: Dictionary=zone_state_at(elapsed)
    radius=float(state["radius"])
    zone_phase=int(state["phase"])
    zone_seconds_remaining=int(state["remaining"])
    if zone_phase>=1 and zone_phase<=3 and not _phase_supplies.has(zone_phase):
        _spawn_phase_resupply(zone_phase)
    _zone_visual.set_safe_radius(radius)
    # Bot hazard decisions are made in physics; they must never lag behind
    # the actual damaging ring just because HUD updates are rate-limited.
    _sync_bot_safe_zone()
    _ui_clock-=delta
    if _ui_clock<=0:
        _ui_clock=.33
        var radial_distance: float=Vector2(player.global_position.x,
            player.global_position.z).distance_to(CENTER)
        var outside: bool=not player.royale_eliminated and
            radial_distance>radius
        hud.set_zone_threat(outside,maxf(0.0,radial_distance-radius))
        if outside and not _was_player_outside:
            _zone_entries+=1
            hud.impact("ZONA PELIGROSA / REGRESA AL CIRCULO")
        _was_player_outside=outside
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


## Battle-generated loot is another real Area3D supply, not a fake
## reward message. The same collection/collision/slot limits apply as
## indoors. At most three extra caches are created in one match.
func _spawn_phase_resupply(phase: int) -> void:
    if mode!="sector_battle" or match_ended or phase<1 or phase>3:
        return
    if _phase_supplies.has(phase):
        return
    _phase_supplies[phase]=true
    var at: Vector2=RESUPPLY_SITES[phase-1]
    var kind: String=RESUPPLY_TYPES[phase-1]
    if not is_outside_zone(Vector3(at.x,0.0,at.y)):
        _make_pickup(at,kind,"AuroraPhaseSupply"+str(phase))
        hud.impact("SUMINISTROS AURORA / FASE "+str(phase))


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
        # Continuous proximity warning already exists; avoid overwriting
        # hit confirmations and weapon cues every single damage tick.
        player.receive_training_hit(damage,true)
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
    if _perf_samples.size()>2:
        var result: Error=PERFORMANCE.record(
            int(combat.get("encounter_size")),_perf_samples,elapsed,true)
        if result!=OK:
            push_warning("Aurora measured FPS report could not be persisted")
    combat.end_sector_battle()
    player.end_sector_battle()
    hud.reset_controls()
    hud.set_match_controls(false)
    hud.set_zone_threat(false,0.0)
    _pending_result={"id":_match_id,"victory":victory,"kills":combat.eliminations,"seconds":int(elapsed)}
    retry_result()
    hud.set_sector_state("VICTORIA AURORA" if victory else "ELIMINADA / AURORA", combat.active_fighter_count(),radius,int(elapsed))
    hud.set_battle_button("REINICIAR BR")
    # Final rank uses the real surviving CharacterBody3D roster, not
    # fabricated network participants or simulated match telemetry.
    var participants: int=int(combat.get("encounter_size"))
    var rank: int=1 if victory else clampi(combat.active_fighter_count()+1,2,participants)
    hud.show_match_result(victory,combat.eliminations,int(elapsed),rank,
        participants,roundi(float(combat.get("damage_dealt"))),
        int(combat.get("loot_collected")),combat.shot_accuracy_percent())
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
    # The sniper was on a remote west-quay approach and was routinely
    # missed in physical Motorola tests. Its ONE real physical pickup now
    # sits in the accessible central plaza, marked on the large map.
    # Do not grant the gun directly: BR still requires actual collection.
    _make_pickup(Vector2(8,24),"weapon_awm","AuroraAWMWeaponPickup")
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


## Loot is produced by an actual CharacterBody3D death, never by fake
## timers or respawn counters. One cache per victim per round, at most 12
## active additions to keep collision and draw costs bounded on Motorola.
func _on_opponent_eliminated(victim: CharacterBody3D,killer: Node3D) -> void:
    if mode!="sector_battle" or match_ended or not combat.sector_battle_active:
        return
    if not is_instance_valid(victim):
        return
    var victim_id: int=victim.get_instance_id()
    if _dropped_opponents.has(victim_id):
        return
    _dropped_opponents[victim_id]=true
    var position: Vector3=victim.global_position
    if not position.is_finite() or is_outside_zone(position):
        return
    if _opponent_drops_spawned>=MAX_OPPONENT_DROPS:
        return
    _opponent_drops_spawned+=1
    # Rewards come from real combat. Player eliminations favor supplies,
    # while AI-on-AI kills may still leave usable ammunition in the world.
    var kind: String="ammo_ar"
    if killer==player:
        kind="medkit" if _opponent_drops_spawned%3==0 else "ammo_ar"
    elif _opponent_drops_spawned%4==0:
        kind="armor_plate"
    var at:=Vector2(position.x,position.z)
    var ground_y: float=float(terrain.height_at(at.x,at.y))
    # Keep loot on a raised walkable deck when the bot died inside a villa,
    # and never float a cache below the current physical standing surface.
    var surface_y: float=maxf(ground_y,position.y-.15)
    _make_pickup(at,kind,"AuroraOpponentLoot"+str(_opponent_drops_spawned),surface_y,true)


func _historic_floor_at(at: Vector2) -> float:
    # Some of the original 16 "outdoor" coordinates overlap an older house
    # (notably the AWM rounds in CENTRO DE EXPLORACION). If so, use the
    # REAL raised InteriorDeck top; never bury a pickup in the terrain below.
    var district: Node3D=get_parent().get_node_or_null("PuertoAuroraSector") as Node3D
    if district==null:
        return NAN
    var sites: Array[Vector4]=[
        Vector4(18,-8,16,12),Vector4(-19,-29,14,11),
        Vector4(46,-36,11,10),Vector4(-48,22,12,12)]
    var names: Array[String]=[
        "CENTRO_DE_EXPLORACION","TALLER_HELIOS",
        "ESTACION_METEOROLOGICA","PUESTO_VORTEX"]
    for index in range(sites.size()):
        var site: Vector4=sites[index]
        if absf(at.x-site.x)<site.z*.5-.8 and             absf(at.y-site.y)<site.w*.5-.8:
            var house: Node3D=district.get_node_or_null(names[index]) as Node3D
            if house!=null:
                return house.global_position.y+.10
    return NAN


func _make_pickup(at: Vector2,kind: String,pickup_name: String,
        floor_height: float=NAN,from_opponent: bool=false) -> void:
    if not is_finite(floor_height):
        floor_height=_historic_floor_at(at)
    var pickup: Area3D=LOOT.new()
    pickup.name=pickup_name
    pickup.pickup_type=kind
    pickup.from_opponent=from_opponent
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
