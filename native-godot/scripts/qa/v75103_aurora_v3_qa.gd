extends SceneTree

const CATALOG=preload("res://scripts/combat/aurora_weapon_catalog.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")


func expect(condition: bool, message: String) -> void:
    if not condition:
        failed=true
        push_error("V75103 "+message)


func collect(director: Node3D, player: CharacterBody3D, id: String) -> bool:
    var pickup: Area3D=director.get_node_or_null(id) as Area3D
    if pickup==null:
        return false
    player.global_position=pickup.global_position-Vector3.UP*.48
    pickup._collect(player)
    if not pickup.collected:
        var ray:=PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP,pickup.global_position)
        ray.exclude=[player.get_rid()]
        var hit:=player.get_world_3d().direct_space_state.intersect_ray(ray)
        print("V75103 pickup=",id," type=",pickup.pickup_type," at=",pickup.global_position,
            " blocker=",hit.get("collider"))
    return pickup.collected


func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var player: CharacterBody3D=game.get_node("Operator")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    combat.set_encounter_size(50)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for fighter: CharacterBody3D in combat._targets:
        fighter.set_physics_process(false)
    await physics_frame

    expect(combat.active_fighter_count()==50,"50-fighter roster or player spawn changed")
    # 37 original public-sector/indoor pickups + two real level-2/3
    # backpack upgrades. Additional privately staged V2/V3 models add
    # physical loot only when their actual imported GLBs exist.
    var expected_loot: int=39
    for index in range(CATALOG.HK416,CATALOG.ENTRIES.size()):
        var source: String=str(CATALOG.ENTRIES[index]["asset"])
        if ResourceLoader.exists(source,"PackedScene"):
            expected_loot+=1
    if ResourceLoader.exists(str(CATALOG.ENTRIES[CATALOG.SHOTGUN]["asset"]),"PackedScene"):
        expected_loot+=1  # real shells near the shotgun
    if ResourceLoader.exists(str(CATALOG.ENTRIES[CATALOG.MAGNUM]["asset"]),"PackedScene"):
        expected_loot+=1  # real pistol rounds near the Magnum
    expect(director.get_loot_remaining()==expected_loot,
        "classic BR world loot does not match the actual staged arsenal and 3 backpack tiers")
    expect(director.get_node_or_null("AuroraTacticalPackLevel2") is Area3D and
        director.get_node_or_null("AuroraTacticalPackLevel3") is Area3D,
        "real world backpack upgrade items are absent")
    expect(not combat.inventory_snapshot()["additions"].has(CATALOG.MP40),"MP40 was granted before pickup")
    var got_mp40: bool=collect(director,player,"AuroraMP40Pickup")
    var got_scar: bool=collect(director,player,"AuroraSCARPickup")
    expect(got_mp40 and got_scar,"expansion guns do not exist as collectible world assets")
    if not got_mp40 or not got_scar:
        quit(1)
        return
    expect(not combat.collect_sector_loot("weapon_mp40") and not combat.collect_sector_loot("weapon_scar"),
        "duplicate weapon collection duplicated magazines")
    expect(collect(director,player,"AuroraSMGAmmoPickup"),"9 mm pickup did not reach SMG reserve")
    var shared_smg_reserve: int=combat.reserve[CATALOG.MP40]
    var got_kriss: bool=collect(director,player,"AuroraKRISSPickup")
    expect(got_kriss and combat.ammo[CATALOG.KRISS]==15 and
        combat.reserve[CATALOG.MP40]==shared_smg_reserve and
        combat.inventory_snapshot()["additions"].get(CATALOG.KRISS,{}).get("reserve")==shared_smg_reserve,
        "the V2 SMG did not share reserve without duplicating supplies")
    hud._inventory_expansion_buttons[CATALOG.MP40].pressed.emit()
    expect(combat.weapon_index==CATALOG.MP40 and combat.ammo[CATALOG.MP40]==15,
        "inventory control or level-one SMG magazine failed")

    player.global_position=Vector3(800,20,800)
    player.rotation=Vector3.ZERO
    player._camera_pivot.rotation=Vector3.ZERO
    player.get_view_camera().position=Vector3(0,0,4.6)
    var target: CharacterBody3D=combat._targets[0]
    target.global_position=player.global_position+Vector3(0,0,-12)
    await physics_frame
    await physics_frame
    combat.cooldown=0.0
    var old_health: float=target.health
    combat._shoot()
    expect(combat.ammo[CATALOG.MP40]==14 and combat.shots_fired_total==1 and target.health<old_health,
        "MP40 did not consume a round and damage a real ray-hit opponent")

    var effects: Array[StringName]=[]
    combat.reload_cue.connect(func(cue: StringName): effects.append(cue))
    var visuals: Node3D=combat._weapon_visuals
    var mag: Node3D=visuals._mp40_magazine
    var bolt: Node3D=visuals._mp40_charging_handle
    expect(mag!=null and bolt!=null and visuals.support_socket!=null,
        "MP40 mesh lacks a movable magazine, charging handle or Lila hand socket")
    if mag==null or bolt==null:
        quit(1)
        return
    var seated: Transform3D=mag.transform
    var neutral: Vector3=bolt.position
    var reserve: int=combat.reserve[CATALOG.MP40]
    combat._on_reload()
    expect(player._combat_action=="AuroraReloadMP40" and
        player._animator.has_animation("AuroraReloadMP40"),"Lila is missing the separate keyed reload")
    combat._process(.70)
    expect(not mag.transform.is_equal_approx(seated) and effects==[&"mp40_extract"] and
        combat.ammo[CATALOG.MP40]==14 and combat.reserve[CATALOG.MP40]==reserve,
        "extract cue, animated mesh and no-early-ammo transfer diverged")
    hud._inventory_expansion_buttons[CATALOG.SCAR].pressed.emit()
    expect(combat.weapon_index==CATALOG.SCAR and combat.reload_timer==0.0 and
        mag.transform.is_equal_approx(seated) and combat.reserve[CATALOG.MP40]==reserve,
        "switch did not cancel reload and return the old magazine")
    combat._equip_inventory_weapon(CATALOG.MP40)
    effects.clear()
    combat._on_reload()
    combat._process(.87*1.85)
    expect(not bolt.position.is_equal_approx(neutral) and
        effects==CATALOG.MP40_RELOAD_CUES,"seat or charging event is out of sync")
    combat._process(.4)
    expect(combat.ammo[CATALOG.MP40]==15 and combat.reserve[CATALOG.MP40]==reserve-1 and
        combat.reloads_completed==1 and bolt.position.is_equal_approx(neutral),
        "ammo was not committed exactly once at the end of the channel")
    combat._equip_inventory_weapon(CATALOG.SCAR)
    combat.cooldown=0.0
    old_health=target.health
    combat._shoot()
    expect(combat.ammo[CATALOG.SCAR]==29 and target.health<old_health,
        "SCAR did not fire a real round through the same combat path")
    if got_kriss:
        combat._equip_inventory_weapon(CATALOG.KRISS)
        combat.cooldown=0.0
        old_health=target.health
        combat._shoot()
        expect(combat.ammo[CATALOG.KRISS]==14 and target.health<old_health,
            "the V2 SMG did not fire against a physical opponent")

    expect(collect(director,player,"AuroraProtection1") and
        collect(director,player,"AuroraProtection2"),"level-one protection was blocked")
    var got_vest: bool=collect(director,player,"AuroraProtection3")
    expect(collect(director,player,"AuroraProtection4"),"level-two helmet was blocked")
    var got_helmet: bool=collect(director,player,"AuroraProtection6")
    expect(got_vest and got_helmet,"world did not grant vest 2 and helmet 3")
    var gear: Node3D=player._protection_visual
    var helmet_socket:=player.find_child("LilaHelmetSocket",true,false) as BoneAttachment3D
    var vest_socket:=player.find_child("LilaVestSocket",true,false) as BoneAttachment3D
    expect(gear!=null and gear._helmet.is_visible_in_tree() and
        gear._plate_carrier.is_visible_in_tree() and not gear._heavy_vest.visible and
        helmet_socket!=null and helmet_socket.bone_name=="Head" and helmet_socket.is_ancestor_of(gear._helmet) and
        vest_socket!=null and vest_socket.bone_name=="Spine2" and vest_socket.is_ancestor_of(gear._plate_carrier),
        "equipped protection did not follow the intended bones")
    expect(not player.equip_protection(false,1),"a downgrade replaced intact protection")
    player._training_immunity=0.0
    var started_hp: float=player.training_health
    player.receive_training_hit(20,false,player.global_position+Vector3.FORWARD,
        player.global_position+Vector3.UP*1.5)
    expect(is_equal_approx(player.training_health,started_hp-7.0) and
        is_equal_approx(player.helmet_points,32.0) and player.armor_points==50,
        "confirmed head contact did not use helmet separately from vest")
    player.receive_training_hit(5,true)
    expect(player.helmet_points==32.0 and player.armor_points==50,
        "storm damage consumed protective equipment")
    expect(collect(director,player,"AuroraProtection5") and player.armor_points==75.0,
        "level-three vest did not upgrade the world equipment")
    expect(gear!=null and not gear._plate_carrier.visible and gear._heavy_vest.is_visible_in_tree(),
        "upgrading the vest kept two pieces visible")
    expect(collect(director,player,"AuroraSyringePickup"),"medical pickup did not enter inventory")
    player.training_health=60.0
    player.velocity=Vector3.ZERO
    player.set_touch_move_axis(Vector2.ZERO)
    hud._inventory_syringe.pressed.emit()
    var medical: Node3D=combat._medical_visual
    expect(medical.syringe.is_visible_in_tree() and not medical.medical_case.visible and
        medical.hand_socket.bone_name=="LeftHand","curing did not display the held syringe")
    combat._process(.6)
    expect(player.training_health==60.0 and combat.syringes_remaining==1,
        "syringe applied before the healing channel completed")
    combat._process(1.0)
    expect(player.training_health==80.0 and combat.syringes_remaining==0 and combat.medkits_remaining==2,
        "syringe did not heal once from its own inventory")
    expect(not medical.syringe.visible,"completed syringe was still held")
    var sound: Node3D=game.get_node("AuroraSoundStage")
    sound.set_enabled(true)
    var shooter: CharacterBody3D=combat._targets[1]
    shooter.global_position=player.global_position+Vector3.FORWARD*80.0
    await physics_frame
    var outdoor_voice: int=sound._world_cursor
    expect(shooter._fire_at_target(player) and
        sound._world_voices[outdoor_voice].stream==sound._samples["distant_fire"],
        "a real distant shot did not select the positional distant sound")
    player.receive_training_hit(300.0,true)
    var previous_voice: int=posmod(sound._cursor-1,sound.VOICES)
    expect(player.royale_eliminated and sound._voices[previous_voice].stream==sound._samples["eliminated"],
        "final elimination did not select its unique sound")
    var next_voice: int=sound._cursor
    player.receive_training_hit(300.0,true)
    expect(sound._cursor==next_voice,"repeated damage repeated the elimination sound")
    director.start_sector_battle()
    expect(combat.inventory_snapshot()["additions"].is_empty() and
        combat.weapon_index==CATALOG.AR and player.helmet_points==0 and
        combat.active_fighter_count()==50,"new round retained equipment or lost fighters")
    expect(gear!=null and not gear._helmet.visible and not gear._heavy_vest.visible,
        "new round retained visible protection")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75103_AURORA_V3 PASS three_world_weapons=1 real_rays=1 smg15=1 synchronized_reload=1 armor_tiers=1 equipment_sockets=1 syringe=1 event_audio=1 roster50=1")
    quit(1 if failed else 0)
