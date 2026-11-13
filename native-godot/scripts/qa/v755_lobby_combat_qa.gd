extends SceneTree
## Regression of actual lobby actions, saved data and live tactical HUD heading.
var failed: bool=false

func _initialize() -> void:
    call_deferred("verify")


func check(ok: bool, message: String) -> void:
    if not ok:
        failed=true
        push_error("V755_LOBBY_COMBAT "+message)


func verify() -> void:
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    front._show_lobby()
    await process_frame
    check(front.stage=="lobby","lobby not displayed")
    check(front._lobby_nav!=null and front._lobby_nav.get_child_count()==8,
        "merged objectives navigation tabs missing")
    check(front._preview_container.visible,"character 3D preview hidden")
    check(front._surface.has_node("OriginalAuroraCoast"),"Aurora background missing")
    check(front._page.find_child("BattleButton",true,false)!=null,"BR launch missing")
    check(front._page.find_child("TrainingButton",true,false)!=null,"training launch missing")
    for tab in ["PERSONAJE","ARMAS","OBJETIVOS","TIENDA","PASE","SOCIAL","CUENTA","AJUSTES"]:
        front._select_tab(tab)
        check(front._info.text.length()>15,"empty tab "+tab)
        check(front._settings_panel.visible==(tab=="AJUSTES"),"incorrect setting panel visibility "+tab)
    check(front._info.text.find("Sensibilidad")>=0,"camera setting disclosure")
    front._select_tab("PERSONAJE")
    for resolution in [Vector2i(1024,768),Vector2i(1280,720),Vector2i(2712,1220)]:
        root.size=resolution
        await process_frame
        await process_frame
        front._layout_safe()
        var visible: Rect2=root.get_visible_rect()
        for control in front.find_children("*","Button",true,false):
            if control.is_visible_in_tree():
                check(visible.encloses(control.get_global_rect()),"off-screen "+control.name+" "+str(resolution))
        check(visible.encloses(front._preview_container.get_global_rect()),"character outside screen "+str(resolution))
    front.queue_free()
    await process_frame

    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var hud=game.get_node("TrainingHUD")
    var player=game.get_node("Operator")
    check(hud._training_radar.get("player")==player,"minimap lacks real player")
    player.set("_yaw",deg_to_rad(90.0))
    hud._refresh_heading()
    check(hud._compass.text.begins_with("E  090"),"east heading mismatch "+hud._compass.text)
    player.set("_yaw",deg_to_rad(225.0))
    hud._refresh_heading()
    check(hud._compass.text.begins_with("SO  225"),"southwest heading mismatch "+hud._compass.text)
    hud.set_air_stage("aircraft")
    check(not hud._reticle.visible,"reticle visible on aircraft")
    hud.set_air_stage("ground")
    check(hud._reticle.visible,"reticle missing on ground")
    hud.set_aim(true,"AWM",8.0)
    check(hud._reticle.zoom>=8.0,"AWM 8x reticle missing")
    check(hud._aim_button.text=="8X","AWM aim label incorrect")
    hud.set_aim(false,"",1.0)
    check(hud._aim_button.text=="MIRA","normal aim label incorrect")
    print("V755_LOBBY_COMBAT PASS: original menu, real actions, responsive UI, live heading, aircraft and 8x reticle")
    quit(1 if failed else 0)
