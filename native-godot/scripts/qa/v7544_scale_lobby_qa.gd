extends SceneTree
const BOT=preload("res://scripts/ai/aurora_bot.gd")
## Internal physics stress fixtures plus ONE 50-fighter playable BR lobby.
## lobby scenery. Never counts simulated clients as human online players.
const PERFORMANCE=preload("res://scripts/persistence/aurora_performance_report.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7544_PLAYABLE_SCALE "+reason)


func _verify() -> void:
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var combat: Node3D=game.get_node("CombatRange")
    var player: CharacterBody3D=game.get_node("Operator")
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    for bot in combat._targets:
        bot.set_physics_process(false)
    await physics_frame
    check(combat._targets.size()==4,
        "training must retain exactly four independently physical bots")
    check(combat.encounter_size==9,
        "safe default must remain 9 for Motorola until 20/30 are profiled")
    combat.set_encounter_size(20)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(combat._targets.size()==19 and combat.active_fighter_count()==20,
        "20-participant BR must have one real player and 19 actual bots")
    var positions: Array[Vector2]=[]
    for i in range(combat._targets.size()):
        var bot: CharacterBody3D=combat._targets[i]
        check(bot is CharacterBody3D and bot.health==BOT.MAX_HEALTH and
            bot.sector_battle and bot.get_node_or_null("OpponentCollider")!=null,
            "20-person round has fake or collision-less participant "+str(i))
        var at: Vector2=bot.spawn_coordinates
        check(terrain.height_at(at.x,at.y)>terrain.sea_level+.3,
            "bot spawned in the sea "+str(i))
        if i>=8:
            var original: Node3D=bot.get_node_or_null("DistantOriginalEnemyRig") as Node3D
            check(bot.distance_lod and original!=null and original.visible and
                original==bot._lod_rig and
                original.find_child("Skeleton3D",true,false)!=null and
                original.find_children("*","MeshInstance3D",true,false).size()>0 and
                bot.get_node_or_null("DistantEnemyVisual")==null,
                "far mobile bot missing original skinned LOD representation "+str(i))
        for prior in positions:
            check(at.distance_to(prior)>2.0,
                "two bots spawned on top of each other: "+str(i))
        positions.append(at)

    combat.end_sector_battle()
    combat.set_encounter_size(30)
    combat.begin_sector_battle()
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(combat._targets.size()==29 and combat.active_fighter_count()==30,
        "30-participant stress mode did not instantiate 29 real physics agents")
    check(combat._targets[28].distance_lod,
        "29th AI should use distance-based performance LOD")
    check(combat._targets[28].get_node_or_null("OpponentCollider")!=null,
        "29th AI has no physical hit target")
    combat.end_sector_battle()
    combat.set_encounter_size(9)
    combat.begin_sector_battle()
    for bot in combat._targets:
        bot.set_physics_process(false)
    check(combat._targets.size()==8 and combat.active_fighter_count()==9,
        "switching back to safe 9 left orphaned active opponents")
    check(not combat._targets[7].distance_lod,
        "standard 9-participant mode lost skinned near opponents")

    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    front._show_lobby()
    check(front.stage=="lobby" and
        front.get_node_or_null("OfflineEncounterSize")==null and
        front.find_child("OfflineEncounterSize",true,false)==null,
        "engineering roster selector leaked into user-facing BR lobby")
    check(front._match_mode_selector.get_item_text(0)=="CLÁSICO" and
        not front._lobby_section_hint.visible and
        not front._lobby_mode_caption.visible and
        front._lobby_mode_status.text.contains("50 PARTICIPANTES"),
        "classic backend remains fixed at 50 with no redundant lobby labels")
    var preview: Node3D=front._preview_container.get_node(
        "PreviewViewport/AuroraCharacterStage/AuroraReal3DLobbyEnvironment")
    check(preview!=null and preview.find_children("*","MeshInstance3D",true,false).size()>22
        and preview.find_children("*","MultiMeshInstance3D",true,false).size()>=6,
        "lobby lost structural meshes or its instanced 3D scenery")
    check(preview.find_child("PolarAuroraCurtain",true,false)!=null,
        "lobby has no visible original aurora 3D curtain")
    var nav: VBoxContainer=front._lobby_nav
    var safe: Rect2=front.get_viewport().get_visible_rect()
    if safe.size.y<620:
        for button in nav.get_children():
            if button is Button:
                check(button.custom_minimum_size.y<=32.0,
                    "nine mobile tabs overflow Motorola landscape height")
    var recorded: Array[float]=[24.0,28.0,34.0,42.0,52.0]
    check(PERFORMANCE.record(20,recorded,42.0,true)==OK,
        "local measured FPS statistics cannot be saved")
    var measurements: Dictionary=PERFORMANCE.latest()
    check(int(measurements.get("participants",0))==20 and
        absf(float(measurements.get("average_fps",0))-36.0)<.1 and
        absf(float(measurements.get("low10_fps",0))-24.0)<.1,
        "performance reporting computes incorrect average or low percentile")
    if not failed:
        print("V7544_PLAYABLE_SCALE PASS standard=9 offline_ai20=19 "+
            "offline_ai30=29 collision=all true_multiplayer=not_claimed "+
            "real_lobby_3d=1 mobile_menu=fit")
    quit(1 if failed else 0)
