extends SkeletonModifier3D
## Local-player correction after the AnimationTree. Physics probes are cached;
## the render callback only rotates existing bones. Never stretches the rig.
var operator: CharacterBody3D
var legs: Array[PackedInt32Array]=[]
var spines: PackedInt32Array=PackedInt32Array()
var offsets: Array[float]=[0.0,0.0]
var normals: Array[Vector3]=[Vector3.UP,Vector3.UP]
var contacts: Array[bool]=[false,false]
var probe_count: int=0
var aim_pitch: float=0.0
var foot_errors: Array[float]=[0.0,0.0]
var _query:=PhysicsRayQueryParameters3D.new()


func bind_player(player: CharacterBody3D) -> void:
    operator=player
    var skeleton: Skeleton3D=get_skeleton()
    for side in ["Left","Right"]:
        legs.append(PackedInt32Array([skeleton.find_bone(side+"UpLeg"),
            skeleton.find_bone(side+"Leg"),skeleton.find_bone(side+"Foot")]))
    for name in ["Spine1","Spine2"]:
        var index: int=skeleton.find_bone(name)
        if index>=0:
            spines.append(index)
    _query.collision_mask=1
    _query.exclude=[player.get_rid()]
    _query.collide_with_areas=false


func _grounded() -> bool:
    return is_instance_valid(operator) and operator.air_mode=="ground" and \
        operator.is_on_floor() and not operator.royale_eliminated and \
        operator._vehicle_ride==null


func _physics_process(delta: float) -> void:
    probe_count=0
    var skeleton: Skeleton3D=get_skeleton()
    for i in range(legs.size()):
        contacts[i]=false
        var wanted: float=0.0
        var normal: Vector3=Vector3.UP
        if _grounded() and not -1 in legs[i]:
            var foot: Vector3=skeleton.to_global(
                skeleton.get_bone_global_pose(legs[i][2]).origin)
            _query.from=Vector3(foot.x,operator.global_position.y+.35,foot.z)
            _query.to=_query.from-Vector3.UP*.70
            var hit: Dictionary=operator.get_world_3d().direct_space_state.intersect_ray(_query)
            probe_count+=1
            if not hit.is_empty() and (hit["normal"] as Vector3).y>.70:
                var rise: float=(hit["position"] as Vector3).y-operator.global_position.y
                if absf(rise)<.23:
                    # Swing feet retain their authored lift and receive less
                    # slope correction. No world-space foot lock while running.
                    var lift: float=maxf(0.0,foot.y-operator.global_position.y-.14)
                    wanted=rise*(1.0-smoothstep(.04,.25,lift))
                    normal=hit["normal"]
                    contacts[i]=true
        offsets[i]=lerpf(offsets[i],wanted,1.0-exp(-delta*18.0))
        normals[i]=normals[i].lerp(normal,1.0-exp(-delta*14.0)).normalized()


func _process_modification_with_delta(delta: float) -> void:
    if not is_instance_valid(operator):
        return
    var skeleton: Skeleton3D=get_skeleton()
    var engaged: bool=(operator._ads_active or operator._fire_held) and \
        operator.air_mode=="ground" and operator._vehicle_ride==null
    var wanted: float=clampf(operator._pitch,-.65,.65) if engaged else 0.0
    aim_pitch=lerpf(aim_pitch,wanted,1.0-exp(-maxf(0.0,delta)*15.0))
    var axis: Vector3=(skeleton.global_basis.inverse()*operator.global_basis.x).normalized()
    for spine in spines:
        var pose: Transform3D=skeleton.get_bone_global_pose(spine)
        pose.basis=Basis(Quaternion(axis,aim_pitch*.5))*pose.basis
        skeleton.set_bone_global_pose(spine,pose)
    if not _grounded():
        return
    for i in range(legs.size()):
        if -1 in legs[i] or not contacts[i] or absf(offsets[i])<.001:
            continue
        _fit_foot(skeleton,legs[i],i)


func _fit_foot(skeleton: Skeleton3D,chain: PackedInt32Array,index: int) -> void:
    var hip: Transform3D=skeleton.get_bone_global_pose(chain[0])
    var knee: Transform3D=skeleton.get_bone_global_pose(chain[1])
    var foot: Transform3D=skeleton.get_bone_global_pose(chain[2])
    var target: Vector3=foot.origin+skeleton.global_basis.inverse()*Vector3.UP*offsets[index]
    var a: float=hip.origin.distance_to(knee.origin)
    var b: float=knee.origin.distance_to(foot.origin)
    var ray: Vector3=target-hip.origin
    if minf(a,b)<.00001 or ray.length_squared()<.00001:
        return
    var direction: Vector3=ray.normalized()
    var length: float=clampf(ray.length(),absf(a-b)+.0001,a+b-.0001)
    var along: float=(a*a-b*b+length*length)/(2.0*length)
    var pole: Vector3=knee.origin-hip.origin
    pole-=direction*pole.dot(direction)
    if pole.length_squared()<.00001:
        return
    var elbow: Vector3=hip.origin+direction*along+pole.normalized()*sqrt(maxf(0.0,a*a-along*along))
    hip.basis=Basis(Quaternion((knee.origin-hip.origin).normalized(),
        (elbow-hip.origin).normalized()))*hip.basis
    skeleton.set_bone_global_pose(chain[0],hip)
    knee=skeleton.get_bone_global_pose(chain[1])
    var moved: Transform3D=skeleton.get_bone_global_pose(chain[2])
    knee.basis=Basis(Quaternion((moved.origin-knee.origin).normalized(),
        (hip.origin+direction*length-knee.origin).normalized()))*knee.basis
    skeleton.set_bone_global_pose(chain[1],knee)
    moved=skeleton.get_bone_global_pose(chain[2])
    var tilt:=Quaternion(Vector3.UP,normals[index])
    moved.basis=Basis(skeleton.global_basis.get_rotation_quaternion().inverse()*tilt*
        skeleton.global_basis.get_rotation_quaternion())*foot.basis
    skeleton.set_bone_global_pose(chain[2],moved)
    foot_errors[index]=(skeleton.global_basis*(moved.origin-target)).length()
