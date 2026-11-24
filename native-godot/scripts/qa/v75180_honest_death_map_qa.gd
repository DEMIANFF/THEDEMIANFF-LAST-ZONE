extends SceneTree
## V75.180: real empty rival death crates must not masquerade as loot.
## Both native maps show the same local shells, never invent ammo or health.
const MATCH=preload("res://scripts/match/sector_director.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V75180_HONEST_DEATH_MAP "+message)

func _verify() -> void:
    root.size=Vector2i(964,434)
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var player: CharacterBody3D=game.get_node("Operator")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var radar: Control=game.get_node(
        "TrainingHUD/AuroraTacticalOverlay/AuroraTrainingRadar")
    var tactical: Control=hud.get("_map_overlay") as Control
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    var base: Vector3=player.global_position
    var location:=Vector2(base.x,base.z)
    check(director.nearby_empty_death_crates(location).is_empty(),
        "fresh battle has corpse markers from an old session")
    var inventory_before: Dictionary=combat.inventory_snapshot()
    var real_world_loot_before: int=director.get_loot_remaining()
    var near_sites: Array[Vector2]=[
        location+Vector2(3.0,0.0),
        location+Vector2(-5.0,4.0),
        location+Vector2(7.0,-6.0)]
    for spot in near_sites:
        director._spawn_empty_opponent_marker(
            Vector3(spot.x,base.y,spot.y),"SIN OBJETOS")
    var far: Vector2=location+Vector2(92.0,92.0)
    director._spawn_empty_opponent_marker(
        Vector3(far.x,base.y,far.y),"SIN ESPACIO PARA BOTÍN")
    var nearby: Array[Vector2]=director.nearby_empty_death_crates(location)
    check(nearby.size()==3 and
        nearby==near_sites and
        not nearby.has(far),
        "real empty shells must remain local, bounded and accurate")
    check(radar.call("nearby_empty_death_crates")==nearby and
        tactical.call("_live_empty_death_crates")==nearby,
        "minimap and full map used different physical empty-crate sources")
    check(combat.inventory_snapshot()==inventory_before and
        director.get_loot_remaining()==real_world_loot_before,
        "empty shell map markers minted imaginary live loot/health")
    check(director.nearby_empty_death_crates(location,0.0).is_empty() and
        director.nearby_empty_death_crates(location,48.0,0).is_empty(),
        "zero scan budget produced non-physical markers")
    check(director.nearby_empty_death_crates(location,48.0,1).size()==1,
        "UI exceeded the requested 1-marker cap")
    check(director.nearby_empty_death_crates(far,48.0,3)==[far],
        "far death evidence was fabricated at a false location")
    director._finish(false)
    check(director.nearby_empty_death_crates(location).is_empty() and
        (radar.call("nearby_empty_death_crates") as Array).is_empty() and
        (tactical.call("_live_empty_death_crates") as Array).is_empty(),
        "ended match exposed empty death crates as actionable targets")
    director.start_sector_battle()
    director.set_process(false)
    check(director._empty_death_markers.is_empty() and
        director.nearby_empty_death_crates(location).is_empty(),
        "new match retained the previous match's death shells")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75180_HONEST_DEATH_MAP PASS true_shells=4 "+
            "local_only=1 no_fictional_loot=1 "+
            "radar_tactical_parity=1 bounded=3 match_reset=1")
    quit(1 if failed else 0)
