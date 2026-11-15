extends SceneTree
## V75.111: real 3D full-body camera projection, not a static background.
## Verify Lila stays clear of the Aurora top header and bottom rail.
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,description: String) -> void:
    if not ok:
        failed=true
        push_error("V75111_LILA_FRAMING "+description)


func _rig_vertical_extents(avatar: Node3D,camera: Camera3D) -> Vector2:
    var low: float=INF
    var high: float=-INF
    var corners: int=0
    for item in avatar.find_children("*","MeshInstance3D",true,false):
        var mesh:=item as MeshInstance3D
        if not mesh.visible:
            continue
        var bounds: AABB=mesh.get_aabb()
        for i in range(8):
            var world_point: Vector3=mesh.to_global(bounds.get_endpoint(i))
            if camera.is_position_behind(world_point):
                continue
            var pixel: Vector2=camera.unproject_position(world_point)
            low=minf(low,pixel.y)
            high=maxf(high,pixel.y)
            corners+=1
    check(corners>=8,"no real skinned model bounds projected")
    return Vector2(low,high)


func _verify() -> void:
    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    front._enter_local_lobby()
    await process_frame
    await process_frame
    var avatar: Node3D=front._preview_avatar
    var camera: Camera3D=front._preview_container.get_node_or_null(
        "PreviewViewport/AuroraCharacterStage/LobbyPortraitCamera") as Camera3D
    check(avatar!=null and camera!=null,
        "Lila and native 3D lobby camera must both exist")
    if avatar==null or camera==null:
        front.queue_free()
        quit(1)
        return
    check(absf(camera.fov-54.0)<.1 and camera.current,
        "default full-body camera was not applied")
    var preview: SubViewport=front._preview_container.get_node("PreviewViewport")

    for dimensions in [Vector2i(964,434),Vector2i(1280,720)]:
        root.size=dimensions
        await process_frame
        front._layout_safe()
        await process_frame
        var extents: Vector2=_rig_vertical_extents(avatar,camera)
        var viewport_height: float=float(preview.size.y)
        # Header finishes near 13.3% and the bottom controls begin at 87.6%.
        # Account for skinned hair/gear a little outside the rig's root AABB.
        check(is_finite(extents.x) and is_finite(extents.y) and
            extents.x>=viewport_height*.105 and
            extents.y<=viewport_height*.89,
            "operator projects into header or bottom rail at "+
            str(dimensions)+": "+str(extents)+" / "+str(viewport_height))
    front._operator_controls[2].pressed.emit()
    await create_timer(.38).timeout
    check(front._preview_zoomed and absf(camera.fov-45.0)<.3 and
        camera.position.y>1.43,
        "portrait framing did not move lens above operator's face")
    front._operator_controls[2].pressed.emit()
    await create_timer(.38).timeout
    check(not front._preview_zoomed and absf(camera.fov-54.0)<.3 and
        absf(camera.position.y-1.18)<.03,
        "full-body framing did not recover after portrait view")
    front.queue_free()
    await process_frame
    if not failed:
        print("V75111_LILA_FRAMING PASS actual_3d=1 full_body=2_sizes zoom=1")
    quit(1 if failed else 0)
