extends SceneTree
## V75.152: recoil is a measurable transform of the actual GLB in Lila's
## hands, not a simulated tracer/UI effect. Imported optional source clip
## synchronization is tested separately, without claiming private GLBs.
const WEAPONS=preload("res://scripts/combat/aurora_weapon_catalog.gd")
const VISUALS=preload("res://scripts/combat/weapon_visuals.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75152_WEAPON_RECOIL "+reason)


func _verify() -> void:
    root.size=Vector2i(964,434)
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
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
    check(combat.active_fighter_count()==50,
        "real 50-body Battle Royale replaced by a rehearsal")
    var gun: Node3D=combat._weapon_visuals
    for kind in ["weapon_scar","weapon_mp40"]:
        check(combat.collect_sector_loot(kind),
            "physically obtainable weapon missing: "+kind)
    var pickup: Area3D=director.get_node("AuroraAWMWeaponPickup")
    player.global_position=pickup.global_position-Vector3.UP
    player.velocity=Vector3.ZERO
    await physics_frame
    # Physical pickup may complete asynchronously on the physics tick and
    # free its Area3D before this assertion gets control again.
    if is_instance_valid(pickup) and not pickup.collected:
        pickup._collect(player)

    for slot in [WEAPONS.AR,WEAPONS.SCAR,WEAPONS.MP40,WEAPONS.AWM]:
        combat._equip_inventory_weapon(slot)
        check(combat.weapon_index==slot,
            "weapon from original inventory not equipped: "+str(slot))
        var model: Node3D=gun.currently_equipped()
        check(model!=null and model.visible,
            "recoil has no imported weapon GLB at slot "+str(slot))
        if model==null:
            continue
        var rest: Transform3D=model.transform
        combat.ammo[slot]=3
        combat.cooldown=0.0
        combat.reload_timer=0.0
        var before: int=combat.shots_fired_total
        combat._shoot()
        check(combat.shots_fired_total==before+1 and
            combat.ammo[slot]==2 and
            gun._visual_recoil_left>0.0 and
            gun._visual_recoil_model==model,
            "actual shot failed to kick the same rendered gun")
        var kick: float=model.transform.origin.distance_to(rest.origin)
        check(kick>=.005 and kick<=.042,
            "recoil mesh jumped too far or did not move: "+str(kick))
        var muzzle: Node3D=model.find_child("Muzzle",true,false) as Node3D
        if muzzle!=null:
            check(gun.muzzle_position().distance_to(
                muzzle.global_position)<.002,
                "projectile origin detached from moving barrel")
        # Multiple rapid shots must not add drift to previously kicked
        # geometry; each kick starts from the original imported rest pose.
        combat.cooldown=0.0
        combat._shoot()
        check(gun._visual_recoil_rest.origin.distance_to(
            rest.origin)<.0001 and gun._visual_recoil_model==model,
            "automatic fire stacked transform offsets permanently")
        gun._advance_visual_recoil(.20)
        check(gun._visual_recoil_left==0.0 and
            model.transform.origin.distance_to(rest.origin)<.0001 and
            model.transform.basis.is_equal_approx(rest.basis),
            "gun muzzle failed to return to original imported placement")
        combat.cooldown=0.0
        combat.ammo[slot]=1
        combat.reserve[WEAPONS.reserve_slot(slot)]=5
        combat._shoot()
        combat._on_reload()
        check(gun._visual_recoil_left==0.0 and
            model.transform.origin.distance_to(rest.origin)<.0001,
            "real magazine change left gun flying off Lila's hand")
        combat._clear_reload()

    # No fictional recoil if the currently selected weapon is holstered,
    # absent, being used to heal, or flying under a parachute.
    combat._equip_inventory_weapon(WEAPONS.AR)
    gun.set_medical_busy(true)
    check(not gun.pulse_visual_recoil(WEAPONS.AR),
        "medical animation could not release the weapon grip")
    gun.set_medical_busy(false)
    player.air_mode="parachute"
    check(not gun.pulse_visual_recoil(WEAPONS.AR),
        "parachute spawned a phantom gun recoil")
    player.air_mode="ground"
    check(VISUALS.visual_recoil_amplitude(WEAPONS.KNIFE)==0.0 and
        VISUALS.visual_recoil_amplitude(WEAPONS.AWM)>
        VISUALS.visual_recoil_amplitude(WEAPONS.MP40),
        "weapon geometry kick ignored firearm class")

    # Unit-test original clip timing without claiming that the private
    # animated SCAR GLB is included in the public assets.
    var fixture:=AnimationPlayer.new()
    gun.add_child(fixture)
    var library:=AnimationLibrary.new()
    var reload:=Animation.new()
    reload.length=3.2
    reload.loop_mode=Animation.LOOP_NONE
    library.add_animation("reload",reload)
    var idle:=Animation.new()
    idle.length=1.0
    library.add_animation("idle",idle)
    fixture.add_animation_library("fixture",library)
    var previous=gun._source_animation_players.get(WEAPONS.SCAR)
    gun._source_animation_players[WEAPONS.SCAR]=fixture
    check(gun.play_source_action(WEAPONS.SCAR,"reload",1.6) and
        absf(fixture.speed_scale-2.0)<.001,
        "real imported reload clip would ignore authoritative ammo time")
    check(gun.play_source_action(WEAPONS.SCAR,"idle") and
        absf(fixture.speed_scale-1.0)<.001,
        "imported clip left subsequent source idle at accelerated speed")
    gun._source_animation_players.erase(WEAPONS.SCAR)
    if previous!=null:
        gun._source_animation_players[WEAPONS.SCAR]=previous
    fixture.queue_free()
    combat.end_sector_battle()
    check(gun._visual_recoil_left==0.0,
        "end of physical battle leaked last shot into following match")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75152_WEAPON_RECOIL PASS real_fighters=50 "+
            "original_AR_SCAR_MP40_AWM=4 fire_consumes_ammo=1 "+
            "actual_GLTF_kick_and_settle=1 no_burst_drift=1 "+
            "reload_reset=1 no_parachute_healing_recoil=1 "+
            "imported_reload_timing_fixture=1 physics_muzzle=1")
    quit(1 if failed else 0)
