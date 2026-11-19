extends Node3D
## Real 50-participant offline Aurora elimination round; only internal QA scales smaller.
## This is not networked multiplayer or a 100-player server match.
## Owns the real shrinking hazard, alive counter, victory/defeat and sector loot.

signal round_ended(victory: bool)
signal aircraft_audio_changed(active: bool)

const LOOT = preload("res://scripts/match/aurora_loot.gd")
const ZONE_VISUAL = preload("res://scripts/match/aurora_zone_visual.gd")
const DROP_SEQUENCE = preload("res://scripts/match/airdrop_sequence.gd")
const COMBAT_ROSTER=preload("res://scripts/combat/training_combat.gd")
const WEAPONS=preload("res://scripts/combat/aurora_weapon_catalog.gd")
const DRIVEABLE_VEHICLE=preload("res://scripts/world/aurora_driveable_vehicle.gd")
const MATCH_RECORDS = preload("res://scripts/persistence/offline_match_records.gd")
const PERFORMANCE=preload("res://scripts/persistence/aurora_performance_report.gd")
const INITIAL_RADIUS: float = 205.0
const FINAL_RADIUS: float = 12.0
# Four phases total ten minutes rather than the previous 4m40s.
# Early victories remain possible when all physical enemies are eliminated.
const SHRINK_DURATION: float = 600.0
# After the four normal phases, the physical last circle closes during
# a 60-second final combat window, rather than remaining at 12m forever.
const OVERTIME_DURATION: float = 60.0
const OVERTIME_RADIUS: float = 0.75
const CENTER: Vector2 = Vector2(0.0,-24.0)
const TICK: float = 1.0
# Max 15 minutes of sparse FPS samples at two measurements per second.
const MAX_PERF_SAMPLES: int=1800
# Physical supplies from actual combat eliminations, capped for mobile GPU/CPU.
const MAX_OPPONENT_DROPS: int=12
const PHASE_COUNT: int=4
const PHASE_SECONDS: float=SHRINK_DURATION/float(PHASE_COUNT)
const PHASE_HOLD_SECONDS: float=24.0
const PHASE_RADII: Array[float]=[INITIAL_RADIUS,155.0,105.0,54.0,FINAL_RADIUS]
# Per-phase center shift stays strictly inside the radius loss. Every new
# circle is enclosed by the last one, including during interpolation.
const ZONE_CENTER_PROGRESS: Array[float]=[0.0,.40,.70,.88,1.0]
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
var zone_center: Vector2=CENTER
var _phase_centers: Array[Vector2]=[]
var zone_phase: int=0
var zone_seconds_remaining: int=0
var _damage_clock: float = 0.0
var _ui_clock: float = 0.0
var _loot: Array[Area3D] = []
var _driveable_cars: Array[AuroraDriveableVehicle]=[]
var _vehicle_ui_clock: float=0.0
var _zone_visual: Node3D
var _flight: Node3D
var _aircraft_paused_navigation: bool=false
var _rivals_departed: bool=false
var _rival_jump_elapsed: float=0.0
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
    _flight.aircraft_audio_changed.connect(aircraft_audio_changed.emit)
    _flight.rival_airdrop_started.connect(_on_rival_airdrop_started)
    player.landed_from_airdrop.connect(_flight.landed)
    hud.jump_pressed.connect(_flight.request_jump_or_parachute)
    hud.start_battle_requested.connect(begin_aircraft_phase)
    hud.vehicle_action_requested.connect(_on_real_vehicle_action)
    player.player_eliminated.connect(_on_player_eliminated)
    combat.bot_eliminated.connect(_on_opponent_eliminated)
    combat.bot_shot.connect(_on_rival_gunfire)
    hud.set_sector_state("ENTRENAMIENTO",4,0.0,0)
    hud.set_battle_button("INICIAR BR")


func begin_aircraft_phase() -> void:
    if not retry_result():
        return
    if mode=="aircraft" or mode=="freefall" or mode=="parachute":
        return
    if not _ready_for_round():
        return
    # Every player-accessible deployment (including Training HUD -> BR)
    # uses the SAME 50-person classic roster, without any difficulty menu.
    _remove_driveable_vehicles()
    combat.set_encounter_size(COMBAT_ROSTER.CLASSIC_BR_PARTICIPANTS)
    combat.end_sector_battle()
    _rivals_departed=false
    _rival_jump_elapsed=0.0
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
    hud.set_radar_battle_mode(true)
    hud.clear_match_result()
    hud.set_battle_button("DESPLIEGUE")
    hud.set_sector_state("AERONAVE / AURORA",int(combat.get("encounter_size")),INITIAL_RADIUS,0)
    _flight.begin()


## Stage a few REAL collidable combatants per frame during aircraft flight
## to avoid the original synchronous 41-rig jump/freefall crash.
func _stage_rival_airdrops(dt: float) -> void:
    if mode!="aircraft":
        return
    if combat._targets.size()<COMBAT_ROSTER.CLASSIC_BR_PARTICIPANTS-1:
        combat._ensure_encounter_capacity(3)
    if not _rivals_departed:
        return
    _rival_jump_elapsed+=maxf(0.0,dt)
    for i in range(combat._targets.size()):
        var rival: CharacterBody3D=combat._targets[i]
        if rival._airdrop_stage!="inactive":
            continue
        var progress: float=float(i)/float(COMBAT_ROSTER.CLASSIC_BR_PARTICIPANTS-2)
        var origin: Vector3=_flight._route_point(progress)
        origin.x+=float(i%5-2)*2.7
        origin.y-=3.0
        rival.begin_real_airdrop(origin,maxf(0.0,float(i)*.17-_rival_jump_elapsed))


func _on_rival_airdrop_started() -> void:
    if mode!="aircraft" or _rivals_departed:
        return
    _rivals_departed=true
    _rival_jump_elapsed=0.0
    combat.visible=true
    _stage_rival_airdrops(0.0)
    hud.impact("RIVALES SALTANDO / DESCENSO FISICO AURORA")


func _on_airdrop_landed() -> void:
    if mode!="aircraft":
        return
    if _rivals_departed:
        combat._ensure_encounter_capacity()
        _stage_rival_airdrops(0.0)
    start_sector_battle(true)


func start_sector_battle(from_airdrop: bool=false) -> void:
    if not retry_result() or not _ready_for_round():
        return
    aircraft_audio_changed.emit(false)
    # A repeatable elimination round, not an endless training target spawner.
    _remove_driveable_vehicles()
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
    _configure_zone_centers(_match_id)
    last_match_saved=false
    elapsed = 0.0
    radius = INITIAL_RADIUS
    zone_phase=0
    zone_seconds_remaining=int(PHASE_SECONDS)
    zone_center=CENTER
    _zone_visual.visible=true
    _zone_visual.set_zone_state(zone_center,radius,true)
    hud.set_radar_battle_mode(true)
    hud.set_sector_zone(zone_center,radius)
    hud.set_next_sector_zone(_zone_center_at(1),PHASE_RADII[1])
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
    combat.begin_sector_battle(from_airdrop and _rivals_departed)
    # The previous round can end with a 12 m radius. Reset every bot's
    # strategic radius NOW, before its next physics tick, rather than
    # allowing stale values to drive several escape/cover decisions.
    _sync_bot_safe_zone()
    hud.clear_match_result()
    hud.reset_controls()
    hud.set_match_controls(true)
    _spawn_loot()
    _spawn_authentic_vehicles()
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
    if mode=="aircraft":
        _stage_rival_airdrops(delta)
    if match_ended and not last_match_saved:
        _save_clock-=delta
        if _save_clock<=0.0:
            _save_clock=1.0
            retry_result()
    if mode != "sector_battle" or match_ended:
        return
    _vehicle_ui_clock-=delta
    if _vehicle_ui_clock<=0.0:
        _vehicle_ui_clock=.25
        var ride: AuroraDriveableVehicle=player._vehicle_ride
        if ride!=null and is_instance_valid(ride):
            hud.set_vehicle_context(false,true,ride.speed_kmh())
        else:
            hud.set_vehicle_context(_nearest_enterable_car()!=null,false,0.0)
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
    zone_center=state["center"]
    zone_phase=int(state["phase"])
    zone_seconds_remaining=int(state["remaining"])
    # A mobile resume can jump over multiple phase boundaries. Do not lose
    # phase transitions or create duplicate supplies after a large delta.
    for phase in range(1,mini(zone_phase,3)+1):
        if not _phase_supplies.has(phase):
            _spawn_phase_resupply(phase)
    _zone_visual.set_zone_state(zone_center,radius)
    # Bot hazard decisions are made in physics; they must never lag behind
    # the actual damaging ring just because HUD updates are rate-limited.
    _sync_bot_safe_zone()
    _ui_clock-=delta
    if _ui_clock<=0:
        _ui_clock=.33
        var radial_distance: float=Vector2(player.global_position.x,
            player.global_position.z).distance_to(zone_center)
        var outside: bool=(not player.royale_eliminated and
            radial_distance>radius)
        hud.set_zone_threat(outside,maxf(0.0,radial_distance-radius))
        if outside and not _was_player_outside:
            _zone_entries+=1
            hud.impact("ZONA PELIGROSA / REGRESA AL CIRCULO")
        _was_player_outside=outside
        hud.set_sector_zone(zone_center,radius)
        var next_phase: int=mini(zone_phase+1,PHASE_COUNT)
        var next_radius: float=(PHASE_RADII[next_phase]
            if zone_phase<PHASE_COUNT else OVERTIME_RADIUS)
        hud.set_next_sector_zone(_zone_center_at(next_phase),next_radius)
        var status: String=("CIERRE FINAL · %ds"%zone_seconds_remaining
            if zone_phase>=PHASE_COUNT and zone_seconds_remaining>0
            else "COMBATE FINAL / ZONA CERRADA" if zone_phase>=PHASE_COUNT
            else "ZONA %d/%d · %ds"%[
                zone_phase+1,PHASE_COUNT,zone_seconds_remaining])
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
    # A relocated storm must not silently cancel its physical phase loot:
    # search for a clear, reachable supply spot INSIDE the actual safe circle.
    if is_outside_zone(Vector3(at.x,0.0,at.y)) or not combat._is_clear_spawn(at):
        for attempt in range(32):
            var angle: float=float(phase)*2.399963+float(attempt)*2.399963
            var distance: float=minf(14.0,radius*.42)*(
                .28+float(attempt%7)*.10)
            var candidate: Vector2=zone_center+Vector2.from_angle(angle)*distance
            if (not is_outside_zone(Vector3(candidate.x,0.0,candidate.y)) and
                    combat._is_clear_spawn(candidate)):
                at=candidate
                break
    if (not is_outside_zone(Vector3(at.x,0.0,at.y)) and
            combat._is_clear_spawn(at)):
        _make_pickup(at,kind,"AuroraPhaseSupply"+str(phase))
        hud.impact("SUMINISTROS AURORA / FASE "+str(phase))


func _sync_bot_safe_zone() -> void:
    for bot in combat._targets:
        if is_instance_valid(bot) and bot.health>0:
            bot.safe_center=zone_center
            bot.safe_radius=radius
            # The destination is an actual later ring, not a fabricated
            # client waypoint. Disable advance rotation after phase four.
            bot.next_zone_active=zone_phase<PHASE_COUNT
            bot.zone_seconds_remaining=zone_seconds_remaining
            bot.next_safe_center=_zone_center_at(
                mini(zone_phase+1,PHASE_COUNT))
            bot.next_safe_radius=(PHASE_RADII[mini(zone_phase+1,PHASE_COUNT)]
                if zone_phase<PHASE_COUNT else OVERTIME_RADIUS)


## A new match has a seeded destination ON WALKABLE LAND instead of a
## permanently centered storm. Phase centers are deterministic for a match
## (debuggable with the persisted sequential match ID), not network users.
## The original seeded center shift remains inside the expanded phase losses.
func _configure_zone_centers(match_id: int) -> void:
    var random:=RandomNumberGenerator.new()
    random.seed=int(match_id)*9539+7588
    var destination: Vector2=CENTER
    for attempt in range(64):
        var angle: float=random.randf_range(0.0,TAU)
        var distance: float=random.randf_range(19.0,46.0)
        var candidate: Vector2=CENTER+Vector2.from_angle(angle)*distance
        if combat._is_clear_spawn(candidate):
            destination=candidate
            break
    if destination==CENTER:
        for candidate in RESUPPLY_SITES:
            if combat._is_clear_spawn(candidate):
                destination=candidate
                break
    _phase_centers.clear()
    for progress in ZONE_CENTER_PROGRESS:
        _phase_centers.append(CENTER.lerp(destination,progress))


func _zone_center_at(phase: int,progress: float=0.0) -> Vector2:
    if _phase_centers.size()!=PHASE_COUNT+1:
        return CENTER
    if phase>=PHASE_COUNT:
        return _phase_centers[PHASE_COUNT]
    return _phase_centers[phase].lerp(_phase_centers[phase+1],
        clampf(progress,0.0,1.0))


## Four actual scheduled storm phases, beginning wide enough to cover both
## new north-coast entrance ramps. Each has a short stable loot window,
## followed by a smooth contraction, then a tighter damage/visibility stage.
## Radar, terrain ring and hazard radius all read the same returned radius.
func zone_state_at(seconds: float) -> Dictionary:
    var time: float=clampf(seconds,0.0,SHRINK_DURATION)
    if seconds>=SHRINK_DURATION:
        var overtime: float=clampf(seconds-SHRINK_DURATION,
            0.0,OVERTIME_DURATION)
        var t: float=overtime/OVERTIME_DURATION
        var ease: float=t*t*(3.0-2.0*t)
        return {"radius":lerpf(FINAL_RADIUS,OVERTIME_RADIUS,ease),
            "center":_zone_center_at(PHASE_COUNT),
            "phase":PHASE_COUNT,
            "remaining":maxi(0,int(ceil(OVERTIME_DURATION-overtime)))}
    var phase: int=clampi(int(floor(time/PHASE_SECONDS)),0,PHASE_COUNT-1)
    var within: float=time-float(phase)*PHASE_SECONDS
    var progress: float=clampf((within-PHASE_HOLD_SECONDS)/
        (PHASE_SECONDS-PHASE_HOLD_SECONDS),0.0,1.0)
    var eased: float=progress*progress*(3.0-2.0*progress)
    return {
        "radius":lerpf(PHASE_RADII[phase],PHASE_RADII[phase+1],eased),
        "center":_zone_center_at(phase,eased),
        "phase":phase,
        "remaining":maxi(0,int(ceil(PHASE_SECONDS-within)))
    }


func is_outside_zone(position: Vector3) -> bool:
    return Vector2(position.x,position.z).distance_to(zone_center)>radius


func _check_hazard_damage() -> void:
    var damage: float=6.0 if zone_phase<=0 else 8.0 if zone_phase==1 else 10.0 if zone_phase==2 else 13.0
    if elapsed>=SHRINK_DURATION:
        # The terminal ring physically closes; late storm exposure is more
        # dangerous for both player and every surviving actual bot.
        damage=13.0+clampf(elapsed-SHRINK_DURATION,0.0,
            OVERTIME_DURATION)*.15
    if not player.royale_eliminated and is_outside_zone(player.global_position):
        # Continuous proximity warning already exists; avoid overwriting
        # hit confirmations and weapon cues every single damage tick.
        player.receive_training_hit(damage,true)
    for actor in combat._targets:
        if is_instance_valid(actor) and actor.health>0 and is_outside_zone(actor.global_position):
            actor.take_training_damage(damage)


func _on_rival_gunfire(at: Vector3) -> void:
    # Only physical shots from currently active enemies are audible.
    # Training, aircraft and completed matches never leak enemy positions.
    if mode=="sector_battle" and not match_ended:
        hud.note_enemy_gunfire(at)


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
    hud.clear_radar_gunfire()
    hud.set_zone_threat(false,0.0)
    # Rank and combat metrics must be captured BEFORE the atomic ledger
    # commit, not only drawn on a temporary results screen.
    var participants: int=int(combat.get("encounter_size"))
    var rank: int=1 if victory else clampi(combat.active_fighter_count()+1,2,participants)
    var extras: Dictionary={
        "rank":rank,
        "participants":participants,
        "damage":roundi(float(combat.get("damage_dealt"))),
        "accuracy":combat.shot_accuracy_percent(),
        "loot":int(combat.get("loot_collected")),
        "shots":int(combat.get("shots_fired_total")),
        "hits":int(combat.get("shots_hit_total")),
        "headshots":int(combat.get("headshots_total")),
        "reloads":int(combat.get("reloads_completed"))
    }
    _pending_result={
        "id":_match_id,"victory":victory,
        "kills":combat.eliminations,"seconds":int(elapsed),
        "extra":extras
    }
    retry_result()
    hud.set_sector_state("VICTORIA AURORA" if victory else "ELIMINADA / AURORA", combat.active_fighter_count(),radius,int(elapsed))
    hud.set_battle_button("REINICIAR BR")
    hud.show_match_result(victory,combat.eliminations,int(elapsed),rank,
        participants,int(extras["damage"]),int(extras["loot"]),
        int(extras["accuracy"]),int(extras["headshots"]))
    hud.impact(("¡VICTORIA DEL SECTOR!" if victory else "PARTIDA TERMINADA / REINTENTAR") if last_match_saved else "ALERTA: NO SE GUARDO EL RESULTADO")
    round_ended.emit(victory)


## Authored Toyota/BMW meshes are never fabricated. An unstaged private
## source produces no car, button or false functionality in the public APK.
func _spawn_authentic_vehicles() -> void:
    for details in [
        {"kind":"Toyota","site":Vector2(72,-6),"yaw":.20},
        {"kind":"BMW","site":Vector2(-66,-58),"yaw":-.65}
    ]:
        var kind: String=details["kind"]
        if not DRIVEABLE_VEHICLE.source_available(kind):
            continue
        var position2d: Vector2=details["site"]
        var height: float=float(terrain.height_at(position2d.x,position2d.y))
        if not is_finite(height):
            continue
        var car: AuroraDriveableVehicle=DRIVEABLE_VEHICLE.new()
        car.variant=kind
        car.terrain=terrain
        car.name="AuroraAuthentic"+kind+"Vehicle"
        car.position=Vector3(position2d.x,height+1.40,position2d.y)
        car.rotation.y=float(details["yaw"])
        add_child(car)
        _driveable_cars.append(car)
    hud.set_vehicle_context(false,false,0.0)


func _remove_driveable_vehicles() -> void:
    if player!=null and player.has_method("vehicle_ride_active") and (
            player.vehicle_ride_active()):
        player.force_vehicle_exit()
    for car in _driveable_cars:
        if is_instance_valid(car):
            car.queue_free()
    _driveable_cars.clear()
    if hud!=null:
        hud.set_vehicle_context(false,false,0.0)


func _nearest_enterable_car() -> AuroraDriveableVehicle:
    var closest: AuroraDriveableVehicle=null
    var distance: float=INF
    if player==null or not player.can_act():
        return null
    for car in _driveable_cars:
        if not is_instance_valid(car) or not car.can_enter(player):
            continue
        var gap: float=player.global_position.distance_to(car.global_position)
        if gap<distance:
            closest=car
            distance=gap
    return closest


func _on_real_vehicle_action() -> void:
    if mode!="sector_battle" or match_ended:
        return
    if player.vehicle_ride_active():
        var car: AuroraDriveableVehicle=player._vehicle_ride
        if car==null or not is_instance_valid(car):
            player.force_vehicle_exit()
            return
        if car.linear_velocity.length()>2.5:
            hud.impact("DETÉN EL VEHÍCULO ANTES DE BAJAR")
            return
        var landing: Vector3=car.exit_position(player)
        if not landing.is_finite():
            hud.impact("SALIDA BLOQUEADA / BUSCA SUELO SEGURO")
            return
        player.force_vehicle_exit(landing)
        hud.set_vehicle_context(true,false,0.0)
        hud.impact("VEHÍCULO ESTACIONADO")
        return
    var nearby: AuroraDriveableVehicle=_nearest_enterable_car()
    if nearby!=null and player.begin_vehicle_ride(nearby):
        hud.set_vehicle_context(false,true,nearby.speed_kmh())
        hud.impact("CONDUCCIÓN REAL / JOYSTICK: AVANZAR, GIRAR, RETROCEDER")


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
    if combat.encounter_size==50:
        _make_pickup(Vector2(42,-20),"weapon_scar","AuroraSCARPickup")
        _make_pickup(Vector2(30,9),"weapon_mp40","AuroraMP40Pickup")
        _make_pickup(Vector2(12,-13),"weapon_kriss","AuroraKRISSPickup")
        # Optional V2 pickups have physical weapons, inventory and ballistics.
        # Skip them until their CC-BY assets have actually been staged locally.
        var optional_weapons: Array[String]=[
            "weapon_hk416","weapon_p90","weapon_vss",
            "weapon_mp5","weapon_shotgun","weapon_magnum","weapon_knife","weapon_sniper"
        ]
        var optional_spots: Array[Vector2]=[
            Vector2(-18,34),Vector2(38,30),Vector2(-44,-42),
            Vector2(5,-42),Vector2(23,43),Vector2(-52,20),
            Vector2(39,-51),Vector2(-25,15)]
        for i in range(optional_weapons.size()):
            var slot: int=WEAPONS.pickup_slot(optional_weapons[i])
            if slot>=0 and ResourceLoader.exists(str(WEAPONS.ENTRIES[slot]["asset"])):
                _make_pickup(optional_spots[i],optional_weapons[i],
                    "AuroraV2Optional_"+str(WEAPONS.ENTRIES[slot]["short"]))
        _make_pickup(Vector2(-38,-12),"ammo_smg","AuroraSMGAmmoPickup")
        # Terrain-supported upgrade tiers; existing interior level-1 pack
        # stays exactly where it was for V75.117 player progression.
        _make_pickup(Vector2(30,25),"backpack_2","AuroraTacticalPackLevel2")
        _make_pickup(Vector2(-37,33),"backpack_3","AuroraTacticalPackLevel3")
        # Caliber-specific reload supplies for private optional models, with
        # no false pickup when the authored weapon resource is absent.
        if ResourceLoader.exists(str(WEAPONS.ENTRIES[WEAPONS.SHOTGUN]["asset"])):
            _make_pickup(Vector2(14,-55),"ammo_shells","AuroraShotgunShells")
        if ResourceLoader.exists(str(WEAPONS.ENTRIES[WEAPONS.MAGNUM]["asset"])):
            _make_pickup(Vector2(-50,-9),"ammo_pistol","AuroraMagnumRounds")
        _make_pickup(Vector2(-24,-31),"syringe","AuroraSyringePickup")
        _make_pickup(Vector2(16,-13),"grenade","AuroraGrenadePickup")
        var gear: Array[Vector2]=[Vector2(27,25),Vector2(32,25),
            Vector2(-34,30),Vector2(-39,33),Vector2(54,-33),Vector2(59,-33)]
        for i in range(gear.size()):
            var level: int=i/2+1
            var slot: String="vest" if i%2==0 else "helmet"
            var key: String="%s_%d"%[slot,level]
            _make_pickup(gear[i],key,"AuroraProtection"+str(i+1))
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


## A dead rival drops only what remains in that actual CharacterBody3D
## inventory; no "random" armor or unlimited ammo is created on death.
## The first player kill remains a physical ammo cache; every third player
## kill may award an unused field medkit, if the rival still owns one.
static func opponent_inventory_reward(rounds_loaded: int,medkits_owned: int,
        killed_by_player: bool,cache_index: int) -> Dictionary:
    var rounds: int=clampi(rounds_loaded,0,18)
    var kits: int=clampi(medkits_owned,0,1)
    if killed_by_player and cache_index%3==0 and kits>0:
        return {"kind":"medkit","quantity":kits}
    if rounds>0:
        return {"kind":"ammo_ar","quantity":rounds}
    if kits>0:
        return {"kind":"medkit","quantity":kits}
    return {}


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
    var supply: Dictionary=opponent_inventory_reward(
        int(victim.get("_magazine")),int(victim.get("_field_medkits")),
        killer==player,_opponent_drops_spawned+1)
    if supply.is_empty():
        return  # A rival with no ammo/medkit cannot create fictitious loot.
    _opponent_drops_spawned+=1
    var kind: String=str(supply["kind"])
    var amount: int=int(supply["quantity"])
    var at:=Vector2(position.x,position.z)
    var ground_y: float=float(terrain.height_at(at.x,at.y))
    # Keep loot on a raised walkable deck when the bot died inside a villa,
    # and never float a cache below the current physical standing surface.
    var surface_y: float=maxf(ground_y,position.y-.15)
    _make_pickup(at,kind,"AuroraOpponentLoot"+str(_opponent_drops_spawned),
        surface_y,true,amount)


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
        floor_height: float=NAN,from_opponent: bool=false,
        quantity: int=-1) -> void:
    if not is_finite(floor_height):
        floor_height=_historic_floor_at(at)
    var pickup: Area3D=LOOT.new()
    pickup.name=pickup_name
    pickup.pickup_type=kind
    pickup.from_opponent=from_opponent
    pickup.quantity=quantity
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
        last_match_saved=_records.record_result(int(result.id),bool(result.victory),
            int(result.kills),int(result.seconds),result.get("extra",{}))
    else:
        last_match_saved=true
    if last_match_saved:
        _pending_result.clear()
        hud.impact("RESULTADO GUARDADO")
    else:
        hud.impact("GUARDADO PENDIENTE / REINTENTANDO")
    return last_match_saved
