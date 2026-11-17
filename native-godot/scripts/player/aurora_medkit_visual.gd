extends Node3D
## Original Aurora medical device, built from a few low-cost primitive meshes.
## The single object is attached to the existing rig's LeftHand bone.
## Shows the current consumable only during its real healing channel.

const SYRINGE = preload("res://assets/gear/aurora_v3/AuroraSyringe.glb")
const PRIVATE_GEAR=preload("res://scripts/player/aurora_private_equipment.gd")

var hand_socket: BoneAttachment3D
var medkit_mount: Node3D
var medical_case: Node3D
var syringe: Node3D
var attachment_uses_hand: bool=false
var healing: bool=false


func _material(name: String,color: Color,metallic: float=.0) -> StandardMaterial3D:
    var mat:=StandardMaterial3D.new()
    mat.resource_name=name
    mat.albedo_color=color
    mat.metallic=metallic
    mat.roughness=.44 if metallic>.0 else .72
    return mat


func _solid(name: String,position: Vector3,size: Vector3,
        surface: StandardMaterial3D) -> MeshInstance3D:
    var piece:=MeshInstance3D.new()
    piece.name=name
    var mesh:=BoxMesh.new()
    mesh.size=size
    piece.mesh=mesh
    piece.material_override=surface
    # Medication has no physics collision and no real-time shadow cost.
    piece.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    piece.position=position
    medical_case.add_child(piece)
    return piece


func attach_to_operator(player: CharacterBody3D) -> void:
    if medkit_mount!=null:
        return
    var rig:=player.get_node_or_null("AuroraFemaleRiggedOperator") as Node3D
    var skeleton: Skeleton3D=null
    if rig:
        skeleton=rig.find_child("Skeleton3D",true,false) as Skeleton3D
    var left_hand_id: int=-1
    if skeleton:
        for i in range(skeleton.get_bone_count()):
            if skeleton.get_bone_name(i).to_lower().ends_with("lefthand"):
                left_hand_id=i
                break
    medkit_mount=Node3D.new()
    medkit_mount.name="MedicalHandMount"
    if skeleton and left_hand_id>=0:
        hand_socket=BoneAttachment3D.new()
        hand_socket.name="LilaLeftHandFirstAidSocket"
        hand_socket.bone_name=skeleton.get_bone_name(left_hand_id)
        skeleton.add_child(hand_socket)
        hand_socket.add_child(medkit_mount)
        var inherited_scale: float=skeleton.global_transform.basis.get_scale().x
        if inherited_scale>.00001:
            medkit_mount.scale=Vector3.ONE/inherited_scale
            medkit_mount.position=Vector3(.0,-.027,-.02)/inherited_scale
        if hand_socket.bone_name=="LeftHand" and inherited_scale>.00001:
            medkit_mount.position=Vector3(0,-.082,.012)/inherited_scale
            medkit_mount.rotation_degrees=Vector3(10,0,0)
        else:
            medkit_mount.rotation_degrees=Vector3(0,0,70)
        attachment_uses_hand=true
    else:
        player.add_child(medkit_mount)
        medkit_mount.position=Vector3(-.3,1.05,-.24)
        push_warning("Lila first aid: no LeftHand bone; using non-verified visible fallback")

    medical_case=Node3D.new()
    medical_case.name="AuroraFirstAidCase3D"
    medkit_mount.add_child(medical_case)
    var shell:=_material("AuroraMedkitIvoryShell",Color(.80,.90,1.0),.13)
    var blue:=_material("AuroraMedkitBlueRim",Color(.08,.25,.69),.42)
    var cross:=_material("AuroraMedkitCyanCross",Color(.04,.78,.95),.08)
    _solid("ReusableMedicalShell",Vector3.ZERO,Vector3(.20,.12,.07),shell)
    _solid("BlueTopRim",Vector3(0,.067,0),Vector3(.21,.018,.083),blue)
    _solid("BlueCarryingHandle",Vector3(0,.082,0),Vector3(.09,.018,.023),blue)
    _solid("AuroraCrossVertical",Vector3(0,0,.039),Vector3(.027,.074,.007),cross)
    _solid("AuroraCrossHorizontal",Vector3(0,0,.041),Vector3(.075,.027,.007),cross)
    _solid("BlueSafetyLatch",Vector3(.095,-.01,0),Vector3(.013,.048,.042),blue)
    # Substitute the actual delivered medkit during the real healing action,
    # not just on the ground. Preserve this low-memory medical case if the
    # licensed source is absent or has corrupt geometry.
    var authored_case: Node3D=PRIVATE_GEAR.mount_optional(
        medical_case,PRIVATE_GEAR.MEDKIT,.24,Vector3.ZERO)
    if authored_case:
        authored_case.name="OriginalMedicalKitInHand"
        for piece in medical_case.get_children():
            if piece is MeshInstance3D:
                (piece as MeshInstance3D).hide()
    syringe=SYRINGE.instantiate() as Node3D
    medkit_mount.add_child(syringe)
    syringe.position=Vector3(0,0,.026)
    syringe.rotation_degrees=Vector3(0,0,68)
    var injector_mesh:=syringe.find_child("*Mesh",true,false) as MeshInstance3D
    injector_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    # Never display a kit before a valid healing action is accepted.
    set_healing(false)


func set_healing(active: bool,with_syringe: bool=false) -> void:
    healing=active
    if medical_case!=null:
        medical_case.visible=active and not with_syringe
    if syringe!=null:
        syringe.visible=active and with_syringe


func get_piece_count() -> int:
    return medical_case.get_child_count() if medical_case!=null else 0
