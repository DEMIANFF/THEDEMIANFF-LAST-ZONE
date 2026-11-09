extends SceneTree
var failed: bool=false

func _initialize() -> void:
    call_deferred("_capture")

func capture(name: String) -> void:
    for i in range(12):
        await process_frame
    await RenderingServer.frame_post_draw
    var picture: Image=root.get_texture().get_image()
    var black_columns: int=0
    for x in range(picture.get_width()):
        var dark: bool=true
        for y in [20,picture.get_height()/2,picture.get_height()-20]:
            var c: Color=picture.get_pixel(x,y)
            dark=dark and maxf(c.r,maxf(c.g,c.b))<.003
        if dark:
            black_columns+=1
    print("RESPONSIVE_RENDER ",name," ",picture.get_size()," black_columns=",black_columns)
    if black_columns>picture.get_width()/100 or picture.save_png("res://out/"+name+".png")!=OK:
        failed=true
        push_error("Unexpected black bars or capture failure")

func _capture() -> void:
    root.size=Vector2i(2712,1220)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await capture("v756-motorola-welcome")
    front._show_lobby()
    await capture("v756-motorola-lobby")
    for tab in ["ARMAS","MISIONES","TIENDA","CUENTA","AJUSTES"]:
        front._select_tab(tab)
        await capture("v756-motorola-"+tab.to_lower())
    front._launch(false)
    for i in range(8):
        await process_frame
    var game: Node=front._game
    var player=game.get_node("Operator")
    var combat=game.get_node("CombatRange")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await capture("v756-motorola-game")
    player.set_crouch(true)
    await capture("v756-motorola-crouch")
    player.set_crouch(false)
    player.set_touch_move_axis(Vector2(0,-.65))
    combat.ammo[0]=1
    combat._on_reload()
    await capture("v756-motorola-moving-reload")
    player.set_touch_move_axis(Vector2.ZERO)
    player.set_ads(true,4.0)
    player._turn_camera(Vector2(-40,22))
    await capture("v756-motorola-ads-aim")
    player.set_ads(false,1.0)
    game.get_node("AuroraSectorMatch").begin_aircraft_phase()
    await capture("v756-motorola-aircraft")
    var flight=game.get_node("AuroraSectorMatch")._flight
    flight.jump_from_aircraft()
    flight.deploy_parachute()
    player._turn_camera(Vector2(150,-50))
    await capture("v756-motorola-parachute")
    quit(1 if failed else 0)
