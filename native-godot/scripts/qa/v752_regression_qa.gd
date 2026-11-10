extends SceneTree
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool, message: String) -> void:
    if not ok:
        failed=true
        push_error("V752 "+message)

func frames(n: int) -> void:
    for i in range(n):
        await physics_frame

func _verify() -> void:
    var game: Node=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player=game.get_node("Operator")
    var combat=game.get_node("CombatRange")
    var hud=game.get_node("TrainingHUD")
    var director=game.get_node("AuroraSectorMatch")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await frames(40)
    var speeds: Array[float]=[]
    for strength in [.2,.5,1.0]:
        player.set_touch_move_axis(Vector2(0,-strength))
        await frames(22)
        speeds.append(Vector2(player.velocity.x,player.velocity.z).length())
    check(speeds[0]>0.0 and speeds[0]<speeds[1] and speeds[1]<speeds[2],"analog magnitude")
    print("V752_ANALOG ",speeds)
    player.set_touch_move_axis(Vector2.ZERO)
    player._desired_yaw=0.0
    player._turn_camera(Vector2(148,0))
    var single: float=player._desired_yaw
    player._desired_yaw=0.0
    player._turn_camera(Vector2(74,0))
    player._turn_camera(Vector2(74,0))
    check(is_equal_approx(single,player._desired_yaw),"event partition changed yaw")
    var crouch: Button=hud.get_node("AuroraTacticalOverlay/AGACHAR")
    check(player._touch_over_action_buttons(crouch.get_global_rect().get_center()),"crouch captured by look")
    player.set_crouch(true)
    player.set_ads(true,2.0)
    await frames(12)
    check(player._current_clip.begins_with("AuroraCrouch"),"ADS lost crouch")
    var rig=player.get_node("AuroraFemaleRiggedOperator")
    var skeleton: Skeleton3D=rig.find_child("Skeleton3D",true,false)
    var animator: AnimationPlayer=rig.find_child("AnimationPlayer",true,false)
    player.set_physics_process(false)
    var head: int=skeleton.find_bone("rig_Head")
    animator.play("AuroraArmedIdle",0)
    animator.advance(0.2)
    skeleton.force_update_all_bone_transforms()
    var standing: float=skeleton.to_global(skeleton.get_bone_global_pose(head).origin).y
    animator.play("AuroraCrouch",0)
    animator.advance(0.2)
    skeleton.force_update_all_bone_transforms()
    var crouched: float=skeleton.to_global(skeleton.get_bone_global_pose(head).origin).y
    print("V752_CROUCH_HEAD_DROP ",standing-crouched)
    check(standing-crouched>.35,"crouch pose did not lower head")
    player.set_physics_process(true)
    player.set_ads(false,1.0)
    player.set_crouch(false)
    player.training_health=50.0
    var weapon: int=combat.weapon_index
    player.end_sector_battle()
    hud.aim_pressed.emit()
    hud.weapon_pressed.emit()
    hud.heal_pressed.emit()
    hud.jump_pressed.emit()
    check(not combat.aim_active and combat.weapon_index==weapon and player.training_health==50 and not player._jump_requested,"post-round actions")
    director.begin_aircraft_phase()
    var flight=director._flight
    player.rotation.y=PI/2
    check((-player.get_node("AuroraTransportAircraft").global_basis.z).dot(Vector3.FORWARD)>.99,"aircraft heading inherited body")
    flight.jump_from_aircraft()
    check(str(flight.phase)=="jump_pending","jump must defer the physics handoff")
    for i in range(4):
        await process_frame
    check(player.air_mode=="freefall" and player.velocity.z<-10.0,
        "ejection lost inherited velocity after deferred handoff")
    flight.deploy_parachute()
    player._yaw=0.0
    player._desired_yaw=0.0
    player.rotation.y=0.0
    player.set_touch_move_axis(Vector2.RIGHT)
    await frames(2)
    check(absf(player._camera_pivot.global_rotation.y)<.001,"parachute camera follows body")
    print("V752_CHUTE_CAMERA ",player._camera_pivot.global_rotation.y)
    player.set_touch_move_axis(Vector2.ZERO)
    var district=game.get_node("PuertoAuroraSector")
    var building: Node3D=district.get_node("CENTRO_DE_EXPLORACION")
    var roof_mesh: Mesh=building.get_node("AngledMetalRoof").mesh
    var normals: PackedVector3Array=roof_mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
    for normal in normals:
        check(normal.y>.9,"roof faces point inside the building")
    var ray:=PhysicsRayQueryParameters3D.create(building.global_position+Vector3(.5,20,0),building.global_position+Vector3(.5,-5,0))
    ray.exclude=[player.get_rid()]
    var hit: Dictionary=player.get_world_3d().direct_space_state.intersect_ray(ray)
    check(not hit.is_empty() and hit.position.y-building.global_position.y>4,"roof not blocking")
    var roof_motion:=KinematicCollision3D.new()
    var roof_blocked: bool=player.test_move(Transform3D(Basis(),building.global_position+Vector3(.5,10,0)),Vector3(0,-12,0),roof_motion)
    check(roof_blocked and roof_motion.get_collision_count()>0 and roof_motion.get_position().y-building.global_position.y>4,"body passed through roof")
    # Camera collision must shorten in the same physics step.
    var wall:=StaticBody3D.new()
    var collider:=CollisionShape3D.new()
    var shape:=BoxShape3D.new()
    shape.size=Vector3(4,4,.2)
    collider.shape=shape
    wall.add_child(collider)
    var terrain=game.get_node("AuroraTerrain")
    var center:=Vector3(105,terrain.height_at(105.0,20.0)+2,20)
    player.global_position=center+Vector3(0,0,-3)
    player.air_mode="ground"
    player.round_finished=false
    player.royale_eliminated=false
    player._training_immunity=0
    player.training_health=100
    player.set_physics_process(false)
    var bot=combat._targets[0]
    bot.global_position=center+Vector3(0,0,3)
    await frames(2)
    bot._sense_player()
    check(bot._target_visible,"bot fixture failed acquisition")
    wall.position=center+Vector3.UP
    game.add_child(wall)
    await frames(2)
    player.rotation=Vector3.ZERO
    player._yaw=0.0
    player._desired_yaw=0.0
    player._pitch=0.0
    player._desired_pitch=0.0
    player._camera_pivot.rotation=Vector3.ZERO
    player.velocity=Vector3.ZERO
    player._camera.position.z=5.45
    player._physics_process(1.0/60)
    check(player._camera.position.z<2.8,"camera crossed cover during smoothing")
    print("V752_CAMERA_COLLISION distance=",player._camera.position.z)
    bot._attack_clock=0
    bot._sense_clock=10
    bot._physics_process(1.0/60)
    check(player.training_health==100,"bot fired through new cover")
    wall.queue_free()
    await frames(2)
    bot._attack_clock=0
    bot._physics_process(1.0/60)
    check(player.training_health<100,"clear shot does not hit")
    print("V752_COVER blocked=100 clear=",player.training_health)
    quit(1 if failed else 0)
