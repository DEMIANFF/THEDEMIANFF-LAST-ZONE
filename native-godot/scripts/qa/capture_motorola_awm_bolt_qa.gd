extends SceneTree
## A genuine 964x434 engine render of the original AWM steel bolt parts,
## captured in the SAME physical scene on open and after full closure.
## Software OpenGL/Xvfb, not a Motorola Vulkan or 120Hz certification.
const WEAPONS=preload("res://scripts/combat/aurora_weapon_catalog.gd")
const CAPTURE=preload("res://scripts/qa/aurora_capture_version.gd")


func _initialize() -> void:
    call_deferred("_capture")


func _screen(name: String,tag: String) -> bool:
    await RenderingServer.frame_post_draw
    var snapshot: Image=root.get_texture().get_image()
    var path: String="res://out/aurora-"+tag+"-motorola-"+name+".png"
    if snapshot.get_size()!=Vector2i(964,434) or snapshot.save_png(path)!=OK:
        push_error("V75151_AWM_CAPTURE cannot save original 3D action "+name)
        return false
    print("V75151_AWM_CAPTURE "+path)
    return true


func _capture() -> void:
    root.size=Vector2i(964,434)
    var tag: String=CAPTURE.tag()
    if tag.is_empty():
        quit(2)
        return
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var operator: CharacterBody3D=game.get_node("Operator")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    combat.set_encounter_size(50)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    operator.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    var pickup: Area3D=director.get_node("AuroraAWMWeaponPickup")
    operator.global_position=pickup.global_position-Vector3.UP
    operator.velocity=Vector3.ZERO
    await physics_frame
    if not pickup.collected:
        pickup._collect(operator)
    combat._equip_inventory_weapon(WEAPONS.AWM)
    var gun: Node3D=combat._weapon_visuals
    if (combat.weapon_index!=WEAPONS.AWM or not gun.awm.visible or
            gun._awm_bolt_meshes.size()!=3):
        push_error("V75151_AWM_CAPTURE real AWM/three GLB pieces absent")
        quit(3)
        return
    var rest: Array[Vector3]=[]
    for piece in gun._awm_bolt_meshes:
        rest.append(piece.position)
    combat.ammo[WEAPONS.AWM]=2
    combat.cooldown=0.0
    combat.reload_timer=0.0
    combat._shoot()
    gun._advance_awm_mechanical_cycle(.23)
    var displaced: int=0
    for i in range(gun._awm_bolt_meshes.size()):
        if gun._awm_bolt_meshes[i].position.distance_to(rest[i])>.025:
            displaced+=1
    if displaced!=3:
        push_error("V75151_AWM_CAPTURE muzzle metal is not retracted")
        quit(4)
        return
    for i in range(3):
        await process_frame
    if not await _screen("real-awm-bolt-open",tag):
        quit(5)
        return
    gun._advance_awm_mechanical_cycle(.60)
    for i in range(gun._awm_bolt_meshes.size()):
        if gun._awm_bolt_meshes[i].position.distance_to(rest[i])>.0001:
            push_error("V75151_AWM_CAPTURE steel mechanism failed to close")
            quit(6)
            return
    for i in range(4):
        await process_frame
    if not await _screen("real-awm-bolt-closed",tag):
        quit(7)
        return
    game.queue_free()
    await process_frame
    print("V75151_AWM_CAPTURE PASS 964x434 original_GLTF_meshes=3 "+
        "physical_round=1 steel_bolt_open_close=1 screenshots=2 "+
        "motorola_device_certification=NO")
    quit(0)
