extends SkeletonModifier3D
## Fit both arms to the held weapon using their actual lengths.
## Only joint rotations change. Source animations, finger poses, collision and
## root motion are retained; reload/heal/flight release this correction.
var weapons: Node3D
var left: PackedInt32Array=PackedInt32Array([-1,-1,-1])
var right: PackedInt32Array=PackedInt32Array([-1,-1,-1])
var solved: bool=false
var last_error_m: float=INF
var right_error_m: float=INF
var grip_adjustment_m: float=0.0


func bind_chain() -> void:
    var skeleton: Skeleton3D=get_skeleton()
    if skeleton==null:
        return
    for i in range(skeleton.get_bone_count()):
        var bone: String=skeleton.get_bone_name(i).to_lower()
        for j in range(3):
            var suffix: String=["arm","forearm","hand"][j]
            if bone.ends_with("left"+suffix): left[j]=i
            if bone.ends_with("right"+suffix): right[j]=i


func _reach(skeleton: Skeleton3D,chain: PackedInt32Array) -> float:
    var a: Vector3=skeleton.to_global(skeleton.get_bone_global_pose(chain[0]).origin)
    var b: Vector3=skeleton.to_global(skeleton.get_bone_global_pose(chain[1]).origin)
    var c: Vector3=skeleton.to_global(skeleton.get_bone_global_pose(chain[2]).origin)
    return a.distance_to(b)+b.distance_to(c)


func _inside_sphere(point: Vector3,center: Vector3,radius: float) -> Vector3:
    var offset: Vector3=point-center
    return center+offset.limit_length(radius)


func _process_modification_with_delta(_delta: float) -> void:
    solved=false
    last_error_m=INF
    right_error_m=INF
    if not is_instance_valid(weapons) or -1 in left or -1 in right:
        return
    if not weapons.support_grip_enabled():
        return
    var anchor: Node3D=weapons.support_grip_anchor()
    if not is_instance_valid(anchor):
        return
    var skeleton: Skeleton3D=get_skeleton()
    weapons._align_mount_to_sight(true)
    var hand_world: Vector3=skeleton.to_global(skeleton.get_bone_global_pose(right[2]).origin)
    var support_offset: Vector3=anchor.global_position-hand_world
    var left_root: Vector3=skeleton.to_global(skeleton.get_bone_global_pose(left[0]).origin)
    var right_root: Vector3=skeleton.to_global(skeleton.get_bone_global_pose(right[0]).origin)
    var left_reach: float=_reach(skeleton,left)*.96
    var right_reach: float=_reach(skeleton,right)*.98
    # A fixed right wrist left the long rifles outside the other arm's reach.
    # Find a grip position reachable by BOTH arms instead of stretching bones
    # or moving the support marker away from the actual foregrip.
    var requested: Vector3=hand_world
    for iteration in range(6):
        requested=_inside_sphere(requested,left_root-support_offset,left_reach)
        requested=_inside_sphere(requested,right_root,right_reach)
    grip_adjustment_m=requested.distance_to(hand_world)
    right_error_m=_solve(skeleton,right,requested,left[0])
    weapons._align_mount_to_sight(true)
    last_error_m=_solve(skeleton,left,anchor.global_position,right[0])
    solved=true


func _solve(skeleton: Skeleton3D,chain: PackedInt32Array,
        destination_world: Vector3,other_upper: int) -> float:
    var upper: Transform3D=skeleton.get_bone_global_pose(chain[0])
    var forearm: Transform3D=skeleton.get_bone_global_pose(chain[1])
    var hand: Transform3D=skeleton.get_bone_global_pose(chain[2])
    var destination: Vector3=skeleton.to_local(destination_world)
    var first: float=upper.origin.distance_to(forearm.origin)
    var second: float=forearm.origin.distance_to(hand.origin)
    var ray: Vector3=destination-upper.origin
    if minf(first,second)<.00001 or ray.length_squared()<.00000001:
        return INF
    var direction: Vector3=ray.normalized()
    var reach: float=clampf(ray.length(),absf(first-second)+.00001,
        first+second-.00001)
    var along: float=(first*first-second*second+reach*reach)/(2.0*reach)
    var opposite: Vector3=skeleton.get_bone_global_pose(other_upper).origin
    var outward: Vector3=(skeleton.global_basis*(upper.origin-opposite)).normalized()
    var pole_world: Vector3=skeleton.to_global(upper.origin)+outward*.35+Vector3.DOWN*.35
    var side: Vector3=skeleton.to_local(pole_world)-upper.origin
    side-=direction*side.dot(direction)
    if side.length_squared()<.00000001:
        return INF
    var elbow: Vector3=upper.origin+direction*along+side.normalized()*sqrt(
        maxf(0.0,first*first-along*along))
    var tip: Vector3=upper.origin+direction*reach
    upper.basis=Basis(Quaternion((forearm.origin-upper.origin).normalized(),
        (elbow-upper.origin).normalized()))*upper.basis
    skeleton.set_bone_global_pose(chain[0],upper)
    forearm=skeleton.get_bone_global_pose(chain[1])
    var moved_hand: Transform3D=skeleton.get_bone_global_pose(chain[2])
    forearm.basis=Basis(Quaternion((moved_hand.origin-forearm.origin).normalized(),
        (tip-forearm.origin).normalized()))*forearm.basis
    skeleton.set_bone_global_pose(chain[1],forearm)
    moved_hand=skeleton.get_bone_global_pose(chain[2])
    moved_hand.basis=hand.basis
    skeleton.set_bone_global_pose(chain[2],moved_hand)
    return skeleton.to_global(moved_hand.origin).distance_to(destination_world)
