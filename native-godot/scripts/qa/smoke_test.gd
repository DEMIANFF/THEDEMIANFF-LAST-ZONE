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
    var opponent: Node=main.get_node_or_null("CombatRange/AuroraPatrol1")
    if opponent == null or not opponent.is_in_group("training_target"):
        push_error("V73 training enemy actor not loaded")
        quit(13)
        return
    if OS.get_environment("AURORA_REQUIRE_OPERATOR") == "1":
        if operator.find_child("AWMPrecisionRifleVisual", true, false)==null:
            push_error("AWM is gameplay-only; no physical 3D mesh was imported")
            quit(16)
            return
        if operator.find_child("AK74TacticalVisual", true, false)==null:
            push_error("V73 imported AK-74 missing; no proxy rifle accepted")
            quit(14)
            return
        var rig := operator.get_node_or_null("AuroraFemaleRiggedOperator")
        if rig == null:
            push_error("Requested CC0 operator not imported into native scene")
            quit(9)
            return
        var clips := rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
        if clips == null or clips.get_animation_list().size() < 3:
            push_error("Imported rig lacks the three authored locomotion clips")
            quit(11)
            return
        var ground_y: float = operator.global_position.y
        var visual_min: float = INF
        var visual_max: float = -INF
        for mesh in rig.find_children("*", "MeshInstance3D", true, false):
            # The visual rig has a BoneAttachment with both separate rifles;
            # those MUST NOT count toward the character's body height.
            var part := mesh as MeshInstance3D
            if str(part.get_path()).contains("RightHandWeaponSocket"):
                continue
            var bounds: AABB = part.get_aabb()
            for i in range(8):
                var y: float = part.to_global(bounds.get_endpoint(i)).y
                visual_min = minf(visual_min,y)
                visual_max = maxf(visual_max,y)
        if absf((visual_max-visual_min)-1.76)>.26 or absf(visual_min-ground_y)>.40:
            push_error("FBX body orientation or floor contact invalid: height="+str(visual_max-visual_min)+" bottom="+str(visual_min-ground_y))
            quit(12)
            return
        if rig.find_children("*", "Skeleton3D", true, false).is_empty():
            push_error("Imported operator has no Skeleton3D")
            quit(10)
            return
    if main.get_node_or_null("TrainingHUD/AuroraTacticalOverlay/DirectionalFirePad")==null:
        push_error("Directional fire touchpad missing")
        quit(15)
        return
    print("V73.2 TPS HUD OK: free camera, drag fire, reticle, actual armed patrols")
    quit(0)
