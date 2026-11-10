extends SceneTree
## Real 3D BR integration: HUD -> inventory -> physical cover -> ray collision.
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V7513_COVER "+message)


func frames(n: int) -> void:
    for i in range(n):
        await physics_frame


func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player=game.get_node("Operator")
    var combat=game.get_node("CombatRange")
    var director=game.get_node("AuroraSectorMatch")
    var terrain=game.get_node("AuroraTerrain")
    var hud=game.get_node("TrainingHUD")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await frames(4)
    check(combat.cover_charges==0,"barrier invented before a real match")
    check(not combat.deploy_aurora_cover(),"barrier spawned in training")
    director.start_sector_battle()
    for bot in combat._targets:
        bot.set_physics_process(false)
    await frames(4)
    check(combat.sector_battle_active and combat.cover_charges==2,
        "sector match did not grant two limited Aurora walls")
    var button: Button=hud.get_node("AuroraTacticalOverlay/BARRERA 0") as Button
    check(button!=null and button.visible and not button.disabled,
        "deployable HUD action absent/disabled")

    # Find actual unobstructed island ground, not a fake collision-free test world.
    player.global_position=Vector3(-76.0,terrain.height_at(-76.0,-76.0)+.8,-76.0)
    player.velocity=Vector3.ZERO
    player._yaw=0.0
    player._desired_yaw=0.0
    await frames(12)
    player.set_physics_process(false)
    var deployed: bool=combat.deploy_aurora_cover()
    check(deployed,"physical Aurora cover could not deploy in open island terrain")
    if not deployed:
        quit(1)
        return
    check(combat.cover_charges==1 and combat.cover_cooldown>0.0,
        "deployment did not consume a charge or enforce cooldown")
    check(not combat.deploy_aurora_cover() and combat.cover_charges==1,
        "cooldown allowed immediate cover spam")
    var cover: StaticBody3D=combat._covers[0]
    check(cover.get_node_or_null("AuroraIceWallCollision")!=null and
        cover.get_node_or_null("AuroraCrystal2")!=null,
        "barrier missing real solid geometry and faceted model")

    var from: Vector3=cover.global_position+cover.global_basis.z*4.0+Vector3.UP*1.25
    var endpoint: Vector3=cover.global_position-cover.global_basis.z*4.0+Vector3.UP*1.25
    var ray:=PhysicsRayQueryParameters3D.create(from,endpoint)
    ray.exclude=[player.get_rid()]
    var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(ray)
    check(hit.get("collider")==cover,
        "real world ray penetrated Aurora cover before damage")
    var resolved: Dictionary=combat.resolve_shot(from,(endpoint-from).normalized(),from)
    check(resolved.get("collider")==cover,
        "player muzzle ray ignores Aurora cover")

    check(not cover.take_damage(100.0) and is_equal_approx(cover.health,120.0),
        "cover was not damageable with persistent HP")
    check(cover.take_damage(120.0),"Aurora cover did not break at zero health")
    await frames(3)
    check(not is_instance_valid(cover),"destroyed cover did not free collision")
    check(combat.collect_sector_loot("cover_charge") and combat.cover_charges==2,
        "real loot cannot replenish barrier charges")
    combat.end_sector_battle()
    check(combat.cover_charges==0 and combat._covers.is_empty(),
        "barriers/inventory leaked beyond the match")
    print("V7513_AURORA_COVER PASS hud,physical_deployment,cooldown,collision,muzzle_damage,loot,cleanup")
    quit(1 if failed else 0)
