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
    var port: int=SESSION.PORT
    if OS.get_environment("AURORA_INTERNET_SERVER")=="1":
        var configured_port: String=OS.get_environment("AURORA_ROOM_PORT")
        if not configured_port.is_empty():
            if not configured_port.is_valid_int() or int(configured_port)<1024 or int(configured_port)>65535:
                push_error("Invalid public room TCP port")
                quit(1)
                return
            port=int(configured_port)
    var result: Error=session.listen(port)
    if result!=OK:
        push_error("Dedicated server listen failed: "+str(result))
        quit(1)
        return
    print("AURORA_ONLINE READY ",("TLS Internet" if session.room_internet else ("private LAN" if session.room_lan else "loopback")),(" TCP " if session.room_internet else " UDP "),port)
