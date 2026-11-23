extends SceneTree
## V75.169: test the real companion rendered by Boot.tscn in a Godot lobby.
## A previous material-only batch silently flattened two spherical eyes into
## boxes. Validate mesh topology AND instances, not just GPU batch count.
var failed: bool=false


func check(ok: bool, reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75169_SENTINEL_MESH "+reason)


func _initialize() -> void:
    call_deferred("_verify")


func _verify() -> void:
    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    front._enter_local_lobby()
    await process_frame
    front._layout_safe()
    await process_frame
    var world: Node3D=front._preview_container.get_node(
        "PreviewViewport/AuroraCharacterStage") as Node3D
    var robot: Node3D=world.get_node_or_null(
        "AuroraSentinelCompanion") as Node3D
    check(robot!=null and front._preview_avatar!=null,
        "the real Lila lobby must retain its 3D companion")
    if robot==null:
        front.queue_free()
        quit(1)
        return

    # Required mesh types are verified independently of shader or color.
    # Batching spheres together with boxes is a geometry defect even if
    # the earlier visual test reports success.
    var expected: Dictionary={
        "AlloyShell":["SphereMesh",2],
        "ArmorShell":["SphereMesh",11],
        "ArmorPanels":["BoxMesh",5],
        "Rubber":["SphereMesh",9],
        "Violet":["BoxMesh",5],
        "Cyan":["BoxMesh",5],
        "CyanEyes":["SphereMesh",2],
        "AlloyJoints":["CylinderMesh",8]
    }
    var batches: Array=robot.find_children(
        "*","MultiMeshInstance3D",true,false)
    check(batches.size()==expected.size(),
        "companion must use exactly eight batched physical material/topology sets")
    var total: int=0
    for key in expected.keys():
        var node: MultiMeshInstance3D=robot.get_node_or_null(
            "Sentinel"+str(key)) as MultiMeshInstance3D
        check(node!=null,"missing geometry batch "+str(key))
        if node==null or node.multimesh==null:
            continue
        var requirement: Array=expected[key]
        var mesh: Mesh=node.multimesh.mesh
        var amount: int=node.multimesh.instance_count
        check(mesh!=null and mesh.get_class()==str(requirement[0]),
            str(key)+" uses incorrect physical mesh topology")
        check(amount==int(requirement[1]),
            str(key)+" submitted "+str(amount)+" rather than "+
            str(requirement[1])+" instances")
        check(node.material_override is StandardMaterial3D and
            node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
            str(key)+" lost mobile-friendly PBR material/shadow policy")
        total+=amount
    check(total==47,"robot physical details must sum to 47 instances")
    var eyes: MultiMeshInstance3D=robot.get_node_or_null(
        "SentinelCyanEyes") as MultiMeshInstance3D
    if eyes!=null and eyes.multimesh!=null:
        check(eyes.multimesh.mesh is SphereMesh and
            eyes.multimesh.instance_count==2,
            "two cyan eyes must retain separate rounded geometry")
    var tail: Node3D=robot.get_node_or_null(
        "CompanionTailPivot") as Node3D
    check(tail!=null,"physical articulated tail is missing")
    if tail!=null:
        check(tail.get_node_or_null("TailLink") is MeshInstance3D and
            tail.get_node_or_null("TailTip") is MeshInstance3D and
            tail.get_node_or_null("TailLight") is MeshInstance3D,
            "all three mechanical tail sections must remain real 3D meshes")
        robot._process(.1)
        var first: float=tail.rotation.y
        robot._process(.1)
        check(absf(tail.rotation.y-first)>.001,
            "tail should actually animate without allocating GPU meshes")
    check(robot.find_children("*","OmniLight3D",true,false).is_empty(),
        "the companion cannot create mobile-expensive point lights")
    check(front._bottom_navigation.get_child_count()==5 and
        front._mode_gallery_entry==null and
        front._match_mode_selector.is_visible_in_tree(),
        "geometry upgrade introduced a duplicate or missing lobby action")
    front._welcome()
    await process_frame
    check(front._preview_container==null,
        "return to login must release the companion with its 3D viewport")
    front.queue_free()
    await process_frame
    if not failed:
        print("V75169_SENTINEL_MESH PASS 8_batches=1 rounded_eyes=2 "+
            "physical_parts=47 moving_tail=1 mobile_lights=0 "+
            "real_Lila=1 lobby_ui=unchanged released_viewport=1")
    quit(1 if failed else 0)
