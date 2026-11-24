extends SceneTree
## V75.183: three user-reported Motorola bugs are tested in real Godot
## scenes at 964x434: Vector shortcut leak, yellow airborne mini route,
## and enemy appearance changing into low-poly cubes with distance.
const BOT=preload("res://scripts/ai/aurora_bot.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V75183_THREE_MOTOROLA_FIXES "+why)

func _verify() -> void:
    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    front._show_lobby()
    await process_frame
    front._layout_safe()
    await process_frame
    var vector_button: Button=front.find_child(
        "AuroraInspectRealVector",true,false) as Button
    check(vector_button!=null and front.stage=="lobby" and
        front._selected_tab=="JUGAR" and
        not vector_button.is_visible_in_tree(),
        "the Kriss Vector inspect button leaks under INICIAR in JUGAR")
    front._select_tab("ARMAS")
    check(front._selected_tab=="ARMAS" and
        vector_button.is_visible_in_tree(),
        "the original 3D Vector inspection is unavailable in ARMAS")
    # The original weapon catalog and its actual model must keep working.
    vector_button.pressed.emit()
    check(front._selected_tab=="ARMAS" and
        int(front._armory_selected_slot)==4,
        "Vector shortcut no longer selects the real weapon catalog slot")
    for tab in ["INVENTARIO","PERSONAJE","SOCIAL","JUGAR"]:
        front._select_tab(tab)
        check(not vector_button.is_visible_in_tree(),
            "weapon inspect shortcut persists in unrelated lobby tab "+tab)
    front.queue_free()
    await process_frame

    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var combat: Node3D=game.get_node("CombatRange")
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var player: CharacterBody3D=game.get_node("Operator")
    var radar: Control=game.get_node(
        "TrainingHUD/AuroraTacticalOverlay/AuroraTrainingRadar")
    for rival in combat._targets:
        rival.set_physics_process(false)
    director.begin_aircraft_phase()
    var actual_route: PackedVector2Array=radar.aircraft_route_pixels()
    check(player.air_mode=="aircraft" and actual_route.size()==2,
        "removing the yellow indicator also destroyed the actual flight route")
    # The enlarged tactical map still renders real airplane route
    # endpoints and can store a landing marker for after disembarking.
    radar.set_waypoint(Vector2(18.0,-16.0))
    check(radar.landing_waypoint_guidance().has("world"),
        "the flight destination information was accidentally deleted")
    # Exercise the actual marker input used by _draw, including in an
    # exported PCK where GDScript source text is not necessarily present.
    check(radar.minimap_waypoint_marker().is_empty(),
        "yellow destination marker still renders aboard aircraft")
    # The route drawing itself stays out of the minimap. Audit source
    # only when available; the runtime checks above and below always run.
    var radar_path: String="res://scripts/ui/aurora_training_radar.gd"
    if FileAccess.file_exists(radar_path):
        var radar_source: String=FileAccess.get_file_as_string(radar_path)
        if not radar_source.is_empty():
            var draw_source: String=radar_source.get_slice("func _draw() -> void:",1)
            check(not draw_source.contains("=aircraft_route_pixels()") and
                not draw_source.contains("draw_line(flight_line[0]") and
                not draw_source.contains("draw_circle(flight_line[1]"),
                "yellow aircraft route returned to the local minimap")
            check(draw_source.contains("waypoint_icon: Dictionary=minimap_waypoint_marker()"),
                "minimap drawing bypasses the tested waypoint visibility gate")
    var flight: Node3D=director.get("_flight") as Node3D
    check(is_instance_valid(flight),"no live aircraft controller to test jump")
    if is_instance_valid(flight):
        flight.jump_from_aircraft()
        check(player.air_mode=="freefall" and
            radar.aircraft_route_pixels().is_empty(),
            "actual jump failed to exit the aircraft navigation phase")
        check(radar.landing_waypoint_guidance().get("world",Vector2(INF,INF))==
            Vector2(18.0,-16.0) and not radar.minimap_waypoint_marker().is_empty(),
            "stored destination did not become visible again after the real jump")

    combat.set_encounter_size(50)
    director.start_sector_battle()
    director.set_process(false)
    combat.set_process(false)
    player.set_physics_process(false)
    for rival in combat._targets:
        rival.set_physics_process(false)
    check(combat._targets.size()==49 and
        combat.active_fighter_count()==50,
        "same-looking enemy visuals removed real physical opponents")
    var inherited: CharacterBody3D
    var distant_count: int=0
    for rival in combat._targets:
        if not rival.distance_lod:
            continue
        distant_count+=1
        var original: Node3D=rival._lod_rig
        check(original!=null and original.visible and
            original.get_node_or_null("DistantEnemyVisual")==null and
            original.find_child("Skeleton3D",true,false)!=null and
            original.find_children("*","MeshInstance3D",true,false).size()>0,
            "distant opponent still has a fake cuboid body instead of original GLB")
        var animator: AnimationPlayer=original.find_child(
            "AnimationPlayer",true,false) as AnimationPlayer
        check(animator!=null and (rival._rig!=null or not animator.active),
            "far enemy's original rig animates despite active-animation cap")
        if inherited==null:
            inherited=rival
    check(distant_count==41,
        "not all 41 original far opponents are rendered from source rig")
    if inherited!=null:
        var original_visual: Node3D=inherited._lod_rig
        var original_mesh: MeshInstance3D=original_visual.find_children(
            "*","MeshInstance3D",true,false)[0] as MeshInstance3D
        inherited.global_position=player.global_position+Vector3(1,0,0)
        inherited._set_full_visual(true)
        check(inherited._rig==original_visual and
            inherited._lod_rig==original_visual,
            "near enemy changed to a different model on promotion")
        inherited._set_full_visual(false)
        var final_mesh: MeshInstance3D=original_visual.find_children(
            "*","MeshInstance3D",true,false)[0] as MeshInstance3D
        var inactive: AnimationPlayer=original_visual.find_child(
            "AnimationPlayer",true,false) as AnimationPlayer
        check(inherited._rig==null and
            inherited._lod_rig==original_visual and
            original_mesh==final_mesh and
            inherited._lod_rig.visible and inactive!=null and
            not inactive.active and
            inherited.get_node_or_null("OpponentCollider") is CollisionShape3D,
            "far-to-near-to-far lost exact skin, mesh, or real collider")
    check(get_nodes_in_group(BOT.DETAILED_ENEMY_GROUP).size()<=
        BOT.MAX_DETAILED_ENEMY_RIGS,
        "same-model LOD broke the strict 14 animated rig budget")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75183_THREE_MOTOROLA_FIXES PASS "+
            "lobby_vector_only_in_ARMAS=1 flight_minimap_no_yellow=1 "+
            "49_original_rivals=1 same_mesh_near_far=1 "+
            "animator_cap_14=1 physical_roster_50=1")
    quit(1 if failed else 0)
