extends SceneTree
## V75.182: checks ACTUAL aircraft mesh in running Main.tscn rather
## than accepting a conceptual C17 model that was never imported.
## Solid swept wing/tail geometry is a tangible visual change only.
const FLIGHT=preload("res://scripts/match/airdrop_sequence.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V75182_AIRFRAME_3D "+why)

func _verify() -> void:
    root.size=Vector2i(964,434)
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var director: Node3D=game.get_node("AuroraSectorMatch")
    var combat: Node3D=game.get_node("CombatRange")
    var player: CharacterBody3D=game.get_node("Operator")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    for bot in combat._targets:
        bot.set_physics_process(false)
    director.begin_aircraft_phase()
    var flight: Node3D=director.get("_flight") as Node3D
    var craft: Node3D=player.get_node_or_null(
        "AuroraTransportAircraft") as Node3D
    check(flight!=null and craft!=null and craft.top_level
        and flight.phase=="aircraft" and player.air_mode=="aircraft",
        "flight did not instantiate an actually airborne transport")
    if craft==null:
        game.queue_free()
        await process_frame
        quit(1)
        return
    # A missing externally supplied aircraft GLB is never described
    # by QA as an integrated production-quality C17.
    var external: Node3D=craft.get_node_or_null("AuroraC17UserVisual")
    if not ResourceLoader.exists(FLIGHT.C17_ASSET,"PackedScene"):
        check(external==null,
            "missing C17 source was incorrectly reported as live geometry")

    var wing: MeshInstance3D=craft.get_node(
        "TransportMainWings") as MeshInstance3D
    var tailwing: MeshInstance3D=craft.get_node(
        "TailPlane") as MeshInstance3D
    var fin: MeshInstance3D=craft.get_node(
        "TailFin") as MeshInstance3D
    check(wing.mesh is ArrayMesh and tailwing.mesh is ArrayMesh and
        fin.mesh is ArrayMesh and
        wing.mesh.get_aabb().size.y>.28 and
        tailwing.mesh.get_aabb().size.y>.28 and
        fin.mesh.get_aabb().size.x>.12,
        "plane wings or vertical stabilizer are still flat 2D quads")
    check(wing.mesh.get_surface_count()==1
        and tailwing.mesh.get_surface_count()==1,
        "extra wing surfaces break the low-draw-call mobile mesh budget")
    var wing_arr: Array=wing.mesh.surface_get_arrays(0)
    check((wing_arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()>=120,
        "actual solid wing has no stitched aerodynamic panels")
    for side in [-1,1]:
        var windows: MeshInstance3D=craft.get_node_or_null(
            "AuroraCabinWindows%d"%side) as MeshInstance3D
        var side_glass: MeshInstance3D=craft.get_node_or_null(
            "AuroraCockpitSideGlass%d"%side) as MeshInstance3D
        var aileron: MeshInstance3D=craft.get_node_or_null(
            "AuroraWingAileron%d"%side) as MeshInstance3D
        var elevator: MeshInstance3D=craft.get_node_or_null(
            "AuroraTailElevator%d"%side) as MeshInstance3D
        check(windows!=null and windows.mesh is ArrayMesh
            and windows.mesh.surface_get_array_len(0)>=30,
            "passenger compartment is missing 5 real panel windows")
        check(side_glass!=null and side_glass.mesh is ArrayMesh
            and aileron!=null and aileron.mesh is ArrayMesh
            and elevator!=null and elevator.mesh is ArrayMesh,
            "cockpit, wing control panel or tail elevator was omitted")
    check(craft.get_node("AuroraRearCargoRamp").mesh is ArrayMesh
        and craft.get_node("AuroraCockpitGlass").mesh is ArrayMesh,
        "grounded cargo ramp or actual cockpit glazing not rendered")
    var mesh_count: int=0
    for node in craft.get_children():
        if node is MeshInstance3D:
            mesh_count+=1
            check((node as MeshInstance3D).cast_shadow==
                GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
                "aircraft introduces expensive dynamic shadow casters")
        check(not (node is CollisionObject3D) and
            not (node is Light3D) and
            not (node is AnimationPlayer),
            "new aircraft visual allocated physics/light/animation nodes")
    check(mesh_count>=27 and mesh_count<=38,
        "flight visual exceeded bounded low-poly mobile draw budget")
    # The historical route and input remain the authority. The mesh must
    # not take control of player's actual CharacterBody3D or change time.
    check(FLIGHT.ROUTE_START_Z==76.0 and
        FLIGHT.ROUTE_END_Z==-78.0 and
        FLIGHT.FLIGHT_SECONDS==13.0 and
        is_equal_approx(player.global_position.y,FLIGHT.FLIGHT_ALTITUDE),
        "new geometry altered the physics-authoritative flight path")
    var first_position: Vector3=player.global_position
    flight.call("_physics_process",.12)
    check(player.global_position.z<first_position.z
        and flight.phase=="aircraft",
        "plane did not progress along the actual Godot flight corridor")
    check(str(hud.get("air_stage"))=="aircraft",
        "plane mesh accidentally switched the live HUD into combat")
    flight.jump_from_aircraft()
    await process_frame
    await process_frame
    check(not is_instance_valid(craft) or craft.is_queued_for_deletion(),
        "new aircraft geometry survives jump, leaks after freefall begins")
    check(flight.phase=="freefall" and player.air_mode=="freefall"
        and str(hud.get("air_stage"))=="freefall",
        "jump from visual aircraft did not reach genuine freefall")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75182_AIRFRAME_3D PASS real_3D_wing=1 "+
            "volumetric_fin=1 two_window_strips=1 "+
            "cockpit=1 cargo_ramp=1 mobile_mesh_budget=1 "+
            "no_extra_physics=1 flight_route=1 real_jump=1")
    quit(1 if failed else 0)
