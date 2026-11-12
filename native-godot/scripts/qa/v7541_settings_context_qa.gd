extends SceneTree
## HUD editor must return to its actual origin. Match settings must pause,
## apply changes, and resume the exact world without a new training match.
const HUD_LAYOUT=preload("res://scripts/persistence/hud_layout.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(condition: bool,message: String) -> void:
    if not condition:
        failed=true
        push_error("V7541_SETTINGS "+message)


func frames(count: int) -> void:
    for i in range(count):
        await process_frame


func _verify() -> void:
    var prior_slot: int=HUD_LAYOUT.selected_preset()
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    front._show_lobby()
    check(front.stage=="lobby" and front._game==null,
        "lobby did not initialize without an active match")

    front._open_settings()
    var modal: CanvasLayer=front.get("_settings_modal") as CanvasLayer
    check(modal!=null and paused and modal.get("context_origin")=="lobby",
        "settings from lobby failed to preserve origin and pause")
    modal.call("_close")
    check(not paused and front.stage=="lobby" and front._game==null,
        "closing lobby settings unexpectedly started a training match")

    check(HUD_LAYOUT.choose_preset(2)==OK,
        "selecting second independent HUD layout failed")
    check(HUD_LAYOUT.selected_preset()==2 and
        HUD_LAYOUT.new().path==HUD_LAYOUT.slot_path(2),
        "HUD2 did not use a separate persistent layout file")
    check(HUD_LAYOUT.choose_preset(prior_slot)==OK,
        "could not restore previously selected HUD")

    front._launch_hud_editor()
    await frames(18)
    check(front.stage=="training" and front._game!=null,
        "lobby-requested editor did not open real customisable controls")
    if front._game==null:
        quit(1)
        return
    var hud: CanvasLayer=front._game.get_node("TrainingHUD")
    check(hud._hud_editing and paused,
        "lobby HUD editor did not pause its temporary live scene")
    hud._hud_edit_save()
    hud._hud_edit_close()
    await frames(5)
    check(front.stage=="lobby" and front._game==null and not paused,
        "closing HUD opened in lobby stranded player inside training")

    front._launch(false)
    await frames(18)
    check(front.stage=="training" and front._game!=null,
        "explicit training did not launch")
    if front._game==null:
        quit(1)
        return
    var training_game: Node3D=front._game
    hud=training_game.get_node("TrainingHUD")
    hud._layout()
    var root_hud: Control=hud.get_node("AuroraTacticalOverlay")
    for name in ["MIRA","RECARGA","ARMA","CORRER","AGACHAR",
            "CURAR 2","BARRERA 0","MOCHILA","AJUSTES"]:
        var button: Button=root_hud.get_node(name) as Button
        check(absf(button.size.x-button.size.y)<.1,
            "gameplay action "+name+" is still rectangular")
        var skin: StyleBoxFlat=button.get_theme_stylebox("normal") as StyleBoxFlat
        check(skin.corner_radius_top_left>=40,
            "button "+name+" has no circular touch silhouette")
    check(hud._settings_button!=null and hud._settings_button.visible,
        "no settings button available during live training")

    hud.emit_signal("settings_requested")
    modal=front.get("_settings_modal") as CanvasLayer
    check(modal!=null and paused and modal.get("context_origin")=="training",
        "training Settings did not open over the current session")
    modal.call("_show_category","SONIDO")
    var content: VBoxContainer=modal.get("_content")
    var effects: HSlider=content.find_child("Audio_effects",true,false) as HSlider
    check(effects!=null,"sound page has no real effects-volume slider")
    if effects!=null:
        var previous: float=effects.value
        effects.value=42
        var audio:=ConfigFile.new()
        audio.load("user://aurora_audio.cfg")
        check(absf(float(audio.get_value("audio","effects",0))-.42)<.015,
            "sound slider did not persist to actual audio file")
        effects.value=previous
    modal.call("_close")
    check(not paused and front.stage=="training" and
        front._game==training_game,
        "closing match settings replaced or restarted training")

    hud.open_hud_editor()
    check(hud._hud_editing and paused,
        "in-training HUD editor cannot open its persistent controls")
    hud._hud_edit_close()
    await frames(2)
    check(front.stage=="training" and front._game==training_game,
        "editing HUD during training returned to lobby unexpectedly")
    front._return_to_lobby()
    await frames(4)
    check(front.stage=="lobby","explicit leave-training failed")

    front._launch(true)
    await frames(18)
    if front._game==null:
        check(false,"Battle Royale did not load")
        quit(1)
        return
    var battle: Node3D=front._game
    var flight: Node3D=battle.get_node("AuroraSectorMatch")
    hud=battle.get_node("TrainingHUD")
    check(front.stage=="battle","real BR flow missing after frontend launch")
    check(hud._settings_button.visible,
        "settings gear disappeared during aircraft deployment")
    hud.emit_signal("settings_requested")
    modal=front.get("_settings_modal") as CanvasLayer
    check(modal!=null and paused and modal.get("context_origin")=="battle",
        "battle settings did not preserve battle context")
    modal.call("_close")
    check(not paused and front._game==battle and
        front.stage=="battle" and flight.mode=="aircraft",
        "closing battle settings reset aircraft or changed the active match")
    front._return_to_lobby()
    await frames(3)
    HUD_LAYOUT.choose_preset(prior_slot)
    if not failed:
        print("V7541_SETTINGS PASS lobby_preserved=1 live_match_preserved=1 "+
            "hud_presets=4 round_buttons=9 sound_persist=1 aircraft_menu=1")
    quit(1 if failed else 0)
