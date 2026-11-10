extends SceneTree
## Real gameplay checks for distance-based footsteps and physical coastal cover.
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")


func check(condition: bool, why: String) -> void:
    if not condition:
        failed=true
        push_error("V7511_GAIT_COASTAL "+why)


func frames(count: int) -> void:
    for i in range(count):
        await physics_frame


func _verify() -> void:
    var scene: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(scene)
    await frames(3)
    var operator=scene.get_node("Operator")
    var terrain=scene.get_node("AuroraTerrain")
    var quarter=scene.get_node("PuertoAuroraCoastalQuarter")
    var combat=scene.get_node("CombatRange")
    var sound=scene.get_node("AuroraSoundStage")
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(quarter.cargo_caches_built==2,"waterfront supply cover missing")
    check(quarter.cover_points.size()>=36,"new tactical AI cover positions not registered")
    check(quarter.navigation_points.size()>=36,"freight routes not registered")

    var space:=scene.get_world_3d().direct_space_state
    var solid_hits: int=0
    for index in range(2):
        var depot: Node3D=quarter.get_node("AuroraFreightCache"+str(index))
        check(depot.get_node_or_null("SolidCargoCover0Solid")!=null,
            "physical cargo crate collider absent")
        var query:=PhysicsRayQueryParameters3D.create(
            depot.global_position+Vector3(-3.2,.58,-.2),
            depot.global_position+Vector3(3.2,.58,-.2))
        query.collision_mask=1
        var hit: Dictionary=space.intersect_ray(query)
        check(not hit.is_empty(),"bullets pass through freight cache "+str(index))
        if not hit.is_empty():
            solid_hits+=1
    check(solid_hits==2,"both coastal shelters must block projectiles")

    # Exercise physical walking and sprinting on a real, isolated collider.
    # Puerto Aurora contains real boxes/walls: they can legitimately stop
    # travel, and must not create false-positive gait regressions.
    var gait_floor:=StaticBody3D.new()
    gait_floor.name="IsolatedGaitCollisionFloor"
    gait_floor.collision_layer=1
    gait_floor.collision_mask=0
    var floor_collision:=CollisionShape3D.new()
    var floor_box:=BoxShape3D.new()
    floor_box.size=Vector3(100.0,1.0,100.0)
    floor_collision.shape=floor_box
    gait_floor.add_child(floor_collision)
    gait_floor.position=Vector3(800.0,15.0,800.0)
    scene.add_child(gait_floor)

    # Sound is now driven by travelled distance, not a timer that plays
    # footsteps repeatedly while a character is sliding into a wall.
    check(is_equal_approx(operator._step_stride(0.0,true),1.02),
        "crouched stride must be shorter")
    check(operator._step_stride(operator.RUN_SPEED,false)>
        operator._step_stride(operator.WALK_SPEED,false),
        "sprint stride must exceed walking stride")
    check(operator._step_stride(operator.RUN_SPEED,false)<2.5,
        "sprint stride too long to sound natural")
    var count: Array[int]=[0]
    operator.footstep.connect(func(_stone: bool): count[0]+=1)
    operator.set_touch_move_axis(Vector2.ZERO)
    operator.global_position=Vector3(800.0,15.56,800.0)
    operator.velocity=Vector3.ZERO
    operator._yaw=0.0
    operator._desired_yaw=0.0
    await frames(12)
    check(operator.is_on_floor(),"isolated gait collider did not ground the character")
    operator.set_touch_move_axis(Vector2.UP)
    await frames(85)
    var walked: int=count[0]
    check(walked>=2 and walked<=7,
        "walk is generating unrealistic footstep count "+str(walked))
    check(operator._footstep_distance>=0.0 and
        operator._footstep_distance<operator._step_stride(operator.WALK_SPEED,false),
        "distance accumulator out of valid stride range")
    # Independently test sprint from a verified unobstructed starting point.
    # A long uninterrupted route may encounter an actual world obstacle;
    # that must not be confused with a gait/audio failure.
    operator.set_touch_move_axis(Vector2.ZERO)
    await frames(10)
    operator.global_position=Vector3(800.0,15.56,800.0)
    operator.velocity=Vector3.ZERO
    operator._footstep_distance=0.0
    operator.set_touch_move_axis(Vector2.UP)
    operator.set_touch_run(true)
    check(operator._sprint_touch,"run control did not engage")
    await frames(65)
    var ran: int=count[0]-walked
    check(ran>=2 and ran<=9,
        "sprint failed to generate distance-driven footfalls "+
        str(ran)+" pos="+str(operator.global_position)+
        " can_act="+str(operator.can_act()))
    operator.set_touch_move_axis(Vector2.ZERO)
    operator.set_touch_run(false)
    await frames(40)
    check(is_zero_approx(operator._footstep_distance),
        "idle character still accumulating footsteps")
    var old_cursor: int=sound._cursor
    operator.grounded_impact.emit(true)
    check(sound._cursor==(old_cursor+1)%sound._voices.size(),
        "landing impact is not linked to audible material cue")
    print("V7511_GAIT_COASTAL PASS cover_colliders=",solid_hits,
        " tactical_cover=",quarter.cover_points.size(),
        " walk_steps=",walked," run_steps=",ran,
        " audio_connected=true")
    quit(1 if failed else 0)
