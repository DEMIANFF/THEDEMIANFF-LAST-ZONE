extends SceneTree
## V75.142: mobile minimap shows bounded nearby *real* enemy drops;
## it never reveals unseen live rivals. Uses 50 CharacterBody3D fighters,
## actual 200 HP elimination and an inventory-consuming physics pickup.
const COMBAT=preload("res://scripts/combat/training_combat.gd")
const RADAR=preload("res://scripts/ui/aurora_training_radar.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75142_PHYSICAL_LOOT_MINIMAP "+reason)


func _verify() -> void:
    check(RADAR.MAX_MINIMAP_CACHES==4 and
        RADAR.MINIMAP_CACHE_RANGE==50.0,
        "phone minimap cache budget exceeds four/50 metres")
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var player: CharacterBody3D=game.get_node("Operator")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var radar: Control=game.get_node(
        "TrainingHUD/AuroraTacticalOverlay/AuroraTrainingRadar")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    check(radar.get("_sector_director")==director and
        not bool(radar.get("_battle_mode")) and
        (radar.call("_nearby_supply_markers") as Array).is_empty(),
        "radar is not linked to physical match or training shows drops")
    combat.set_encounter_size(COMBAT.CLASSIC_BR_PARTICIPANTS)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(combat._targets.size()==49 and
        bool(radar.get("_battle_mode")) and
        (radar.call("_nearby_supply_markers") as Array).is_empty(),
        "50-fighter BR spawned fake supply dots before physical kills")

    # Five actual bodies fall within 50 m, but the phone only draws four
    # marker squares. No additional physics Area3D or reward is created.
    for i in range(5):
        var spot:=Vector2(8.0+float(i)*4.0,-22.0)
        var bot: CharacterBody3D=combat._targets[i]
        bot.global_position=Vector3(spot.x,
            terrain.height_at(spot.x,spot.y)+2.0,spot.y)
        bot._magazine=7
        bot._field_medkits=0
        check(bot.health==200.0 and
            bot.take_training_damage(999.0,player),
            "physical 200 HP rival death failed: "+str(i))
    check(director._active_opponent_drop_count()==5,
        "minimap feature changed the 12 live-cache gameplay budget")
    var at:=Vector2(8.0,-22.0)
    player.global_position=Vector3(at.x,
        terrain.height_at(at.x,at.y)+1.5,at.y+7.0)
    var markers: Array=radar.call("_nearby_supply_markers")
    check(markers.size()==4 and markers[0] is Vector2 and
        (markers[0] as Vector2).distance_to(at)<.1,
        "minimap did not read capped real supplies through the director")
    check((radar.get("_gunfire_pings") as Array).is_empty() and
        (radar.get("opponents") as Array).size()==49,
        "minimap revealed living rivals rather than physical death caches")

    # A nearby bot's seven ammo rounds are truly transferred to the
    # inventory; the same spot must disappear, without a phantom icon.
    var cache: Area3D=director.get_node_or_null("AuroraOpponentLoot1")
    check(cache!=null and cache.quantity==7 and cache.from_opponent,
        "real first opponent ammo cache absent")
    if cache!=null:
        var ammo_before: int=combat.reserve[0]
        player.global_position=cache.global_position-Vector3.UP*.85
        player.velocity=Vector3.ZERO
        await physics_frame
        await physics_frame
        if is_instance_valid(cache) and not cache.collected:
            cache._collect(player)
        check(combat.reserve[0]==ammo_before+7 and
            combat.opponent_caches_collected==1,
            "physical pickup failed to grant exactly seven carried rounds")
        markers=radar.call("_nearby_supply_markers")
        check(markers.size()==4,
            "remaining four actual enemy crates were incorrectly suppressed")
        for marker in markers:
            check((marker as Vector2).distance_to(at)>.5,
                "collected cache still appears as a ghost minimap dot")

    # Remote player should not see boxes across the island.
    player.global_position=Vector3(210.0,10.0,210.0)
    check((radar.call("_nearby_supply_markers") as Array).is_empty(),
        "remote supply crates leaked through map beyond 50m")
    player.royale_eliminated=true
    check((radar.call("_nearby_supply_markers") as Array).is_empty(),
        "eliminated operator still sees combat loot markers")
    player.royale_eliminated=false
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check((radar.call("_nearby_supply_markers") as Array).is_empty() and
        director._active_opponent_drop_count()==0,
        "new round leaked old opponent caches into the minimap")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75142_PHYSICAL_LOOT_MINIMAP PASS roster=50 real_200HP=1 "+
            "real_kills=5 visible_max=4 radius=50m real_ammo=7 "+
            "no_wallhack=1 cache_reset=1 mobile_budget=1")
    quit(1 if failed else 0)
