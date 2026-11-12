extends SceneTree
var failed: bool=false

func _initialize() -> void:
    call_deferred("verify")

func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V753_COMBAT "+message)

func frames(n: int) -> void:
    for i in range(n):
        await physics_frame

func verify() -> void:
    var game=load("res://scenes/Main.tscn").instantiate()
    root.add_child(game)
    var player=game.get_node("Operator")
    var combat=game.get_node("CombatRange")
    var director=game.get_node("AuroraSectorMatch")
    var terrain=game.get_node("AuroraTerrain")
    combat.set_process(false)
    director.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    var y: float=terrain.height_at(100.0,0.0)+1.0
    player.global_position=Vector3(100,y,3)
    var target=combat._targets[0]
    target.global_position=Vector3(100,y,-5)
    var wall:=StaticBody3D.new()
    var shape:=CollisionShape3D.new()
    shape.shape=BoxShape3D.new()
    shape.shape.size=Vector3(4,1.7,.25)
    wall.add_child(shape)
    wall.position=Vector3(100,y+.85,0)
    game.add_child(wall)
    var camera: Camera3D=player.get_view_camera()
    camera.global_position=Vector3(100,y+3,6)
    camera.look_at(target.global_position+Vector3.UP)
    await frames(4)
    combat._shoot()
    check(target.health==100.0,"low cover allowed damage")
    print("V753_LOW_COVER blocked_health=",target.health)
    wall.queue_free()
    await frames(3)
    combat.cooldown=0
    combat._shoot()
    check(target.health==74.0,"clear muzzle lost reticle hit")
    print("V753_CLEAR_SHOT health=",target.health)
    var nodes: int=combat.get_child_count()
    for i in range(500):
        combat._spawn_tracer(player.global_position+Vector3.UP,player.global_position+Vector3(0,1,-20))
    check(combat.get_child_count()==nodes and combat._tracers.size()==8,"tracers allocated per shot")
    combat._process(.2)
    for tracer in combat._tracers:
        check(not tracer.visible,"expired tracer still visible")
    print("V753_TRACER_POOL shots=500 nodes=",combat._tracers.size())
    combat.sector_battle_active=true
    combat.medkits_remaining=5
    check(not combat.collect_sector_loot("medkit"),"full medkit inventory consumed pickup")
    combat.medkits_remaining=4
    check(combat.collect_sector_loot("medkit") and combat.medkits_remaining==5,"available medkit slot not filled")
    player.training_health=100
    player._training_immunity=5
    player.battle_royale_active=true
    # This world now includes a larger physically explorable northern
    # district. Choose a point beyond the ACTUAL initial radius, rather
    # than assuming that x=100m is still outside the storm.
    player.global_position=Vector3(director.INITIAL_RADIUS+35.0,y,3.0)
    director._check_hazard_damage()
    check(player.training_health==94.0,"weapon immunity suppressed zone")
    player.receive_training_hit(5)
    check(player.training_health==94.0,"environmental hit removed weapon immunity")
    print("V753_ZONE health=",player.training_health)
    # AI uses a real spread ray: close shots hit, long range is not perfect.
    player.global_position=Vector3(100,y,15)
    target.global_position=Vector3(100,y,-5)
    await frames(3)
    for i in range(100):
        target._fire_at_target(player)
    check(target.shots_hit>20 and target.shots_hit<100,"AI spread ray must hit and miss")
    print("V753_AI_PRECISION hits=",target.shots_hit," shots=",target.shots_fired)
    print("V753_COMBAT PASS")
    quit(1 if failed else 0)
