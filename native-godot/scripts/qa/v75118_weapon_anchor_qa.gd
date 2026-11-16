extends SceneTree
const CATALOG=preload("res://scripts/combat/aurora_weapon_catalog.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V75118_ANCHORS "+message)


func world_bounds(visual: Node3D) -> AABB:
    var lower:=Vector3(INF,INF,INF)
    var upper:=Vector3(-INF,-INF,-INF)
    for child in visual.find_children("*","MeshInstance3D",true,false):
        var mesh:=child as MeshInstance3D
        for corner in range(8):
            var point: Vector3=mesh.to_global(mesh.get_aabb().get_endpoint(corner))
            lower=lower.min(point)
            upper=upper.max(point)
    return AABB(lower,upper-lower)


func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    var combat: Node3D=game.get_node("CombatRange")
    player.set_physics_process(false)
    combat.set_process(false)
    for bot: CharacterBody3D in combat._targets:
        bot.set_physics_process(false)
    combat.open_training_armory()
    var pickup: Area3D=combat._training_armory.get_node("Training_weapon_scar")
    var ground_grip:=pickup.find_child("Grip",true,false) as Node3D
    check(ground_grip!=null,"world pickup lacks its model grip")
    if ground_grip:
        var model:=ground_grip.get_parent() as Node3D
        check(world_bounds(model).grow(.04).has_point(ground_grip.global_position),
            "world SCAR geometry is detached from its pickup anchor")
        check(ground_grip.global_position.distance_to(pickup.global_position)<.3,
            "world SCAR lies outside its collectible beacon")
    for kind in ["weapon_scar","weapon_mp40","weapon_kriss"]:
        check(combat.collect_sector_loot(kind),"weapon not collectible: "+kind)
    for frame in range(12):
        await process_frame
    var visuals: Node3D=combat._weapon_visuals
    for slot in [CATALOG.AWM,CATALOG.SCAR]:
        combat._equip_inventory_weapon(slot)
        for frame in range(3):
            await process_frame
        visuals._process(.016)
        var weapon: Node3D=visuals.currently_equipped()
        var grip:=weapon.find_child("Grip",true,false) as Node3D
        var muzzle:=weapon.find_child("Muzzle",true,false) as Node3D
        var support:=weapon.find_child("SupportGrip",true,false) as Node3D
        check(grip!=null and muzzle!=null and support!=null,"missing physical anchor")
        if grip==null or muzzle==null or support==null:
            continue
        var bounds: AABB=world_bounds(weapon)
        var hand_gap: float=grip.global_position.distance_to(
            visuals.right_hand_socket.global_position)
        var forward: Vector3=-player.global_basis.z
        var barrel_forward: float=(muzzle.global_position-grip.global_position).dot(forward)
        check(hand_gap<.08,"pistol grip detached from right hand")
        check(bounds.grow(.04).has_point(muzzle.global_position),
            "muzzle marker outside the actual weapon geometry")
        check(bounds.grow(.04).has_point(grip.global_position),
            "grip marker outside the actual weapon geometry")
        check(barrel_forward>.5,"barrel points backwards")
        check(muzzle.global_position.y>grip.global_position.y,
            "barrel below pistol grip: rifle upside down")
        check(visuals.muzzle_position().distance_to(muzzle.global_position)<.001,
            "physical shot origin differs from visible muzzle")
        print("AURORA_ANCHOR_MEASURE weapon=",CATALOG.ENTRIES[slot]["short"],
            " right_hand_gap_m=",hand_gap," barrel_forward_m=",barrel_forward,
            " support_hand_gap_m=",support.global_position.distance_to(
                visuals.support_socket.global_position))
    # Check the rendered bone attachment, not just an IK target or flag.
    for slot in range(CATALOG.ENTRIES.size()):
        combat._equip_inventory_weapon(slot)
        player.set_equipped_weapon(slot)
        player._animation_controller.reset_ground_pose()
        for frame in range(20):
            await process_frame
        var support: Node3D=visuals.support_grip_anchor()
        check(support!=null,"missing support anchor for slot "+str(slot))
        if support:
            var gap: float=support.global_position.distance_to(
                visuals.support_socket.global_position)
            check(gap<.045,"support hand detached for slot "+str(slot)+": "+str(gap))
            check(world_bounds(visuals.currently_equipped()).grow(.045).has_point(
                support.global_position),"support anchor outside weapon geometry")
            print("AURORA_SUPPORT_MEASURE weapon=",CATALOG.ENTRIES[slot]["short"],
                " actual_hand_gap_m=",gap," solver_error_m=",visuals._support_ik.last_error_m)
        player.play_weapon_action("reload",CATALOG.ENTRIES[slot]["reload"])
        for frame in range(3):
            await process_frame
        check(not visuals.support_grip_enabled(),"reload hand locked to foregrip")
        check(not visuals._support_ik.solved,"IK overrides reload animation")
        player._animation_controller.cancel_action()
        for frame in range(15):
            await process_frame
        check(visuals.support_grip_enabled(),"support grip did not return after reload")
    visuals.set_medical_busy(true)
    check(not visuals.support_grip_enabled(),"medical hand cannot release rifle")
    visuals.set_medical_busy(false)
    player.air_mode="parachute"
    check(not visuals.support_grip_enabled(),"support IK active while parachuting")
    player.air_mode="ground"
    game.queue_free()
    await process_frame
    if not failed:
        print("V75118_WEAPON_ANCHORS PASS grip_at_hand=1 forward_barrel=1 mesh_contains_anchors=1 physical_muzzle=1")
    quit(1 if failed else 0)
