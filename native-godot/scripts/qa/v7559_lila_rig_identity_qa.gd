extends SceneTree
## Check the supplied Lila mesh in both actual gameplay scenes.
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7559_LILA_RIG "+reason)


func verify_lila_mesh(container: Node3D,context: String) -> MeshInstance3D:
    check(container!=null,context+" missing Lila")
    if container==null:
        return null
    var body:=container.find_child("Lila_Aurora_Mesh",true,false) as MeshInstance3D
    var skeleton:=container.find_child("Skeleton3D",true,false) as Skeleton3D
    check(skeleton!=null and skeleton.get_bone_count()==56,
        context+" does not have the 56 joints from the supplied GLB")
    check(body!=null and body.skin!=null and not body.skeleton.is_empty(),
        context+" supplied Lila mesh is missing or unskinned")
    var geometry:=body.mesh as ArrayMesh if body!=null else null
    check(geometry!=null and geometry.get_surface_count()==1,
        context+" Lila is missing its single skinned surface")
    if geometry!=null and geometry.get_surface_count()==1:
        check(geometry.surface_get_array_index_len(0)==287655,
            context+" mesh differs from the supplied Lila geometry")
        var material:=geometry.surface_get_material(0) as StandardMaterial3D
        check(material!=null and material.albedo_texture!=null and
            material.albedo_texture.get_width()<=2048,
            context+" Lila texture is absent or above the mobile budget")
        check((geometry.surface_get_format(0) & Mesh.ARRAY_FORMAT_TEX_UV2)!=0,
            context+" Lila clothing mask was lost during import")
    return body

func _verify() -> void:
    check(str(ProjectSettings.get_setting(
        "rendering/renderer/rendering_method.mobile"))=="mobile",
        "Vulkan Mobile is not the only Android renderer")
    var source: PackedScene=load(
        "res://assets/characters/lila_aurora.glb") as PackedScene
    check(source!=null,"game omitted the supplied Lila GLB")
    if source==null:
        quit(1)
        return
    var real_game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(real_game)
    var player: CharacterBody3D=real_game.get_node("Operator")
    var combat: Node3D=real_game.get_node("CombatRange")
    for opponent in combat._targets:
        opponent.set_physics_process(false)
    player.set_physics_process(false)
    await physics_frame

    var body: MeshInstance3D=verify_lila_mesh(
        player._avatar,"TPS operator")
    var capsule: CollisionShape3D=player.get_node("CapsuleCollider")
    check(capsule.shape is CapsuleShape3D and
        absf((capsule.shape as CapsuleShape3D).height-1.82)<.01,
        "visual upgrade changed the stable player physics collider")
    var camera: Camera3D=player.get_view_camera()
    check(camera!=null and camera.position.z>3.9,
        "new visual displaced the third-person camera toward Lila")
    check(player._animation_controller!=null and
        player._animation_controller.tree.active,
        "Aurora upper-body/locomotion AnimationTree disconnected")
    if player._animator!=null:
        for clip in [
            "AuroraIdle","AuroraArmedIdle","AuroraArmedWalk",
            "AuroraArmedRun","AuroraAim","AuroraAimAWM",
            "AuroraFire","AuroraReloadAR","AuroraReloadAWM",
            "AuroraJump","AuroraFreefall","AuroraParachute",
            "AuroraCrouch","AuroraCrouchWalk"]:
            check(player._animator.has_animation(clip),
                "Lila rig lost required animation clip "+clip)
    var enemy: CharacterBody3D=combat._targets[0]
    var enemy_rig: Node3D=enemy.get("_rig") as Node3D
    check(enemy_rig!=null,"physical near-range opponent lost skinned body")
    if enemy_rig!=null:
        var enemy_kit: MeshInstance3D=enemy_rig.find_child(
            "LilaAuroraSignatureKit",true,false) as MeshInstance3D
        check(enemy_rig.find_child("Lila_Aurora_Mesh",true,false)==null and
            enemy_kit!=null and not enemy_kit.visible,
            "enemies must not wear Lila's original signature outfit")
        check(enemy.get_node_or_null("OpponentCollider")!=null,
            "making outfits distinct must not remove physical AI collisions")
    var frontend: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(frontend)
    frontend._show_lobby()
    var avatar: Node3D=frontend._preview_avatar
    var lobby_body: MeshInstance3D=verify_lila_mesh(
        avatar,"360-degree lobby portrait")
    check(frontend._preview_container!=null and
        frontend._preview_container.visible,
        "Lila cannot be rotated in the original 3D lobby")
    check(frontend._preview_caption!=null and
        frontend._preview_caption.text.contains("LILA AURORA"),
        "lobby lost the Lila Aurora identity")
    if body!=null and lobby_body!=null:
        check(body.mesh.get_surface_count()==lobby_body.mesh.get_surface_count(),
            "the lobby and in-match Lila are different costume assets")
        check(body.mesh.resource_path==lobby_body.mesh.resource_path,
            "the game is loading separate Lila visual mesh resources")
    if not failed:
        print("V7559_LILA_RIG PASS source_mesh=1 surfaces=1 joints=56 "+
            "authored_clips=14 lobby3d=1 game3d=1 exclusive_to_lila=1 "+
            "collision=preserved camera=preserved vulkan=1")
    quit(1 if failed else 0)
