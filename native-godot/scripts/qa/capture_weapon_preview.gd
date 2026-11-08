extends SceneTree
## Side-by-side verification artifacts from Godot's actual renderer, not concept
## drawings. Tests the weapon switch in the third-person game scene.
func _initialize() -> void:
    call_deferred("_capture")


func _capture() -> void:
    var scene: PackedScene=load("res://scenes/Main.tscn")
    var game: Node3D=scene.instantiate()
    root.add_child(game)
    var combat:=game.get_node("CombatRange") as Node3D
    for i in range(8):
        await process_frame
    var ak: Image=root.get_texture().get_image()
    if ak.save_png("res://out/aurora-v74-1-ak74.png")!=OK:
        push_error("Could not render AK-74 scene")
        quit(1)
        return
    combat._on_weapon()
    for i in range(10):
        await process_frame
    var awm: Image=root.get_texture().get_image()
    if awm.save_png("res://out/aurora-v74-1-awm.png")!=OK:
        push_error("Could not render AWM scene")
        quit(2)
        return
    print("AURORA_WEAPON_RENDER",ak.get_width(),"x",ak.get_height(),
        " AK visible=",combat._weapon_visuals.ak.visible,
        " AWM visible=",combat._weapon_visuals.awm.visible)
    quit(0)
