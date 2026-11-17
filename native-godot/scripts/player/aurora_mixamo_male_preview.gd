extends RefCounted
## Real private Mixamo Ch02 male preview. Never claim these four files contain
## weapon firing, reload, parachute or medical motions: they do not.
const GLB_PATH: String="res://assets/characters/aurora_male_mixamo/AuroraMaleMixamo.glb"
const REQUIRED: Array[String]=[
    "AuroraArmedIdle","AuroraArmedWalk","AuroraArmedRun","AuroraJump"]
const PLAYABLE_PREVIEW_ONLY: bool=true


static func source_available() -> bool:
    return ResourceLoader.exists(GLB_PATH,"PackedScene")


static func _find_animator(subject: Node3D) -> AnimationPlayer:
    return subject.find_child("*AnimationPlayer*",true,false) as AnimationPlayer


static func find_clip(animator: AnimationPlayer,short_name: String) -> String:
    if animator==null:
        return ""
    if animator.has_animation(short_name):
        return short_name
    for name in animator.get_animation_list():
        if str(name).to_lower().ends_with(short_name.to_lower()):
            return str(name)
    return ""


static func inspect(subject: Node3D) -> Dictionary:
    if subject==null:
        return {"valid":false,"reason":"instantiation_failed"}
    var skeleton: Skeleton3D=null
    for node in subject.find_children("*","Skeleton3D",true,false):
        skeleton=node as Skeleton3D
        break
    if skeleton==null:
        return {"valid":false,"reason":"missing_skeleton"}
    var count: int=skeleton.get_bone_count()
    if count<65:
        return {"valid":false,"reason":"expected_65_mixamo_bones","bones":count}
    var names: Dictionary={}
    for i in range(count):
        names[str(skeleton.get_bone_name(i)).to_lower()]=true
    for needed in ["hips","leftfoot","righthand"]:
        var found: bool=false
        for bone in names:
            if str(bone).ends_with(needed):
                found=true
                break
        if not found:
            return {"valid":false,"reason":"missing_"+needed,"bones":count}
    var animator: AnimationPlayer=_find_animator(subject)
    if animator==null:
        return {"valid":false,"reason":"missing_animation_player","bones":count}
    for clip in REQUIRED:
        if find_clip(animator,clip).is_empty():
            return {"valid":false,"reason":"missing_clip_"+clip,"bones":count}
    var mesh_count: int=0
    for node in subject.find_children("*","MeshInstance3D",true,false):
        var model: MeshInstance3D=node as MeshInstance3D
        if model.mesh!=null:
            mesh_count+=1
    if mesh_count<1:
        return {"valid":false,"reason":"no_visible_mesh","bones":count}
    return {"valid":true,"bones":count,"meshes":mesh_count,"clips":REQUIRED.size(),
        "weapon_actions_authored":false,"combat_playable_certified":false}


static func instantiate_valid_preview() -> Node3D:
    if not source_available():
        return null
    var scene: PackedScene=load(GLB_PATH) as PackedScene
    if scene==null:
        return null
    var preview: Node3D=scene.instantiate() as Node3D
    if preview==null:
        return null
    var report: Dictionary=inspect(preview)
    if not bool(report.get("valid",false)):
        push_warning("Aurora Mixamo male is not an approved 3D preview: "+
            str(report.get("reason","unknown")))
        preview.free()
        return null
    return preview


static func play_original_motion(subject: Node3D,clip: String) -> bool:
    if subject==null or not REQUIRED.has(clip):
        return false
    var animator: AnimationPlayer=_find_animator(subject)
    var source: String=find_clip(animator,clip)
    if source.is_empty():
        return false
    var animation: Animation=animator.get_animation(source)
    animation.loop_mode=(Animation.LOOP_NONE if clip=="AuroraJump"
        else Animation.LOOP_LINEAR)
    animator.play(source,.20)
    return true
