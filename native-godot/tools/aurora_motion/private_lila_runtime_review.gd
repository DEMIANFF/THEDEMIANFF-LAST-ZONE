extends SceneTree
## Explicit local-only test of the private Rev2 through Rev9 GLB, NOT an exported scene.
const EXPECTED: Array[String]=[
    "AuroraIdle","AuroraArmedIdle","AuroraAim","AuroraAimAWM","AuroraCrouch",
    "AuroraArmedWalk","AuroraArmedRun","AuroraCrouchWalk","AuroraArmedStrafeLeft",
    "AuroraArmedStrafeRight","AuroraArmedBackpedal","AuroraJump","AuroraLand",
    "AuroraFreefall","AuroraParachute","AuroraFire","AuroraFireAWM","AuroraReloadAR",
    "AuroraReloadAWM","AuroraReloadMP40","AuroraHeal","AuroraEquip","AuroraHit",
    "AuroraHitFront","AuroraHitBack","AuroraHitLeft","AuroraHitRight"]
const SHA: String="ab0df204ebe5cdbd2c9472af22eb672eac6cc9cec3818e6859baf1d884c3aa12"
const CONTACT_SHA: String="b3fd330483756a16d2a5022776428e54db39f916404ec70438b64de37932b896"
const CACHE_SHA: String="2a4c00e4ec9afcfcc7d529d73dadb85e57b94f80e2b59a6e25c7f599b5289c7d"
const HAND_SHA: String="c9b755349a4dc2692f45f3bec1918001d72a05f01b3bcad4aff406c743afb74b"
const SLEEVE_SHA: String="a98b6cca5b51fff38ff1570704dedbe58b4be90edbc84f0685b9bd282d74e6b1"
const HAIR_SHA: String="7e01f72eced0556b29c6232f999e1a6351fcc4e39563e6a32f5cf2ab13f274a8"
const RESIDUAL_SHA: String="498d7dd7e4f5346e81fd20ddc7c9ff442f14dddaa0a42a41f941dc9a313880ed"
const ADAPTIVE_SHA: String="19c93a00c114246aba2dca99c3a53698990dea2b9c519fc50a61a159331c4d45"
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
    if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) not in [SHA,CONTACT_SHA,CACHE_SHA,HAND_SHA,SLEEVE_SHA,HAIR_SHA,RESIDUAL_SHA,ADAPTIVE_SHA]:
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
    var require_hand_refit: bool=FileAccess.get_sha256(path) in [HAND_SHA,SLEEVE_SHA,HAIR_SHA,RESIDUAL_SHA,ADAPTIVE_SHA]
    var direct_digit_vertices: Dictionary={}
    if require_hand_refit:
        for side in ["Left","Right"]:
            for digit in ["Thumb","Index","Middle","Ring","Pinky"]:
                for segment in range(1,4):
                    direct_digit_vertices[side+"Hand"+digit+str(segment)]=0
    var outfit_mask: bool=false
    for node in meshes:
        var mesh: MeshInstance3D=node as MeshInstance3D
        if mesh.mesh==null:
            continue
        for surface in range(mesh.mesh.get_surface_count()):
            var arrays: Array=mesh.mesh.surface_get_arrays(surface)
            if arrays[Mesh.ARRAY_TEX_UV2]!=null and arrays[Mesh.ARRAY_TEX_UV2].size()>0:
                outfit_mask=true
            if require_hand_refit and mesh.skin!=null:
                var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
                var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
                var verts: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
                if bones.is_empty() or verts.is_empty():
                    continue
                check(bones.size()==weights.size() and bones.size()%verts.size()==0,
                    "invalid imported skin arrays")
                if bones.size()!=weights.size() or bones.size()%verts.size()!=0:
                    continue
                @warning_ignore("integer_division")
                var influences: int=bones.size()/verts.size()
                check(influences in [4,8],"unexpected influences per vertex")
                var bind_names: Array[String]=[]
                for bind in range(mesh.skin.get_bind_count()):
                    var bone_name: String=str(mesh.skin.get_bind_name(bind))
                    if bone_name.is_empty():
                        var bone_id: int=mesh.skin.get_bind_bone(bind)
                        if bone_id>=0 and bone_id<rig.get_bone_count():
                            bone_name=rig.get_bone_name(bone_id)
                    bind_names.append(bone_name)
                for vertex in range(verts.size()):
                    var seen: Dictionary={}
                    for k in range(influences):
                        var offset: int=vertex*influences+k
                        if weights[offset]<=0.00001:
                            continue
                        var bind: int=bones[offset]
                        if bind<0 or bind>=bind_names.size():
                            check(false,"imported skin bind out of bounds")
                            continue
                        var bone_name: String=bind_names[bind]
                        if direct_digit_vertices.has(bone_name) and not seen.has(bone_name):
                            direct_digit_vertices[bone_name]+=1
                            seen[bone_name]=true
    check(outfit_mask,"outfit UV2 mask missing")
    if require_hand_refit:
        for digit in direct_digit_vertices:
            # Godot may merge vertices during import. Require meaningful
            # positive support, not the exact pre-import vertex count.
            check(direct_digit_vertices[digit]>=10,"missing digit influence "+digit)
        print("LILA_PRIVATE_RUNTIME imported_digit_support=",direct_digit_vertices)
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
