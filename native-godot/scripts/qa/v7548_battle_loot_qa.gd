extends SceneTree
## V75.48: real eliminations generate collectible physical loot, no fake bots.
## CI runs a normal Godot scene with CharacterBody3D and active Area3D.
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V7548_BATTLE_LOOT "+why)

func _verify() -> void:
    check(str(ProjectSettings.get_setting(
        "rendering/renderer/rendering_method.mobile"))=="mobile",
        "Android must default to Mobile renderer, not a duplicate OpenGL build")
    check(str(ProjectSettings.get_setting(
        "rendering/rendering_device/driver.android"))=="vulkan",
        "Android Vulkan driver missing")
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
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
    check(combat.sector_battle_active and director.get_loot_remaining()==25,
        "battle should start with 25 original physical supplies")
    check(director._opponent_drops_spawned==0,
        "a new round begins with phantom elimination drops")

    var victim: CharacterBody3D=combat._targets[0]
    var before: int=combat.reserve[0]
    check(victim.take_training_damage(999.0,player),
        "real bot elimination did not register")
    check(combat.eliminations==1 and director._opponent_drops_spawned==1,
        "player kill not credited or opponent drop not created")
    var reward: Area3D=director.get_node_or_null("AuroraOpponentLoot1") as Area3D
    check(reward!=null and director.get_loot_remaining()==26,
        "eliminated rival must create one live supply Area3D")
    if reward!=null:
        check(reward.from_opponent and reward.pickup_type=="ammo_ar" and
            reward.get_node_or_null("LootPickupRange")!=null,
            "enemy loot is decorative rather than an identifiable collidable pickup")
        var label: Label3D=reward.get_node(
            "SupplyCacheVisual/SupplyLabel") as Label3D
        check(label.text.begins_with("RIVAL / "),
            "enemy death cache is indistinguishable from ambient loot")
        check(reward.global_position.y>=terrain.height_at(
            reward.global_position.x,reward.global_position.z)+.49,
            "enemy drop spawned beneath real ground")
        player.global_position=reward.global_position-Vector3.UP
        player.velocity=Vector3.ZERO
        await physics_frame
        await physics_frame
        reward._collect(player)
        check(reward.collected and combat.reserve[0]>before,
            "physical death cache cannot replenish actual rifle ammo")
    director._on_opponent_eliminated(victim,player)
    check(director._opponent_drops_spawned==1,
        "the same dead body generated duplicate supply caches")

    var outside: CharacterBody3D=combat._targets[1]
    outside.global_position=Vector3(
        director.CENTER.x+director.INITIAL_RADIUS+8.0,
        terrain.height_at(director.CENTER.x+director.INITIAL_RADIUS+8.0,
            director.CENTER.y)+.15,director.CENTER.y)
    check(outside.take_training_damage(999.0,null),
        "zone-lost rival cannot be eliminated")
    check(director._opponent_drops_spawned==1 and combat.eliminations==1,
        "outside-zone kill spawned unreachable loot or credited false player kill")

    var foe: CharacterBody3D=combat._targets[2]
    var killer: CharacterBody3D=combat._targets[3]
    check(foe.take_training_damage(999.0,killer),
        "other bots should eliminate rivals without fake simulation")
    check(director._opponent_drops_spawned==2 and combat.eliminations==1,
        "AI-on-AI death did not leave loot or wrongly credited player")
    check(director.get_node_or_null("AuroraOpponentLoot2")!=null,
        "AI-on-AI elimination did not create world loot")
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(director._opponent_drops_spawned==0 and
        director.get_loot_remaining()==25 and combat.eliminations==0,
        "round restart leaked old drops, player credits or supplies")
    if not failed:
        print("V7548_BATTLE_LOOT PASS android_vulkan_only=1 player_drop=1 "+
            "physical_collection=1 bot_vs_bot=1 zone_safety=1 reset=1")
    quit(1 if failed else 0)
