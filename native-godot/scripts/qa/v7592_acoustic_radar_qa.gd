extends SceneTree
## V75.92 — real gunfire-only BR minimap: no permanent wallhack markers.
## Uses the existing 50 CharacterBody3D match, real muzzle signal routing
## and bounded audible markers. Separate training radar stays unchanged.
const COMBAT=preload("res://scripts/combat/training_combat.gd")
const RADAR=preload("res://scripts/ui/aurora_training_radar.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V7592_ACOUSTIC_RADAR "+why)


func _verify() -> void:
    check(RADAR.MAX_GUNFIRE_PINGS==8 and
        RADAR.GUNFIRE_HEARING_RANGE==42.0 and
        RADAR.GUNFIRE_PING_SECONDS==3.0,
        "mobile acoustic markers are unbounded or unrealistic")
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var player: CharacterBody3D=game.get_node("Operator")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var nav: Node3D=game.get_node("AuroraNavigation")
    var radar: Control=hud._training_radar
    for rival in combat._targets:
        rival.set_physics_process(false)
    await physics_frame
    check(not radar._battle_mode and
        radar._gunfire_pings.is_empty(),
        "training wrongly starts with secret BR acoustic markers")

    combat.set_encounter_size(COMBAT.CLASSIC_BR_PARTICIPANTS)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    nav.set_physics_process(false)
    player.set_physics_process(false)
    for rival in combat._targets:
        rival.set_physics_process(false)
    check(radar._battle_mode and
        radar.opponents.size()==49 and
        radar._gunfire_pings.is_empty() and
        combat._targets.size()==49 and combat.active_fighter_count()==50,
        "battle leaked omniscient enemy markers or removed physical rivals")
    check(radar._zone_enabled and radar._next_zone_enabled and
        radar._zone_world_center.distance_to(director.zone_center)<.001,
        "acoustic map removed current or next safe circles")

    # Real physical bot firing invokes weapon_fired, then bot_shot, then
    # director -> player HUD. No invented online users, map-only test shots
    # or fabricated target-lock events during gameplay.
    var shooter: CharacterBody3D=combat._targets[0]
    var target: CharacterBody3D=combat._targets[1]
    player.global_position=shooter.global_position+Vector3(4.0,0,4.0)
    var shots_before: int=shooter.shots_fired
    check(shooter._fire_at_target(target) and
        shooter.shots_fired==shots_before+1,
        "AI did not execute an actual physics-based firearm shot")
    check(radar._gunfire_pings.size()==1 and
        (radar._gunfire_pings[0]["position"] as Vector2).distance_to(
            Vector2(shooter.global_position.x,shooter.global_position.z))<.001,
        "a real nearby muzzle blast failed to create one acoustic ping")
    var stored_location: Vector2=radar._gunfire_pings[0]["position"]
    shooter.global_position+=Vector3(5.0,0,0)
    check((radar._gunfire_pings[0]["position"] as Vector2)==stored_location,
        "minimap tracks an unseen moving rival through cover")

    # Repeated shots in one location refresh their short-lived pulse rather
    # than allocating one marker per automatic weapon round.
    for i in range(30):
        shooter.weapon_fired.emit(shooter.global_position)
    check(radar._gunfire_pings.size()==1,
        "an automatic burst allocated 30 separate minimap markers")
    var from_player: Vector3=player.global_position
    for i in range(24):
        var angle: float=TAU*float(i)/24.0
        var pos:=from_player+Vector3(cos(angle)*30.0,0,sin(angle)*30.0)
        shooter.weapon_fired.emit(pos)
    check(radar._gunfire_pings.size()<=RADAR.MAX_GUNFIRE_PINGS,
        "simultaneous 49-bot gunfire exceeded capped mobile UI memory")
    var count: int=radar._gunfire_pings.size()
    shooter.weapon_fired.emit(from_player+Vector3(120,0,0))
    check(radar._gunfire_pings.size()==count,
        "shots beyond actual hearing range revealed remote enemies")
    radar._process(RADAR.GUNFIRE_PING_SECONDS+.25)
    check(radar._gunfire_pings.is_empty(),
        "last-known sound pings never expire")
    director.mode="training"
    shooter.weapon_fired.emit(player.global_position)
    check(radar._gunfire_pings.is_empty(),
        "ended BR or training leaked fresh enemy radar detections")
    game.queue_free()
    await process_frame
    if not failed:
        print("V7592_ACOUSTIC_RADAR PASS roster=50 "+
            "real_gunfire=1 no_permanent_enemy_tracking=1 "+
            "hearing=42m lifetime=3s max_pings=8 storm_map=preserved "+
            "training=unmodified online=false")
    quit(1 if failed else 0)
