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
    operator.global_position=Vector3(20.0,terrain.height_at(20.0,26.0)+.22,26.0)
    operator.velocity=Vector3.ZERO
    operator._yaw=0.0
    operator._desired_yaw=0.0
    operator.set_touch_move_axis(Vector2.UP)
    await frames(85)
    var walked: int=count[0]
    check(walked>=2 and walked<=7,
        "walk is generating unrealistic footstep count "+str(walked))
    check(operator._footstep_distance>0.0,"stride accumulator not progressing")
    operator.set_touch_run(true)
    await frames(75)
    var ran: int=count[0]-walked
    check(ran>=2 and ran<=9,
        "sprint footstep count ignored physical speed "+str(ran))
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
