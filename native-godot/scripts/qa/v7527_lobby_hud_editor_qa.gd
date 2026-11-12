extends SceneTree
## Native automated acceptance: actual lobby, match HUD, layout editing,
## backup recovery and reset. Physical Motorola touch still requires testing.
const HUD_LAYOUT=preload("res://scripts/persistence/hud_layout.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")


func check(condition: bool,detail: String) -> void:
    if not condition:
        failed=true
        push_error("V7527_HUD_EDITOR "+detail)


func _verify() -> void:
    var path: String="user://qa/v7527-hud-layout.cfg"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
    for suffix in ["",".tmp",".bak"]:
        var filename: String=ProjectSettings.globalize_path(path+suffix)
        if FileAccess.file_exists(filename):
            DirAccess.remove_absolute(filename)

    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    front._show_lobby()
    front._select_tab("AJUSTES")
    check(front._settings_panel.visible,"settings tab not visible in lobby")
    var editor_entry: Button=front._settings_panel.get_node_or_null("EditHUDEntry") as Button
    check(editor_entry!=null and editor_entry.visible and not editor_entry.disabled,
        "real HUD editor button not accessible from lobby settings")
    var portrait: Node3D=front._preview_avatar
    check(portrait!=null and is_instance_valid(portrait),
        "3D operator preview did not load")
    if portrait!=null:
        # Real portrait intentionally holds its opening pose for one second.
        # End that idle hold before measuring smooth automatic rotation.
        front._preview_resume_spin=0.0
        var before_y: float=portrait.rotation.y
        for i in range(9):
            await process_frame
        check(absf(angle_difference(before_y,portrait.rotation.y))>.004,
            "live animated 3D lobby portrait stopped rotating")
    check(front._surface.has_node("LobbyMenuBackplate") and
        front._surface.has_node("LobbySidebarBackplate"),
        "Aurora lobby background panels missing")

    front._launch_hud_editor()
    for i in range(16):
        await process_frame
    check(front.stage=="training" and front._game!=null,
        "HUD editor failed to load the real Training scene")
    if front._game==null:
        quit(1)
        return
    var hud: CanvasLayer=front._game.get_node("TrainingHUD")
    check(hud._hud_editing and paused and hud._hud_editor.visible,
        "HUD editor did not pause combat or enable the real edit overlay")

    var storage=HUD_LAYOUT.new(path)
    hud._hud_layout=storage
    hud._layout()
    var stick: Control=hud.hud_editor_target("MovePad")
    var firepad: Control=hud.hud_editor_target("DirectionalFirePad")
    check(stick!=null and firepad!=null,"movepad or drag-fire action absent")
    var safe: Rect2=Rect2(Vector2.ZERO,root.get_visible_rect().size)
    var origin: Vector2=firepad.get_global_rect().get_center()
    var wanted: Vector2=safe.position+safe.size*Vector2(.74,.70)
    hud.hud_editor_selected("DirectionalFirePad")
    hud.hud_editor_move("DirectionalFirePad",wanted)
    hud._hud_edit_adjust(.08,-.10)
    var saved_center: Vector2=firepad.get_global_rect().get_center()
    check(saved_center.distance_to(wanted)<2.0,
        "drag positioning not reflected on actual fired button")
    check(firepad.scale.x>1.05 and firepad.modulate.a<.95,
        "size and opacity edits did not change the real control")
    hud._hud_edit_save()
    check(FileAccess.file_exists(path),"HUD layout not saved to persistent disk")
    var restored=HUD_LAYOUT.new(path)
    check(restored.loaded and not restored.recovered,
        "HUD settings could not be read after process recreation")
    var item: Dictionary=restored.get_item("DirectionalFirePad")
    check(not item.is_empty() and float(item.get("scale",0))>1.05 and
        float(item.get("alpha",1))<.95,
        "save lost adjusted fire button size / alpha")
    check((item.get("center",Vector2.ZERO) as Vector2).distance_to(
        Vector2(.74,.70))<.015,
        "HUD positions must be normalized so they survive resolution changes")

    # Two durable writes leave a valid backup. A malformed primary must NOT
    # silently overwrite or destroy the previously valid layout.
    check(restored.set_item("MovePad",Vector2(.16,.75),1.10,.80)==OK,
        "valid analog joystick layout rejected")
    check(restored.save()==OK,"second HUD write failed to create backup")
    var file:=FileAccess.open(path,FileAccess.WRITE)
    if file:
        file.store_string("corrupt_v7527_layout")
        file.close()
    var recovered=HUD_LAYOUT.new(path)
    check(recovered.recovered and recovered.loaded and
        not recovered.get_item("DirectionalFirePad").is_empty(),
        "HUD backup recovery failed after corrupt save")

    hud._hud_layout=recovered
    hud._hud_edit_restore()
    check(recovered.get_item("DirectionalFirePad").is_empty() and
        HUD_LAYOUT.new(path).get_item("DirectionalFirePad").is_empty(),
        "restore factory HUD failed to remove personalized controls")
    check(absf(firepad.scale.x-1.0)<.001 and
        is_equal_approx(firepad.modulate.a,1.0),
        "factory restoration failed to restore native control scale / opacity")
    hud._hud_edit_close()
    check(not paused and not hud._hud_editing and not hud._hud_editor.visible,
        "closing edit session did not resume training and release overlay")
    front._return_to_lobby()
    for i in range(4):
        await process_frame
    check(front.stage=="lobby" and front._game==null and
        front._preview_container!=null and
        is_instance_valid(front._preview_container),
        "return to lobby did not restore 3D portrait after HUD editing")
    if not failed:
        print("V7527_HUD_EDITOR PASS real lobby preview, safe paused HUD editor,",
            " normalized drag/scale/opacity, durable save/recovery/reset",
            " and re-entry to 3D lobby")
    quit(1 if failed else 0)
