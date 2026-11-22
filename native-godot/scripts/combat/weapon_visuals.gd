extends Node3D
## Real GLB attachments for AR/AWM. Both live in the animated right-hand socket.
## Crucial: the source FBX visual is scaled ~0.008; compensate parent scaling
## or the rifle would be invisible even though the bone attachment exists.

const AK_PATH: String="res://assets/weapons/ak74-tactical.glb"
const AWM_PATH: String="res://assets/weapons/aurora_awm.glb"
# Source-faithful SCAR option: retains the real rig and animations, unlike
# the static mobile derivative. Private staging only, fallback never removed.
const SCAR_ANIMATED_SOURCE: String="res://assets/weapons/aurora_v3_sources/aurora_scar_animated_private.glb"
const SUPPORT_IK=preload("res://scripts/combat/weapon_support_ik.gd")
const WEAPONS=preload("res://scripts/combat/aurora_weapon_catalog.gd")

var operator: CharacterBody3D
var right_hand_socket: BoneAttachment3D
var spine_socket: BoneAttachment3D
var support_socket: BoneAttachment3D
var mount: Node3D
var back_mount: Node3D
var ak: Node3D
var awm: Node3D
var back_ak: Node3D
var back_awm: Node3D
var awm_owned: bool=false
var medical_busy: bool=false
var flight_holster: bool=false
var selected_weapon: int=0
var equipped_visual_scale: float=1.0
var attachment_uses_hand: bool=false
var _expansion: Dictionary={}
var _expansion_holsters: Dictionary={}
var _source_animation_players: Dictionary={}
var _mp40_magazine: Node3D
var _mp40_charging_handle: Node3D
var _magazine_rest: Transform3D
var _charging_rest: Vector3
var _skeleton: Skeleton3D
var _right_hand_id: int=-1
var _support_ik: SkeletonModifier3D
var _support_anchors: Dictionary={}
# Animated pieces of the ACTUAL authored AWM model (build_awm.py).
# Never fake an AWM bolt when the corresponding source meshes are absent.
const AWM_BOLT_MESH_NAMES: Array[String]=[
    "steel bolt stem","raised bolt lever","bolt actuator knob"]
const AWM_MECHANICAL_SECONDS: float=.50
var _awm_bolt_meshes: Array[MeshInstance3D]=[]
var _awm_bolt_rest: Array[Vector3]=[]
var _awm_mechanical_left: float=0.0
var awm_bolt_visual_cycles: int=0

# Additive visual response on the REAL held GLB. This never changes the
# authoritative camera recoil, damage, muzzle physics or animation skeleton.
const VISUAL_RECOIL_SECONDS: float=.155
var _visual_recoil_left: float=0.0
var _visual_recoil_model: Node3D
var _visual_recoil_rest: Transform3D
var _visual_recoil_amplitude: float=0.0
var visual_recoil_events: int=0


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
        _skeleton=skeleton
        _right_hand_id=right_hand_id
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
        var left_hand_id: int=skeleton.find_bone("LeftHand")
        if left_hand_id>=0:
            support_socket=BoneAttachment3D.new()
            support_socket.name="LeftHandReloadSocket"
            support_socket.bone_name=skeleton.get_bone_name(left_hand_id)
            skeleton.add_child(support_socket)
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
        var uses_lila_bones: bool=spine_socket.bone_name=="Spine"
        if scale_compensation>.00001:
            back_mount.scale=Vector3.ONE/scale_compensation
            var offset:=Vector3(.025,.32,-.18) if uses_lila_bones else Vector3(.075,.035,-.155)
            back_mount.position=offset/scale_compensation
        if uses_lila_bones:
            back_mount.quaternion=Basis.looking_at(
                Vector3(.58,-.81,-.08).normalized(),Vector3.BACK).get_rotation_quaternion()
        else:
            back_mount.rotation_degrees=Vector3(13,-11,53)
    elif skeleton:
        push_warning("Aurora spine bone missing; back holster disabled safely")
    else:
        # Headless/asset-free source builds still keep working hand weapons.
        back_mount=null

    ak=_load_visual(AK_PATH,"AK74TacticalVisual",mount)
    awm=_load_visual(AWM_PATH,"AWMPrecisionRifleVisual",mount)
    _index_awm_mechanical_parts()
    if back_mount:
        back_ak=_load_visual(AK_PATH,"AK74BackHolsterVisual",back_mount)
        back_awm=_load_visual(AWM_PATH,"AWMBackHolsterVisual",back_mount)
    set_awm_owned(false)
    equip(0)
    # The mount follows the solved wrist in world space; a later bone update
    # must not apply its transform a second time to the already aligned gun.
    mount.top_level=attachment_uses_hand
    if skeleton and support_socket:
        _support_ik=SUPPORT_IK.new()
        _support_ik.name="WeaponSupportArm"
        _support_ik.weapons=self
        skeleton.add_child(_support_ik)
        _support_ik.bind_chain()


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
    # Authored anchors take precedence over an estimated optical center.
    # The AWM now exports its real pistol grip in canonical game axes.
    var grip:=visual.find_child("Grip",true,false) as Node3D
    if grip:
        visual.position-=holder.to_local(grip.global_position)
    if display_name.begins_with("AK"):
        var support:=Node3D.new()
        # Rear part of the handguard, ahead of the magazine: this is a
        # usable close support hold for Lila\'s measured 46 cm arm reach.
        support.name="SupportGrip"
        visual.add_child(support)
        support.global_position=holder.to_global(Vector3(0,.025,-.25))
    print("AURORA_WEAPON_VISUAL ",display_name,
        " mesh_length_m=",desired_length," imported_bounds=",extent)
    return visual


## Find the ORIGINAL separate bolt pieces in the exported 3D GLB.
## This index is built exactly once, instead of traversing 40+ mesh
## objects or allocating frame-by-frame during an Android firefight.
func _index_awm_mechanical_parts() -> void:
    _awm_bolt_meshes.clear()
    _awm_bolt_rest.clear()
    if not is_instance_valid(awm):
        return
    for original_name in AWM_BOLT_MESH_NAMES:
        var part_found: MeshInstance3D=null
        for node in awm.find_children("*","MeshInstance3D",true,false):
            var part: MeshInstance3D=node as MeshInstance3D
            var label: String=part.name.to_lower().replace("_"," ")
            if label.contains(original_name):
                part_found=part
                break
        if part_found!=null:
            _awm_bolt_meshes.append(part_found)
            _awm_bolt_rest.append(part_found.position)
    if _awm_bolt_meshes.size()!=AWM_BOLT_MESH_NAMES.size():
        _awm_bolt_meshes.clear()
        _awm_bolt_rest.clear()
        push_warning("AWM imported model has no individually animated bolt meshes")


## The visual cycle is driven by the real AWM round, independent of the
## existing 280ms bolt SOUND and 500ms authoritative firing cadence.
## Each GLB part moves along the existing receiver then returns to the
## original resting vertex transform, without adding separate fake meshes.
func begin_awm_mechanical_cycle() -> bool:
    if (not is_instance_valid(awm) or not awm_owned or
            selected_weapon!=WEAPONS.AWM or medical_busy or flight_holster or
            _awm_bolt_meshes.size()!=AWM_BOLT_MESH_NAMES.size()):
        return false
    cancel_awm_mechanical_cycle()
    _awm_mechanical_left=AWM_MECHANICAL_SECONDS
    awm_bolt_visual_cycles+=1
    return true


func _advance_awm_mechanical_cycle(delta: float) -> void:
    if _awm_mechanical_left<=0.0:
        return
    if (not is_instance_valid(awm) or medical_busy or flight_holster or
            selected_weapon!=WEAPONS.AWM):
        cancel_awm_mechanical_cycle()
        return
    _awm_mechanical_left=maxf(0.0,
        _awm_mechanical_left-maxf(0.0,delta))
    var t: float=1.0-_awm_mechanical_left/AWM_MECHANICAL_SECONDS
    # Unlock, slide rearward, close and relock. All three objects are
    # within the physical metal receiver; no stock, barrel or optic moves.
    var open: float=smoothstep(.08,.35,t)*(1.0-smoothstep(.55,.94,t))
    for i in range(_awm_bolt_meshes.size()):
        var part: MeshInstance3D=_awm_bolt_meshes[i]
        if is_instance_valid(part):
            part.position=_awm_bolt_rest[i]+Vector3(
                0.0,.012*open if i>0 else .0,.068*open)
    if _awm_mechanical_left<=0.0:
        cancel_awm_mechanical_cycle()


func cancel_awm_mechanical_cycle() -> void:
    _awm_mechanical_left=0.0
    for i in range(_awm_bolt_meshes.size()):
        if is_instance_valid(_awm_bolt_meshes[i]):
            _awm_bolt_meshes[i].position=_awm_bolt_rest[i]


## A bounded kick/settle on the original skinned operator's held model.
## Existing GeometryInstance3D meshes, scope, muzzle and hand markers are
## transformed TOGETHER. No copied guns, extra animation rigs or emitters.
static func visual_recoil_amplitude(slot: int) -> float:
    if slot<0 or slot>=WEAPONS.ENTRIES.size() or slot==WEAPONS.KNIFE:
        return 0.0
    return clampf(float(WEAPONS.ENTRIES[slot]["recoil"])*1.5+.004,
        .006,.04)


func pulse_visual_recoil(slot: int) -> bool:
    if (slot!=selected_weapon or medical_busy or flight_holster or
            not is_instance_valid(operator) or
            operator.get("air_mode")!="ground"):
        return false
    var model: Node3D=currently_equipped()
    if not is_instance_valid(model) or not model.visible:
        return false
    # Burst fire starts from the same imported rest transform each round,
    # never from an already kicked pose (which would drift the rifle).
    cancel_visual_recoil()
    _visual_recoil_model=model
    _visual_recoil_rest=model.transform
    _visual_recoil_amplitude=visual_recoil_amplitude(slot)
    _visual_recoil_left=VISUAL_RECOIL_SECONDS
    visual_recoil_events+=1
    _apply_visual_recoil()
    return true


func _apply_visual_recoil() -> void:
    if not is_instance_valid(_visual_recoil_model):
        return
    var weight: float=clampf(
        _visual_recoil_left/VISUAL_RECOIL_SECONDS,0.0,1.0)
    var amount: float=_visual_recoil_amplitude*weight*weight
    # Small kick away from the hands (positive Z along barrel's rear)
    # with a mild muzzle-rise rotation, in compensated mount metres.
    var basis: Basis=_visual_recoil_rest.basis*Basis(
        Vector3.RIGHT,-amount*.7)
    var origin: Vector3=_visual_recoil_rest.origin+Vector3(
        0.0,amount*.20,amount)
    _visual_recoil_model.transform=Transform3D(basis,origin)


func _advance_visual_recoil(delta: float) -> void:
    if _visual_recoil_left<=0.0:
        return
    if (not is_instance_valid(_visual_recoil_model) or
            _visual_recoil_model!=currently_equipped() or
            medical_busy or flight_holster):
        cancel_visual_recoil()
        return
    _visual_recoil_left=maxf(0.0,
        _visual_recoil_left-maxf(delta,0.0))
    if _visual_recoil_left<=0.0:
        cancel_visual_recoil()
    else:
        _apply_visual_recoil()


func cancel_visual_recoil() -> void:
    if is_instance_valid(_visual_recoil_model):
        _visual_recoil_model.transform=_visual_recoil_rest
    _visual_recoil_left=0.0
    _visual_recoil_model=null
    _visual_recoil_amplitude=0.0


func _process(_delta: float) -> void:
    _advance_awm_mechanical_cycle(_delta)
    _advance_visual_recoil(_delta)
    if is_instance_valid(operator):
        var stow: bool=operator.get("air_mode") in ["freefall","parachute"]
        if flight_holster!=stow:
            if stow:
                cancel_visual_recoil()
            flight_holster=stow
            _sync_equipment_visibility()
    _align_mount_to_sight()


func _align_mount_to_sight(from_modifier: bool=false) -> void:
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
    var grip_world: Vector3=(_skeleton.to_global(
        _skeleton.get_bone_global_pose(_right_hand_id).origin)
        if from_modifier and _skeleton and _right_hand_id>=0 else right_hand_socket.global_position)
    mount.global_transform=Transform3D(basis,
        grip_world+basis*Vector3(.015,-.027,-.02))


## The AWM is visible on Lila's back ONLY after its world pickup.
## When it is equipped, the default AR-7 moves to the spine holster.
func set_awm_owned(owned: bool) -> void:
    if not owned:
        cancel_visual_recoil()
        cancel_awm_mechanical_cycle()
    awm_owned=owned
    _sync_equipment_visibility()


func set_medical_busy(active: bool) -> void:
    if active:
        cancel_visual_recoil()
        cancel_awm_mechanical_cycle()
    medical_busy=active
    _sync_equipment_visibility()


func add_expansion(slot: int) -> bool:
    if _expansion.has(slot):
        return true
    var path: String=WEAPONS.ENTRIES[slot]["asset"]
    var animated_scar: bool=slot==WEAPONS.SCAR and ResourceLoader.exists(
        SCAR_ANIMATED_SOURCE,"PackedScene")
    if animated_scar:
        path=SCAR_ANIMATED_SOURCE
    if not ResourceLoader.exists(path):
        return false
    var scene:=load(path) as PackedScene
    if scene==null:
        return false
    var carried:=scene.instantiate() as Node3D
    if carried==null:
        return false
    carried.name="AuroraAnimatedScar" if animated_scar else "AuroraWeapon_"+str(slot)
    mount.add_child(carried)
    calibrate_expansion(carried,slot)
    # An import can exist but contain invalid or empty meshes: never grant
    # an invisible weapon as if its visual passed inspection.
    if not carried.visible:
        carried.queue_free()
        return false
    _expansion[slot]=carried
    if animated_scar or slot>=WEAPONS.MP5:
        var source_anim: AnimationPlayer=carried.find_child(
            "*AnimationPlayer*",true,false) as AnimationPlayer
        if source_anim:
            _source_animation_players[slot]=source_anim
            # A native source reload, shot or equip must return to its authored
            # resting pose, rather than leaving the original rig frozen.
            source_anim.animation_finished.connect(func(clip: StringName) -> void:
                if not str(clip).to_lower().contains("idle") and is_instance_valid(source_anim) and (
                        _source_animation_players.get(slot)==source_anim):
                    play_source_action(slot,"idle"))
            play_source_action(slot,"idle")
        else:
            push_warning("SCAR original GLB has no imported AnimationPlayer")
    if back_mount:
        var holstered:=scene.instantiate() as Node3D
        if holstered:
            # Apply exactly the same source-unit normalization to the spine
            # attachment. Otherwise the privately staged animated SCAR can
            # appear 10x larger on the back than in Lila's right hand.
            holstered.name="AuroraAnimatedScar" if animated_scar else "AuroraBackWeapon_"+str(slot)
            back_mount.add_child(holstered)
            calibrate_expansion(holstered,slot)
            var passive: AnimationPlayer=holstered.find_child(
                "*AnimationPlayer*",true,false) as AnimationPlayer
            if passive:
                passive.stop()
            _expansion_holsters[slot]=holstered
    if slot==WEAPONS.MP40:
        _mp40_magazine=carried.find_child("Magazine",true,false) as Node3D
        _mp40_charging_handle=carried.find_child("ChargingHandle",true,false) as Node3D
        if _mp40_magazine:
            _magazine_rest=_mp40_magazine.transform
        if _mp40_charging_handle:
            _charging_rest=_mp40_charging_handle.position
    _sync_equipment_visibility()
    return true


static func calibrate_expansion(visual: Node3D,slot: int) -> void:
    if slot>=WEAPONS.HK416 or (slot==WEAPONS.SCAR and
            visual.name=="AuroraAnimatedScar"):
        # User GLBs have very different units (HK416 ~86, P90 ~1235,
        # VSS ~0.9). Calibrate geometry in holder coordinates, not by name.
        # An imported GLB is never a valid mounted rifle at raw source scale.
        var low:=Vector3(INF,INF,INF)
        var high:=Vector3(-INF,-INF,-INF)
        var count: int=0
        for element in visual.find_children("*","MeshInstance3D",true,false):
            var part: MeshInstance3D=element as MeshInstance3D
            if part.mesh==null:
                continue
            count+=1
            var bound: AABB=part.get_aabb()
            for point in range(8):
                var local: Vector3=visual.to_local(
                    part.to_global(bound.get_endpoint(point)))
                low=low.min(local)
                high=high.max(local)
        var extents: Vector3=high-low
        var length: float=maxf(extents.x,maxf(extents.y,extents.z))
        if count==0 or not extents.is_finite() or not is_finite(length) or length<.0001:
            visual.hide()
            push_error("Optional gun GLB has no usable mesh geometry: "+visual.name)
            return
        # Source long-axis to canonical forward (-Z), without mirroring.
        if extents.x>=extents.y and extents.x>=extents.z:
            visual.rotation.y=PI*.5
        elif extents.y>=extents.z:
            visual.rotation.x=-PI*.5
        var target_length: float=(
            .38 if slot==WEAPONS.KNIFE else
            .54 if slot==WEAPONS.MAGNUM else
            .76 if slot==WEAPONS.P90 else
            .84 if slot==WEAPONS.MP5 else
            1.38 if slot==WEAPONS.SNIPER else
            1.15 if slot==WEAPONS.SHOTGUN else
            1.05 if slot==WEAPONS.VSS else 1.10)
        var factor: float=clampf(target_length/length,.00001,100.0)
        var center: Vector3=low+extents*.5
        var grip_location:=Vector3(0,.01,-.20)
        visual.scale=Vector3.ONE*factor
        visual.position=grip_location-(visual.quaternion*center)*factor
        var holder: Node3D=visual.get_parent() as Node3D
        # A knife or revolver should NOT force Lila's left hand into a
        # nonexistent foregrip. Keep her weapon-specific upper body free.
        if slot!=WEAPONS.KNIFE and slot!=WEAPONS.MAGNUM:
            var support:=Node3D.new()
            support.name="SupportGrip"
            visual.add_child(support)
            if holder:
                support.global_position=holder.to_global(Vector3(0,.015,-.36))
        # A real scene muzzle attachment is needed for geometry-based bullets.
        # This approximation is tested against the displayed mesh and kept
        # separate from the user's original GLB (no destructive asset edits).
        if visual.find_child("Muzzle",true,false)==null:
            var muzzle:=Node3D.new()
            muzzle.name="Muzzle"
            visual.add_child(muzzle)
            if holder:
                muzzle.global_position=holder.to_global(Vector3(0,.03,
                    -.70 if slot!=WEAPONS.P90 else -.52))
        print("AURORA_OPTIONAL_GUN ",slot," source_bounds=",extents,
            " target_length=",target_length)
        return
    if slot!=WEAPONS.SCAR:
        var front:=Node3D.new()
        front.name="SupportGrip"
        visual.add_child(front)
        front.position=(Vector3(0,.025,-.22) if slot==WEAPONS.MP40 else
            Vector3(0,.015,-.18))
        return
    # Measured from the existing V3 GLB POSITION accessors. Its rifle is
    # along +Y at Z=1.63..1.89, while the old empty markers described an
    # unrelated origin. Normalize the EXISTING derivative, without changing
    # source bytes or pretending its discarded FPS clips were retargeted.
    visual.rotation_degrees.x=-90.0
    visual.position=Vector3(0,-1.72,-1.49)
    var grip:=visual.find_child("Grip",true,false) as Node3D
    var muzzle:=visual.find_child("Muzzle",true,false) as Node3D
    if grip:
        grip.position=Vector3(0,-1.49,1.72)
    if muzzle:
        muzzle.position=Vector3(.0014,-.7864,1.7956)
    var support:=Node3D.new()
    support.name="SupportGrip"
    visual.add_child(support)
    support.position=Vector3(0,-1.26,1.77)


## Play the genuine imported weapon action on its own source skeleton.
## Lila's independently rigged upper body remains driven by operator_animation.
## Clips are never faked when the licensed source has not been staged.
func play_source_action(slot: int,kind: String,
        game_duration: float=0.0) -> bool:
    var animator: AnimationPlayer=_source_animation_players.get(slot) as AnimationPlayer
    if animator==null or not is_instance_valid(animator):
        return false
    var keyword: String=""
    match kind:
        "fire": keyword="fire1" if slot==WEAPONS.KNIFE else (
            "shot" if slot==WEAPONS.SNIPER else "shoot")
        "reload": keyword="reload"
        "equip": keyword="take"
        "idle": keyword="idle"
        _: return false
    var names: PackedStringArray=animator.get_animation_list()
    # Prefer exact actions over ReloadStart / ReloadEnd (shotgun holds
    # those as distinct source clips). Keep all original clips intact.
    for name in names:
        if str(name).to_lower().ends_with("|"+keyword):
            _start_original_clip(animator,name,kind,game_duration)
            return true
    for name in names:
        if str(name).to_lower().contains(keyword):
            _start_original_clip(animator,name,kind,game_duration)
            return true
    return false


## Fit an imported ORIGINAL reload animation to the actual finite ammo
## timer; only if the source resource really has the clip. For the public
## static SCAR/MP40 models, no fictitious skeletal clip is asserted.
func _start_original_clip(animator: AnimationPlayer,clip: String,
        kind: String,game_duration: float) -> void:
    var playback_speed: float=1.0
    if kind=="reload" and game_duration>.05:
        var resource: Animation=animator.get_animation(clip)
        if resource!=null and resource.length>.01:
            playback_speed=clampf(resource.length/game_duration,.35,3.5)
    animator.speed_scale=playback_speed
    animator.play(clip)


func clear_expansion() -> void:
    cancel_visual_recoil()
    for player_anim in _source_animation_players.values():
        if is_instance_valid(player_anim):
            (player_anim as AnimationPlayer).stop()
    _source_animation_players.clear()
    for visual: Node3D in _expansion.values()+_expansion_holsters.values():
        visual.hide()
        visual.queue_free()
    _expansion.clear()
    _support_anchors.clear()
    _expansion_holsters.clear()
    _mp40_magazine=null
    _mp40_charging_handle=null


func set_mp40_reload_progress(progress: float) -> void:
    if _mp40_magazine:
        _mp40_magazine.transform=_magazine_rest
        if support_socket and progress>.14 and progress<.69:
            # Translate the actual mesh between the magwell and Lila's
            # animated support hand, then restore its seat on completion.
            var hand_weight: float=smoothstep(.14,.28,progress)*(
                1.0-smoothstep(.53,.69,progress))
            _mp40_magazine.global_position=_mp40_magazine.global_position.lerp(
                support_socket.global_position-Vector3.UP*.035,hand_weight)
    if _mp40_charging_handle:
        var stroke: float=smoothstep(.76,.85,progress)*(1.0-smoothstep(.85,.95,progress))
        _mp40_charging_handle.position=_charging_rest+Vector3.BACK*.055*stroke


func _sync_equipment_visibility() -> void:
    for slot: int in _expansion:
        _expansion[slot].visible=slot==selected_weapon and not (flight_holster or medical_busy)
    for slot: int in _expansion_holsters:
        _expansion_holsters[slot].visible=slot==selected_weapon and (flight_holster or medical_busy)
    if flight_holster:
        if ak: ak.hide()
        if awm: awm.hide()
        if back_ak: back_ak.visible=selected_weapon==0
        if back_awm: back_awm.visible=selected_weapon==1 and awm_owned
        return
    if ak:
        ak.visible=selected_weapon==0 and not medical_busy
    if awm:
        awm.visible=selected_weapon==1 and awm_owned and not medical_busy
    if back_ak:
        # The default AR always belongs to Lila; holster it even before
        # she has found the AWM, rather than making it vanish while healing.
        back_ak.visible=(selected_weapon==1 and awm_owned) or (
            selected_weapon==0 and medical_busy) or (
            selected_weapon>=WEAPONS.SCAR and not awm_owned and not medical_busy)
    if back_awm:
        back_awm.visible=awm_owned and (selected_weapon==0 or
            (selected_weapon>=WEAPONS.SCAR and not medical_busy) or
            (selected_weapon==1 and medical_busy))


func equip(index: int) -> void:
    if index<WEAPONS.AR or (index>=WEAPONS.SCAR and not _expansion.has(index)):
        return
    if selected_weapon!=index:
        cancel_visual_recoil()
        var inactive: AnimationPlayer=(
            _source_animation_players.get(selected_weapon) as AnimationPlayer)
        if is_instance_valid(inactive):
            # A holstered imported SCAR should not consume CPU still
            # playing a hidden reload/fire animation for each frame.
            inactive.stop()
            inactive.speed_scale=1.0
    if index!=WEAPONS.AWM:
        cancel_awm_mechanical_cycle()
    # Do not display a weapon that is neither owned nor available.
    selected_weapon=index if index!=WEAPONS.AWM or awm_owned else WEAPONS.AR
    _sync_equipment_visibility()


func currently_equipped() -> Node3D:
    if selected_weapon>=WEAPONS.SCAR:
        return _expansion.get(selected_weapon)
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
    var equipped: Node3D=currently_equipped()
    if equipped:
        var tip:=equipped.find_child("Muzzle",true,false) as Node3D
        if tip:
            return tip.global_position
    return mount.to_global(Vector3(0,.03,-1.10 if selected_weapon==1 else -.78))



func support_grip_anchor() -> Node3D:
    if not _support_anchors.has(selected_weapon):
        var weapon: Node3D=currently_equipped()
        if weapon==null:
            return null
        _support_anchors[selected_weapon]=weapon.find_child("SupportGrip",true,false)
    return _support_anchors[selected_weapon] as Node3D


func support_grip_enabled() -> bool:
    if not is_instance_valid(operator) or medical_busy or flight_holster:
        return false
    if operator.get("air_mode") in ["freefall","parachute"]:
        return false
    # Let the original hand tracks perform reloads and medical actions.
    # The AnimationTree is authoritative even during a manual visual capture.
    var controller: Node=operator.get("_animation_controller")
    if controller and controller.tree and bool(
            controller.tree.get("parameters/UpperBody/active")):
        var action_name: String=str(controller.action_clip.animation)
        if action_name.begins_with("AuroraReload") or action_name=="AuroraHeal":
            return false
    return currently_equipped()!=null
