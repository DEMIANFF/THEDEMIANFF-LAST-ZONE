extends SceneTree
## V75.112: true native sign-in UI at desktop and compact Motorola aspect.
## The optional brief must not conceal any real Google/Guest/Offline action.
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,problem: String) -> void:
    if not ok:
        failed=true
        push_error("V75112_AUTH_BRIEFING "+problem)


func _test_login_actions(front: Control) -> void:
    var safe: Rect2=root.get_visible_rect()
    var previous_bottom: float=-1.0
    for button in [front._login_google_button,front._login_guest_button,
            front._login_local_button]:
        var area: Rect2=button.get_global_rect()
        check(button.is_visible_in_tree() and safe.grow(.5).encloses(area),
            "login action clipped: "+button.name+" at "+str(root.size))
        check(area.size.x>=40.0 and area.size.y>=40.0,
            "login action too small: "+button.name)
        check(area.position.y>=previous_bottom,
            "login actions overlapped at "+str(root.size))
        previous_bottom=area.end.y


func _verify() -> void:
    root.size=Vector2i(1280,720)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    await process_frame
    check(front.stage=="welcome" and front._preview_container==null,
        "real entry loaded the 3D lobby before authentication")
    var briefing: PanelContainer=front._entry_info_panel
    check(briefing!=null and briefing.name=="AuroraMissionBriefing",
        "native mission briefing panel missing")
    check(briefing.visible and briefing.is_visible_in_tree(),
        "large landscape screen did not show the original information panel")
    check(briefing.get_global_rect().size.y>=112.0,
        "mission briefing collapsed vertically")
    var content: VBoxContainer=briefing.get_node("MissionBriefingContent")
    check(content.get_child_count()==3,
        "briefing has missing live text children")
    check((content.get_child(1) as Label).text.contains("50 PARTICIPANTES") and
        (content.get_child(2) as Label).text.contains("49 rivales IA"),
        "briefing falsely claims server matchmaking instead of local BR")
    check(front._entry_mission_caption.anchor_top<=.43,
        "mission copy still starts over the distant hangar horizon")
    _test_login_actions(front)

    root.size=Vector2i(964,434)
    await process_frame
    front._layout_safe()
    await process_frame
    print("V75112_LAYOUT_DIAGNOSTIC root=",root.size,
        " viewport=",front.get_viewport().size,
        " surface=",front._surface.size," info_visible=",briefing.visible)
    check(not briefing.visible,
        "optional briefing blocked compact Motorola login")
    _test_login_actions(front)
    check(front._login_google_button.get_parent()==
        front._login_local_button.get_parent(),
        "Google, Guest and Offline controls no longer share one native layout")

    front._login_local_button.pressed.emit()
    await process_frame
    check(front.stage=="lobby" and front._preview_avatar!=null,
        "compact login did not reach the actual 3D lobby")
    front._welcome()
    await process_frame
    check(front.stage=="welcome" and
        not front._entry_info_panel.visible and
        front._preview_container==null,
        "logout leaked 3D renderer or expanded briefing onto compact login")

    root.size=Vector2i(1280,720)
    await process_frame
    front._layout_safe()
    await process_frame
    check(front._entry_info_panel.visible and
        front._entry_info_panel.get_global_rect().size.y>=112.0,
        "returning to larger screen did not restore native briefing")
    _test_login_actions(front)
    front.queue_free()
    await process_frame
    if not failed:
        print("V75112_AUTH_BRIEFING PASS 1280=rich 964=compact "+
            "auth=real logout=clean")
    quit(1 if failed else 0)
