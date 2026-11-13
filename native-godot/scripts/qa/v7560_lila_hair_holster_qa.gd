extends SceneTree
## V75.60 — physically skinned original hair and weapon holstering in
## real Main.tscn and rotating lobby. No dummy assets or fake network clients.
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7560_LILA_HOLSTERS "+reason)


func _find_hair(avatar: Node3D,context: String) -> MeshInstance3D:
    check(avatar!=null,context+" has no skinned humanoid")
    if avatar==null:
        return null
    var hair: MeshInstance3D=avatar.find_child(
        "LilaAuroraOriginalHair",true,false) as MeshInstance3D
    check(hair!=null,context+" does not load original Aurora hair GLB")
    if hair==null:
        return null
    check(hair.visible and hair.skin!=null and
        not hair.skeleton.is_empty(),
        context+" hair is decorative, unskinned or invisible")
    check(hair.mesh!=null and hair.mesh.get_surface_count()==3,
        context+" hairstyle lost its three shared original PBR materials")
    if hair.mesh!=null:
        var surface_count: int=hair.mesh.get_surface_count()
        var poly_count: int=0
        for surface in range(surface_count):
            var mat: Material=hair.mesh.surface_get_material(surface)
            check(mat!=null and mat.resource_name.begins_with(
                "LilaAuroraHair"),context+" hair material isn't original Aurora art")
            poly_count+=hair.mesh.surface_get_array_len(surface)
        check(poly_count>=1200 and poly_count<6000,
            context+" hairstyle is missing or exceeds bounded mobile mesh size")
    var skeleton: Skeleton3D=avatar.find_child(
        "Skeleton3D",true,false) as Skeleton3D
    check(skeleton!=null and skeleton.get_bone_count()>35,
        context+" hairstyle severed the authored humanoid skeleton")
    return hair


func _verify() -> void:
    check(str(ProjectSettings.get_setting(
        "rendering/renderer/rendering_method.mobile"))=="mobile",
        "Android must remain Vulkan Mobile only")
    var scene: PackedScene=load("res://scenes/Main.tscn") as PackedScene
    check(scene!=null,"original battle Royale scene missing")
    if scene==null:
        quit(1)
        return
    var world: Node3D=scene.instantiate()
    root.add_child(world)
    var player: CharacterBody3D=world.get_node("Operator")
    var combat: Node3D=world.get_node("CombatRange")
    var director: Node3D=world.get_node("AuroraSectorMatch")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    player.set_physics_process(false)
    combat.set_process(false)
    director.set_process(false)

    var playable_hair: MeshInstance3D=_find_hair(
        player._avatar,"Lila in third-person gameplay")
    var visuals: Node3D=combat._weapon_visuals
    check(visuals!=null and visuals.get("attachment_uses_hand"),
        "original skinned right-hand weapon socket lost")
    check(visuals.get("spine_socket") is BoneAttachment3D and
        visuals.get("back_mount") is Node3D,
        "original skeleton is not driving the back rifle holster")
    var back_ak: Node3D=visuals.get("back_ak") as Node3D
    var back_awm: Node3D=visuals.get("back_awm") as Node3D
    check(back_ak!=null and back_awm!=null,
        "both actual weapon GLBs must be physically mountable on Lila")
    if back_ak!=null and back_awm!=null:
        check(visuals.ak.visible and back_awm.visible and
            not back_ak.visible and not visuals.awm.visible,
            "training inventory with AR equipped must stow the owned AWM")
        var socket: BoneAttachment3D=visuals.spine_socket
        check(socket.bone_name.to_lower().ends_with("spine"),
            "back mount is parented to scenery or camera instead of torso")
        check(socket.get_parent() is Skeleton3D,
            "back rifle holster isn't part of animated humanoid skeleton")
        check(back_awm.global_position.is_finite() and
            back_awm.global_position.distance_to(player.global_position)<3.0,
            "stowed AWM is misplaced outside Lila's actual 3D body")

    # BR resets ownership: do not show a sniper weapon not collected yet.
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(combat.weapon_owned==[true,false] and
        not visuals.awm_owned and visuals.ak.visible and
        not visuals.awm.visible and
        (back_awm==null or not back_awm.visible) and
        (back_ak==null or not back_ak.visible),
        "uncollected AWM appeared on back after new BR deployment")
    combat._equip_inventory_weapon(1)
    check(combat.weapon_index==0 and visuals.selected_weapon==0,
        "back holster allowed equipping a gun without physical ownership")
    var pickup: Area3D=director.get_node("AuroraAWMWeaponPickup")
    var loot_before: int=director.get_loot_remaining()
    player.global_position=pickup.global_position-Vector3.UP
    player.velocity=Vector3.ZERO
    await physics_frame
    await physics_frame
    if is_instance_valid(pickup) and not pickup.collected:
        pickup._collect(player)
    check(combat.weapon_owned[1] and visuals.awm_owned and
        director.get_loot_remaining()==loot_before-1 and
        back_awm!=null and back_awm.visible,
        "real AWM pickup didn't move its actual 3D model to Lila's back")

    combat._equip_inventory_weapon(1)
    check(combat.weapon_index==1 and visuals.selected_weapon==1 and
        visuals.awm.visible and not visuals.ak.visible and
        back_ak!=null and back_ak.visible and not back_awm.visible,
        "equipping AWM didn't atomically holster AR-7 and unholster AWM")
    combat._equip_inventory_weapon(0)
    check(combat.weapon_index==0 and visuals.selected_weapon==0 and
        visuals.ak.visible and not visuals.awm.visible and
        back_awm!=null and back_awm.visible and not back_ak.visible,
        "swapping back to AR didn't holster the AWM behind the shoulder")

    # Existing opponents retain active combat bodies without copying
    # the protagonist's distinctive original hair or outfit.
    var enemy: CharacterBody3D=combat._targets[0]
    var enemy_rig: Node3D=enemy.get("_rig") as Node3D
    check(enemy_rig!=null and enemy.get_node_or_null(
        "OpponentCollider")!=null,
        "enemy LOD/physics was lost while dressing Lila")
    if enemy_rig!=null:
        var forbidden_hair: MeshInstance3D=enemy_rig.find_child(
            "LilaAuroraOriginalHair",true,false) as MeshInstance3D
        check(forbidden_hair!=null and not forbidden_hair.visible,
            "AI enemy is incorrectly wearing Lila's unique hair")

    var frontend: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(frontend)
    frontend._show_lobby()
    var lobby_hair: MeshInstance3D=_find_hair(
        frontend._preview_avatar,"Lila in rotating 3D lobby")
    check(frontend._preview_container.visible and
        frontend._preview_caption.text.contains("LILA"),
        "actual 3D Lila portrait disappeared from lobby")
    if playable_hair!=null and lobby_hair!=null:
        check(playable_hair.mesh.resource_path==lobby_hair.mesh.resource_path,
            "lobby and match use different invented hairstyles")
        check(playable_hair.mesh.get_surface_count()==
            lobby_hair.mesh.get_surface_count(),
            "Lila wardrobe was replaced by a different static lobby render")
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    check(combat.weapon_index==0 and not visuals.awm_owned and
        (back_awm==null or not back_awm.visible),
        "next round leaked the previous AWM into Lila's holster")
    if not failed:
        print("V7560_LILA_HOLSTERS PASS original_hair=1 "+
            "shared_lobby_model=1 original_skin=1 materials=3 "+
            "spine_holster=1 actual_awm_pickup=1 "+
            "weapon_switching=1 no_unowned_sniper=1 "+
            "enemy_identity=1 collision=preserved reset=clean vulkan=1")
    quit(1 if failed else 0)
