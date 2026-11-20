extends SceneTree
## Regression: an enemy shot in the air must leave an actual collectible
## supply pod on the terrain, never hovering at the death altitude.
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75126_AIRBORNE_LOOT "+reason)

func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var player: CharacterBody3D=game.get_node("Operator")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    var victim: CharacterBody3D=combat._targets[0]
    var spot:=Vector2(12.0,-12.0)
    var ground: float=terrain.height_at(spot.x,spot.y)
    victim.global_position=Vector3(spot.x,ground+25.0,spot.y)
    victim.velocity=Vector3(0,-10.0,0)
    victim._magazine=7
    victim._field_medkits=0
    check(not director.is_outside_zone(victim.global_position),
        "test airborne death must happen inside playable safe zone")
    check(victim.health==200.0,
        "rival must start airborne death at the real 200 HP maximum")
    check(victim.take_training_damage(999.0,player),
        "physical airborne enemy cannot be eliminated by player")
    var drop: Area3D=director.get_node_or_null("AuroraOpponentLoot1") as Area3D
    check(drop!=null and director._opponent_drops_spawned==1,
        "airborne elimination lost its finite real inventory cache")
    if drop!=null:
        check(drop.from_opponent and drop.pickup_type=="ammo_ar" and
            drop.quantity==7,
            "airborne elimination invented loot not carried by enemy")
        var expected_y: float=ground+.50
        check(absf(drop.global_position.y-expected_y)<.08,
            "airborne death cache is suspended in the sky: actual="+
            str(drop.global_position.y)+" expected="+str(expected_y))
        check(victim.global_position.y-drop.global_position.y>20.0,
            "airborne death cache remained at enemy's altitude")
        check(drop.get_node_or_null("LootPickupRange") is CollisionShape3D,
            "grounded rival cache has no physical pickup collider")
    director._on_opponent_eliminated(victim,player)
    check(director._opponent_drops_spawned==1,
        "duplicate falling-kill notification spawned another loot pod")
    if not failed:
        print("V75126_AIRBORNE_LOOT PASS real_200_HP=1 physical_death=1 "+
            "ground_snap=1 no_airborne_floating=1 no_duplication=1")
    quit(1 if failed else 0)
