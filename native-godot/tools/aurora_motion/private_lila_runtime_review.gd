extends SceneTree
## Explicit local-only test of the private Rev2 or Rev3 GLB, NOT an exported scene.
const EXPECTED: Array[String]=[
    "AuroraIdle","AuroraArmedIdle","AuroraAim","AuroraAimAWM","AuroraCrouch",
    "AuroraArmedWalk","AuroraArmedRun","AuroraCrouchWalk","AuroraArmedStrafeLeft",
    "AuroraArmedStrafeRight","AuroraArmedBackpedal","AuroraJump","AuroraLand",
    "AuroraFreefall","AuroraParachute","AuroraFire","AuroraFireAWM","AuroraReloadAR",
    "AuroraReloadAWM","AuroraReloadMP40","AuroraHeal","AuroraEquip","AuroraHit",
    "AuroraHitFront","AuroraHitBack","AuroraHitLeft","AuroraHitRight"]
const SHA: String="ab0df204ebe5cdbd2c9472af22eb672eac6cc9cec3818e6859baf1d884c3aa12"
const CONTACT_SHA: String="b3fd330483756a16d2a5022776428e54db39f916404ec70438b64de37932b896"
var failed: bool=false

func _initialize() -> void:
    call_deferred("_review")

func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("LILA_PRIVATE_RUNTIME "+reason)

func _review() -> void:
    var args: PackedStringArray=OS.get_cmdline_user_args()
    if args.size()!=1:
        push_error("Supply exactly one private GLB path after --")
        quit(2)
        return
    var path: String=args[0]
    if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) not in [SHA,CONTACT_SHA]:
        push_error("Private candidate missing or SHA mismatch")
        quit(2)
        return
    var doc:=GLTFDocument.new()
    var state:=GLTFState.new()
    if doc.append_from_file(path,state)!=OK:
        push_error("GLTFDocument failed to import candidate")
        quit(1)
        return
    var visual: Node=doc.generate_scene(state)
    if visual==null:
        push_error("GLTFDocument did not generate a scene")
        quit(1)
        return
    root.add_child(visual)
    var skeletons: Array[Node]=visual.find_children("*","Skeleton3D",true,false)
    var players: Array[Node]=visual.find_children("*","AnimationPlayer",true,false)
    var meshes: Array[Node]=visual.find_children("*","MeshInstance3D",true,false)
    if skeletons.size()!=1 or players.size()!=1 or meshes.is_empty():
        push_error("Unexpected imported skeleton, animation or mesh structure")
        quit(1)
        return
    var rig: Skeleton3D=skeletons[0] as Skeleton3D
    var animator: AnimationPlayer=players[0] as AnimationPlayer
    check(rig.get_bone_count()==56,"missing original bones")
    for side in ["Left","Right"]:
        for digit in ["Thumb","Index","Middle","Ring","Pinky"]:
            for segment in range(1,4):
                check(rig.find_bone(side+"Hand"+digit+str(segment))>=0,"missing digit bone")
    var outfit_mask: bool=false
    for node in meshes:
        var mesh: MeshInstance3D=node as MeshInstance3D
        if mesh.mesh==null:
            continue
        for surface in range(mesh.mesh.get_surface_count()):
            var arrays: Array=mesh.mesh.surface_get_arrays(surface)
            if arrays[Mesh.ARRAY_TEX_UV2]!=null and arrays[Mesh.ARRAY_TEX_UV2].size()>0:
                outfit_mask=true
    check(outfit_mask,"outfit UV2 mask missing")
    var poses: int=0
    for clip in EXPECTED:
        if not animator.has_animation(clip):
            check(false,"missing runtime clip "+clip)
            continue
        var anim: Animation=animator.get_animation(clip)
        check(anim.length>0.0,"invalid duration "+clip)
        animator.play(clip)
        for fraction in [0.0,.25,.5,.75,.999]:
            animator.seek(anim.length*float(fraction),true)
            animator.advance(0.0)
            rig.force_update_all_bone_transforms()
            for bone in range(rig.get_bone_count()):
                check(rig.get_bone_global_pose(bone).is_finite(),"invalid bone "+clip)
            poses+=1
        animator.stop()
    print("LILA_PRIVATE_RUNTIME imported_clips=",EXPECTED.size()," sampled_poses=",poses,
        " production_approved=false")
    visual.queue_free()
    quit(1 if failed else 0)
