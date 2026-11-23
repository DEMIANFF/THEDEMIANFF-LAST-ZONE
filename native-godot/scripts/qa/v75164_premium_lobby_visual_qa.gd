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
    # Verify renderer submissions using the authored transforms that were
    # passed to MultiMesh.set_instance_transform. Headless GPU readback of
    # packed instance positions reported 0/0 in earlier runs despite
    # successfully constructing 588 visible 3D instances.
    var audit: Dictionary=stage._runway_batch_audit
    var multimeshes: Array=stage.find_children("*","MultiMeshInstance3D",true,false)
    var batch_count: int=multimeshes.size()
    check(int(audit.get("edge_count",-1))==44 and
        int(audit.get("center_count",-1))==7 and
        bool(audit.get("side_submitted",false)) and
        bool(audit.get("center_submitted",false)),
        "physical runway transform submission invalid: "+str(audit))
    check(batch_count<=12,
        "airfield GPU batches exceeded mobile budget: "+str(batch_count))
    var bars: HBoxContainer=front._bottom_navigation
    check(bars.get_child_count()==5 and bars.get_node_or_null("BottomPRESET")==null,
        "five functional footer tabs and no PRESET required")
    var left: VBoxContainer=front._left_shortcuts
    check(left.get_child_count()==5 and left.get_node_or_null("QuickJUGAR")==null,
        "five functional left shortcuts required; no duplicate JUGAR")
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
