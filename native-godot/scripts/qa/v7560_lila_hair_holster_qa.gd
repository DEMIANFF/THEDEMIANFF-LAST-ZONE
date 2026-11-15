extends SceneTree
## Weapon ownership and physically attached holsters on the Lila skeleton.
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7560_LILA_HOLSTERS "+reason)


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

    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    check(combat.weapon_index==0 and not visuals.awm_owned and
        (back_awm==null or not back_awm.visible),
        "next round leaked the previous AWM into Lila's holster")
    player.air_mode="freefall"
    visuals._process(0.0)
    check(not visuals.ak.visible and back_ak.visible,
        "Lila's rifle was still in hand during freefall")
    player.air_mode="parachute"
    visuals._process(0.0)
    check(not visuals.ak.visible and back_ak.visible,
        "Lila's rifle occupied a hand during the canopy pose")
    player.air_mode="ground"
    visuals._process(0.0)
    check(visuals.ak.visible and not back_ak.visible,
        "Lila did not draw the owned rifle after landing")
    if not failed:
        print("V7560_LILA_HOLSTERS PASS lila_skeleton=1 "+
            "spine_holster=1 actual_awm_pickup=1 "+
            "weapon_switching=1 no_unowned_sniper=1 "+
            "enemy_identity=1 collision=preserved reset=clean flight_holster=1 vulkan=1")
    quit(1 if failed else 0)
