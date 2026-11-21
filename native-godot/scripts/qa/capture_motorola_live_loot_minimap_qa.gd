extends SceneTree
## Actual Main.tscn phone-size screenshot: 50-fighter BR and two physically
## eliminated enemies whose real ammo caches are within minimap range.
## Desktop software OpenGL rendering only, NOT physical Motorola Vulkan.
const COMBAT=preload("res://scripts/combat/training_combat.gd")
const CAPTURE_VERSION=preload("res://scripts/qa/aurora_capture_version.gd")


func _initialize() -> void:
    call_deferred("_capture")


func _fail(reason: String) -> void:
    push_error("V75142_MINIMAP_CAPTURE "+reason)
    quit(1)


func _capture() -> void:
    root.size=Vector2i(964,434)
    var tag: String=CAPTURE_VERSION.tag()
    if tag.is_empty():
        _fail("no versioned screenshot tag")
        return
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var player: CharacterBody3D=game.get_node("Operator")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var radar: Control=hud.get_node(
        "AuroraTacticalOverlay/AuroraTrainingRadar")
    var tactical: Control=hud.get_node(
        "AuroraTacticalOverlay/AuroraFullTacticalMap")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    combat.set_encounter_size(COMBAT.CLASSIC_BR_PARTICIPANTS)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    if combat._targets.size()!=49:
        _fail("50-person BR roster missing")
        return

    for i in range(2):
        var at:=Vector2(8.0+float(i)*8.0,-22.0)
        var bot: CharacterBody3D=combat._targets[i]
        bot.global_position=Vector3(at.x,
            terrain.height_at(at.x,at.y)+2.0,at.y)
        bot._magazine=7
        bot._field_medkits=0
        if bot.health!=200.0 or not bot.take_training_damage(999.0,player):
            _fail("real 200-HP bot elimination failed: "+str(i))
            return
    player.global_position=Vector3(12.0,
        terrain.height_at(12.0,-16.0)+1.5,-16.0)
    player.velocity=Vector3.ZERO
    tactical.visible=false
    radar.visible=true
    radar.queue_redraw()
    var markers: Array=radar.call("_nearby_supply_markers")
    if markers.size()!=2 or director._active_opponent_drop_count()!=2:
        _fail("two actual post-kill caches not visible to minimap")
        return
    for frame in range(14):
        await process_frame
    await RenderingServer.frame_post_draw
    var image: Image=root.get_texture().get_image()
    if image.get_size()!=Vector2i(964,434):
        _fail("image has incorrect Motorola viewport")
        return
    var path: String="res://out/aurora-"+tag+"-motorola-live-loot-minimap.png"
    if image.save_png(path)!=OK:
        _fail("cannot save true Godot scene screenshot")
        return
    print("V75142_MINIMAP_CAPTURE PASS 964x434 roster=50 "+
        "200hp=1 real_deaths=2 real_ammo_caches=2 minimap_icons=2 "+
        "no_fake_enemies=1 device_test=NO file="+path)
    game.queue_free()
    await process_frame
    quit(0)
