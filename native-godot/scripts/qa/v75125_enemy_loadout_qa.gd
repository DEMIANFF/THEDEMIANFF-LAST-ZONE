extends SceneTree
## Real GLB-based rival loadouts with ballistic stats and bounded LOD.
const WEAPONS=preload("res://scripts/combat/aurora_weapon_catalog.gd")
const BOT=preload("res://scripts/ai/aurora_bot.gd")
const VISUAL=preload("res://scripts/combat/weapon_visuals.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75125_ENEMY_LOADOUT "+reason)

func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    await physics_frame
    combat.set_encounter_size(50)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(combat._targets.size()==49 and
        combat.BOT_LOADOUTS.size()>=5,
        "50-person round lacks real firearm role variety")
    var roles: Dictionary={}
    for i in range(combat._targets.size()):
        var rival: CharacterBody3D=combat._targets[i]
        var slot: int=rival.weapon_slot
        roles[slot]=true
        check(slot>=WEAPONS.AR and slot<WEAPONS.ENTRIES.size(),
            "enemy has a missing catalog weapon slot")
        check(rival._magazine==rival._loadout_capacity(),
            "real enemy magazine does not use selected weapon capacity")
        check(rival._loadout_damage()>0.0 and
            rival._loadout_range()>0.0,
            "enemy weapon is only a cosmetic skin without ballistics")
        check(rival.health==BOT.MAX_HEALTH,
            "armed opponent lost its 200 HP initial health")
        if i<8:
            check(slot==WEAPONS.AR and rival._magazine==BOT.MAGAZINE_CAPACITY,
                "old training bot regression changed AR initial weapon")
        else:
            var model: String=rival._loadout_visual_path()
            check(ResourceLoader.exists(model,"PackedScene"),
                "AI selected a weapon with no installed licensed GLB")
    check(roles.has(WEAPONS.AR) and roles.has(WEAPONS.AWM) and
        roles.size()>=3,
        "49 opponents still share just one rifle instead of real loadouts")
    check(BOT.CHASE_SPEED>=4.0 and BOT.CHASE_SPEED<7.1,
        "enemies cannot pursue effectively or sprint faster than Lila")
    check(BOT.BURST_ROUNDS==2 and BOT.MAX_VISION_RAYS<=5,
        "faster combat changed the mobile perception or burst safety budget")
    var ar_bot: CharacterBody3D=combat._targets[0]
    check(ar_bot._loadout_shot_gap()>=.20 and
        ar_bot._loadout_shot_gap()<BOT.BURST_SHOT_GAP and
        ar_bot._loadout_burst_rest()<BOT.BURST_RECOVERY,
        "rifle rivals still use the outdated sluggish identical burst timer")
    for rival in combat._targets:
        check(rival._loadout_shot_gap()>=.20 and
            rival._loadout_burst_rest()>=.67 and
            rival._loadout_burst_rest()<=BOT.BURST_RECOVERY,
            "a rival weapon bypassed the finite bounded shot/recovery timers")
    check(BOT.MAX_DETAILED_ENEMY_RIGS<=14,
        "weapon variation made every remote enemy allocate a full skeleton")
    if not failed:
        print("V75125_ENEMY_LOADOUT PASS opponents=49 "+
            "distinct_installed_weapons=",roles.size()," ranged_physics=1 "+
            "magazines=real detailed_rig_budget=14")
    quit(1 if failed else 0)
