extends Node3D

const PRIVATE_GEAR=preload("res://scripts/player/aurora_private_equipment.gd")
const HELMET = preload("res://assets/gear/aurora_v3/AuroraHelmet.glb")
const PLATE_CARRIER = preload("res://assets/gear/aurora_v3/AuroraPlateCarrier.glb")
const HEAVY_VEST = preload("res://assets/gear/aurora_v3/AuroraHeavyVest.glb")
const LEVEL_COLORS: Array[Color]=[Color("738178"),Color("4d666c"),Color("414b60")]

var _helmet: MeshInstance3D
var _plate_carrier: MeshInstance3D
var _heavy_vest: MeshInstance3D
var _original_helmet: Node3D
var _original_vest: Node3D


func attach(rig: Node3D) -> void:
    var skeleton:=rig.find_child("Skeleton3D",true,false) as Skeleton3D
    if skeleton==null:
        return
    var helmet_mount:=_mount(skeleton,"Head","LilaHelmetSocket",Vector3(0,0,-.002))
    var vest_mount:=_mount(skeleton,"Spine2","LilaVestSocket",Vector3(0,.019,.115))
    if helmet_mount!=null:
        helmet_mount.rotation_degrees.y=-90
    if vest_mount!=null:
        vest_mount.rotation_degrees.y=180
    _helmet=_piece(helmet_mount,HELMET)
    _plate_carrier=_piece(vest_mount,PLATE_CARRIER,90)
    _heavy_vest=_piece(vest_mount,HEAVY_VEST)
    # User-supplied equipment appears only in locally staged/rights-cleared
    # test scenes. All original Aurora fallback models remain operational.
    _original_helmet=PRIVATE_GEAR.mount_optional(helmet_mount,
        PRIVATE_GEAR.HELMET,.34,Vector3(0,.11,0),Vector3(0,PI*.5,0))
    _original_vest=PRIVATE_GEAR.mount_optional(vest_mount,
        PRIVATE_GEAR.VEST,.65,Vector3(0,-.06,.08),Vector3(0,PI,0))
    if _original_helmet:
        _original_helmet.hide()
    if _original_vest:
        _original_vest.hide()


func _mount(skeleton: Skeleton3D,bone: String,socket_name: String,offset: Vector3) -> Node3D:
    if skeleton.find_bone(bone)<0:
        return null
    var socket:=BoneAttachment3D.new()
    socket.name=socket_name
    socket.bone_name=bone
    skeleton.add_child(socket)
    var mount:=Node3D.new()
    socket.add_child(mount)
    var rig_scale: float=skeleton.global_basis.get_scale().x
    mount.scale=Vector3.ONE/rig_scale
    mount.position=offset/rig_scale
    return mount


func _piece(mount: Node3D,scene: PackedScene,turn: float=0.0) -> MeshInstance3D:
    if mount==null:
        return null
    var model:=scene.instantiate() as Node3D
    mount.add_child(model)
    model.rotation_degrees.y=turn
    var surface:=model.find_child("*Mesh",true,false) as MeshInstance3D
    var paint:=StandardMaterial3D.new()
    paint.roughness=.78
    paint.metallic=.20
    surface.material_override=paint
    surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    surface.hide()
    return surface


func apply_levels(helmet: int,vest: int) -> void:
    _show_level(_helmet,helmet)
    _show_level(_plate_carrier,vest if vest<3 else 0)
    _show_level(_heavy_vest,vest if vest==3 else 0)
    if _original_helmet:
        _helmet.hide()
        _original_helmet.visible=helmet>0
    if _original_vest:
        _plate_carrier.hide()
        _heavy_vest.hide()
        _original_vest.visible=vest>0


func _show_level(piece: MeshInstance3D,level: int) -> void:
    if piece==null:
        return
    piece.visible=level>0
    if level>0:
        (piece.material_override as StandardMaterial3D).albedo_color=LEVEL_COLORS[level-1]
