extends SceneTree
var failed: bool=false
func _initialize() -> void:
    call_deferred("_verify")
func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V75220_NAV "+why)
func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var nav: Node3D=game.get_node("AuroraNavigation")
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var player: CharacterBody3D=game.get_node("Operator")
    for bot in combat._targets:
        bot.set_physics_process(false)
    for frame in range(900):
        await physics_frame
        if nav.available:
            break
    check(nav.available and nav.graph.get_point_count()>150,"graph unavailable")
    # Find a real connected graph edge. Compare the query count on the same
    # traversable geometry, retaining collision checks on every real step.
    var found: bool=false
    for id in nav.graph.get_point_ids():
        var connections: PackedInt64Array=nav.graph.get_point_connections(id)
        if connections.is_empty():
            continue
        var from: Vector3=nav.graph.get_point_position(id)
        var to: Vector3=nav.graph.get_point_position(connections[0])
        nav.reset_live_metrics()
        if not nav.segment_clear(from,to):
            continue
        var steps: int=maxi(1,int(ceil(from.distance_to(to)/.65)))
        check(nav.segment_ground_queries==steps+1 and nav.segment_overlap_queries==steps and nav.segment_motion_queries==steps,"redundant queries retained")
        print("V75220_SEGMENT steps=",steps," old_queries=",3*steps+4," new_queries=",3*steps+1)
        found=true
        break
    check(found,"no clear graph edge")
    var building: Node3D=game.get_node("PuertoAuroraSector/CENTRO_DE_EXPLORACION")
    var start: Vector3=nav.ground_point(building.global_position+Vector3(0,0,-9))
    var goal: Vector3=nav.ground_point(building.global_position)
    check(not nav.segment_clear(start,goal),"solid wall became walkable")
    var path: PackedVector3Array=nav.route(start,goal)
    check(path.size()>=3,"lost route around building")
    for point in path:
        check(nav.segment_clear(start,point),"route crossed solid wall")
        start=point
    # Admission boundary: 49 simultaneous requests in one physics frame.
    nav.reset_live_metrics()
    var admitted: int=0
    for i in range(49):
        if nav.try_live_plan():
            admitted+=1
    check(admitted==2 and nav.live_deferred==47,"simultaneous plan cap")
    await physics_frame
    check(nav.try_live_plan(),"budget did not reset next tick")
    nav.finish_live_plan(Time.get_ticks_usec()-nav.LIVE_PLAN_SOFT_USEC-1)
    check(not nav.try_live_plan(),"soft time threshold ignored")
    combat.set_encounter_size(50)
    director.start_sector_battle()
    check(combat._targets.size()==49 and combat.active_fighter_count()==50,"initial roster")
    var initial: Dictionary={}
    for bot in combat._targets:
        initial[bot.get_instance_id()]=bot.global_position
    for frame in range(360):
        await physics_frame
    var moved: int=0
    var shots: int=0
    var routed: int=0
    for bot in combat._targets:
        check(initial.has(bot.get_instance_id()) and bot.get_node_or_null("OpponentCollider") is CollisionShape3D,"lost actor or collider")
        if bot.global_position.distance_to(initial[bot.get_instance_id()])>.1:
            moved+=1
        if bot._route_goal.is_finite():
            routed+=1
        shots+=bot.shots_fired
    var metrics: Dictionary=nav.live_metrics()
    check(metrics.plans>0 and metrics.deferred>0 and metrics.plans_per_tick_peak<=2,"live plan budget not exercised")
    check(combat._targets.size()==49 and moved>0 and routed>0,"live navigation inactive")
    print("V75220_LIVE roster=50 moved=",moved," routed=",routed," shots=",shots," metrics=",JSON.stringify(metrics))
    game.queue_free()
    await process_frame
    if not failed:
        print("V75220_NAV PASS")
    quit(1 if failed else 0)
