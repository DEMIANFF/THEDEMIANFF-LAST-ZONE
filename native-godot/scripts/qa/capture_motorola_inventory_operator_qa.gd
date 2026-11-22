extends SceneTree
## Genuine native Godot 964x434 composition evidence for new lobby modules.
## Desktop GL compatibility captures do not prove physical Motorola Vulkan QA.
const CAPTURE_VERSION=preload("res://scripts/qa/aurora_capture_version.gd")
const GEAR=preload("res://scripts/combat/aurora_equipment_families.gd")


func _initialize() -> void:
    call_deferred("_capture")


func _save(screen: String,tag: String) -> bool:
    var image: Image=root.get_texture().get_image()
    if image.get_size()!=Vector2i(964,434):
        push_error("V75130_CAPTURE incorrect physical viewport "+str(image.get_size()))
        return false
    var path: String="res://out/aurora-%s-motorola-%s.png"%[tag,screen]
    if image.save_png(path)!=OK:
        push_error("V75130_CAPTURE cannot save "+path)
        return false
    print("V75130_CAPTURE screen=",screen," output=",path)
    return true


func _capture() -> void:
    root.size=Vector2i(964,434)
    var tag: String=CAPTURE_VERSION.tag()
    if tag.is_empty():
        push_error("V75130_CAPTURE missing version tag")
        quit(2)
        return
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    front._enter_local_lobby()
    for frame in range(12):
        await process_frame
    # V75.155: show the actual sole selector in the right-side BR panel.
    # No modal gallery, PRESET footer, or centre-left floating MODOS button.
    front._select_tab("JUGAR")
    if (front._match_mode_selector==null or
            not front._match_mode_selector.visible or
            front._mode_gallery_entry!=null or
            front._mode_gallery_overlay!=null or
            front._bottom_navigation.get_node_or_null("BottomPRESET")!=null):
        push_error("V75155_CAPTURE redundant MODOS/PRESET still rendered")
        quit(6)
        return
    for frame in range(10):
        await process_frame
    front._layout_safe()
    await RenderingServer.frame_post_draw
    if not _save("mode-selector",tag):
        quit(7)
        return
    # Visual evidence for the real settings path and four editable HUD slots.
    front._top_settings_button.emit_signal("pressed")
    var modal: CanvasLayer=front._settings_modal
    if (modal==null or
            modal.find_child("HUDPresetSelector",true,false)==null or
            modal.find_child("EditCurrentHud",true,false)==null):
        push_error("V75155_CAPTURE HUD is not inside top-right AJUSTES")
        quit(12)
        return
    for frame in range(8):
        await process_frame
    await RenderingServer.frame_post_draw
    if not _save("settings-hud",tag):
        quit(13)
        return
    modal.call("_close")
    front._select_tab("TIENDA")
    front._open_skin_gallery()
    if front._shop_gallery_overlay==null or (
            not front._shop_gallery_overlay.visible):
        push_error("V75132_CAPTURE real Lila shop gallery did not open")
        quit(8)
        return
    for frame in range(10):
        await process_frame
    front._layout_safe()
    await RenderingServer.frame_post_draw
    if not _save("skin-gallery",tag):
        quit(9)
        return
    front._close_skin_gallery()
    front._select_tab("OBJETIVOS")
    if front._objectives_progress_panel==null or (
            not front._objectives_progress_panel.visible):
        push_error("V75136_CAPTURE verified local mission progress not visible")
        quit(10)
        return
    for frame in range(10):
        await process_frame
    front._layout_safe()
    await RenderingServer.frame_post_draw
    if not _save("local-objectives",tag):
        quit(11)
        return
    front._select_tab("INVENTARIO")
    front._equipment_category_selector.select(GEAR.PROTECTION)
    front._on_equipment_category_selected(GEAR.PROTECTION)
    for frame in range(9):
        await process_frame
    front._layout_safe()
    await RenderingServer.frame_post_draw
    if not _save("inventory",tag):
        quit(3)
        return
    front._select_tab("PERSONAJE")
    for frame in range(9):
        await process_frame
    front._layout_safe()
    await RenderingServer.frame_post_draw
    if not _save("operator-lila",tag):
        quit(4)
        return
    if front._operator_selector!=null and (
            not front._operator_selector.is_item_disabled(1)):
        front._operator_selector.select(1)
        front._on_operator_selected(1)
        if front._preview_male_active:
            for frame in range(12):
                await process_frame
            front._layout_safe()
            await RenderingServer.frame_post_draw
            if not _save("operator-ch02",tag):
                quit(5)
                return
    front._welcome()
    front.queue_free()
    for frame in range(7):
        await process_frame
    print("V75136_CAPTURE PASS resolution=964x434 "+
        "local_objectives=1 skin_gallery=1 right_mode_selector=1 hud_in_settings=1 "+
        "inventory=1 lila=1 optional_ch02=source_dependent")
    quit(0)
