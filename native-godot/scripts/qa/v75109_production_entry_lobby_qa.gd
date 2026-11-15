extends SceneTree
## V75.109 native user-facing composition, NOT a screenshot overlay.
## Verify actual panel stacking, tap targets, real resource loading,
## live Battle Royale action and clean entry/lobby lifecycle.
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V75109_PRODUCTION_UI "+message)

func _verify() -> void:
    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    await process_frame
    check(front.stage=="welcome" and not front._loading_overlay.visible,
        "auth was displayed before authentic Godot resource load finished")
    check(front._loading_meter.value==100 and front._game==null,
        "login did not use the actual resource load progress")
    check(front._entry_glass.is_visible_in_tree() and
        front._entry_mission_caption.is_visible_in_tree(),
        "real login composition invisible")
    check(front._preview_container==null,
        "login incorrectly retained 3D lobby VRAM")
    var safe: Rect2=root.get_visible_rect()
    var input_buttons: Array=[
        front._login_google_button,
        front._login_guest_button,
        front._login_local_button
    ]
    var last_bottom: float=-1
    for button in input_buttons:
        var rect: Rect2=button.get_global_rect()
        check(button.is_visible_in_tree() and
            safe.grow(.5).encloses(rect) and rect.size.y>=38.0,
            "login action clipped or too small: "+button.name)
        check(rect.position.y>last_bottom,
            "login actions overlap or are not ordered vertically")
        last_bottom=rect.end.y
    var art: Control=front._surface.get_node("AuroraWinterBaseArtwork")
    check(front._entry_glass.get_index()>art.get_index() and
        safe.encloses(front._entry_glass.get_global_rect()),
        "login panel is behind artwork or beyond safe bounds")
    front._login_local_button.pressed.emit()
    await process_frame
    check(front.stage=="lobby" and front._game==null and
        front._preview_avatar!=null,"offline login did not enter real lobby")
    check(not front._entry_glass.visible and
        not front._entry_mission_caption.visible,
        "entry glass overlays Battle Royale UI")
    check(front._lobby_backplates.size()==3,
        "operational header, menu and commerce panels missing")
    for panel in front._lobby_backplates:
        check(panel.is_visible_in_tree() and
            panel.get_index()>art.get_index(),
            "real lobby panel is hidden behind painted background")
    check(front._battle_entry.visible and
        front._battle_entry.custom_minimum_size.y>=54 and
        front._left_shortcuts.visible and
        front._social_panel.visible and
        front._bottom_navigation.visible,
        "production lobby lost primary action or navigation")
    check(front._preview_container.visible and
        front._preview_avatar.find_child("AnimationPlayer",true,false)!=null,
        "Lila is not an actual animated model")
    var main_card: Control=front._play_match_card
    var scene: Node3D=front._preview_container.get_node(
        "PreviewViewport/AuroraCharacterStage")
    var env:=scene.get_node("WorldEnvironment") as WorldEnvironment
    # Directional key lighting is still a real scene node, not baked art.
    var bright: bool=false
    for child in scene.get_children():
        if child is DirectionalLight3D and child.light_energy>=1.5:
            bright=true
    check(bright,"live 3D operator lighting was not upgraded")
    check(main_card.visible and main_card.get_index()>art.get_index(),
        "BR mode card is hidden behind artwork")

    for dimensions in [Vector2i(964,434),Vector2i(1280,720)]:
        root.size=dimensions
        await process_frame
        await process_frame
        front._layout_safe()
        await process_frame
        safe=root.get_visible_rect()
        for control in [front._preview_container,front._battle_entry,
                front._social_panel,front._top_settings_button,
                front._bottom_navigation]:
            check(safe.grow(1).encloses(control.get_global_rect()),
                "functional lobby control beyond safe screen: "+
                control.name+" "+str(dimensions))
    front._select_tab("TIENDA")
    check(not front._battle_entry.visible and
        front._shop_selector.visible,
        "BR actions cover live store")
    front._bottom_navigation.get_node("BottomJUGAR").pressed.emit()
    check(front._battle_entry.visible and front._selected_tab=="JUGAR",
        "bottom JUGAR did not restore real match action")
    front._welcome()
    await process_frame
    check(front._entry_glass.is_visible_in_tree() and
        front._entry_mission_caption.is_visible_in_tree() and
        front._preview_container==null and
        not front._left_shortcuts.visible and
        not front._social_panel.visible,
        "logout leaked old 3D world/commerce UI into login")
    for panel in front._lobby_backplates:
        check(not panel.visible,"lobby glass panel not hidden on logout")
    check(front._login_google_button.visible and
        front._login_guest_button.visible,
        "Google/guest providers unavailable after account change")
    front.queue_free()
    await process_frame
    if not failed:
        print("V75109_PRODUCTION_UI PASS loading=real login=vertical "+
            "responsive=1 stage=3d panels=front CTA=real logout=clean")
    quit(1 if failed else 0)
