extends SceneTree
## Two 964x434 captures from the real Godot Main.tscn battle.
## The rendered GLBs recoil in Lila's hand after actual ammo-consuming shots.
## Desktop OpenGL/Xvfb evidence, NOT a physical Motorola Vulkan test.
const WEAPONS=preload("res://scripts/combat/aurora_weapon_catalog.gd")
const CAPTURE=preload("res://scripts/qa/aurora_capture_version.gd")


func _initialize() -> void:
    call_deferred("_capture")


func _screen(name: String,tag: String) -> bool:
    await RenderingServer.frame_post_draw
    var png: Image=root.get_texture().get_image()
    var name_on_disk: String="res://out/aurora-"+tag+"-motorola-"+name+".png"
    if png.get_size()!=Vector2i(964,434) or png.save_png(name_on_disk)!=OK:
        push_error("V75152_CAPTURE cannot save live weapon frame "+name)
        return false
    print("V75152_CAPTURE "+name_on_disk)
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
    var operator: CharacterBody3D=game.get_node("Operator")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    combat.set_encounter_size(50)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    operator.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    for kind in ["weapon_scar","weapon_mp40"]:
        if not combat.collect_sector_loot(kind):
            push_error("V75152_CAPTURE actual GLB missing: "+kind)
            quit(3)
            return
    var gun: Node3D=combat._weapon_visuals
    for entry in [
        {"slot":WEAPONS.SCAR,"label":"real-scar-fire-recoil"},
        {"slot":WEAPONS.MP40,"label":"real-mp40-fire-recoil"}
    ]:
        var slot: int=entry["slot"]
        combat._equip_inventory_weapon(slot)
        combat.ammo[slot]=3
        combat.cooldown=0.0
        combat.reload_timer=0.0
        var held: Node3D=gun.currently_equipped()
        if held==null or not held.visible:
            push_error("V75152_CAPTURE actual equipped mesh missing "+str(slot))
            quit(4)
            return
        var rest: Transform3D=held.transform
        var before: int=combat.shots_fired_total
        combat._shoot()
        if (combat.shots_fired_total!=before+1 or
                gun._visual_recoil_left<=0.0 or
                held.transform.origin.distance_to(rest.origin)<.005):
            push_error("V75152_CAPTURE gun did not physically kick "+str(slot))
            quit(5)
            return
        await process_frame
        if not await _screen(str(entry["label"]),tag):
            quit(6)
            return
        gun.cancel_visual_recoil()
        if held.transform.origin.distance_to(rest.origin)>.0001:
            push_error("V75152_CAPTURE rifle did not return to real hand pose")
            quit(7)
            return
    game.queue_free()
    await process_frame
    print("V75152_CAPTURE PASS resolution=964x434 original_scar_mp40=2 "+
        "true_cartridges=2 actual_GLTF_recoil=2 photos=NO hardware_test=NO")
    quit(0)
