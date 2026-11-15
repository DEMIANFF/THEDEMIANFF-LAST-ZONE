extends RefCounted

# Normalized toe plant times measured in Lila's imported clips and the bot rig.
const PLANTS: Dictionary={
    &"AuroraArmedWalk":[.125,.625],
    &"AuroraArmedRun":[.333,.875],
    &"AuroraCrouchWalk":[.125,.292,.583],
    &"AuroraArmedStrafeLeft":[.292,.875],
    &"AuroraArmedStrafeRight":[.292,.875],
    &"AuroraArmedBackpedal":[.167,.667],
    &"AuroraWalk":[.333,.792],
    &"AuroraRun":[.375,.875],
}

var _clip: StringName
var _phase: float=0.0
var _spacing: float=0.0


static func stone_footing(body: CharacterBody3D) -> bool:
    for i in range(body.get_slide_collision_count()):
        var collision:=body.get_slide_collision(i)
        if collision.get_normal().y<=.6:
            continue
        var support:=collision.get_collider() as Node
        if support!=null:
            var name: String=support.name.to_lower()
            if "floor" in name or "deck" in name or "ramp" in name or (
                    "foundation" in name or "porch" in name or "landing" in name):
                return true
    var at: Vector3=body.global_position
    return at.x>=-28.0 and at.x<=81.0 and at.z>=6.0 and at.z<=74.0


func advance(clip: StringName,seconds: float,length: float,delta: float) -> bool:
    _spacing=maxf(0.0,_spacing-delta)
    if length<=0.0 or not PLANTS.has(clip):
        _clip=&""
        return false
    var at: float=clampf(seconds/length,0.0,1.0)
    var before: float=_phase
    _phase=at
    if clip!=_clip:
        _clip=clip
        return false
    for marker: float in PLANTS[clip]:
        if _spacing<=0.0 and ((at>=before and marker>before and marker<=at) or
                (at<before and (marker>before or marker<=at))):
            _spacing=.14
            return true
    return false
