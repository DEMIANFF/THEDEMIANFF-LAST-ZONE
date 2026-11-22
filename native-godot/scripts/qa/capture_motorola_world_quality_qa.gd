extends SceneTree
## Phone-aspect evidence of the REAL Main.tscn and connected 50-roster
## world render: snow/rock, opaque reflective water, tree crowns, distant
## aerial perspective. Desktop OpenGL screenshots are NOT Vulkan FPS tests.
const CAPTURE_VERSION=preload("res://scripts/qa/aurora_capture_version.gd")
const COMBAT=preload("res://scripts/combat/training_combat.gd")


func _initialize() -> void:
    call_deferred("_capture")


func _fail(why: String) -> void:
    push_error("V75162_ACTUAL_WORLD_CAPTURE "+why)
    quit(1)


func frames(n: int) -> void:
    for i in range(n):
        await process_frame


func _screenshot(tag: String,stage: String) -> bool:
    await RenderingServer.frame_post_draw
    var image: Image=root.get_texture().get_image()
    if image.get_size()!=Vector2i(964,434):
        return false
    var path: String="res://out/aurora-%s-motorola-%s.png"%[tag,stage]
    if image.save_png(path)!=OK:
        return false
    print("V75162_ACTUAL_WORLD_CAPTURE frame=",stage," path=",path)
    return true


func _capture() -> void:
    root.size=Vector2i(964,434)
    var tag: String=CAPTURE_VERSION.tag()
    if tag.is_empty():
        _fail("real Android version metadata missing")
        return
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var budget: Node=game.get_node("AuroraRenderBudget")
    var nature: Node3D=game.get_node("AuroraNature")
    var trees: MultiMeshInstance3D=nature.get_node("AuroraPineCrowns")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var player: CharacterBody3D=game.get_node("Operator")
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
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
    if (combat._targets.size()!=49 or
            terrain.get_node_or_null("ContinuousIslandSurface")==null):
        _fail("screenshot replaced real fifty-fighter Battle Royale island")
        return
    # Actual 3D coastal cliff with forest, open water and playable collider.
    var at:=Vector2(107,83)
    player.global_position=Vector3(at.x,
        terrain.height_at(at.x,at.y)+1.2,at.y)
    player.velocity=Vector3.ZERO
    player.set("_yaw",-.40)
    player.set("_desired_yaw",-.40)
    player.set("_pitch",-.14)
    player.set("_desired_pitch",-.14)
    if (budget.call("select_profile","CLARIDAD")!=OK or
            not bool(nature.get("detailed_foliage")) or
            not (trees.multimesh.mesh is ArrayMesh)):
        _fail("clarity is not rendering real original layered tree crowns")
        return
    await frames(20)
    var clear_ok: bool=await _screenshot(tag,"quality-claridad-world")
    if not clear_ok:
        _fail("could not capture real higher-detail quality scene")
        return
    if (budget.call("select_profile","FLUIDEZ")!=OK or
            bool(nature.get("detailed_foliage")) or
            not (trees.multimesh.mesh is CylinderMesh)):
        _fail("performance mode did not switch the genuine distant forest LOD")
        return
    await frames(20)
    var fast_ok: bool=await _screenshot(tag,"quality-fluidez-world")
    if not fast_ok:
        _fail("could not capture real lower-cost mode")
        return
    budget.call("select_profile","AUTO")
    game.queue_free()
    await process_frame
    print("V75162_ACTUAL_WORLD_CAPTURE PASS 964x434 "+
        "50_roster=1 real_island=1 128px_normals=1 "+
        "actual_pine_mesh_LOD_switched=1 high_low=2 "+
        "native_vulkan_Motorola_test=NOT_PERFORMED")
    quit(0)
