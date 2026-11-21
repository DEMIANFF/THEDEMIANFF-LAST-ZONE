extends SceneTree
## Real 964x434 Godot combat scene, two actual fuse/detonation frames.
## OpenGL desktop CI evidence, not an on-device Vulkan certification.
const GRENADE=preload("res://scripts/combat/aurora_grenade.gd")
const CAPTURE=preload("res://scripts/qa/aurora_capture_version.gd")


func _initialize() -> void:
    call_deferred("_capture")


func _screen(name: String,tag: String) -> bool:
    await RenderingServer.frame_post_draw
    var image: Image=root.get_texture().get_image()
    var dest: String="res://out/aurora-"+tag+"-motorola-"+name+".png"
    if image.get_size()!=Vector2i(964,434) or image.save_png(dest)!=OK:
        push_error("V75148_GRENADE_CAPTURE incorrect rendered frame "+name)
        return false
    print("V75148_GRENADE_CAPTURE "+dest)
    return true


func _capture() -> void:
    root.size=Vector2i(964,434)
    var tag: String=CAPTURE.tag()
    if tag.is_empty():
        quit(2)
        return
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var player: CharacterBody3D=game.get_node("Operator")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    for rival in combat._targets:
        rival.set_physics_process(false)
    await physics_frame
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for rival in combat._targets:
        rival.set_physics_process(false)
    var site:=Vector2(8.0,-22.0)
    var y: float=terrain.height_at(site.x,site.y)
    player.global_position=Vector3(site.x,y+1.4,site.y)
    var rival: CharacterBody3D=combat._targets[0]
    rival.global_position=player.global_position+Vector3(3.0,.4,0)
    var grenade: Node3D=GRENADE.new()
    combat.add_child(grenade)
    grenade.global_position=player.global_position+Vector3(2.0,.2,0.0)
    grenade.excluded=player.get_rid()
    grenade.velocity=Vector3.ZERO
    grenade.set_physics_process(false)
    grenade.audible_fuse.connect(combat._on_grenade_audible_fuse)
    grenade.detonated.connect(combat._on_grenade_detonated)
    grenade._remaining=.75
    grenade._physics_process(.05)
    var warning: Label=hud.get_node(
        "AuroraTacticalOverlay/LivePhysicalGrenadeThreat")
    if (not warning.visible or rival.grenade_dodges!=1 or
            combat.active_fighter_count()!=50):
        push_error("V75148_GRENADE_CAPTURE no physical fuse/AI warning")
        quit(3)
        return
    for i in range(5):
        await process_frame
    if not await _screen("real-grenade-fuse-warning",tag):
        quit(4)
        return
    grenade._remaining=.01
    grenade._physics_process(.03)
    var ring: MeshInstance3D=combat.get_node_or_null(
        "AuroraPhysicalBlastRing") as MeshInstance3D
    if ring==null or rival.health>=200.0:
        push_error("V75148_GRENADE_CAPTURE detonation has no true damage/ring")
        quit(5)
        return
    for i in range(3):
        await process_frame
    if not await _screen("real-grenade-blast",tag):
        quit(6)
        return
    game.queue_free()
    await process_frame
    print("V75148_GRENADE_CAPTURE PASS 964x434 screenshots=2 "+
        "grenade_real=1 AI_damage=1 shockwave_real=1 mobile_hardware=NO")
    quit(0)
