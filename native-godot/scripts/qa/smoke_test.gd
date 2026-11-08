extends SceneTree
## Godot headless scene boot validation, not a physical Android performance test.


func _initialize() -> void:
    call_deferred("_verify")


func _verify() -> void:
    var scene_resource := load("res://scenes/Main.tscn")
    if not scene_resource is PackedScene:
        push_error("Main native scene is not importable")
        quit(1)
        return
    var main: Node3D = scene_resource.instantiate()
    root.add_child(main)
    await process_frame
    var terrain := main.get_node_or_null("AuroraTerrain")
    var operator := main.get_node_or_null("Operator")
    if terrain == null or operator == null:
        push_error("Missing native terrain/operator nodes")
        quit(2)
        return
    if terrain.get_node_or_null("ContinuousIslandSurface") == null:
        push_error("Terrain mesh was not built")
        quit(3)
        return
    if terrain.get_node_or_null("HeightfieldCollision") == null:
        push_error("Collision shape was not built")
        quit(4)
        return
    if main.get_node_or_null("PuertoAuroraSector") == null:
        push_error("Missing realistic Aurora district")
        quit(6)
        return
    var district := main.get_node("PuertoAuroraSector")
    if district.get_node_or_null("CENTRO_DE_EXPLORACION/AngledMetalRoof") == null:
        push_error("District roofs not assembled")
        quit(7)
        return
    if operator.get_node_or_null("CameraPivot/ThirdPersonCamera") == null:
        push_error("Native third-person camera not found")
        quit(5)
        return
    if main.get_node_or_null("TrainingHUD") == null or main.get_node_or_null("CombatRange") == null:
        push_error("Missing native combat HUD or target range")
        quit(8)
        return
    if OS.get_environment("AURORA_REQUIRE_OPERATOR") == "1":
        var rig := operator.get_node_or_null("AuroraFemaleRiggedOperator")
        if rig == null:
            push_error("Requested CC0 operator not imported into native scene")
            quit(9)
            return
        if rig.find_children("*", "Skeleton3D", true, false).is_empty():
            push_error("Imported operator has no Skeleton3D")
            quit(10)
            return
    print("V72 slice OK: island, structures, camera, touch HUD, actual weapon rays, rig check")
    quit(0)
