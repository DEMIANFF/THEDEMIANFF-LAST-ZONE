extends Node3D
## Real GLB attachments for AR/AWM. Both live in the animated right-hand socket.
## Crucial: the source FBX visual is scaled ~0.008; compensate parent scaling
## or the rifle would be invisible even though the bone attachment exists.

const AK_PATH: String="res://assets/weapons/ak74-tactical.glb"
const AWM_PATH: String="res://assets/weapons/aurora_awm.glb"

var operator: CharacterBody3D
var right_hand_socket: BoneAttachment3D
var spine_socket: BoneAttachment3D
var mount: Node3D
var back_mount: Node3D
var ak: Node3D
var awm: Node3D
var back_ak: Node3D
var back_awm: Node3D
var awm_owned: bool=false
var medical_busy: bool=false
var selected_weapon: int=0
var equipped_visual_scale: float=1.0
var attachment_uses_hand: bool=false


func attach_to_player(player: CharacterBody3D) -> void:
    operator=player
    name="WeaponVisuals"
    var rig:=player.get_node_or_null("AuroraFemaleRiggedOperator") as Node3D
    var skeleton: Skeleton3D=null
    if rig:
        skeleton=rig.find_child("Skeleton3D",true,false) as Skeleton3D
    var right_hand_id: int=-1
    if skeleton:
        for i in range(skeleton.get_bone_count()):
            if skeleton.get_bone_name(i).to_lower().ends_with("righthand"):
                right_hand_id=i
                break

    mount=Node3D.new()
    mount.name="WeaponMount"
    if skeleton and right_hand_id>=0:
        right_hand_socket=BoneAttachment3D.new()
        right_hand_socket.name="RightHandWeaponSocket"
        right_hand_socket.bone_name=skeleton.get_bone_name(right_hand_id)
        skeleton.add_child(right_hand_socket)
        right_hand_socket.add_child(mount)
        # Conversion from centimetres / FBX coordinates: parent visual scales
        # the skeleton to human metres, but GLB guns already use metres.
        var parent_scale: float=skeleton.global_transform.basis.get_scale().x
        if parent_scale<=.00001:
            push_error("Invalid skinned operator scale for weapon attachment")
            return
        mount.scale=Vector3.ONE/parent_scale
        # Position in bone coordinates adjusted by original import scale.
        mount.position=Vector3(0,-.012,-.075)/parent_scale
        mount.rotation_degrees=Vector3(-12,0,90)
        equipped_visual_scale=mount.global_transform.basis.get_scale().x
        attachment_uses_hand=true
        print("AURORA_WEAPON_SOCKET bone=",right_hand_socket.bone_name,
            " imported_scale=",parent_scale," compensated_scale=",equipped_visual_scale)
    else:
        # Offline source builds may omit generated FBX. This fallback is not
        # marked as a correct rigged-operator weapon pose by QA.
        player.add_child(mount)
        mount.position=Vector3(.31,1.32,-.38)
        mount.rotation_degrees=Vector3(-12,0,0)
        push_warning("No usable right-hand bone; visible temporary chest mount")

    # The spare rifle rides a real spine bone and therefore animates with
    # crouch, sprint, jumps and parachute. It is not glued to the HUD camera.
    var spine_id: int=-1
    if skeleton:
        for i in range(skeleton.get_bone_count()):
            if skeleton.get_bone_name(i).to_lower().ends_with("spine"):
                spine_id=i
                break
    if skeleton and spine_id>=0:
        spine_socket=BoneAttachment3D.new()
        spine_socket.name="SpineHolsterSocket"
        spine_socket.bone_name=skeleton.get_bone_name(spine_id)
        skeleton.add_child(spine_socket)
        back_mount=Node3D.new()
        back_mount.name="BackHolsterMount"
        spine_socket.add_child(back_mount)
        var scale_compensation: float=skeleton.global_transform.basis.get_scale().x
        if scale_compensation>.00001:
            back_mount.scale=Vector3.ONE/scale_compensation
            back_mount.position=Vector3(.075,.035,-.155)/scale_compensation
        back_mount.rotation_degrees=Vector3(13,-11,53)
    elif skeleton:
        push_warning("Aurora spine bone missing; back holster disabled safely")
    else:
        # Headless/asset-free source builds still keep working hand weapons.
        back_mount=null

    ak=_load_visual(AK_PATH,"AK74TacticalVisual",mount)
    awm=_load_visual(AWM_PATH,"AWMPrecisionRifleVisual",mount)
    if back_mount:
        back_ak=_load_visual(AK_PATH,"AK74BackHolsterVisual",back_mount)
        back_awm=_load_visual(AWM_PATH,"AWMBackHolsterVisual",back_mount)
    set_awm_owned(false)
    equip(0)


func _load_visual(path: String, display_name: String,
        holder: Node3D) -> Node3D:
    if not ResourceLoader.exists(path):
        push_warning("Weapon visual missing: "+path)
        return null
    var source:=load(path) as PackedScene
    if source==null:
        push_error("Weapon resource is not a GLB PackedScene: "+path)
        return null
    var visual:=source.instantiate() as Node3D
    visual.name=display_name
    holder.add_child(visual)
    var minimum:=Vector3(INF,INF,INF)
    var maximum:=Vector3(-INF,-INF,-INF)
    for item in visual.find_children("*","MeshInstance3D",true,false):
        var part:=item as MeshInstance3D
        var bounds: AABB=part.get_aabb()
        for j in range(8):
            var v: Vector3=visual.to_local(part.to_global(bounds.get_endpoint(j)))
            minimum=minimum.min(v)
            maximum=maximum.max(v)
    var extent:=maximum-minimum
    var original_length: float=maxf(extent.x,maxf(extent.y,extent.z))
    if not is_finite(original_length) or original_length<.0001:
        push_error("Weapon GLB lacks valid geometry: "+path)
        visual.visible=false
        return visual
    var desired_length: float=1.06 if display_name.begins_with("AK") else 1.42
    var factor: float=clampf(desired_length/original_length,.00001,100.0)
    # Canonical forward is -Z; imported AK-74's major axis is X.
    if extent.x>extent.y and extent.x>extent.z:
        visual.rotation.y=PI*.5
    elif extent.y>extent.z:
        visual.rotation.x=-PI*.5
    # Pistol grip/trigger should be near the hand socket, not midpoint of rifle.
    # Barrel runs in -Z and stock is behind the hand.
    var optical_center:=minimum+extent*.5
    var desired_origin:=Vector3(0,.03,-.25 if display_name.begins_with("AK") else -.39)
    visual.scale=Vector3.ONE*factor
    visual.position=desired_origin-(visual.quaternion*optical_center)*factor
    print("AURORA_WEAPON_VISUAL ",display_name,
        " mesh_length_m=",desired_length," imported_bounds=",extent)
    return visual


func _process(_delta: float) -> void:
    _align_mount_to_sight()


func _align_mount_to_sight() -> void:
    if not attachment_uses_hand or not is_instance_valid(operator) or right_hand_socket==null:
        return
    # Keep the rifle physically aligned with Lila's torso/hands during
    # free look. Previously the barrel always followed a camera orbit while
    # the skinned body remained still: the gun detached from the visible grip.
    # Only aiming/fire deliberately raises it to the true reticle direction.
    var camera: Camera3D=operator.get_view_camera()
    var engaged: bool=bool(operator.get("_ads_active")) or bool(
        operator.get("_fire_held"))
    var forward: Vector3=-camera.global_basis.z if engaged and camera else         -operator.global_basis.z
    if not forward.is_finite() or forward.length_squared()<0.9:
        return
    var basis: Basis=Basis.looking_at(forward.normalized(),Vector3.UP)
    var grip_world: Vector3=right_hand_socket.global_position
    mount.global_transform=Transform3D(basis,
        grip_world+basis*Vector3(.015,-.027,-.02))


## The AWM is visible on Lila's back ONLY after its world pickup.
## When it is equipped, the default AR-7 moves to the spine holster.
func set_awm_owned(owned: bool) -> void:
    awm_owned=owned
    _sync_equipment_visibility()


func set_medical_busy(active: bool) -> void:
    medical_busy=active
    _sync_equipment_visibility()


func _sync_equipment_visibility() -> void:
    if ak:
        ak.visible=selected_weapon==0 and not medical_busy
    if awm:
        awm.visible=selected_weapon==1 and awm_owned and not medical_busy
    if back_ak:
        # The default AR always belongs to Lila; holster it even before
        # she has found the AWM, rather than making it vanish while healing.
        back_ak.visible=(selected_weapon==1 and awm_owned) or (
            selected_weapon==0 and medical_busy)
    if back_awm:
        back_awm.visible=awm_owned and (selected_weapon==0 or
            (selected_weapon==1 and medical_busy))


func equip(index: int) -> void:
    if index!=0 and index!=1:
        return
    # Do not display a weapon that is neither owned nor available.
    selected_weapon=index if index==0 or awm_owned else 0
    _sync_equipment_visibility()


func currently_equipped() -> Node3D:
    return ak if selected_weapon==0 else awm


func equipped_global_extents() -> Vector3:
    # World-space bounding box is the actual observable orientation and size.
    var visual: Node3D=currently_equipped()
    if visual==null:
        return Vector3.ZERO
    var smallest:=Vector3(INF,INF,INF)
    var largest:=Vector3(-INF,-INF,-INF)
    for item in visual.find_children("*","MeshInstance3D",true,false):
        var mesh:=item as MeshInstance3D
        var aabb: AABB=mesh.get_aabb()
        for i in range(8):
            var world_point: Vector3=mesh.to_global(aabb.get_endpoint(i))
            smallest=smallest.min(world_point)
            largest=largest.max(world_point)
    if not smallest.is_finite() or not largest.is_finite():
        return Vector3.ZERO
    return largest-smallest


func equipped_global_length() -> float:
    var size: Vector3=equipped_global_extents()
    return maxf(size.x,maxf(size.y,size.z))


func muzzle_position() -> Vector3:
    # Input may fire between render frames: align before computing the ray.
    _align_mount_to_sight()
    return mount.to_global(Vector3(0,.03,-1.10 if selected_weapon==1 else -.78))
