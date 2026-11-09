extends Node3D
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
var _warmup: int=2
var _started: int=0
var _building_edges: bool=false
var _capsule:=CapsuleShape3D.new()
var _query:=PhysicsShapeQueryParameters3D.new()

func _ready() -> void:
    _capsule.radius=.43
    _capsule.height=1.74
    _query.shape=_capsule
    _query.collision_mask=1
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

func _physics_process(_delta: float) -> void:
    if _warmup>0:
        _warmup-=1
        return
    _query.exclude=_exclusions()
    var space:=get_world_3d().direct_space_state
    if not _building_edges:
        for i in range(_build_index,mini(_build_index+40,_samples.size())):
            var point:=ground_point(_samples[i])
            if point.is_finite():
                _query.transform=Transform3D(Basis(),point+Vector3.UP*.95)
                _query.motion=Vector3.ZERO
                if space.intersect_shape(_query,1).is_empty():
                    graph.add_point(graph.get_available_point_id(),point)
        _build_index+=40
        if _build_index>=_samples.size():
            _building_edges=true
            _build_index=0
            _ids=graph.get_point_ids()
        return
    var slice_started:=Time.get_ticks_usec()
    while _build_index<_ids.size():
        var i: int=_build_index
        var from:=graph.get_point_position(_ids[i])
        for j in range(i+1,_ids.size()):
            var to:=graph.get_point_position(_ids[j])
            if from.distance_squared_to(to)<20.0*20.0 and segment_clear(from,to):
                graph.connect_points(_ids[i],_ids[j])
        _build_index+=1
        if Time.get_ticks_usec()-slice_started>=2000:
            break
    max_build_slice_usec=maxi(max_build_slice_usec,Time.get_ticks_usec()-slice_started)
    if _build_index>=_ids.size():
        available=true
        build_msec=Time.get_ticks_msec()-_started
        set_physics_process(false)
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
    if start_id>=0 and goal_id>=0:
        var path:=graph.get_point_path(start_id,goal_id)
        if not path.is_empty():
            path.append(goal)
            return path
    # A local sector may be isolated in the prebuilt graph after a world
    # rebuild. Find physically validated door/sidestep nodes before giving up.
    return _local_detour(from,goal)


func _local_detour(from: Vector3,goal: Vector3) -> PackedVector3Array:
    if Vector2(from.x-goal.x,from.z-goal.z).length()>32.0:
        return PackedVector3Array()
    var exits: Array[Vector3]=[]
    var entries: Array[Vector3]=[]
    for location in district.navigation_points:
        var walkable: Vector3=ground_point(location)
        if not walkable.is_finite():
            continue
        if Vector2(walkable.x-from.x,walkable.z-from.z).length()<25.0:
            exits.append(walkable)
        if Vector2(walkable.x-goal.x,walkable.z-goal.z).length()<25.0:
            entries.append(walkable)
    exits.sort_custom(func(a,b): return a.distance_squared_to(goal)<b.distance_squared_to(goal))
    entries.sort_custom(func(a,b): return a.distance_squared_to(goal)<b.distance_squared_to(goal))
    for i in range(mini(exits.size(),14)):
        var a: Vector3=exits[i]
        if not segment_clear(from,a):
            continue
        for j in range(mini(entries.size(),14)):
            var b: Vector3=entries[j]
            if a.distance_squared_to(b)<2.0 or a.distance_squared_to(b)>30.0*30.0:
                continue
            if segment_clear(a,b) and segment_clear(b,goal):
                return PackedVector3Array([a,b,goal])
    return PackedVector3Array()

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
