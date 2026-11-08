extends SceneTree
## Validate actual AWM single-shot cycling and AR automatic trigger logic.
func _initialize() -> void:
    call_deferred("_verify")
func _verify() -> void:
    var game: Node3D = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    await process_frame
    var combat: Node3D = game.get_node("CombatRange")
    if combat._targets.size()!=4:
        push_error("V73: expected four real humanoid patrols")
        quit(6)
        return
    combat.weapon_index=1
    combat.cooldown=0.0
    var before: int = combat.ammo[1]
    combat._on_fire_pressed()
    if combat.ammo[1] != before-1 or combat.cooldown < .49:
        push_error("AWM first shot or half-second cycle failed")
        quit(1)
        return
    combat._process(.49)
    if combat.cooldown<=0:
        push_error("AWM cycle unlocked too early")
        quit(2)
        return
    combat._process(.52)
    if combat.ammo[1]!=before-1:
        push_error("AWM repeated on held trigger")
        quit(3)
        return
    combat._on_fire_released()
    combat._on_fire_pressed()
    if combat.ammo[1]!=before-2:
        push_error("AWM second press failed")
        quit(4)
        return
    combat._on_fire_released()
    combat.weapon_index=0
    combat.cooldown=0
    var ar_start: int=combat.ammo[0]
    combat._on_fire_pressed()
    combat._process(.12)
    if combat.ammo[0]>ar_start-2:
        push_error("AR held-fire automatic mode failed")
        quit(5)
        return
    print("V72: AWM 0.5s no repeat on hold; AR automatic fire verified")
    quit(0)
