extends SceneTree
## V75.55 — one integrated executable BR regression, not mockups.
const ANIM=preload("res://scripts/player/operator_animation.gd")
const COMBAT=preload("res://scripts/combat/training_combat.gd")
const DIRECTOR=preload("res://scripts/match/sector_director.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(value: bool,reason: String) -> void:
    if not value:
        failed=true
        push_error("V7555_UNIFIED "+reason)

func _verify() -> void:
    check(str(ProjectSettings.get_setting(
        "rendering/renderer/rendering_method.mobile"))=="mobile",
        "Android must retain Vulkan Mobile only")
    check(ANIM.gait_multiplier(4.6,4.6)==1.0 and
        ANIM.gait_multiplier(2.0,4.6)>=.75 and
        ANIM.gait_multiplier(8.0,4.6)<=1.30,
        "gait speed clamp missing or producing invalid playback")
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    var controller: Node=player._animation_controller
    check(controller!=null,"real skinned character AnimationTree missing")
    if controller!=null:
        controller.set_gait_speed(5.5,7.1)
        check(controller.tree.tree_root.has_node("GaitSpeed") and
            absf(float(controller.tree.get("parameters/GaitSpeed/scale"))-
            ANIM.gait_multiplier(5.5,7.1))<.01,
            "speed-dependent gait was not connected to authored rig animation")
    check(player.get_view_camera()!=null and
        player.get_view_camera().position.z>3.0,
        "stable third person shoulder distance lost")

    # Camera-relative incoming fire is emitted from a real damaged body,
    # never triggered just by unverified noise or player input.
    player.training_health=100.0
    player._training_immunity=0.0
    player._yaw=0.0
    player.receive_training_hit(12.0,false,
        player.global_position+Vector3(0,0,-7))
    check(player.training_health==88.0 and
        hud._incoming_hint.text=="DAÑO DESDE FRENTE",
        "physical attacker did not produce truthful forward damage direction")
    var previous: String=hud._incoming_hint.text
    player._training_immunity=0.0
    player.receive_training_hit(4.0,true)
    check(hud._incoming_hint.text==previous,
        "radiation damage falsely invented a firearm shooter")

    # Real inventory controls; do not equip an uncollected world weapon.
    var panel: PanelContainer=hud.get_node(
        "AuroraTacticalOverlay/RealMatchInventory")
    check(combat.weapon_index==0 and combat.weapon_owned==[true,false] and
        hud._inventory_awm.disabled,
        "AWM was provided for free before physical loot collection")
    hud._inventory_awm.pressed.emit()
    check(combat.weapon_index==0,
        "inventory selection bypassed live weapon ownership")
    var weapon: Area3D=director.get_node("AuroraAWMWeaponPickup")
    player.global_position=weapon.global_position-Vector3.UP
    player.velocity=Vector3.ZERO
    await physics_frame
    await physics_frame
    weapon._collect(player)
    check(weapon.collected and combat.weapon_owned[1] and
        not hud._inventory_awm.disabled,
        "world AWM pickup failed to enable actual inventory action")
    hud._toggle_inventory()
    check(panel.visible and panel.get_node_or_null(
        "InventoryActions/InventoryWeaponSelectors/EquipAR")!=null,
        "inventory weapon actions not reachable from real touch panel")
    hud._inventory_awm.pressed.emit()
    check(combat.weapon_index==1 and
        int(combat.inventory_snapshot()["active_weapon"])==1,
        "inventory cannot equip physically collected AWM")
    hud._inventory_ar.pressed.emit()
    check(combat.weapon_index==0 and
        int(combat.inventory_snapshot()["active_weapon"])==0,
        "inventory cannot return to AR-7 through same equipment path")
    hud._toggle_inventory()

    # Supply events must instantiate collectable Area3D caches, never
    # grant inventory remotely or repeat endlessly each frame.
    check(director.get_loot_remaining()==24 and
        director._phase_supplies.is_empty(),
        "match had invented early phase rewards or broke standard 25 loot")
    director._process(director.PHASE_SECONDS+.5)
    check(director._phase_supplies.size()==1 and
        director.get_node_or_null("AuroraPhaseSupply1") is Area3D,
        "phase one did not spawn physical world resupply")
    director._process(director.PHASE_SECONDS)
    director._process(director.PHASE_SECONDS)
    check(director._phase_supplies.size()==3 and
        director.get_node_or_null("AuroraPhaseSupply3") is Area3D,
        "later zone phases did not create bounded collectible resupplies")
    check(director.get_loot_remaining()==27,
        "phase loot count differs from 25 originals minus collected AWM plus 3")
    director._spawn_phase_resupply(3)
    check(director.get_loot_remaining()==27,
        "phase supply exploited to generate duplicate resources")
    var supply: Area3D=director.get_node("AuroraPhaseSupply3")
    check(supply.get_node_or_null("LootPickupRange")!=null and
        supply.global_position.y>=terrain.height_at(
            supply.global_position.x,supply.global_position.z)+.49,
        "new supplies are decorative or buried under the actual world")
    var before: int=combat.medkits_remaining
    player.global_position=supply.global_position-Vector3.UP
    player.velocity=Vector3.ZERO
    await physics_frame
    await physics_frame
    supply._collect(player)
    check(supply.collected and combat.medkits_remaining==before+1 and
        combat.loot_collected>=2,
        "phase medkit does not use real collision/inventory collection")
    check(hud._inventory_label.text.contains("RECOGIDOS:"),
        "HUD does not display verified physical pickups")

    # Defeat panel uses the genuine local roster. Records are already
    # committed through the existing atomic player-profile ledger.
    combat.damage_dealt=87.0
    player.royale_eliminated=true
    director._finish(false)
    var results: Label=hud._result_text
    check(results.text.contains("POSICIÓN: #") and
        results.text.contains("DAÑO: 87") and
        results.text.contains("BOTÍN:"),
        "end-of-round leaderboard omits genuine rank, damage and loot")
    check(director.match_ended and director.last_match_saved,
        "results were not stored atomically in the existing offline ledger")
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(director._phase_supplies.is_empty() and
        director.get_loot_remaining()==25 and
        combat.loot_collected==0 and combat.damage_dealt==0.0 and
        not combat.weapon_owned[1] and hud._inventory_awm.disabled,
        "restarted match leaked phase loot, stolen weapons or results")
    if not failed:
        print("V7555_UNIFIED PASS rig_gait=1 incoming_fire=1 "+
            "inventory_equip=1 world_resupply=3 real_pickup=1 "+
            "match_rank=1 ledger=1 reset=clean vulkan=1")
    quit(1 if failed else 0)
