extends SceneTree
## V75.95: no instant spawn-kill at Lila's actual parachute touchdown.
## Three distinct landing spots: 49 genuine damageable CharacterBody3D
## rivals remain on terrain, with real colliders and mutually separated.
const COMBAT=preload("res://scripts/combat/training_combat.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7595_SAFE_LANDING "+reason)


func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var player: CharacterBody3D=game.get_node("Operator")
    var nav: Node3D=game.get_node("AuroraNavigation")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    for rival in combat._targets:
        rival.set_physics_process(false)
    await physics_frame
    combat.set_encounter_size(COMBAT.CLASSIC_BR_PARTICIPANTS)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    nav.set_physics_process(false)
    for rival in combat._targets:
        rival.set_physics_process(false)
    check(combat.active_fighter_count()==50 and combat._targets.size()==49,
        "the first BR has fewer than 49 physical rivals")
    var collision_count: int=0
    for rival in combat._targets:
        if rival.get_node_or_null("OpponentCollider") is CollisionShape3D:
            collision_count+=1
    check(collision_count==49,"safety placement removed real hitboxes")

    # Land directly on three known original enemy spawn locations.
    # Each test uses an actual player pose and complete match restart,
    # not a synthetic enemy removal or a mock landing coordinate.
    for trial in range(3):
        var victim_index: int=[3,13,29][trial]
        var victim: CharacterBody3D=combat._targets[victim_index]
        var forced: Vector2=victim.spawn_coordinates
        player.global_position=Vector3(forced.x,
            terrain.height_at(forced.x,forced.y)+.17,forced.y)
        director.start_sector_battle(true)
        director.set_process(false)
        combat.set_process(false)
        player.set_physics_process(false)
        nav.set_physics_process(false)
        for bot in combat._targets:
            bot.set_physics_process(false)
        var landing: Vector2=Vector2(player.global_position.x,
            player.global_position.z)
        check(landing.distance_to(forced)<.001,
            "true parachute landing position changed to force a test pass")
        check(combat._targets.size()==49 and
            combat.active_fighter_count()==50 and
            combat.eliminations==0,
            "moving spawn locations removed rivals or awarded phantom kills")
        var positions: Array[Vector2]=[]
        for rival in combat._targets:
            var at: Vector2=rival.spawn_coordinates
            check(at.distance_to(landing)>=COMBAT.PLAYER_LANDING_CLEARANCE-.001,
                "real enemy body overlaps the landing player trial "+str(trial))
            check(rival.health==100.0 and rival.sector_battle and
                rival.get_node_or_null("OpponentCollider") is CollisionShape3D,
                "repositioned rival lost physical combat or collision")
            check(rival.global_position.distance_to(rival._anchor)<.001,
                "relocation changed spawn UI only, not actual physics body")
            for prior in positions:
                check(at.distance_to(prior)>=3.19,
                    "two real enemy hitboxes overlap after landing relocation")
            positions.append(at)
        check(positions.size()==49 and
            combat._is_clear_spawn(victim.spawn_coordinates),
            "replacement was not valid walkable island terrain")
    game.queue_free()
    await process_frame
    if not failed:
        print("V7595_SAFE_LANDING PASS roster=50 colliders=49 "+
            "forced_landings=3 clearance=14m unique_physical_spawns=49 "+
            "no_spawn_kills=1 online=false motorola_fps=unmeasured")
    quit(1 if failed else 0)
