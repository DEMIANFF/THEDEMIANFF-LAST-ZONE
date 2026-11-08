extends SceneTree
## Weapon-geometry acceptance: actual GLB scene instances, world-scale, hand
## socket, animations, x8 exclusive to AWM and 0.50s one-shot bolt cooldown.
## CI tests do not prove physical Motorola graphics or touch handling.


func _initialize() -> void:
    call_deferred("_verify")


func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player:=game.get_node("Operator") as CharacterBody3D
    var combat:=game.get_node("CombatRange") as Node3D
    var weapons: Node3D=combat._weapon_visuals
    if weapons==null or weapons.ak==null or weapons.awm==null:
        push_error("GLB weapon visual not imported: expected AK74 and AWM")
        quit(110)
        return
    if not weapons.attachment_uses_hand or weapons.right_hand_socket==null:
        push_error("No actual Skeleton3D hand socket for rifle visuals")
        quit(111)
        return
    var skeleton:=weapons.right_hand_socket.get_parent() as Skeleton3D
    if skeleton==null or skeleton.find_bone(weapons.right_hand_socket.bone_name)<0:
        push_error("Right-hand socket does not resolve to a real skeleton bone")
        quit(112)
        return
    var rig:=player.get_node("AuroraFemaleRiggedOperator") as Node3D
    var animator:=rig.find_child("AnimationPlayer",true,false) as AnimationPlayer
    if animator==null:
        push_error("Arm animation player missing")
        quit(113)
        return
    var available: PackedStringArray=animator.get_animation_list()
    for clip in ["AuroraArmedIdle","AuroraArmedWalk","AuroraArmedRun",
                "AuroraAim","AuroraAimAWM","AuroraReloadAWM"]:
        if not available.has(clip):
            push_error("Real rig missing armed pose animation: "+clip)
            quit(114)
            return
    await process_frame
    for i in range(10):
        await process_frame
    # Combat hands must be *ahead* of the player, not folded behind the back.
    # The former source FBX pose solver aimed towards the wrong signed Z axis.
    var grip_world: Vector3=weapons.right_hand_socket.global_position
    var torso: Vector3=player.global_position + Vector3.UP*1.25
    var forward: Vector3=-player.global_transform.basis.z.normalized()
    var ahead: float=(grip_world-torso).dot(forward)
    print("V74_1_RIG_GRIP_AHEAD_METRES ",ahead)
    if ahead<.05:
        push_error("Weapon hand behind player's back, no usable aiming pose: "+str(ahead))
        quit(125)
        return
    if not weapons.ak.visible or weapons.awm.visible:
        push_error("AR/AK74 starting visual state wrong")
        quit(115)
        return
    weapons._process(.016)
    var ak_length: float=weapons.equipped_global_length()
    var ak_extents: Vector3=weapons.equipped_global_extents()
    if ak_extents.y>maxf(ak_extents.x,ak_extents.z)*.90:
        push_error("AK74 floats vertically in third person instead of horizontal combat carry")
        quit(123)
        return
    if ak_length<.70 or ak_length>2.0:
        push_error("AK74 globally tiny/huge after skinned-FBX scale: "+str(ak_length))
        quit(116)
        return
    combat._on_weapon()
    await process_frame
    if weapons.ak.visible or not weapons.awm.visible or combat.weapon_index!=1:
        push_error("Switching to AWM did not display real AWM mesh")
        quit(117)
        return
    weapons._process(.016)
    var awm_length: float=weapons.equipped_global_length()
    var awm_extents: Vector3=weapons.equipped_global_extents()
    if awm_extents.y>maxf(awm_extents.x,awm_extents.z)*.90:
        push_error("AWM barrel floats vertically after rigging: "+str(awm_extents))
        quit(124)
        return
    if awm_length<.95 or awm_length>2.4:
        push_error("AWM globally tiny/huge after skinned-FBX scale: "+str(awm_length))
        quit(118)
        return
    combat._on_aim()
    if not is_equal_approx(combat.current_zoom,8.0):
        push_error("AWM x8 exclusivity lost")
        quit(119)
        return
    var ammo_start: int=combat.ammo[1]
    combat.cooldown=0.0
    combat._on_fire_pressed()
    if combat.ammo[1]!=ammo_start-1 or combat.cooldown<.49:
        push_error("AWM bullet/cycle must be one shot with 0.50s bolt")
        quit(120)
        return
    combat._process(.6)
    if combat.ammo[1]!=ammo_start-1:
        push_error("AWM autoshot under held trigger")
        quit(121)
        return
    combat._on_fire_released()
    combat._on_weapon()
    if not weapons.ak.visible or weapons.awm.visible:
        push_error("Returning to AR did not restore the AK74 model")
        quit(122)
        return
    print("V74.1 WEAPON VISUAL PASS: 2 real GLBs on hand socket, scale AK=",
          ak_length,"m AWM=",awm_length,
          "m, gun horizontal AR=",ak_extents,
          " AWM=",awm_extents,
          " arm clips, x8 scoped one-shot AWM 0.5s")
    quit(0)
