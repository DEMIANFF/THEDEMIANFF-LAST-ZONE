extends SceneTree
## V75.66: authored directional skeletal impacts and real sniper recoil.
## Instantiates the complete original Main.tscn, inventory and BoneAttachment
## rig. Damage is real; no dummy multiplayer clients or fake screenshots.
const OPERATOR=preload("res://scripts/player/third_person_operator.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7566_LILA_IMPACT_RECOIL "+reason)


func frames(n: int) -> void:
    for index in range(n):
        await physics_frame


func _verify() -> void:
    check(str(ProjectSettings.get_setting(
        "rendering/renderer/rendering_method.mobile"))=="mobile",
        "one Vulkan Mobile renderer must remain the sole Android target")
    check(OPERATOR.directional_hit_clip(
            Vector3(0,0,-8),Vector3.ZERO,Basis.IDENTITY)=="AuroraHitFront" and
        OPERATOR.directional_hit_clip(
            Vector3(0,0,8),Vector3.ZERO,Basis.IDENTITY)=="AuroraHitBack" and
        OPERATOR.directional_hit_clip(
            Vector3(-8,0,0),Vector3.ZERO,Basis.IDENTITY)=="AuroraHitLeft" and
        OPERATOR.directional_hit_clip(
            Vector3(8,0,0),Vector3.ZERO,Basis.IDENTITY)=="AuroraHitRight" and
        OPERATOR.directional_hit_clip(
            Vector3.ZERO,Vector3.ZERO,Basis.IDENTITY)=="AuroraHit" and
        OPERATOR.directional_hit_clip(
            Vector3(INF,0,0),Vector3.ZERO,Basis.IDENTITY)=="AuroraHit",
        "actual hit direction or unknown-attacker handling regressed")
    var rotated:=Basis(Vector3.UP,PI*.5)
    check(OPERATOR.directional_hit_clip(
        rotated*Vector3(-8,0,0),Vector3.ZERO,rotated)=="AuroraHitLeft",
        "body-local injury animations follow camera world axis instead of player")

    var scene: PackedScene=load("res://scenes/Main.tscn") as PackedScene
    check(scene!=null,"real Puerto Aurora battle royale scene missing")
    if scene==null:
        quit(1)
        return
    var game: Node3D=scene.instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await frames(3)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    var controller: Node=player._animation_controller
    check(controller!=null and controller.tree.active and
        player._animator!=null,"existing skinned Lila AnimationTree lost")
    if controller==null or player._animator==null:
        quit(1)
        return
    # The OneShot mask must include the NEW neck reaction, while its
    # existing legs, hips and feet continue to run the V75.65 gait.
    var neck_filtered: bool=false
    for track in controller.upper_tracks:
        var bone: String=str(track).to_lower()
        if "neck" in bone:
            neck_filtered=true
        check(not ("hips" in bone or "upleg" in bone or
                "foot" in bone or "thigh" in bone),
            "recoil/hit overlay took over lower-body walking physics")
    check(neck_filtered,
        "directional hit animation cannot bend Lila's neck: missing upper mask")
    for name in ["AuroraHitFront","AuroraHitBack","AuroraHitLeft",
            "AuroraHitRight","AuroraFireAWM"]:
        check(player._animator.has_animation(name) and
            controller.states.has_node(name),
            "original rig is missing directional body animation "+name)
        if player._animator.has_animation(name):
            var clip: Animation=player._animator.get_animation(name)
            check(clip.length>.25 and clip.length<.55 and
                clip.get_track_count()>=6 and
                clip.loop_mode==Animation.LOOP_NONE,
                "clip must be real keyed nonloop upper-body rig animation "+name)

    var body: Skeleton3D=player._avatar.find_child(
        "Skeleton3D",true,false) as Skeleton3D
    check(body!=null and body.get_bone_count()>35,
        "Lila's original humanoid bones disappeared")
    check(combat._weapon_visuals.attachment_uses_hand and
        combat._medical_visual.attachment_uses_hand,
        "hit animations removed weapon or actual 3D medkit hand sockets")
    var damaged: Array[float]=[]
    var directions: Array[Vector3]=[]
    player.player_damaged.connect(func(amount: float): damaged.append(amount))
    player.incoming_fire.connect(
        func(origin: Vector3): directions.append(origin))
    var hp: float=player.training_health
    for entry in [
        {"offset":Vector3(0,0,-12),"clip":"AuroraHitFront"},
        {"offset":Vector3(0,0,12),"clip":"AuroraHitBack"},
        {"offset":Vector3(-12,0,0),"clip":"AuroraHitLeft"},
        {"offset":Vector3(12,0,0),"clip":"AuroraHitRight"}
    ]:
        # Every event must be a confirmed non-environmental HP hit;
        # reset the existing 0.42s damage immunity between isolated hits.
        player._training_immunity=0.0
        player.receive_training_hit(6.0,false,
            player.global_position+player.global_basis*entry.offset)
        check(player.last_hit_reaction==entry.clip and
            controller.action_clip.animation==entry.clip and
            controller.tree.get("parameters/UpperBody/active"),
            "real incoming damage did not play matching local-space reaction")
        hp-=6.0
        check(absf(player.training_health-hp)<.01 and
            directions.size()==damaged.size() and
            directions.size()>0 and absf(damaged[-1]-6.0)<.01,
            "visual hit animation modified physical damage or incoming signals")
    check(player.hit_reactions_shown==4 and damaged.size()==4,
        "counted animation reactions instead of genuinely accepted hits")

    # Environmental hazards have no attacker and should not display an
    # invented front/back enemy. Armor bypass remains unchanged.
    player.receive_training_hit(3.0,true)
    check(player.last_hit_reaction=="AuroraHit" and
        directions.size()==4 and
        absf(player.training_health-(hp-3.0))<.01,
        "hazard damage fabricated an incoming-fire directional cue")

    # Reload priority is preserved: hit reaction does not abort an unfinished
    # weapon action, though actual damage/armor still updates.
    player.set_equipped_weapon(0)
    player.play_weapon_action("reload",combat.AR_RELOAD_SECONDS)
    player._training_immunity=0.0
    var before: int=player.hit_reactions_shown
    var health_before: float=player.training_health
    player.receive_training_hit(3.0,false,
        player.global_position+Vector3(-6,0,0))
    check(controller.action_clip.animation=="AuroraReloadAR" and
        player.hit_reactions_shown==before and
        absf(player.training_health-(health_before-3.0))<.01,
        "minor hit should not cancel an ongoing full magazine reload")
    player.set_equipped_weapon(0)
    combat.ammo[0]=5
    combat.cooldown=0.0
    combat.reload_timer=0.0
    combat._shoot()
    check(combat.ammo[0]==4 and combat.shots_fired_total>=1 and
        player._combat_action=="AuroraFire" and
        controller.action_clip.animation=="AuroraFire",
        "actual AR projectile failed to trigger its authored short recoil")

    # Physically collect AWM before firing. It cannot be equipped or
    # animated by pretending the player owns a non-existent rifle.
    var pickup: Area3D=director.get_node(
        "AuroraAWMWeaponPickup") as Area3D
    player.global_position=pickup.global_position-Vector3.UP
    player.velocity=Vector3.ZERO
    await frames(2)
    if is_instance_valid(pickup) and not pickup.collected:
        pickup._collect(player)
    combat._equip_inventory_weapon(1)
    check(combat.weapon_owned[1] and combat.weapon_index==1 and
        combat._weapon_visuals.awm.visible,
        "sniper recoil test must use the physically obtained rifle in Lila's hands")
    combat.ammo[1]=2
    combat.cooldown=0.0
    combat.reload_timer=0.0
    combat._shoot()
    check(combat.ammo[1]==1 and
        combat.cooldown==combat.AWM_BOLT_SECONDS and
        player._combat_action=="AuroraFireAWM" and
        controller.action_clip.animation=="AuroraFireAWM" and
        player._combat_action_seconds>=.23 and
        combat._weapon_visuals.awm.visible,
        "physical AWM shot lost its distinct recoil and bolt cadence")

    # Even a burst/hit animation may not change weapon ownership, camera,
    # inventory, skin attachment or flight/parachute lifecycle.
    check(player.get_view_camera()!=null and
        player.get_view_camera().position.z>1.0 and
        combat.weapon_owned[0] and combat.weapon_owned[1],
        "bone animation changed camera or physical rifle inventory")
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    check(player.last_hit_reaction.is_empty() and
        player.hit_reactions_shown==0 and
        player._combat_action.is_empty() and
        combat.weapon_index==0 and
        not combat.weapon_owned[1] and
        controller.tree.active,
        "new Battle Royale retained last round's hit/weapon or animation state")
    if not failed:
        print("V7566_LILA_IMPACT_RECOIL PASS "+
            "four_directional_rig_clips=1 body_relative=1 "+
            "real_damage=1 environmental_unknown=1 "+
            "reload_priority=1 physical_AR_recoil=1 "+
            "AWM_distinct_recoil=1 bolt_cadence=1 "+
            "armor_inventory_preserved=1 round_reset=clean vulkan=1")
    quit(1 if failed else 0)
