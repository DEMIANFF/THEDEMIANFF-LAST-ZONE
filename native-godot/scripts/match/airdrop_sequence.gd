extends Node3D
## Aurora offline deployment sequence: aircraft -> freefall -> parachute -> land.
## It is a playable sector prototype, not an 8km aircraft network simulation.
signal touchdown
const FLIGHT_DIAGNOSTICS=preload("res://scripts/match/flight_diagnostics.gd")

const FLIGHT_SECONDS: float=13.0
const FLIGHT_ALTITUDE: float=97.0
const ROUTE_START_Z: float=76.0
const ROUTE_END_Z: float=-78.0
# V75.17 A/B: isolate the mobile physics ray invoked near 39 m terrain clearance.
# The island heightfield is authoritative and already agrees with its collider.
const TERRAIN_PROXIMITY_M: float=42.0
const AUTO_PARACHUTE_CLEARANCE_M: float=26.0

var player: CharacterBody3D
var terrain: StaticBody3D
var hud: CanvasLayer
var phase: String="inactive"
var elapsed: float=0.0
var _craft: Node3D
var _drop_requested: bool=false
var _trace_clock: float=0.0
var _ground_approach_marked: bool=false
var _aircraft_motion_committed: bool=false
var _flight_tick_count: int=0


func _ready() -> void:
    set_physics_process(false)


func begin() -> void:
    phase="aircraft"
    elapsed=0.0
    _drop_requested=false
    _trace_clock=0.0
    _ground_approach_marked=false
    _aircraft_motion_committed=false
    _flight_tick_count=0
    player.begin_aircraft()
    player.global_position=_route_point(0.0)
    _build_craft()
    hud.set_air_stage("aircraft")
    hud.impact("VUELO AURORA / SALTA O ESPERA EL DESPLIEGUE")
    FLIGHT_DIAGNOSTICS.checkpoint("active","aircraft",player,"start")
    set_physics_process(true)


func request_jump_or_parachute() -> void:
    if phase=="aircraft":
        _drop_requested=true
        # Record the input BEFORE any physics callback or character transition.
        FLIGHT_DIAGNOSTICS.checkpoint("active","jump_requested",player,"button_pressed")
    elif phase=="freefall":
        deploy_parachute()


func _route_point(progress: float) -> Vector3:
    var z: float=lerpf(ROUTE_START_Z,ROUTE_END_Z,clampf(progress,0.0,1.0))
    return Vector3(0.0,FLIGHT_ALTITUDE,z)


func _physics_process(delta: float) -> void:
    # First Android frame is materially different from a sustained flight.
    # Keep diagnostic notes AFTER camera/aircraft transforms, not before.
    # Never overwrite the key first-motion note with an initial flight_tick.
    _trace_clock-=delta
    _flight_tick_count+=1
    if phase=="aircraft":
        elapsed+=delta
        player.global_position=_route_point(elapsed/FLIGHT_SECONDS)
        if not _aircraft_motion_committed:
            FLIGHT_DIAGNOSTICS.checkpoint("active","aircraft",player,"first_player_motion")
        if _craft:
            _craft.global_position=player.global_position+Vector3(0,.7,-1)
        if not _aircraft_motion_committed:
            _aircraft_motion_committed=true
            FLIGHT_DIAGNOSTICS.checkpoint("active","aircraft",player,"first_aircraft_frame_committed")
            _trace_clock=.25
        elif _trace_clock<=0.0:
            # Higher resolution during the first two seconds, lower IO after.
            _trace_clock=.35 if elapsed<2.0 else 1.0
            FLIGHT_DIAGNOSTICS.checkpoint("active","aircraft",player,
                "aircraft_tick_"+str(_flight_tick_count))
        if _drop_requested or elapsed>=FLIGHT_SECONDS:
            jump_from_aircraft()
    elif phase=="freefall":
        if _trace_clock<=0.0:
            _trace_clock=1.0
            FLIGHT_DIAGNOSTICS.checkpoint("active","freefall",player,
                "freefall_tick_"+str(_flight_tick_count))
        var pos: Vector3=player.global_position
        # Controlled Motorola diagnosis: the V75.16 build hard-exited close
        # to this altitude. Do not allocate/call PhysicsDirectSpaceState3D
        # roof-ray queries inside freefall. Use the same continuously
        # interpolated heightfield backing the terrain trimesh collider.
        # Body/roof collisions still run through CharacterBody3D.move_and_slide().
        var ground_y: float=terrain.height_at(pos.x,pos.z)
        var clearance: float=pos.y-ground_y
        if not is_finite(clearance):
            FLIGHT_DIAGNOSTICS.checkpoint("active","freefall",player,"invalid_ground_clearance")
            deploy_parachute()
            return
        if not _ground_approach_marked and clearance<TERRAIN_PROXIMITY_M:
            _ground_approach_marked=true
            FLIGHT_DIAGNOSTICS.checkpoint("active","freefall",player,
                "terrain_approach_no_ray_"+str(snappedf(clearance,0.1))+"m")
        if clearance<AUTO_PARACHUTE_CLEARANCE_M:
            # Retain the automatic *real* canopy and existing touch behavior.
            # At the known 6–10 m building scale this leaves room above roofs.
            FLIGHT_DIAGNOSTICS.checkpoint("active","freefall",player,
                "auto_canopy_terrain_clearance_"+str(snappedf(clearance,0.1))+"m")
            deploy_parachute()
    elif phase=="parachute" and _trace_clock<=0.0:
        _trace_clock=1.0
        FLIGHT_DIAGNOSTICS.checkpoint("active","parachute",player,
            "parachute_tick_"+str(_flight_tick_count))


func jump_from_aircraft() -> void:
    if phase!="aircraft":
        return
    # A jump requested by the plane's _physics_process() must not replace
    # character animation, release 3D meshes and rebuild the HUD inside the
    # active physics step. This is a deferred *real* transition, not a fake fall.
    phase="jump_pending"
    _drop_requested=false
    set_physics_process(false)
    FLIGHT_DIAGNOSTICS.checkpoint("active","jump_pending",player,"jump_transition_started")
    call_deferred("_release_craft_for_jump")


func _release_craft_for_jump() -> void:
    if phase!="jump_pending":
        return
    FLIGHT_DIAGNOSTICS.checkpoint("active","jump_pending",player,"craft_release_started")
    if _craft and is_instance_valid(_craft):
        _craft.visible=false
        _craft.queue_free()
    _craft=null
    FLIGHT_DIAGNOSTICS.checkpoint("active","jump_pending",player,"craft_release_scheduled")
    # Allow queued aircraft meshes to leave the RenderServer at the end
    # of this frame before revealing and animating the airborne operator.
    get_tree().process_frame.connect(_commit_jump,CONNECT_ONE_SHOT)


func _commit_jump() -> void:
    if phase!="jump_pending":
        return
    if not is_instance_valid(player) or not is_instance_valid(hud):
        phase="inactive"
        return
    FLIGHT_DIAGNOSTICS.checkpoint("active","jump_pending",player,"operator_freefall_before")
    player.begin_freefall(Vector3(0,0,(ROUTE_END_Z-ROUTE_START_Z)/FLIGHT_SECONDS))
    FLIGHT_DIAGNOSTICS.checkpoint("active","jump_pending",player,"operator_freefall_after")
    hud.set_air_stage("freefall")
    FLIGHT_DIAGNOSTICS.checkpoint("active","jump_pending",player,"hud_freefall_after")
    hud.impact("CAÍDA LIBRE / MUEVE EL JOYSTICK")
    phase="freefall"
    _trace_clock=1.2
    set_physics_process(true)
    FLIGHT_DIAGNOSTICS.checkpoint("active","freefall",player,"jump_committed")


func deploy_parachute() -> void:
    if phase!="freefall":
        return
    phase="parachute"
    player.deploy_parachute()
    hud.set_air_stage("parachute")
    hud.impact("PARACAÍDAS ABIERTO / CONTROLA EL ATERRIZAJE")
    _trace_clock=1.2
    FLIGHT_DIAGNOSTICS.checkpoint("active","parachute",player,"canopy_deployed")


func landed() -> void:
    # The operator emits landed_from_airdrop from CharacterBody3D physics.
    # Starting an entire match in the same callback can mutate physics
    # collision objects while Godot is flushing the physics step.
    # Commit the transition on the deferred main-thread pass instead.
    if phase=="inactive" or phase=="landed" or phase=="touchdown_pending":
        return
    phase="touchdown_pending"
    FLIGHT_DIAGNOSTICS.checkpoint("active","touchdown_pending",player,"pending_deferred_match")
    set_physics_process(false)
    call_deferred("_commit_touchdown")


func _commit_touchdown() -> void:
    if phase!="touchdown_pending":
        return
    if not is_instance_valid(player) or not is_instance_valid(hud):
        phase="inactive"
        return
    phase="landed"
    hud.set_air_stage("ground")
    touchdown.emit()
    FLIGHT_DIAGNOSTICS.checkpoint("completed","ground",player,"landed_and_match_started")


func _build_craft() -> void:
    if _craft:
        _craft.queue_free()
    _craft=Node3D.new()
    _craft.name="AuroraTransportAircraft"
    _craft.position=Vector3(0,.7,-1)
    player.add_child(_craft)
    _craft.top_level=true
    _craft.global_position=player.global_position+Vector3(0,.7,-1)
    _craft.global_rotation=Vector3.ZERO
    var wing_material:=StandardMaterial3D.new()
    wing_material.albedo_color=Color(.15,.26,.35)
    wing_material.metallic=.45
    wing_material.roughness=.48
    var accent:=StandardMaterial3D.new()
    accent.albedo_color=Color(.12,.68,.88)
    accent.metallic=.34
    accent.roughness=.4
    var body:=CylinderMesh.new()
    body.top_radius=.46
    body.bottom_radius=.46
    body.height=5.8
    body.radial_segments=12
    _piece("TransportFuselage",body,Vector3(0,0,0),Vector3(PI*.5,0,0),wing_material)
    var wings:=BoxMesh.new()
    wings.size=Vector3(8.2,.12,1.1)
    _piece("TransportMainWings",wings,Vector3(0,-.08,-.2),Vector3.ZERO,wing_material)
    var tail:=BoxMesh.new()
    tail.size=Vector3(3.0,.10,.55)
    _piece("TailPlane",tail,Vector3(0,.12,2.0),Vector3.ZERO,wing_material)
    var fin:=BoxMesh.new()
    fin.size=Vector3(.12,1.15,.65)
    _piece("TailFin",fin,Vector3(0,.62,2.10),Vector3.ZERO,accent)
    var stripe:=BoxMesh.new()
    stripe.size=Vector3(.22,.035,3.5)
    _piece("AuroraAircraftStripe",stripe,Vector3(0,.48,0),Vector3.ZERO,accent)


func _piece(label: String,mesh: Mesh,where: Vector3,angles: Vector3,material: Material) -> void:
    var o:=MeshInstance3D.new()
    o.name=label
    o.mesh=mesh
    o.position=where
    o.rotation=angles
    o.material_override=material
    o.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _craft.add_child(o)
