extends SceneTree
const SESSION=preload("res://scripts/network/aurora_online_session.gd")
func _initialize() -> void:
    call_deferred("_boot")
func _boot() -> void:
    if DisplayServer.get_name()!="headless":
        push_error("Run dedicated server headless")
        quit(1)
        return
    var world: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(world)
    var session:=SESSION.new()
    session.name="AuroraOnline"
    session.world=world
    session.operator=world.get_node("Operator")
    session.combat=world.get_node("CombatRange")
    session.director=world.get_node("AuroraSectorMatch")
    root.add_child(session)
    var result: Error=session.listen()
    if result!=OK:
        push_error("ENet server listen failed: "+str(result))
        quit(1)
        return
    print("AURORA_ONLINE READY loopback UDP ",SESSION.PORT)
