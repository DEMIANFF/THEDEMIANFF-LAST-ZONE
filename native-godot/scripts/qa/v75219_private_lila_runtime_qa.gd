extends SceneTree
const SOURCE=preload("res://scripts/player/aurora_lila_source.gd")
var failed: bool=false
func _initialize() -> void:
    call_deferred("_verify")
func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V75219_LILA_RUNTIME "+why)
func mesh_contract(avatar: Node3D,private: bool) -> void:
    check(avatar!=null,"missing avatar")
    if avatar==null:
        return
    check(bool(avatar.get_meta("aurora_private_lila_rev9",false))==private,"wrong source marker")
    var mesh: MeshInstance3D=avatar.find_child("Lila_Aurora_Mesh",true,false) as MeshInstance3D
    var rig: Skeleton3D=avatar.find_child("Skeleton3D",true,false) as Skeleton3D
    check(mesh!=null and rig!=null,"missing mesh or skeleton")
    if private and mesh!=null and rig!=null:
        var arrays: Array=mesh.mesh.surface_get_arrays(0)
        check(arrays[Mesh.ARRAY_VERTEX].size()==93572 and arrays[Mesh.ARRAY_INDEX].size()==95885*3 and rig.get_bone_count()==56,"wrong private geometry or rig")
func _verify() -> void:
    var args: PackedStringArray=OS.get_cmdline_user_args()
    var private: bool=args.has("--private")
    var capture: bool=args.has("--capture")
    # This QA does not modify the user-provided scene or any saved profile.
    var source: PackedScene=SOURCE.scene()
    check(source!=null and (source.resource_path==SOURCE.PRIVATE_PATH)==private,"resolver source")
    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    front._enter_local_lobby()
    await process_frame
    front._layout_safe()
    await process_frame
    mesh_contract(front._preview_avatar,private)
    var anim: AnimationPlayer=front._preview_avatar.find_child("AnimationPlayer",true,false) as AnimationPlayer
    check(anim.has_animation("AuroraIdle") and anim.has_animation("aurora_lobby/Motion"),"lobby motion missing")
    front._preview_resume_spin=100.0
    front._preview_avatar.rotation.y=0.0
    anim.play("AuroraIdle")
    anim.advance(.36)
    if capture:
        for i in range(3):
            await process_frame
            await RenderingServer.frame_post_draw
        check(root.get_texture().get_image().save_png("user://lila_lobby_"+("private" if private else "baseline")+".png")==OK,"lobby capture")
    front._play_lobby_gesture()
    check(anim.current_animation=="aurora_lobby/Motion","emote did not play")
    anim.advance(.8)
    for i in range(3):
        await process_frame
    anim.play("AuroraIdle")
    front._select_tab("PERSONAJE")
    front._on_shop_skin_selected(2)
    check(front._preview_skin_applied=="aurora_ember","skin preview")
    front._select_tab("JUGAR")
    check(front._portrait_character_hit_rect().has_area(),"touch target lost")
    print("V75219_LOBBY private=",private," motion=",anim.get_animation_list().size()," body=",front._preview_avatar.find_child("Lila_Aurora_Mesh",true,false).mesh.resource_name)
    front.queue_free()
    await process_frame
    await process_frame
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    mesh_contract(player._avatar,private)
    var combat: Node3D=game.get_node("CombatRange")
    for bot in combat._targets:
        bot.set_physics_process(false)
    for i in range(45):
        await physics_frame
    player.set_crouch(true)
    player.set_ads(true,2.0)
    for i in range(45):
        await physics_frame
    check(player._current_clip.begins_with("AuroraCrouch") and player._body_contact!=null,"playable crouch or body correction absent")
    check(combat._weapon_visuals._support_ik.solved,"playable grip not solved")
    print("V75219_MAIN private=",private," clip=",player._current_clip," support_error=",combat._weapon_visuals._support_ik.last_error_m)
    game.queue_free()
    await process_frame
    if not failed:
        print("V75219_LILA_RUNTIME PASS private=",private)
    quit(1 if failed else 0)
