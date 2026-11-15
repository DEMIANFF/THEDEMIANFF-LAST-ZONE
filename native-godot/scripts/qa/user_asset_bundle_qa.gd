extends SceneTree
## Verify staged user assets only when binaries are actually installed.
const FLIGHT=preload("res://scripts/match/airdrop_sequence.gd")
const CATALOG=preload("res://scripts/combat/user_arsenal_catalog.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("AURORA_ASSET_BRIDGE "+reason)

func _verify() -> void:
    var paths: Array[String]=CATALOG.supplemental_paths()
    check(paths.size()==5 and paths[4]==FLIGHT.OPTIONAL_C17,
        "unified asset manifest is inconsistent")
    var imported: int=0
    for path in paths:
        if not ResourceLoader.exists(path):
            continue
        var scene:=load(path) as PackedScene
        check(scene!=null,"asset import failed: "+path)
        if scene==null:
            continue
        var model:=scene.instantiate() as Node3D
        check(model!=null,"asset root must be 3D "+path)
        if model==null:
            continue
        root.add_child(model)
        var meshes: Array[Node]=model.find_children(
            "*","MeshInstance3D",true,false)
        check(meshes.size()>0,"asset contains no visible meshes "+path)
        var min_clips: int=0
        if path==CATALOG.PISTOL_ANIM_MODEL or path==CATALOG.AK_ANIM_MODEL:
            min_clips=11
        elif path==CATALOG.SAPS_ANIM_MODEL:
            min_clips=10
        if min_clips>0:
            var animator:=model.find_child(
                "*AnimationPlayer*",true,false) as AnimationPlayer
            check(animator!=null,"FPS rig lost AnimationPlayer "+path)
            if animator!=null:
                check(animator.get_animation_list().size()>=min_clips,
                    "FPS reference lost authored clips "+path)
        imported+=1
        model.queue_free()
    var body:=CharacterBody3D.new()
    root.add_child(body)
    var flight: Node3D=FLIGHT.new()
    root.add_child(flight)
    flight.player=body
    flight._build_craft()
    var fallback: MeshInstance3D=body.get_node_or_null(
        "AuroraTransportAircraft/TransportFuselage") as MeshInstance3D
    check(fallback!=null,"procedural fallback was removed")
    var c17: Node3D=body.get_node_or_null(
        "AuroraTransportAircraft/AuroraImportedTransport") as Node3D
    if ResourceLoader.exists(FLIGHT.OPTIONAL_C17):
        check(c17!=null,"user C17 was not instantiated")
        if c17!=null:
            check(c17.scale.is_finite() and c17.scale.x>.02 and
                c17.scale.x<.5 and not fallback.visible,
                "imported plane has wrong scale or duplicated old meshes")
    else:
        check(c17==null and fallback!=null and fallback.visible,
            "original plane no longer appears without asset pack")
    flight.queue_free()
    body.queue_free()
    if not failed:
        print("AURORA_ASSET_BRIDGE PASS staged=",imported,
            " aircraft_hero=",c17!=null,
            " procedural_fallback=preserved retarget=required")
    quit(1 if failed else 0)
