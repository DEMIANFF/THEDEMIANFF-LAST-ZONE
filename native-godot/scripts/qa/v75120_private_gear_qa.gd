extends SceneTree
## Godot regression for source-gated protective gear; never fake asset QA.
const GEAR=preload("res://scripts/player/aurora_private_equipment.gd")
const BACKPACK=preload("res://scripts/player/aurora_backpack_visual.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V75120_PRIVATE_GEAR "+message)


func _verify() -> void:
    var root3d:=Node3D.new()
    root.add_child(root3d)
    var staged: int=0
    var names: Array[String]=[GEAR.BACKPACK,GEAR.MEDKIT,GEAR.HELMET,GEAR.VEST]
    var target_sizes: Array[float]=[.55,.38,.34,.65]
    for i in range(names.size()):
        var path: String=names[i]
        check(path.begins_with("res://assets/gear/aurora_v3_private/"),
            "original source escaped non-distributed staging root")
        if not ResourceLoader.exists(path,"PackedScene"):
            check(GEAR.mount_optional(root3d,path,target_sizes[i])==null,
                "invented original asset when private model is absent")
            continue
        staged+=1
        var model: Node3D=GEAR.mount_optional(root3d,path,target_sizes[i])
        check(model!=null,"source GLB cannot be mounted as a 3D mesh")
        if model!=null:
            var mesh_count: int=0
            for child in model.find_children("*","MeshInstance3D",true,false):
                if (child as MeshInstance3D).mesh!=null:
                    mesh_count+=1
            check(mesh_count>0 and model.scale.is_finite() and
                model.scale.x>.00001 and model.scale.x<100.0,
                "original equipment has invalid dimensions or no meshes")
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var operator: CharacterBody3D=game.get_node("Operator")
    check(operator.has_method("set_backpack_visual_level"),
        "inventory backpack is not linked to operator rig")
    operator.set_backpack_visual_level(0)
    operator.set_backpack_visual_level(1)
    operator.set_backpack_visual_level(0)
    if not ResourceLoader.exists(GEAR.BACKPACK,"PackedScene"):
        check(operator._backpack_visual==null,
            "private backpack was added when its real model is absent")
    game.queue_free()
    root3d.queue_free()
    await process_frame
    if not failed:
        print("V75120_PRIVATE_GEAR PASS source_paths=4 staged=",staged,
            " fallback_safe=1 rig_binding=1 no_asset_claim_if_absent=1")
    quit(1 if failed else 0)
