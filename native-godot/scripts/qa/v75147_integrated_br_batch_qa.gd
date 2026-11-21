extends SceneTree
## V75.147 integrated round: 50 true CharacterBody rivals, one physical
## loot list for map/radar/HUD, authentic optional cars, and one real timed
## automatic magazine replacement. No screenshots or fake combatants.
const WEAPONS=preload("res://scripts/combat/aurora_weapon_catalog.gd")
const COMBAT=preload("res://scripts/combat/training_combat.gd")
const VEHICLE=preload("res://scripts/world/aurora_driveable_vehicle.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75147_INTEGRATED_BR "+reason)


func _verify() -> void:
    root.size=Vector2i(964,434)
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var player: CharacterBody3D=game.get_node("Operator")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var radar: Control=hud.get_node(
        "AuroraTacticalOverlay/AuroraTrainingRadar")
    var map: Control=hud.get_node(
        "AuroraTacticalOverlay/AuroraFullTacticalMap")
    var intel: Label=hud.get_node(
        "AuroraTacticalOverlay/RealGroundBattleIntel")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    map.call("_clear_waypoint")
    check(director.nearby_world_pickups(Vector2.ZERO).is_empty() and
        director.nearby_real_vehicles(Vector2.ZERO).is_empty() and
        (radar.call("nearby_physical_resources") as Array).is_empty() and
        (radar.call("nearby_physical_vehicles") as Array).is_empty() and
        not intel.visible,
        "training fabricates battle supplies, vehicles or ground guidance")
    check(COMBAT.AUTO_RELOAD_SLOTS.has(WEAPONS.AR) and
        COMBAT.AUTO_RELOAD_SLOTS.has(WEAPONS.SCAR) and
        COMBAT.AUTO_RELOAD_SLOTS.has(WEAPONS.MP40) and
        not COMBAT.AUTO_RELOAD_SLOTS.has(WEAPONS.AWM) and
        not COMBAT.AUTO_RELOAD_SLOTS.has(WEAPONS.SHOTGUN) and
        not COMBAT.AUTO_RELOAD_SLOTS.has(WEAPONS.KNIFE),
        "automatic magazine logic interrupts AWM bolt or manual shotguns")

    combat.set_encounter_size(COMBAT.CLASSIC_BR_PARTICIPANTS)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(combat.active_fighter_count()==50 and
        combat._targets.size()==49,
        "integrated battle replaced physical 50-participant BR")

    var field:=Vector2(6.0,-7.0)
    var resources: Array[Dictionary]=director.nearby_world_pickups(
        field,65.0,8)
    check(resources.size()>=1 and resources.size()<=8,
        "real match loot not available inside bounded 65m scan")
    for i in range(resources.size()):
        var data: Dictionary=resources[i]
        check((data["at"] as Vector2).distance_to(field)<=65.0 and
            float(data["meters"])<=65.0,
            "scan leaks remote physical supplies")
        if i>0:
            check(float(resources[i-1]["meters"])<=
                float(data["meters"])+.001,
                "supply scan prioritizes old list order instead of closest")
        var actual: bool=false
        for loot in director._loot:
            if (is_instance_valid(loot) and not loot.collected and
                    not loot.from_opponent and
                    loot.pickup_type==str(data["kind"]) and
                    Vector2(loot.global_position.x,
                        loot.global_position.z).distance_to(
                        data["at"] as Vector2)<.05):
                actual=true
                break
        check(actual,"tactical scan created a fictitious supply marker")
    check(director.nearby_world_pickups(field,65.0,0).is_empty() and
        director.nearby_world_pickups(Vector2(260,260),20.0,8).is_empty(),
        "zero-budget or remote-supply scan exposed map locations")
    # Only physical car sources can produce actual vehicle/map pins.
    var available: int=0
    for kind in ["Toyota","BMW"]:
        available+=1 if VEHICLE.source_available(kind) else 0
    check(director._driveable_cars.size()==available,
        "vehicle HUD fabricated cars that are not in the private GLB pack")
    for car in director._driveable_cars:
        var point:=Vector2(car.global_position.x,car.global_position.z)
        check(director.nearby_real_vehicles(point,8.0,2).has(point),
            "real car with wheels cannot be found by the live tactical map")
    check(director.nearby_real_vehicles(field,95.0,0).is_empty(),
        "zero-budget vehicle query leaked physical pins")

    # The same world source drives both map types and a compact ground HUD.
    player.global_position=Vector3(field.x,
        terrain.height_at(field.x,field.y)+1.4,field.y+5.0)
    var circle: Array=radar.call("nearby_physical_resources")
    var large: Array=map.call("_live_world_resources")
    check(not circle.is_empty() and not large.is_empty() and
        circle.size()<=5 and large.size()<=8,
        "full map and minimap disagree on actual nearby loot objects")
    hud.call("_refresh_ground_battle_intel")
    check(intel.visible and
        (intel.text.contains("MUNICION") or
         intel.text.contains("BOTIQUIN") or
         intel.text.contains("SUMINISTROS") or
         intel.text.contains("EQUIPO")),
        "ground HUD lost its local resource context")
    var waypoint:=Vector2(player.global_position.x+26.0,
        player.global_position.z-12.0)
    map.call("mark",waypoint)
    hud.call("_refresh_ground_battle_intel")
    check(intel.visible and intel.text.begins_with("DESTINO ") and
        (radar.get("_waypoint") as Vector2)==waypoint,
        "in-flight waypoint is not navigable on the ground with real metres")
    map.call("_clear_waypoint")
    check(not (radar.get("_waypoint") as Vector2).is_finite() and
        not intel.text.begins_with("DESTINO "),
        "deleting a real waypoint leaves a phantom ground navigation label")

    # Last REAL AR-7 bullet fires once, causes ordinary recoil/tracer,
    # then the *existing* 1.55 s reload consumes finite reserve ammo.
    combat.weapon_index=WEAPONS.AR
    combat.ammo[WEAPONS.AR]=1
    combat.reserve[0]=8
    combat.cooldown=0.0
    combat.trigger_held=false
    combat.reload_timer=0.0
    var before_shots: int=combat.shots_fired_total
    var before_reloads: int=combat.reloads_completed
    combat._shoot()
    check(combat.shots_fired_total==before_shots+1 and
        combat.ammo[WEAPONS.AR]==0 and
        combat.reserve[0]==8 and
        bool(combat.get("_auto_reload_queued")) and
        combat.reload_timer==0.0,
        "empty-magazine assistance fired virtual bullets or skipped cooldown")
    combat._process(.30)
    check(combat.reload_timer>0.0 and
        combat.reload_timer<COMBAT.AR_RELOAD_SECONDS and
        not bool(combat.get("_auto_reload_queued")) and
        combat.reserve[0]==8,
        "automatic reload is not actual authored timed weapon reload")
    combat._process(1.60)
    check(combat.reloads_completed==before_reloads+1 and
        combat.ammo[WEAPONS.AR]==8 and combat.reserve[0]==0 and
        combat.reload_timer<=0.0,
        "automatic reload duplicated ammo or bypassed finite inventory")

    director.match_ended=true
    hud.call("_refresh_ground_battle_intel")
    check(not intel.visible and
        director.nearby_world_pickups(field).is_empty() and
        director.nearby_real_vehicles(field).is_empty() and
        (radar.call("landing_waypoint_guidance") as Dictionary).is_empty(),
        "post-match leaks stale resources, vehicles or objective guidance")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75147_INTEGRATED_BR PASS real_roster=50 "+
            "real_resource_queries=2 nearby_radius=65m max=8 "+
            "real_optional_vehicles=1 mobile_ground_guidance=1 "+
            "waypoint_cleanup=1 AR_last_bullet=1 timed_reload=1 "+
            "finite_reserve=1 result_cleanup=1")
    quit(1 if failed else 0)
