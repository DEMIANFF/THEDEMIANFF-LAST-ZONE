extends SceneTree
var failed: bool=false

func _initialize() -> void:
    call_deferred("verify")

func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V753_NAV "+message)

func frames(n: int) -> void:
    for i in range(n):
        await physics_frame

func verify() -> void:
    var game=load("res://scenes/Main.tscn").instantiate()
    root.add_child(game)
    var player=game.get_node("Operator")
    var combat=game.get_node("CombatRange")
    var terrain=game.get_node("AuroraTerrain")
    var nav=game.get_node("AuroraNavigation")
    for bot in combat._targets:
        bot.set_physics_process(false)
    for i in range(300):
        if nav.available:
            break
        await physics_frame
    check(nav.available and nav.graph.get_point_count()>150,"walking graph not built")
    var building: Node3D=game.get_node("PuertoAuroraSector/CENTRO_DE_EXPLORACION")
    var worst_height_error: float=0.0
    for at in [Vector2(105,-60),Vector2(77,55),Vector2(31,70),Vector2(-72,-65),Vector2(18,6)]:
        var estimated: float=terrain.height_at(at.x,at.y)
        var ray:=PhysicsRayQueryParameters3D.create(Vector3(at.x,estimated+3,at.y),Vector3(at.x,estimated-3,at.y))
        # Explicitly compare the terrain triangle, not district support.
        var hit: Dictionary=terrain.get_world_3d().direct_space_state.intersect_ray(ray)
        if not hit.is_empty() and hit.collider==terrain:
            worst_height_error=maxf(worst_height_error,absf(hit.position.y-estimated))
    check(worst_height_error<.003,"height helper disagrees with terrain triangles")
    print("V753_TERRAIN_HEIGHT max_error=",worst_height_error)
    for label in ["CENTRO_DE_EXPLORACION","TALLER_HELIOS","ESTACION_METEOROLOGICA","PUESTO_VORTEX"]:
        var entry: Node3D=game.get_node("PuertoAuroraSector/"+label)
        var depth: float=11.0 if label=="TALLER_HELIOS" else 10.0 if label=="ESTACION_METEOROLOGICA" else 12.0
        var entrance: Vector3=entry.global_position+Vector3(0,0,depth*.5+8)
        player.global_position=Vector3(entrance.x,terrain.height_at(entrance.x,entrance.z)+.12,entrance.z)
        player.rotation=Vector3.ZERO
        player._yaw=0
        player._desired_yaw=0
        player.velocity=Vector3.ZERO
        player.set_touch_move_axis(Vector2.UP)
        await frames(180)
        player.set_touch_move_axis(Vector2.ZERO)
        check(player.global_position.z<entry.global_position.z+depth*.5-1.4,"entry foundation still needs jumping: "+label)
        print("V753_WALK_IN ",label," actual=",player.global_position)
    # Opposite side of the rear wall must route around the building to its door.
    var start: Vector3=nav.ground_point(building.global_position+Vector3(0,0,-9))
    var goal: Vector3=nav.ground_point(building.global_position)
    var route: PackedVector3Array=nav.route(start,goal)
    check(not nav.segment_clear(start,goal),"fixture does not cross a wall")
    check(route.size()>=3,"A* did not route around rear wall")
    var prior:=start
    for point in route:
        check(nav.segment_clear(prior,point),"route crosses a solid obstacle")
        prior=point
    var bot=combat._targets[0]
    player.set_physics_process(false)
    player.global_position=goal+Vector3(1,0,0)
    bot.global_position=start
    bot.velocity=Vector3.ZERO
    bot._last_seen=goal
    bot._alert_time=90
    bot._sense_clock=90
    bot._attack_clock=90
    bot._idle_phase=0
    bot._route_clock=0
    bot._route.clear()
    bot._route_goal=Vector3(INF,INF,INF)
    # Real CharacterBody movement along the same route; no teleporting.
    bot.set_physics_process(true)
    await frames(2400)
    bot.set_physics_process(false)
    check(Vector2(bot.global_position.x-goal.x,bot.global_position.z-goal.z).length()<4.0,"bot failed to reach interior through doorway")
    print("V753_AI_ROUTE waypoints=",route.size()," final=",bot.global_position," goal=",goal," queries=",nav.route_requests)
    var cover: Vector3=nav.find_cover(nav.ground_point(Vector3(4,0,-20)),Vector3(4,terrain.height_at(4,-28),-28))
    check(cover.is_finite(),"no reachable solid cover")
    bot.global_position=nav.ground_point(Vector3(4,0,-20))
    bot.health=40
    bot._last_seen=Vector3(4,terrain.height_at(4,-28),-28)
    bot._cover_clock=0
    bot._alert_time=5
    bot._sense_clock=5
    bot._physics_process(1.0/60.0)
    check(bot.behavior=="cover","wounded bot never entered cover behavior")
    print("V753_COVER point=",cover," state=",bot.behavior," build_ms=",nav.build_msec)
    print("V753_NAVIGATION PASS")
    quit(1 if failed else 0)
