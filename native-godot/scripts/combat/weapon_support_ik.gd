extends SkeletonModifier3D
## Runtime support-arm correction over the existing authored animation.
## Only rotations change: bone lengths, root motion and source clips stay intact.
## This is not a retarget of the unavailable V3 first-person source animations.
var weapons: Node3D
var upper_id: int=-1
var forearm_id: int=-1
var hand_id: int=-1
var other_upper_id: int=-1
var solved: bool=false
var last_error_m: float=INF


func bind_chain() -> void:
    var skeleton: Skeleton3D=get_skeleton()
    if skeleton==null:
        return
    for i in range(skeleton.get_bone_count()):
        var bone: String=skeleton.get_bone_name(i).to_lower()
        if bone.ends_with("leftarm"): upper_id=i
        if bone.ends_with("leftforearm"): forearm_id=i
        if bone.ends_with("lefthand"): hand_id=i
        if bone.ends_with("rightarm"): other_upper_id=i


func _process_modification_with_delta(_delta: float) -> void:
    solved=false
    last_error_m=INF
    if not is_instance_valid(weapons) or min(upper_id,min(forearm_id,hand_id))<0:
        return
    if not weapons.support_grip_enabled():
        return
    var anchor: Node3D=weapons.support_grip_anchor()
    if not is_instance_valid(anchor):
        return
    var skeleton: Skeleton3D=get_skeleton()
    # Re-evaluate the hand-mounted rifle from this frame's animated right
    # hand before solving the left arm; no previous-frame bone attachment lag.
    weapons._align_mount_to_sight()
    var upper: Transform3D=skeleton.get_bone_global_pose(upper_id)
    var forearm: Transform3D=skeleton.get_bone_global_pose(forearm_id)
    var hand: Transform3D=skeleton.get_bone_global_pose(hand_id)
    var destination: Vector3=skeleton.to_local(anchor.global_position)
    var first: float=upper.origin.distance_to(forearm.origin)
    var second: float=forearm.origin.distance_to(hand.origin)
    var ray: Vector3=destination-upper.origin
    if minf(first,second)<.00001 or ray.length_squared()<.00000001:
        return
    var direction: Vector3=ray.normalized()
    var reach: float=clampf(ray.length(),absf(first-second)+.00001,
        first+second-.00001)
    var along: float=(first*first-second*second+reach*reach)/(2.0*reach)
    var side: Vector3=forearm.origin-upper.origin
    if other_upper_id>=0:
        var opposite: Vector3=skeleton.get_bone_global_pose(other_upper_id).origin
        var outward: Vector3=skeleton.global_basis*(upper.origin-opposite)
        outward=outward.normalized()
        # Elbow stays outside the torso and below the rifle, following body yaw.
        var pole_world: Vector3=skeleton.to_global(upper.origin)+outward*.35+Vector3.DOWN*.35
        side=skeleton.to_local(pole_world)-upper.origin
    side-=direction*side.dot(direction)
    if side.length_squared()<.00000001:
        return
    var elbow: Vector3=upper.origin+direction*along+side.normalized()*sqrt(
        maxf(0.0,first*first-along*along))
    var tip: Vector3=upper.origin+direction*reach
    upper.basis=Basis(Quaternion((forearm.origin-upper.origin).normalized(),
        (elbow-upper.origin).normalized()))*upper.basis
    skeleton.set_bone_global_pose(upper_id,upper)
    forearm=skeleton.get_bone_global_pose(forearm_id)
    var moved_hand: Transform3D=skeleton.get_bone_global_pose(hand_id)
    forearm.basis=Basis(Quaternion((moved_hand.origin-forearm.origin).normalized(),
        (tip-forearm.origin).normalized()))*forearm.basis
    skeleton.set_bone_global_pose(forearm_id,forearm)
    moved_hand=skeleton.get_bone_global_pose(hand_id)
    # Preserve the authored wrist orientation and finger pose.
    moved_hand.basis=hand.basis
    skeleton.set_bone_global_pose(hand_id,moved_hand)
    last_error_m=skeleton.to_global(moved_hand.origin).distance_to(anchor.global_position)
    solved=true
