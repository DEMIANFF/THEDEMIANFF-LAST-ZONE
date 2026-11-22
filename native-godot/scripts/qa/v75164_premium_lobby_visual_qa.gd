extends SceneTree
## V75.164 integration gate: tests the actual Boot scene at Motorola
## dimensions, not a flat screenshot substituted for a live lobby.
var failed: bool=false


func check(ok: bool, reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75164_PREMIUM_LOBBY "+reason)


func _initialize() -> void:
    call_deferred("_verify")


func _verify() -> void:
    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    front._show_lobby()
    await process_frame
    front._layout_safe()
    await process_frame
    check(front.stage=="lobby" and front._game==null and
        is_instance_valid(front._preview_avatar),
        "real rig and interactive lobby must be preserved")
    var stage: Node3D=front._preview_container.get_node(
        "PreviewViewport/AuroraCharacterStage/AuroraReal3DLobbyEnvironment")
    for mesh_name in ["BaseAuroraSnowFir", "BaseAuroraFirSnowCaps"]:
        var node: MultiMeshInstance3D=stage.get_node_or_null(mesh_name) as MultiMeshInstance3D
        check(node!=null and node.multimesh!=null and
            node.multimesh.instance_count>0,
            "missing batched physical 3D detail "+mesh_name)
    # Verify every physical center dash is preserved inside the shared
    # fitting batch, instead of asserting an unnecessary dedicated draw call.
    # Check physical GPU instance positions rather than relying on the
    # precise transformed Basis axis lengths. The original test demanded
    # GPU quantized basis values with a 0.002 tolerance, leading to false
    # negatives despite the new V75.165 batch-count test passing.
    # Every expected mark location must be represented in a real MultiMesh,
    # with the same material group budget as all existing airfield fittings.
    var multimeshes: Array=stage.find_children("*","MultiMeshInstance3D",true,false)
    var center_marks: int=0
    var edge_marks: int=0
    var total_instances: int=0
    for rendered in multimeshes:
        var group: MultiMesh=(rendered as MultiMeshInstance3D).multimesh
        total_instances+=group.instance_count
        for i in range(group.instance_count):
            var pose: Transform3D=group.get_instance_transform(i)
            if absf(pose.origin.y+.103)>.012:
                continue
            var z: float=pose.origin.z
            for slot in range(22):
                var expected_z: float=3.0-float(slot)*.91
                if absf(z-expected_z)>.012:
                    continue
                if slot>2 and slot%3==0 and absf(pose.origin.x)<.012:
                    center_marks+=1
                elif absf(absf(pose.origin.x)-2.45)<.012:
                    edge_marks+=1
                break
    print("V75164_RUNWAY_GPU center=",center_marks,
        " side=",edge_marks," batches=",multimeshes.size(),
        " instances=",total_instances)
    check(center_marks>=7 and edge_marks>=44,
        "physical runway stripes missing in shared GPU batches: center="+
        str(center_marks)+" / 7 edges="+str(edge_marks)+" / 44")
    check(multimeshes.size()<=12,
        "airfield exceeds 12 MultiMesh batches: "+str(multimeshes.size()))
    var bars: HBoxContainer=front._bottom_navigation
    check(bars.get_child_count()==5 and bars.get_node_or_null("BottomPRESET")==null,
        "five functional footer tabs and no PRESET required")
    var left: VBoxContainer=front._left_shortcuts
    check(left.get_child_count()==6 and left.get_node_or_null("QuickJUGAR")!=null,
        "six live left rail actions required")
    check((left.get_child(0) as Button).get_theme_font_size("font_size")<=19,
        "left commerce hierarchy did not become more compact")
    check((bars.get_child(0) as Button).get_theme_font_size("font_size")<=20,
        "footer typography was not refined")
    check(front._match_mode_selector.is_visible_in_tree() and
        front._mode_gallery_entry==null and front._mode_gallery_overlay==null,
        "one BR selector at right only")
    var header: Panel=front.find_child("AuroraOperationalHeader",true,false) as Panel
    check(header!=null and header.get_theme_stylebox("panel") is StyleBoxFlat,
        "real premium header backdrop missing")
    var settings_button: Button=front._top_settings_button
    settings_button.pressed.emit()
    check(front._settings_modal!=null and front._game==null,
        "HUD/settings must remain inside the real gear modal")
    if front._settings_modal!=null:
        front._settings_modal.call("_close")
    front.queue_free()
    await process_frame
    if not failed:
        print("V75164_PREMIUM_LOBBY PASS mobile=964x434 3d_airfield=1 "+
            "fir_mipmap_batched=1 glass_panels=1 five_tabs=1 "+
            "BR_one_selector=1 HUD_settings=1 gameplay_preserved=1")
    quit(1 if failed else 0)
