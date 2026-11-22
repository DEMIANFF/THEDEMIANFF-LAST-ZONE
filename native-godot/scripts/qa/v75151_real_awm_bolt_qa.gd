extends SceneTree
## V75.151: Lila fires the existing 3D AWM, moves the steel bolt/lever/knob
## of the real imported GLB, then restores each original mechanical part.
## The 280ms audio cue and 500ms cartridge lock remain authoritative.
const WEAPONS=preload("res://scripts/combat/aurora_weapon_catalog.gd")
const VISUALS=preload("res://scripts/combat/weapon_visuals.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75151_REAL_AWM_BOLT "+reason)


func _verify() -> void:
    root.size=Vector2i(964,434)
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var player: CharacterBody3D=game.get_node("Operator")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    combat.set_encounter_size(50)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    var pickup: Area3D=director.get_node("AuroraAWMWeaponPickup")
    player.global_position=pickup.global_position-Vector3.UP
    player.velocity=Vector3.ZERO
    await physics_frame
    if not pickup.collected:
        pickup._collect(player)
    combat._equip_inventory_weapon(WEAPONS.AWM)
    var gun: Node3D=combat._weapon_visuals
    check(combat.active_fighter_count()==50 and
        gun.awm_owned and combat.weapon_index==WEAPONS.AWM and
        gun.awm.visible,
        "50-body BR did not physically collect and mount authored AWM GLB")
    check(gun._awm_bolt_meshes.size()==3 and
        gun._awm_bolt_rest.size()==3,
        "original exported AWM lacks 3 independent bolt pieces")
    var muzzle: Node3D=gun.awm.find_child("Muzzle",true,false) as Node3D
    var support: Node3D=gun.awm.find_child("SupportGrip",true,false) as Node3D
    check(muzzle!=null and support!=null,
        "physical firing or two-handed AWM attachment was discarded")
    var original_muzzle: Vector3=gun.muzzle_position()
    var barrel_length: float=gun.equipped_global_length()
    var original: Array[Vector3]=[]
    for part in gun._awm_bolt_meshes:
        original.append(part.position)
    combat.ammo[WEAPONS.AWM]=2
    combat.reload_timer=0.0
    combat.cooldown=0.0
    var before: int=combat.shots_fired_total
    combat._shoot()
    check(combat.shots_fired_total==before+1 and
        combat.ammo[WEAPONS.AWM]==1 and
        combat.cooldown==combat.AWM_BOLT_SECONDS and
        gun.awm_bolt_visual_cycles>=1 and
        gun._awm_mechanical_left==VISUALS.AWM_MECHANICAL_SECONDS,
        "mechanical cycle fired without a real consumed sniper cartridge")
    var audio_cues: Array[int]=[]
    combat.awm_bolt_cycled.connect(func(): audio_cues.append(1))
    gun._advance_awm_mechanical_cycle(.22)
    var moved: int=0
    for i in range(gun._awm_bolt_meshes.size()):
        if gun._awm_bolt_meshes[i].position.distance_to(original[i])>.025:
            moved+=1
    check(moved==3 and gun._awm_mechanical_left>0.0,
        "the visible stem, lever and handle did not physically retract")
    check(gun.muzzle_position().distance_to(original_muzzle)<.005 and
        absf(gun.equipped_global_length()-barrel_length)<.13,
        "bolt action displaced the barrel/optic or the real projectile origin")
    combat._advance_awm_bolt(.30)
    check(audio_cues.size()==1 and gun._awm_mechanical_left>0.0,
        "sound timing reset the physical cycle before the handle closed")
    gun._advance_awm_mechanical_cycle(.35)
    check(gun._awm_mechanical_left==0.0 and
        gun._awm_bolt_meshes.size()==original.size(),
        "mechanical action never returned to rest")
    for i in range(gun._awm_bolt_meshes.size()):
        check(gun._awm_bolt_meshes[i].position.distance_to(
            original[i])<.0001,
            "3D sniper mechanism remained detached after the shot")

    combat.cooldown=0.0
    combat._shoot()
    gun._advance_awm_mechanical_cycle(.19)
    combat._on_reload()
    check(gun._awm_mechanical_left==0.0 and
        not combat._awm_bolt_pending,
        "real AWM magazine replacement did not cancel the bolt animation")
    for i in range(gun._awm_bolt_meshes.size()):
        check(gun._awm_bolt_meshes[i].position.distance_to(
            original[i])<.0001,
            "reloading left steel actuator parts sticking out")
    combat._clear_reload()
    combat._equip_inventory_weapon(WEAPONS.AR)
    check(gun._awm_mechanical_left==0.0 and
        gun.awm.visible==false,
        "holstered AWM retained an unfinished moving bolt")
    combat.end_sector_battle()
    check(gun._awm_mechanical_left==0.0,
        "match end leaked a visual bolt cycle into the next round")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75151_REAL_AWM_BOLT PASS 50_fighters=1 "+
            "actual_3_original_GLTF_parts=1 two_handed=1 "+
            "physical_ammo=1 true_muzzle=1 0.5s_cycle=1 "+
            "sound_independent=1 reload_cancel=1 "+
            "weapon_swap_reset=1 next_match_clean=1")
    quit(1 if failed else 0)
