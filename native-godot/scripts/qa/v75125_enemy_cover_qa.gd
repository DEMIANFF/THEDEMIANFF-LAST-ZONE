extends SceneTree
## Enemy Aurora cover: real destructible shape, one charge, mobile cap.
const BOT=preload("res://scripts/ai/aurora_bot.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75125_ENEMY_COVER "+reason)

func _verify() -> void:
    check(BOT.MAX_ENEMY_COVERS<=10 and BOT.ENEMY_COVER_COOLDOWN>=12.0,
        "49 AI agents can spam unbounded defensive walls on mobile")
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    await physics_frame
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    var rival: CharacterBody3D=combat._targets[0]
    check(rival._cover_charges==1 and rival.covers_deployed==0,
        "enemy had no tactical cover at match start")
    var placed: bool=false
    for at in [Vector2(-76,-76),Vector2(-80,-50),
            Vector2(-55,-80),Vector2(-110,-20)]:
        rival.global_position=Vector3(at.x,terrain.height_at(at.x,at.y)+.15,at.y)
        rival.health=110.0
        rival._last_seen=rival.global_position+Vector3(0,0,-17)
        rival._last_attacker=player
        rival._cover_deploy_clock=0.0
        await physics_frame
        placed=rival._try_deploy_cover()
        if placed:
            break
    check(placed and rival._cover_charges==0 and rival.covers_deployed==1,
        "wounded AI could not place one real Aurora defense")
    if placed:
        var wall: StaticBody3D=rival._owned_covers[0]
        check(wall.get_node_or_null("AuroraIceWallCollision")!=null and
            wall.get_node_or_null("AuroraCrystal2")!=null,
            "enemy defensive wall lacks collision or authentic 3D geometry")
        await physics_frame
        var start: Vector3=wall.global_position+wall.global_basis.z*4.0+Vector3.UP*1.25
        var end: Vector3=wall.global_position-wall.global_basis.z*4.0+Vector3.UP*1.25
        var ray:=PhysicsRayQueryParameters3D.create(start,end)
        # The shooter stands behind its cover: exclude that actual body
        # to test the wall collision rather than the shooter capsule.
        ray.exclude=[rival.get_rid()]
        var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(ray)
        check(hit.get("collider")==wall,
            "bullets pass through a real AI deployable wall")
        check(not rival._try_deploy_cover() and rival.covers_deployed==1,
            "enemy obtained unlimited free cover charges")
        combat.end_sector_battle()
        await process_frame
        check(not is_instance_valid(wall),
            "enemy cover survived match cleanup")
    if not failed:
        print("V75125_ENEMY_COVER PASS physics=1 capped=1 "+
            "charge=1 ballistic_obstruction=1 cleanup=1")
    quit(1 if failed else 0)
