extends SceneTree
## Deterministic samples of the REAL gameplay AnimationTree and reload timeline.
## These images are desktop evidence, not a physical Android acceptance test.
const CATALOG=preload("res://scripts/combat/aurora_weapon_catalog.gd")
var game: Node3D
var combat: Node3D
var player: CharacterBody3D
var controller: Node
var records: Array[Dictionary]=[]
var failed: bool=false


func _initialize() -> void:
    call_deferred("_capture")


func advance_pose(seconds: float) -> void:
    var remaining: float=seconds
    while remaining>0.0:
        var step: float=minf(remaining,1.0/60.0)
        combat._process(step)
        controller.tree.advance(step)
        combat._weapon_visuals._process(step)
        remaining-=step


func save_pose(slot: int, pose: String) -> void:
    combat._weapon_visuals._process(0.0)
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var path: String="res://out/aurora-v3-weapons/%02d-%s.png"%[slot,pose]
    if root.get_texture().get_image().save_png(path)!=OK:
        failed=true
        push_error("Could not save Godot weapon capture "+path)
    var visual: Node3D=combat._weapon_visuals
    records.append({"slot":slot,"weapon":CATALOG.ENTRIES[slot]["short"],
        "pose":pose,"image":path,"length_m":visual.equipped_global_length(),
        "action":player._combat_action,"reload_remaining":combat.reload_timer,
        "visual_position":str(visual.currently_equipped().global_position),
        "muzzle_world":str(visual.muzzle_position()),
        "right_hand_world":str(visual.right_hand_socket.global_position),
        "left_hand_world":str(visual.support_socket.global_position) if visual.support_socket else "",
        "renderer":RenderingServer.get_current_rendering_method(),
        "physical_motorola_test":false})


func _capture() -> void:
    DirAccess.make_dir_recursive_absolute("res://out/aurora-v3-weapons")
    game=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    combat=game.get_node("CombatRange")
    player=game.get_node("Operator")
    player.set_physics_process(false)
    combat.set_process(false)
    game.get_node("TrainingHUD").hide()
    for bot: CharacterBody3D in combat._targets:
        bot.set_physics_process(false)
    player.global_position=Vector3(0,game.island.height_at(0,0),0)
    player.rotation=Vector3.ZERO
    player._avatar.visible=true
    controller=player._animation_controller
    controller.set_process(false)
    controller.tree.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    var review_camera:=Camera3D.new()
    game.add_child(review_camera)
    review_camera.global_position=player.global_position+Vector3(1.6,1.45,-2.2)
    review_camera.look_at(player.global_position+Vector3(0,1.12,-.25))
    review_camera.fov=40.0
    review_camera.current=true
    combat.open_training_armory()
    for kind in ["weapon_scar","weapon_mp40","weapon_kriss"]:
        if not combat.collect_sector_loot(kind):
            push_error("Cannot capture missing gameplay weapon "+kind)
            quit(1)
            return
    for slot in range(CATALOG.ENTRIES.size()):
        combat._equip_inventory_weapon(slot)
        player.set_equipped_weapon(slot)
        controller.reset_ground_pose()
        advance_pose(.25)
        await save_pose(slot,"idle")
        combat.cooldown=0.0
        combat._shoot()
        advance_pose(.07)
        await save_pose(slot,"fire")
        # Trigger a real magazine transaction; sample its action and MP40 parts
        # from the authoritative timer, rather than fabricating AnimationPlayer poses.
        combat._on_reload()
        var duration: float=CATALOG.ENTRIES[slot]["reload"]
        var previous: float=0.0
        for phase: float in [.15,.38,.64,.85,.99]:
            advance_pose((phase-previous)*duration)
            await save_pose(slot,"reload_%02d"%roundi(phase*100))
            previous=phase
        advance_pose(.02*duration)
        await save_pose(slot,"ready")
        combat._weapon_visuals.set_medical_busy(true)
        await save_pose(slot,"holster")
        combat._weapon_visuals.set_medical_busy(false)
    var file:=FileAccess.open("res://out/aurora-v3-weapons/poses.json",FileAccess.WRITE)
    if file==null:
        push_error("Missing weapon capture manifest")
        quit(1)
        return
    file.store_string(JSON.stringify(records,"  "))
    print("AURORA_POSES_JSON ",JSON.stringify(records))
    file.close()
    print("AURORA_V3_WEAPON_CAPTURE PASS weapons=5 poses=",records.size(),
        " renderer=",RenderingServer.get_current_rendering_method(),
        " physical_motorola_test=false")
    game.queue_free()
    await process_frame
    quit(1 if failed else 0)
