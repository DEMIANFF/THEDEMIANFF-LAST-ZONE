extends SceneTree
const SESSION=preload("res://scripts/network/aurora_online_session.gd")
const PRESENTATION=preload("res://scripts/network/online_presentation.gd")
func _initialize() -> void:
    call_deferred("_boot")
func _boot() -> void:
    var world: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    world.online_presentation_only=true
    root.add_child(world)
    var session:=SESSION.new()
    session.name="AuroraOnline"
    root.add_child(session)
    var view:=PRESENTATION.new()
    view.name="OnlinePresentation"
    world.add_child(view)
    view.setup(world,session)
    var result: Error=session.connect_local()
    if result!=OK:
        push_error("Online connection failed: "+str(result))
        quit(1)
