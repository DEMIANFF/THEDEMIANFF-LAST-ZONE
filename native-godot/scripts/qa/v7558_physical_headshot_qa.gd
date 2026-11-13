extends SceneTree
## Real Godot PhysicsServer verified enemy head/body hits. No dummy NPC
## scores, no synthetic mobile performance measurements.
const RECORDS=preload("res://scripts/persistence/offline_match_records.gd")
const COMBAT=preload("res://scripts/combat/training_combat.gd")
const LEDGER_PATH="user://qa/aurora_headshot_ledger_ci.json"
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V7558_HEADSHOTS "+why)

func _clear_files() -> void:
    for ext in ["",".bak",".tmp"]:
        var file: String=ProjectSettings.globalize_path(LEDGER_PATH+ext)
        if FileAccess.file_exists(file):
            DirAccess.remove_absolute(file)

func _verify() -> void:
    check(str(ProjectSettings.get_setting(
        "rendering/renderer/rendering_method.mobile"))=="mobile",
        "Vulkan Mobile renderer changed")
    check(not COMBAT.is_critical_contact(
        Vector3(0,1.25,0),Vector3.ZERO) and
        COMBAT.is_critical_contact(Vector3(0,1.58,0),Vector3.ZERO) and
        not COMBAT.is_critical_contact(Vector3(0,2.15,0),Vector3.ZERO) and
        not COMBAT.is_critical_contact(Vector3(INF,1.60,0),Vector3.ZERO),
        "critical region is not the upper physical 1.74m capsule")
    check(absf(COMBAT.physical_hit_damage(0,false)-26.0)<.01 and
        absf(COMBAT.physical_hit_damage(0,true)-48.1)<.01 and
        absf(COMBAT.physical_hit_damage(1,false)-115.0)<.01 and
        absf(COMBAT.physical_hit_damage(1,true)-189.75)<.01 and
        COMBAT.physical_hit_damage(9,true)==0.0,
        "AR/AWM physically grounded head/body damage multipliers regressed")

    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var player: CharacterBody3D=game.get_node("Operator")
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    var enemy: CharacterBody3D=combat._targets[0]
    var base: float=terrain.height_at(105.0,20.0)+2.0
    enemy.global_position=Vector3(105.0,base,23.0)
    enemy.velocity=Vector3.ZERO
    await physics_frame
    await physics_frame
    var space: PhysicsDirectSpaceState3D=player.get_world_3d().direct_space_state
    var upper:=PhysicsRayQueryParameters3D.create(
        Vector3(105.0,base+1.58,17.0),
        Vector3(105.0,base+1.58,29.0))
    upper.exclude=[player.get_rid()]
    var physical_head: Dictionary=space.intersect_ray(upper)
    check(physical_head.get("collider")==enemy,
        "physical head-height ray did not hit the actual enemy capsule")
    if physical_head.get("collider")==enemy:
        combat.shots_fired_total=1
        var critical: Dictionary=combat._apply_verified_opponent_hit(physical_head)
        check(bool(critical.get("critical",false)) and
            absf(float(critical.get("damage",0.0))-48.1)<.05 and
            combat.headshots_total==1 and combat.shots_hit_total==1 and
            hud._hit_confirm_label.text.contains("CABEZA") and
            not bool(critical.get("eliminated",true)),
            "verified physical headshot failed to affect actual enemy health")

    var middle:=PhysicsRayQueryParameters3D.create(
        Vector3(105.0,base+1.0,17.0),
        Vector3(105.0,base+1.0,29.0))
    middle.exclude=[player.get_rid()]
    var physical_torso: Dictionary=space.intersect_ray(middle)
    check(physical_torso.get("collider")==enemy,
        "physical chest-height ray did not contact same real enemy")
    if physical_torso.get("collider")==enemy:
        combat.shots_fired_total=2
        var torso: Dictionary=combat._apply_verified_opponent_hit(physical_torso)
        check(not bool(torso.get("critical",true)) and
            absf(float(torso.get("damage",0.0))-26.0)<.05 and
            combat.headshots_total==1 and combat.shots_hit_total==2 and
            hud._hit_confirm_label.text.begins_with("+26"),
            "ordinary body hit incorrectly applied headshot bonus")

    check(combat._apply_verified_opponent_hit({}).is_empty() and
        combat._apply_verified_opponent_hit({
            "collider":terrain,"position":enemy.global_position
        }).is_empty() and
        combat._apply_verified_opponent_hit({
            "collider":enemy,"position":Vector3(NAN,base+1.5,23)
        }).is_empty() and combat.headshots_total==1,
        "empty, environmental or invalid hits were falsely counted")

    # Complete the same physical duel with a final headshot.
    if physical_head.get("collider")==enemy:
        combat.shots_fired_total=3
        var final_hit: Dictionary=combat._apply_verified_opponent_hit(physical_head)
        check(bool(final_hit.get("critical",false)) and
            bool(final_hit.get("eliminated",false)) and
            enemy.health==0.0 and combat.eliminations==1 and
            combat.headshots_total==2 and combat.shots_hit_total==3,
            "actual headshot elimination failed or invented an extra kill")
    check(int(combat.inventory_snapshot().get("headshots",-1))==2 and
        combat.shot_accuracy_percent()==100,
        "real headshot and accuracy counters differ from live inventory")

    var root_path: String=ProjectSettings.globalize_path(LEDGER_PATH)
    DirAccess.make_dir_recursive_absolute(root_path.get_base_dir())
    _clear_files()
    director._records=RECORDS.new(LEDGER_PATH)
    director._match_id=director._records.next_match_id()
    director._finish(false)
    var saved: Dictionary=RECORDS.new(LEDGER_PATH).snapshot()
    var entry: Dictionary=saved["history"][0]
    check(director.last_match_saved and
        int(entry.get("headshots",-1))==2 and
        int(entry.get("hits",-1))==3 and
        int(entry.get("shots",-1))==3 and
        hud._result_text.text.contains("CABEZA: 2"),
        "physical critical hits did not persist atomically or appear in results")
    var store=RECORDS.new(LEDGER_PATH)
    check(not store.record_result(2,false,0,10,{
        "shots":2,"hits":1,"headshots":2}),
        "rejected impossible headshots>hits telemetry corrupted journal")
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(combat.headshots_total==0 and combat.shots_hit_total==0 and
        combat.shots_fired_total==0 and combat.eliminations==0 and
        not combat.weapon_owned[1],
        "fresh round inherited previous critical hits, kills or rare weapon")
    _clear_files()
    if not failed:
        print("V7558_HEADSHOTS PASS physical_ray_head=1 chest=1 "+
            "invalid_ray=0 critical_kill=1 accuracy=1 durable_ledger=1 "+
            "reject_invalid=1 round_reset=1 vulkan=1")
    quit(1 if failed else 0)
