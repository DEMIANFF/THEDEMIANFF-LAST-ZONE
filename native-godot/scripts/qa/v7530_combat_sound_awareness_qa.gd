extends SceneTree
## End-to-end acoustic awareness: real weapon signal, short-range hearing,
## no wall-penetrating target acquisition, and disabled outside BR rounds.
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7530_SOUND_AWARENESS "+reason)


func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var player: CharacterBody3D=game.get_node("Operator")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    check(combat.sector_battle_active and combat._targets.size()==8,
        "round did not create eight connected enemies")
    for bot in combat._targets:
        bot.set_physics_process(false)
    var shooter: CharacterBody3D=combat._targets[0]
    var listener: CharacterBody3D=combat._targets[1]
    var far: CharacterBody3D=combat._targets[2]
    var dead: CharacterBody3D=combat._targets[3]
    var origin:=Vector3(0.0,terrain.height_at(0.0,0.0)+.15,0.0)
    shooter.global_position=origin
    listener.global_position=origin+Vector3(9,0,0)
    far.global_position=origin+Vector3(100,0,0)
    dead.global_position=origin+Vector3(12,0,0)
    dead.health=0.0
    listener._target_visible=false
    listener._target_actor=null
    listener._alert_time=0.0
    listener._sense_clock=4.0
    listener._route_clock=5.0
    listener._route=PackedVector3Array([Vector3(9,0,9)])
    await physics_frame
    shooter.weapon_fired.emit(origin)
    check(listener.heard_shots==1 and listener._alert_time>=4.0,
        "nearby living opponent ignored a real bot weapon signal")
    check(listener._last_seen.distance_to(origin)<.001,
        "sound investigation did not use the physical gunshot position")
    check(listener._route.is_empty() and listener._route_clock==0.0,
        "new gunfire failed to refresh navigation toward sound")
    check(listener._sense_clock<=.1 and not listener._target_visible,
        "hearing incorrectly provided instant line-of-sight target lock")
    check(shooter.heard_shots==0,"shooter investigated its own gunshot")
    check(far.heard_shots==0,"opponent heard a shot beyond hearing range")
    check(dead.heard_shots==0,"eliminated opponent reacted to gunfire")
    listener._target_visible=true
    listener._target_actor=shooter
    var count: int=listener.heard_shots
    var previous: Vector3=listener._last_seen
    shooter.weapon_fired.emit(origin)
    check(listener.heard_shots==count and listener._last_seen==previous,
        "sound overrode a visible opponent")
    listener._target_visible=false
    listener._target_actor=null
    combat.sector_battle_active=false
    shooter.weapon_fired.emit(origin)
    check(listener.heard_shots==count,
        "opponents continued to react after BR ended")
    combat.sector_battle_active=true
    player.global_position=origin+Vector3(10,0,3)
    listener._alert_time=0.0
    var before: int=listener.heard_shots
    var ammo_before: int=combat.ammo[0]
    combat.cooldown=0.0
    combat.weapon_index=0
    combat._shoot()
    check(combat.ammo[0]==ammo_before-1,
        "weapon did not fire a real shot")
    check(listener.heard_shots==before+1,
        "actual player muzzle blast did not notify nearby AI")
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
        check(bot.heard_shots==0 and bot._alert_time==0.0,
            "round restart retained gunshot awareness from previous match")
    if not failed:
        print("V7530_SOUND_AWARENESS PASS bot_shot=1 near=1 far=0 dead=0 "+
            "priority=visible training_disabled=1 player_real_shot=1 reset=1")
    quit(1 if failed else 0)
