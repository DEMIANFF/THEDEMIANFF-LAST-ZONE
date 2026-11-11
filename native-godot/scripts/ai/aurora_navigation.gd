extends Node3D
const STARTUP_DIAG=preload("res://scripts/persistence/scene_startup_diagnostics.gd")
const TRACE=preload("res://scripts/match/flight_diagnostics.gd")
## Shared, collision-checked walking graph. Only traversable edges enter A*;
## dynamic actors remain handled by CharacterBody3D and local avoidance.
var terrain: StaticBody3D
var district: Node3D
var actors: Array[CharacterBody3D]=[]
var graph:=AStar3D.new()
var available: bool=false
var route_requests: int=0
var build_msec: int=0
var max_build_slice_usec: int=0
var _ground_ray:=PhysicsRayQueryParameters3D.new()
var _samples: Array[Vector3]=[]
var _ids:=PackedInt64Array()
var _build_index: int=0
var _edge_other_index: int=1
# Defer nav shape queries until the first skinned character/world frames
# have had time to settle on GL Compatibility Android hardware.
const NODE_BATCH_SIZE: int=12
const INITIAL_PHYSICS_WARMUP: int=18
# Bound both sampling and A* edge building within a physics-frame budget.
const SAMPLE_SLICE_USEC: int=1800
const EDGE_SLICE_USEC: int=1800
# Each full segment sweep performs many synchronous 3D collision queries.
# Limit sweeps as well as wall-clock time; one long sweep cannot be preempted.
const EDGE_MAX_SEGMENTS_PER_TICK: int=3
var _warmup: int=INITIAL_PHYSICS_WARMUP
var _started: int=0
var _building_edges: bool=false
var _first_navigation_batch_logged: bool=false
var _first_edge_slice_logged: bool=false
var _edge_probes_completed: int=0
var _capsule:=CapsuleShape3D.new()
var _query:=PhysicsShapeQueryParameters3D.new()

func _ready() -> void:
    _capsule.radius=.43
    _capsule.height=1.74
    _query.shape=_capsule
    _query.collision_mask=1
    if STARTUP_DIAG.without_navigation_graph():
        set_physics_process(false)
        TRACE.checkpoint("active","scene_load",null,"navigation_graph_skipped_diagnostic")
        return
    _build.call_deferred()

func _exclusions() -> Array[RID]:
    var result: Array[RID]=[]
    for actor in actors:
        if is_instance_valid(actor):
            result.append(actor.get_rid())
    return result

func ground_point(at: Vector3) -> Vector3:
    var h: float=terrain.height_at(at.x,at.z)
    _ground_ray.from=Vector3(at.x,h+12.0,at.z)
    _ground_ray.to=Vector3(at.x,h-2,at.z)
    _ground_ray.collision_mask=2
    _ground_ray.exclude=_query.exclude
    var hit:=get_world_3d().direct_space_state.intersect_ray(_ground_ray)
    if hit.is_empty() or hit.normal.y<.65:
        return Vector3(INF,INF,INF)
    return hit.position+Vector3.UP*.04

func _build() -> void:
    _started=Time.get_ticks_msec()
    for x in range(-84,85,12):
        for z in range(-96,73,12):
            _samples.append(Vector3(x,0,z))
    _samples.append_array(district.navigation_points)

func _trace_actor() -> Node3D:
    return actors[0] if not actors.is_empty() and is_instance_valid(actors[0]) else null


func _physics_process(_delta: float) -> void:
    if _warmup>0:
        _warmup-=1
        return
    if not _first_navigation_batch_logged:
        _first_navigation_batch_logged=true
        TRACE.checkpoint("active","training",_trace_actor(),"navigation_first_batch_before",
            "queued_samples="+str(_samples.size())+
            " batch_size="+str(NODE_BATCH_SIZE))
    _query.exclude=_exclusions()
    var space:=get_world_3d().direct_space_state
    if not _building_edges:
        var start_index: int=_build_index
        var batch_limit: int=mini(start_index+NODE_BATCH_SIZE,_samples.size())
        var started_us: int=Time.get_ticks_usec()
        TRACE.checkpoint("active","training",_trace_actor(),
            "navigation_batch_before",
            "index="+str(start_index)+".."+str(batch_limit)+
            " nodes="+str(graph.get_point_count()))
        for i in range(start_index,batch_limit):
            var point:=ground_point(_samples[i])
            if point.is_finite():
                _query.transform=Transform3D(Basis(),point+Vector3.UP*.95)
                _query.motion=Vector3.ZERO
                if space.intersect_shape(_query,1).is_empty():
                    graph.add_point(graph.get_available_point_id(),point)
            # Resume the exact next sample next physics tick; no node skipped.
            _build_index=i+1
            if Time.get_ticks_usec()-started_us>=SAMPLE_SLICE_USEC:
                break
        var elapsed_us: int=Time.get_ticks_usec()-started_us
        TRACE.checkpoint("active","training",_trace_actor(),
            "navigation_batch_after",
            "index="+str(_build_index)+"/"+str(_samples.size())+
            " nodes="+str(graph.get_point_count())+
            " elapsed_us="+str(elapsed_us))
        if start_index==0:
            TRACE.checkpoint("active","training",_trace_actor(),
                "navigation_first_batch_after",
                "graph_nodes="+str(graph.get_point_count()))
        if _build_index>=_samples.size():
            _building_edges=true
            _build_index=0
            _edge_other_index=1
            _ids=graph.get_point_ids()
            TRACE.checkpoint("active","training",_trace_actor(),
                "navigation_nodes_complete_edges_pending",
                "nodes="+str(_ids.size())+" samples="+str(_samples.size()))
        return
    # Never process an unbounded series of PhysicsServer sweeps in one tick.
    # Durable events straddle the FIRST real sweep so an Android exit can be
    # distinguished from sampling and graph insertion, not guessed from timing.
    var slice_started: int=Time.get_ticks_usec()
    var segments_this_tick: int=0
    if not _first_edge_slice_logged:
        _first_edge_slice_logged=true
        TRACE.checkpoint("active","training",_trace_actor(),
            "navigation_first_edge_slice_enter",
            "nodes="+str(_ids.size()))
    while _build_index<_ids.size():
        var i: int=_build_index
        var from: Vector3=graph.get_point_position(_ids[i])
        while _edge_other_index<_ids.size():
            var j: int=_edge_other_index
            _edge_other_index+=1
            var to: Vector3=graph.get_point_position(_ids[j])
            if from.distance_squared_to(to)<20.0*20.0:
                var first_probe: bool=_edge_probes_completed==0
                if first_probe:
                    TRACE.checkpoint("active","training",_trace_actor(),
                        "navigation_first_edge_probe_before",
                        "from="+str(i)+" to="+str(j))
                var clear: bool=segment_clear(from,to)
                _edge_probes_completed+=1
                if first_probe:
                    TRACE.checkpoint("active","training",_trace_actor(),
                        "navigation_first_edge_probe_after",
                        "clear="+str(clear)+" queries="+str(_edge_probes_completed))
                if clear:
                    graph.connect_points(_ids[i],_ids[j])
                segments_this_tick+=1
            if segments_this_tick>=EDGE_MAX_SEGMENTS_PER_TICK or \
                Time.get_ticks_usec()-slice_started>=EDGE_SLICE_USEC:
                max_build_slice_usec=maxi(max_build_slice_usec,
                    Time.get_ticks_usec()-slice_started)
                return
        _build_index+=1
        _edge_other_index=_build_index+1
        if Time.get_ticks_usec()-slice_started>=EDGE_SLICE_USEC:
            break
    max_build_slice_usec=maxi(max_build_slice_usec,Time.get_ticks_usec()-slice_started)
    if _build_index>=_ids.size():
        available=true
        build_msec=Time.get_ticks_msec()-_started
        set_physics_process(false)
        TRACE.checkpoint("active","training",_trace_actor(),
            "navigation_graph_ready",
            "nodes="+str(graph.get_point_count())+
            " probes="+str(_edge_probes_completed)+
            " ms="+str(build_msec))
        print("AURORA_NAVIGATION nodes=",graph.get_point_count()," build_ms=",build_msec," max_slice_us=",max_build_slice_usec)

func segment_clear(from: Vector3, to: Vector3) -> bool:
    if not from.is_finite() or not to.is_finite():
        return false
    var space:=get_world_3d().direct_space_state
    var previous:=ground_point(from)
    if not previous.is_finite():
        return false
    var steps:=maxi(1,int(ceil(from.distance_to(to)/.65)))
    for i in range(steps+1):
        var point:=ground_point(from.lerp(to,float(i)/steps))
        if not point.is_finite() or absf(point.y-previous.y)>.65:
            return false
        _query.transform=Transform3D(Basis(),previous+Vector3.UP*.95)
        _query.motion=Vector3.ZERO
        if not space.intersect_shape(_query,1).is_empty():
            return false
        _query.motion=point-previous
        if space.cast_motion(_query)[0]<.995:
            return false
        previous=point
    return true

func _reachable_node(at: Vector3) -> int:
    var candidates: Array=[]
    for id in graph.get_point_ids():
        var point:=graph.get_point_position(id)
        var distance:=at.distance_squared_to(point)
        if distance<24.0*24.0:
            candidates.append([distance,id])
    candidates.sort_custom(func(a,b): return a[0]<b[0])
    for candidate in candidates:
        if segment_clear(at,graph.get_point_position(candidate[1])):
            return candidate[1]
    return -1

func route(from: Vector3,to: Vector3) -> PackedVector3Array:
    route_requests+=1
    if not available:
        return PackedVector3Array()
    _query.exclude=_exclusions()
    var goal:=ground_point(to)
    if not goal.is_finite() or absf(goal.y-to.y)>2.0:
        return PackedVector3Array()
    if segment_clear(from,goal):
        return PackedVector3Array([goal])
    var start_id:=_reachable_node(from)
    var goal_id:=_reachable_node(goal)
    if start_id<0 or goal_id<0:
        return PackedVector3Array()
    var path:=graph.get_point_path(start_id,goal_id)
    if path.is_empty():
        return path
    path.append(goal)
    return path

func find_cover(from: Vector3, threat: Vector3) -> Vector3:
    # Only solid, reachable cover within 18 m; never select through a wall.
    var best:=Vector3(INF,INF,INF)
    var distance:=18.0*18.0
    for candidate in district.cover_points:
        var cost: float=from.distance_squared_to(candidate)
        if cost>=distance:
            continue
        var ray:=PhysicsRayQueryParameters3D.create(threat+Vector3.UP*1.35,candidate+Vector3.UP*1.0)
        ray.exclude=_exclusions()
        if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
            continue
        if not route(from,candidate).is_empty():
            best=candidate
            distance=cost
    return best
