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
    await capture("v752-motorola-welcome")
    front._show_lobby()
    await capture("v752-motorola-lobby")
    for tab in ["ARMAS","MISIONES","TIENDA","CUENTA"]:
        front._select_tab(tab)
        await capture("v752-motorola-"+tab.to_lower())
    front._launch(false)
    for i in range(8):
        await process_frame
    var game: Node=front._game
    var player=game.get_node("Operator")
    var combat=game.get_node("CombatRange")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await capture("v752-motorola-game")
    player.set_crouch(true)
    await capture("v752-motorola-crouch")
    game.get_node("AuroraSectorMatch").begin_aircraft_phase()
    await capture("v752-motorola-aircraft")
    quit(1 if failed else 0)
