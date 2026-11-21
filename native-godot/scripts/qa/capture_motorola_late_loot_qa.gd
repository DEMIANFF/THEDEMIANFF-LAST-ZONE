extends SceneTree
## Live native Godot evidence that a *later* physical kill still produces
## its carried loot after twelve earlier caches were spawned and one picked up.
## 964x434 desktop GL: NOT a physical Motorola Vulkan certification.
const CAPTURE_VERSION=preload("res://scripts/qa/aurora_capture_version.gd")


func _initialize() -> void:
    call_deferred("_capture")


func _fail(reason: String) -> void:
    push_error("V75138_LOOT_CAPTURE "+reason)
    quit(1)


func _capture() -> void:
    root.size=Vector2i(964,434)
    var tag: String=CAPTURE_VERSION.tag()
    if tag.is_empty():
        _fail("missing CI version tag")
        return
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var player: CharacterBody3D=game.get_node("Operator")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    # Camera evidence must use the public fifty-participant battle rather
    # than Main.tscn's nine-person internal QA fixture.
    combat.set_encounter_size(combat.CLASSIC_BR_PARTICIPANTS)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    if combat.encounter_size!=50 or combat._targets.size()!=49:
        _fail("actual 49-opponent physical roster missing")
        return
    for i in range(12):
        var victim: CharacterBody3D=combat._targets[i]
        var at:=Vector2(8.0+float(i%4)*5.0,
            -22.0+float(i/4)*5.0)
        victim.global_position=Vector3(at.x,
            terrain.height_at(at.x,at.y)+2.0,at.y)
        victim._magazine=7
        victim._field_medkits=0
        if not victim.take_training_damage(999.0,player):
            _fail("physical death failed "+str(i))
            return
    if director._active_opponent_drop_count()!=12:
        _fail("initial live cache cap was not twelve")
        return
    var first: Area3D=director.get_node("AuroraOpponentLoot1")
    player.global_position=first.global_position-Vector3.UP*.85
    player.velocity=Vector3.ZERO
    await physics_frame
    await physics_frame
    first._collect(player)
    if not first.collected:
        _fail("real ammo cache could not be physically collected")
        return
    var later: CharacterBody3D=combat._targets[12]
    var spot:=Vector2(20.0,-23.0)
    later.global_position=Vector3(spot.x,
        terrain.height_at(spot.x,spot.y)+1.5,spot.y)
    later._magazine=7
    later._field_medkits=0
    if not later.take_training_damage(999.0,player):
        _fail("later real enemy could not die")
        return
    var drop: Area3D=director.get_node_or_null(
        "AuroraOpponentLoot13") as Area3D
    if drop==null or drop.pickup_type!="ammo_ar" or drop.quantity!=7 or (
            director._active_opponent_drop_count()!=12):
        _fail("late kill has no real physical carried-ammo cache")
        return
    var view:=Camera3D.new()
    view.name="LateLootProofCamera"
    view.fov=58.0
    game.add_child(view)
    view.global_position=drop.global_position+Vector3(3.8,2.3,5.4)
    view.look_at(drop.global_position+Vector3.UP*.6)
    view.current=true
    var label: Label3D=drop.get_node_or_null(
        "SupplyCacheVisual/SupplyLabel") as Label3D
    if label==null or not label.text.contains("RIVAL /") or (
            not label.text.contains("x7")):
        _fail("genuine 7-round cache label missing in 3D world")
        return
    for frame in range(16):
        await process_frame
    await RenderingServer.frame_post_draw
    var image: Image=root.get_texture().get_image()
    if image.get_size()!=Vector2i(964,434):
        _fail("actual render not 964x434")
        return
    var path: String="res://out/aurora-"+tag+"-motorola-late-loot.png"
    if image.save_png(path)!=OK:
        _fail("could not save evidence PNG")
        return
    print("V75138_LOOT_CAPTURE PASS 964x434 "+
        "physical_bot_deaths=13 active_budget=12 "+
        "real_collected_cache=1 late_ammo=7 file="+path)
    game.queue_free()
    await process_frame
    quit(0)
