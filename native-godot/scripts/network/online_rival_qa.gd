extends SceneTree
const SESSION=preload("res://scripts/network/aurora_online_session.gd")
const PRESENTATION=preload("res://scripts/network/online_presentation.gd")
const WEAPONS=preload("res://scripts/combat/aurora_weapon_catalog.gd")

func _initialize() -> void:
    call_deferred("_verify")

func _has_weapon(holder: Node3D,slot: int,visual_name: String) -> bool:
    var socket:=holder.find_child("OnlineRivalHandSocket",true,false) as BoneAttachment3D
    if socket==null or not socket.bone_name.to_lower().ends_with("righthand"):
        return false
    var visual:=socket.find_child(visual_name,true,false) as Node3D
    return int(holder.get_meta("weapon_slot",-1))==slot and visual!=null and visual.is_visible_in_tree() and not visual.find_children("*","MeshInstance3D",true,false).is_empty()

func _verify() -> void:
    var world: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    world.online_presentation_only=true
    root.add_child(world)
    var session:=SESSION.new()
    session.name="AuroraOnline"
    root.add_child(session)
    var view:=PRESENTATION.new()
    world.add_child(view)
    view.setup(world,session)
    view.send_controls=false
    if session.connect_local()!=OK:
        quit(1)
        return
    var rival_id: int=0
    var idle_ok: bool=false
    var move_ok: bool=false
    var occluded: bool=false
    var returned: bool=false
    var eliminated: bool=false
    var ar_ok: bool=false
    var fire_ok: bool=false
    var reload_ok: bool=false
    var hit_ok: bool=false
    var restored_weapon: bool=false
    var no_sim: bool=world.get_node_or_null("CombatRange")==null and world.get_node_or_null("AuroraSectorMatch")==null and world.get_node_or_null("AuroraNavigation")==null
    for i in range(600):
        await create_timer(.05).timeout
        if not view._has_state:
            continue
        var contacts: Array=session.state.rivals
        if rival_id==0:
            for item in contacts:
                if (item.position as Vector3).distance_to(Vector3(0,55,-37))<.1:
                    rival_id=int(item.id)
                    break
        if rival_id==0:
            continue
        var present: bool=false
        for item in contacts:
            if int(item.id)==rival_id:
                present=true
        if present and view.replicas.has(rival_id):
            var holder: Node3D=view.replicas[rival_id]
            var animator:=holder.find_child("AnimationPlayer",true,false) as AnimationPlayer
            if animator==null:
                continue
            if not idle_ok:
                var skeleton:=holder.find_child("Skeleton3D",true,false) as Skeleton3D
                var meshes: Array[Node]=holder.find_children("*","MeshInstance3D",true,false)
                idle_ok=skeleton!=null and skeleton.get_bone_count()>0 and not meshes.is_empty() and animator.current_animation=="AuroraIdle" and holder.is_visible_in_tree()
            if idle_ok and animator.current_animation=="AuroraWalk" and holder.global_position.distance_to(Vector3(1,55,-38))<.2 and absf(angle_difference(holder.rotation.y,.65))<.15:
                move_ok=true
            if animator.current_animation=="AuroraIdle" and _has_weapon(holder,WEAPONS.AR,"AK74OnlineRivalVisual"):
                ar_ok=true
            if animator.current_animation=="AuroraFire" and _has_weapon(holder,WEAPONS.AR,"AK74OnlineRivalVisual"):
                fire_ok=true
            if animator.current_animation=="AuroraReloadAR" and _has_weapon(holder,WEAPONS.AWM,"OnlineRivalWeaponVisual") and holder.find_child("AK74OnlineRivalVisual",true,false)==null:
                reload_ok=true
            if animator.current_animation=="AuroraHitFront" and _has_weapon(holder,WEAPONS.AWM,"OnlineRivalWeaponVisual"):
                hit_ok=true
            if occluded and animator.current_animation=="AuroraRun":
                returned=true
                restored_weapon=_has_weapon(holder,WEAPONS.AWM,"OnlineRivalWeaponVisual")
        elif not present and not view.replicas.has(rival_id) and not view.target_positions.has(rival_id):
            if move_ok and not returned:
                occluded=true
            elif returned:
                eliminated=true
                break
    var ok: bool=idle_ok and move_ok and occluded and returned and eliminated and no_sim
    print("V75228_RIVALS idle_rig=",idle_ok," movement=",move_ok," occlusion=",occluded," restored=",returned," eliminated_removed=",eliminated," no_local_ai=",no_sim)
    var weapons_ok: bool=ar_ok and fire_ok and reload_ok and hit_ok and restored_weapon
    print("V75229_WEAPONS ar_hand=",ar_ok," fire=",fire_ok," awm_switch_reload=",reload_ok," hit=",hit_ok," restored_awm=",restored_weapon)
    ok=ok and weapons_ok
    if ok:
        print("V75228_RIVALS PASS")
        print("V75229_WEAPONS PASS")
    else:
        push_error("V75228 remote rival regression")
    session.multiplayer.multiplayer_peer.close()
    quit(0 if ok else 1)
