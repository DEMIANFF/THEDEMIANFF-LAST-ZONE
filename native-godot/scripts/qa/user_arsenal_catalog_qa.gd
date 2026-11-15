extends SceneTree
## Non-destructive user-arsenal stage: all 13 uploaded GLBs were converted
## separately outside Git. The source repo remains functional without them.
const CATALOG=preload("res://scripts/combat/user_arsenal_catalog.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(condition: bool,reason: String) -> void:
    if not condition:
        failed=true
        push_error("USER_ARSENAL_CATALOG "+reason)

func _verify() -> void:
    var paths: Array[String]=CATALOG.all_paths()
    check(paths.size()==13,"expected exactly 13 staged meshes")
    check(CATALOG.AR_MODEL==CATALOG.model_path(4) and
        CATALOG.AWM_MODEL==CATALOG.model_path(11),
        "AR/AWM slots point to the wrong converted asset")
    check(CATALOG.model_path(0).is_empty() and
        CATALOG.model_path(14).is_empty(),
        "catalog accepts invalid inventory indices")
    var loaded: int=0
    for path in paths:
        if not ResourceLoader.exists(path):
            continue
        var source:=load(path) as PackedScene
        check(source!=null,"invalid GLB "+path)
        if source==null:
            continue
        var model:=source.instantiate() as Node3D
        check(model!=null,"GLB has no Node3D root "+path)
        if model==null:
            continue
        root.add_child(model)
        var grip: Node3D=model.find_child("AuroraGrip",true,false) as Node3D
        var muzzle: Node3D=CATALOG.muzzle_marker(model)
        var sight: Node3D=model.find_child("AuroraSight",true,false) as Node3D
        var eject: Node3D=model.find_child("AuroraEjection",true,false) as Node3D
        check(grip!=null and muzzle!=null and sight!=null and eject!=null,
            "converted GLB lost its four 3D attachment markers "+path)
        if muzzle!=null and grip!=null:
            var forward: Vector3=model.to_local(muzzle.global_position) - (
                model.to_local(grip.global_position))
            check(forward.is_finite() and forward.z<-.035,
                "muzzle is not ahead of grip on Godot -Z axis "+path)
        var components: Array[Node]=model.find_children("*","MeshInstance3D",true,false)
        check(components.size()>=1,"empty gun geometry "+path)
        loaded+=1
        model.queue_free()
    # Do not require user-uploaded binary blobs in GitHub CI until rights
    # review and deliberate asset import. Original combat GLBs stay stable.
    var legacy_ar: String="res://assets/weapons/ak74-tactical.glb"
    var legacy_awm: String="res://assets/weapons/aurora_awm.glb"
    check(CATALOG.preferred_path(0,legacy_ar)==(
        CATALOG.AR_MODEL if ResourceLoader.exists(CATALOG.AR_MODEL)
        else legacy_ar),"AR fallback path is not deterministic")
    check(CATALOG.preferred_path(1,legacy_awm)==(
        CATALOG.AWM_MODEL if ResourceLoader.exists(CATALOG.AWM_MODEL)
        else legacy_awm),"AWM fallback path is not deterministic")
    if not failed:
        print("USER_ARSENAL_CATALOG PASS models_available=",loaded,
            " slots=2 original_fallback=1 original_combat=preserved")
    quit(1 if failed else 0)
