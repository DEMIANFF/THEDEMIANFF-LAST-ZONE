extends SceneTree
## Optional private FBX-derived male model. Tests real imported clips WHEN
## the model exists; otherwise only tests the truthful Lila fallback path.
const MALE=preload("res://scripts/player/aurora_mixamo_male_preview.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V75120_MIXAMO_SOURCE "+message)


func _verify() -> void:
    check(MALE.REQUIRED.size()==4 and MALE.PLAYABLE_PREVIEW_ONLY,
        "operator source preview contract changed")
    if not MALE.source_available():
        check(MALE.instantiate_valid_preview()==null,
            "an absent private source became an imaginary model")
        if not failed:
            print("V75120_MIXAMO_SOURCE PASS optional_source_unstaged=1 "+
                "lila_fallback_untouched=1 source_animation_not_claimed=1")
        quit(1 if failed else 0)
        return
    var model: Node3D=MALE.instantiate_valid_preview()
    check(model!=null,"real imported Ch02 is not a valid 65-bone model")
    if model==null:
        quit(1)
        return
    root.add_child(model)
    var report: Dictionary=MALE.inspect(model)
    check(bool(report.get("valid",false)) and
        int(report.get("bones",0))>=65 and int(report.get("meshes",0))>=1,
        "rig geometry and skeleton did not survive FBX/GLB conversion")
    var animator: AnimationPlayer=model.find_child(
        "*AnimationPlayer*",true,false) as AnimationPlayer
    for clip in ["AuroraArmedWalk","AuroraArmedRun","AuroraJump"]:
        check(MALE.play_original_motion(model,clip),
            "real supplied motion did not play: "+clip)
        await process_frame
        check(animator!=null and animator.is_playing(),
            "no current source playback: "+clip)
    model.queue_free()
    await process_frame
    if not failed:
        print("V75120_MIXAMO_SOURCE PASS original_mixamo_bones=65 "+
            "source_3d_mesh=1 supplied_motion_clips=3 preview_only=1")
    quit(1 if failed else 0)
