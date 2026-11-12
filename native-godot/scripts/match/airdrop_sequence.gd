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
var _parachute_first_tick_committed: bool=false
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
    _parachute_first_tick_committed=false
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
            _queue_auto_parachute()
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
            _queue_auto_parachute()
    elif phase=="parachute":
        if not _parachute_first_tick_committed:
            _parachute_first_tick_committed=true
            FLIGHT_DIAGNOSTICS.checkpoint("active","parachute",player,
                "first_parachute_physics_tick")
            _trace_clock=.25
        elif _trace_clock<=0.0:
            _trace_clock=.5
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


func _queue_auto_parachute() -> void:
    # The 26-m terrain trigger runs inside _physics_process. The aircraft
    # jump is deferred, but until now this equivalent transition modified
    # player animations, HUD controls and visibility inside the active
    # physics step. Defer the *whole* automatic canopy handoff once.
    if phase!="freefall":
        return
    phase="parachute_pending"
    FLIGHT_DIAGNOSTICS.checkpoint("active","parachute_pending",player,
        "canopy_auto_deferred_queued")
    call_deferred("_commit_parachute")


func deploy_parachute() -> void:
    # Manual canopy input may occur through the HUD outside the physics
    # callback. Preserve the existing public API and QA expectations.
    if phase!="freefall":
        return
    _commit_parachute()


func _commit_parachute() -> void:
    if phase!="freefall" and phase!="parachute_pending":
        return
    FLIGHT_DIAGNOSTICS.checkpoint("active","parachute_pending",player,
        "canopy_deferred_commit_started")
    phase="parachute"
    _parachute_first_tick_committed=false
    FLIGHT_DIAGNOSTICS.checkpoint("active","parachute",player,"canopy_transition_before")
    player.deploy_parachute()
    FLIGHT_DIAGNOSTICS.checkpoint("active","parachute",player,"canopy_physics_mode_after")
    hud.set_air_stage("parachute")
    FLIGHT_DIAGNOSTICS.checkpoint("active","parachute",player,"canopy_hud_after")
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
    player.add_child(_craft)
    _craft.top_level=true
    _craft.global_position=player.global_position+Vector3(0,.7,-1)
    _craft.global_rotation=Vector3.ZERO
    # Authored aerodynamic shapes rather than intersecting primitive cubes.
    # Low-poly elliptical hull and tapered lifting surfaces preserve mobile GL.
    var alloy:=StandardMaterial3D.new()
    alloy.albedo_color=Color(.16,.25,.33)
    alloy.metallic=.25
    alloy.roughness=.60
    alloy.cull_mode=BaseMaterial3D.CULL_DISABLED
    var shade:=StandardMaterial3D.new()
    shade.albedo_color=Color(.035,.12,.19)
    shade.metallic=.12
    shade.roughness=.28
    shade.cull_mode=BaseMaterial3D.CULL_DISABLED
    var stripe:=StandardMaterial3D.new()
    stripe.albedo_color=Color(.20,.78,.94)
    stripe.metallic=.20
    stripe.roughness=.40
    stripe.cull_mode=BaseMaterial3D.CULL_DISABLED

    # -Z points toward the plane's nose, matching flight route and camera.
    var fuselage: Mesh=_loft_hull([
        Vector3(-3.65,.15,.10),Vector3(-3.06,.43,.43),
        Vector3(-2.10,.60,.66),Vector3(-.70,.70,.76),
        Vector3(1.18,.67,.70),Vector3(2.72,.39,.43),
        Vector3(3.40,.09,.12)],14)
    _piece("TransportFuselage",fuselage,Vector3.ZERO,Vector3.ZERO,alloy)
    _piece("TransportMainWings",_airfoil_pair(5.90,.76,-.30),
        Vector3.ZERO,Vector3.ZERO,alloy)
    _piece("TailPlane",_airfoil_pair(2.45,.22,2.48),
        Vector3.ZERO,Vector3.ZERO,alloy)
    _piece("TailFin",_tail_fin(),Vector3.ZERO,Vector3.ZERO,stripe)
    _piece("AuroraAircraftStripe",_hull_stripe(),Vector3.ZERO,
        Vector3.ZERO,stripe)

    # Slanted dark cockpit glass and real engine nacelles.
    var glass_mesh:=_panel_mesh([
        Vector3(-.38,.31,-3.20),Vector3(.38,.31,-3.20),
        Vector3(.47,.66,-2.29),Vector3(-.47,.66,-2.29)])
    _piece("AuroraCockpitGlass",glass_mesh,Vector3.ZERO,Vector3.ZERO,shade)
    for sign in [-1,1]:
        var side: float=float(sign)
        var nacelle:=CylinderMesh.new()
        nacelle.top_radius=.24
        nacelle.bottom_radius=.34
        nacelle.height=1.02
        nacelle.radial_segments=12
        _piece("AuroraTurboprop%d"%sign,nacelle,
            Vector3(side*2.03,-.31,-.42),Vector3(PI*.5,0,0),alloy)
        var cone:=SphereMesh.new()
        cone.radius=.28
        cone.height=.42
        cone.radial_segments=10
        cone.rings=4
        _piece("AuroraEngineCowling%d"%sign,cone,
            Vector3(side*2.03,-.31,-1.06),Vector3.ZERO,shade)
        for blade in range(3):
            var angle: float=float(blade)*TAU/3.0
            var direction: Vector3=Vector3(cos(angle),sin(angle),0)
            var normal: Vector3=Vector3(-direction.y,direction.x,0)
            var center:=Vector3(side*2.03,-.31,-1.14)
            var blade_mesh:=_panel_mesh([
                center+normal*.055,
                center+direction*.9+normal*.17,
                center+direction*1.04-normal*.03,
                center-normal*.055])
            _piece("AuroraPropeller%d_%d"%[sign,blade],blade_mesh,
                Vector3.ZERO,Vector3.ZERO,stripe)
    # Physical player and camera remain independent of decorative airplane.


func _loft_hull(profiles: Array[Vector3],segments: int) -> ArrayMesh:
    # profiles: z along X, elliptical horizontal width along Y, vertical
    # height along Z. Radial interpolation avoids box-built transport look.
    var drawing:=SurfaceTool.new()
    drawing.begin(Mesh.PRIMITIVE_TRIANGLES)
    for j in range(profiles.size()-1):
        for i in range(segments):
            var a: float=TAU*float(i)/segments
            var b: float=TAU*float(i+1)/segments
            var first: Vector3=profiles[j]
            var second: Vector3=profiles[j+1]
            var p0:=Vector3(cos(a)*first.y,sin(a)*first.z,first.x)
            var p1:=Vector3(cos(b)*first.y,sin(b)*first.z,first.x)
            var p2:=Vector3(cos(a)*second.y,sin(a)*second.z,second.x)
            var p3:=Vector3(cos(b)*second.y,sin(b)*second.z,second.x)
            _triangle(drawing,p0,p1,p2)
            _triangle(drawing,p1,p3,p2)
    drawing.generate_normals()
    return drawing.commit()


func _triangle(tool: SurfaceTool,a: Vector3,b: Vector3,c: Vector3) -> void:
    tool.add_vertex(a)
    tool.add_vertex(b)
    tool.add_vertex(c)


func _panel_mesh(vertices: Array[Vector3]) -> ArrayMesh:
    var drawing:=SurfaceTool.new()
    drawing.begin(Mesh.PRIMITIVE_TRIANGLES)
    _triangle(drawing,vertices[0],vertices[1],vertices[2])
    _triangle(drawing,vertices[0],vertices[2],vertices[3])
    _triangle(drawing,vertices[2],vertices[1],vertices[0])
    _triangle(drawing,vertices[3],vertices[2],vertices[0])
    drawing.generate_normals()
    return drawing.commit()


func _airfoil_pair(span: float,sweep: float,z: float) -> ArrayMesh:
    var drawing:=SurfaceTool.new()
    drawing.begin(Mesh.PRIMITIVE_TRIANGLES)
    for sign in [-1,1]:
        var side: float=float(sign)
        var vertices: Array[Vector3]=[
            Vector3(.45*side,-.16,z-.58),
            Vector3(span*side,-.05,z+sweep-.22),
            Vector3(span*side,-.05,z+sweep+.25),
            Vector3(.45*side,-.16,z+.69)]
        _triangle(drawing,vertices[0],vertices[1],vertices[2])
        _triangle(drawing,vertices[0],vertices[2],vertices[3])
        _triangle(drawing,vertices[2],vertices[1],vertices[0])
        _triangle(drawing,vertices[3],vertices[2],vertices[0])
    drawing.generate_normals()
    return drawing.commit()


func _tail_fin() -> ArrayMesh:
    return _panel_mesh([
        Vector3(0,.2,2.25),Vector3(0,1.72,2.98),
        Vector3(0,1.84,3.41),Vector3(0,.2,3.20)])


func _hull_stripe() -> ArrayMesh:
    return _panel_mesh([
        Vector3(-.57,.23,-2.12),Vector3(.57,.23,-2.12),
        Vector3(.63,.45,-.65),Vector3(-.63,.45,-.65)])


func _piece(label: String,mesh: Mesh,where: Vector3,angles: Vector3,material: Material) -> void:
    var o:=MeshInstance3D.new()
    o.name=label
    o.mesh=mesh
    o.position=where
    o.rotation=angles
    o.material_override=material
    o.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _craft.add_child(o)
