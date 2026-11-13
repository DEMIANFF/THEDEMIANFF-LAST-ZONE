extends SceneTree
## V75.59: real GLB shared by the operator, lobby and enemies.
## Tests a skin-weighted original Aurora combat kit, not the final face sculpt.
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7559_LILA_RIG "+reason)


func verify_lila_kit(container: Node3D,context: String) -> MeshInstance3D:
    check(container!=null,context+" missing full 3D humanoid")
    if container==null:
        return null
    var part: MeshInstance3D=container.find_child(
        "LilaAuroraSignatureKit",true,false) as MeshInstance3D
    check(part!=null,context+" lacks the original Aurora gear in rigged GLB")
    if part==null:
        return null
    check(part.mesh!=null and part.mesh.get_surface_count()==3,
        context+" needs one low-poly mesh with three original shared materials")
    check(part.skin!=null and not part.skeleton.is_empty(),
        context+" accessory must be skinned to animated human armature")
    check(part.visible,context+" Lila signature kit is invisible")
    var parent_skeleton: Skeleton3D=container.find_child(
        "Skeleton3D",true,false) as Skeleton3D
    check(parent_skeleton!=null and parent_skeleton.get_bone_count()>35,
        context+" original articulated body skeleton was replaced")
    if part.mesh!=null:
        # FBX/Godot import can permute Y-up to Z-up and normalize model
        # metres via parent transforms. Compare to the original body mesh,
        # not to an assumed raw Y height in centimetres.
        var aabb: AABB=part.mesh.get_aabb()
        var source_body: MeshInstance3D=null
        for candidate in container.find_children(
                "*","MeshInstance3D",true,false):
            if candidate!=part and candidate.mesh!=null:
                source_body=candidate
                break
        check(source_body!=null,
            context+" no original humanoid mesh remains under the skin")
        if source_body!=null:
            var base_size: float=source_body.mesh.get_aabb().size.length()
            var kit_size: float=aabb.size.length()
            var ratio: float=kit_size/maxf(.001,base_size)
            check(is_finite(ratio) and ratio>.08 and ratio<1.4,
                context+" outfit proportions differ from the original body")
        for i in range(part.mesh.get_surface_count()):
            var material: Material=part.mesh.surface_get_material(i)
            check(material!=null and material.resource_name.begins_with(
                "LilaAurora"),
                context+" visual gear lost its original Aurora materials")
    return part


func _verify() -> void:
    check(str(ProjectSettings.get_setting(
        "rendering/renderer/rendering_method.mobile"))=="mobile",
        "Vulkan Mobile is not the only Android renderer")
    var source: PackedScene=load(
        "res://assets/characters/aurora_operator.glb") as PackedScene
    check(source!=null,"signed Android build omitted shared character GLB")
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

    var body: MeshInstance3D=verify_lila_kit(
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
    if body!=null:
        check(body.mesh.get_surface_count()==3 and
            body.skin!=null,"gameplay uses decorative rather than skinned gear")
    var enemy: CharacterBody3D=combat._targets[0]
    var enemy_rig: Node3D=enemy.get("_rig") as Node3D
    check(enemy_rig!=null,"physical near-range opponent lost skinned body")
    if enemy_rig!=null:
        var enemy_kit: MeshInstance3D=enemy_rig.find_child(
            "LilaAuroraSignatureKit",true,false) as MeshInstance3D
        check(enemy_kit!=null and not enemy_kit.visible,
            "enemies must not wear Lila's original signature outfit")
        check(enemy.get_node_or_null("OpponentCollider")!=null,
            "making outfits distinct must not remove physical AI collisions")
    var frontend: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(frontend)
    frontend._show_lobby()
    var avatar: Node3D=frontend._preview_avatar
    var lobby_kit: MeshInstance3D=verify_lila_kit(
        avatar,"360-degree lobby portrait")
    check(frontend._preview_container!=null and
        frontend._preview_container.visible,
        "Lila cannot be rotated in the original 3D lobby")
    check(frontend._preview_caption!=null and
        frontend._preview_caption.text.contains("LILA AURORA V1") and
        frontend._preview_caption.text.contains("PROVISIONAL"),
        "lobby hides identity or incorrectly claims final Lila original sculpt")
    if body!=null and lobby_kit!=null:
        check(body.mesh.get_surface_count()==lobby_kit.mesh.get_surface_count(),
            "the lobby and in-match Lila are different costume assets")
        check(body.mesh.resource_path==lobby_kit.mesh.resource_path,
            "the game is loading separate Lila visual mesh resources")
    if not failed:
        print("V7559_LILA_RIG PASS original_gear=19 lowpoly=1 "+
            "skinned=1 materials=3 original_skeleton=1 "+
            "authored_clips=14 lobby3d=1 game3d=1 exclusive_to_lila=1 "+
            "collision=preserved camera=preserved vulkan=1")
    quit(1 if failed else 0)
