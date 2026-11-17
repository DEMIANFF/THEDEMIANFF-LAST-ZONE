extends Node3D
## The real backpack follows a Spine bone. No duplicate inventory state.
const GEAR=preload("res://scripts/player/aurora_private_equipment.gd")
var _model: Node3D
var _attachment: BoneAttachment3D
var _level: int=0


func attach(actor: Node3D) -> void:
    if actor==null or _attachment!=null or not ResourceLoader.exists(
            GEAR.BACKPACK,"PackedScene"):
        return
    var skeleton: Skeleton3D=null
    for child in actor.find_children("*","Skeleton3D",true,false):
        skeleton=child as Skeleton3D
        break
    if skeleton==null:
        return
    var chosen: int=-1
    for suffix in ["spine2","spine1","spine"]:
        for i in range(skeleton.get_bone_count()):
            if str(skeleton.get_bone_name(i)).to_lower().ends_with(suffix):
                chosen=i
                break
        if chosen>=0:
            break
    if chosen<0:
        return
    _attachment=BoneAttachment3D.new()
    _attachment.name="AuroraUserBackpackSocket"
    _attachment.bone_name=skeleton.get_bone_name(chosen)
    skeleton.add_child(_attachment)
    var mount:=Node3D.new()
    mount.name="BackpackPrivateMount"
    _attachment.add_child(mount)
    var scale: float=skeleton.global_basis.get_scale().x
    if scale<.00001:
        _attachment.queue_free()
        _attachment=null
        return
    mount.scale=Vector3.ONE/scale
    _model=GEAR.mount_optional(mount,GEAR.BACKPACK,.55,
        Vector3(0,-.09,.23)/scale,Vector3(0,PI,0))
    if _model:
        _model.visible=_level>0


func apply_level(level: int) -> void:
    _level=clampi(level,0,3)
    if _model:
        _model.visible=_level>0
