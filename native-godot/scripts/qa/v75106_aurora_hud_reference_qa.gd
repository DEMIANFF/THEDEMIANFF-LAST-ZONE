extends SceneTree
## V75.106 real HUD preset and live lobby navigation acceptance.
const HUD_LAYOUT=preload("res://scripts/persistence/hud_layout.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,description: String) -> void:
    if not ok:
        failed=true
        push_error("V75106_AURORA_HUD "+description)

func _verify() -> void:
    root.size=Vector2i(964,434)
    # Open the actual lobby first: its scene registers and owns the
    # music/settings services exactly as in Android, not in isolation.
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    front._enter_local_lobby()
    var original_slot: int=HUD_LAYOUT.selected_preset()
    check(HUD_LAYOUT.choose_preset(1)==OK,"cannot select original HUD slot")
    var original: RefCounted=HUD_LAYOUT.new()
    # Read-only snapshot: QA must NOT write a synthetic joystick into HUD 1,
    # because other suites reuse this isolated test profile and test multiple
    # aspect ratios. The factory/user layout is sacrosanct.
    var original_snapshot: Dictionary=original.controls.duplicate(true)
    front._open_settings()
    var settings: CanvasLayer=front._settings_modal
    var action: Button=settings._content.find_child(
        "ApplyAuroraHudReference",true,false) as Button
    check(action!=null and action.visible,
        "Aurora HUD install control is not accessible in settings")
    if action==null:
        paused=false
        quit(1)
        return
    action.pressed.emit()
    check(HUD_LAYOUT.selected_preset()==4,
        "Aurora preset did not activate slot 4")
    var active: RefCounted=HUD_LAYOUT.new(HUD_LAYOUT.slot_path(4))
    check(active.loaded and active.controls.size()==HUD_LAYOUT.IDS.size(),
        "Aurora preset failed to persist all 15 touch actions")
    check(HUD_LAYOUT.choose_preset(1)==OK,"cannot inspect original HUD slot")
    var original_after: RefCounted=HUD_LAYOUT.new()
    check(original_after.controls==original_snapshot,
        "Aurora preset altered any persisted HUD 1 control")
    var fire: Dictionary=active.get_item("DirectionalFirePad")
    var stick: Dictionary=active.get_item("MovePad")
    check(fire.get("center",Vector2.ZERO).x>.7 and
        stick.get("center",Vector2.ONE).x<.3,
        "joystick and drag fire are not placed on opposite sides")
    check(active.set_item("MIRA",Vector2(.72,.73),1.12,.85)==OK,
        "customizing Aurora ADS control failed")
    check(active.save()==OK,"custom Aurora HUD did not persist")
    var second: Button=settings._content.find_child(
        "ApplyAuroraHudReference",true,false) as Button
    check(second!=null,"Aurora HUD action disappeared after selection")
    if second!=null:
        second.pressed.emit()
    var preserved: RefCounted=HUD_LAYOUT.new(HUD_LAYOUT.slot_path(4))
    check(preserved.get_item("MIRA").get("center",Vector2.ZERO)==Vector2(.72,.73),
        "reselecting Aurora discarded the player's existing edits")
    settings._close()
    paused=false
    await process_frame

    var hud: CanvasLayer=load("res://scripts/ui/native_hud.gd").new()
    root.add_child(hud)
    await process_frame
    hud._hud_layout=preserved
    hud._layout()
    var safe: Rect2=root.get_visible_rect()
    for id in HUD_LAYOUT.IDS:
        var control: Control=hud.hud_editor_target(id)
        check(control!=null,"missing real touch control "+id)
        if control!=null:
            check(safe.grow(1.5).encloses(control.get_global_rect()),
                "Aurora HUD touch action outside Motorola bounds: "+id)
    var icon_script=preload("res://scripts/ui/hud_action_icon.gd")
    for id in ["MIRA","RECARGA","ARMA","CORRER","SALTAR","AGACHAR",
            "CURAR 2","BARRERA 0","GRANADA","MOCHILA","AJUSTES"]:
        var button: Button=hud.hud_editor_target(id) as Button
        var art: Control=button.get_node_or_null("AuroraActionIcon") as Control
        check(art!=null and art.mouse_filter==Control.MOUSE_FILTER_IGNORE and
            button.get_theme_color("font_color").a==0.0 and
            icon_script.texture_for(str(icon_script.IDS[id]))!=null,
            "illustrated action missing or intercepts input: "+id)
    check(icon_script.texture_for("fire")!=null,
        "directional fire lacks its original vector icon")
    hud.open_hud_editor()
    check(hud._hud_editing and hud._grenade_button.visible,
        "granade icon cannot be edited in training")
    hud._hud_edit_close()
    var pad: Control=hud.hud_editor_target("MovePad")
    var trigger: Control=hud.hud_editor_target("DirectionalFirePad")
    if pad!=null and trigger!=null:
        check(not pad.get_global_rect().intersects(trigger.get_global_rect()),
            "movement stick and fire controls overlap")

    hud.queue_free()
    await process_frame
    var avatar: Node3D=front._preview_avatar
    front._select_tab("TIENDA")
    check(not front._battle_entry.visible and front._shop_selector.visible,
        "shop tab is not isolated from Battle Royale actions")
    var home: Button=front._bottom_navigation.get_node_or_null("BottomJUGAR") as Button
    check(home!=null and home.is_visible_in_tree(),
        "visible return to JUGAR is missing")
    if home!=null:
        home.pressed.emit()
    check(front._selected_tab=="JUGAR" and front._battle_entry.visible and
        front._social_panel.visible and avatar==front._preview_avatar,
        "return to JUGAR did not restore same live lobby and Lila")
    front.queue_free()
    HUD_LAYOUT.choose_preset(original_slot)
    if not failed:
        print("V75106_AURORA_HUD PASS preset4=15 controls saved preserved=1 mobile_bounds=1 shop_to_play=1")
    quit(1 if failed else 0)
