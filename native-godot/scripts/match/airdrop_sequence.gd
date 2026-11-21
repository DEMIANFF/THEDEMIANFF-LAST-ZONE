extends Node3D
## Aurora offline deployment sequence: aircraft -> freefall -> parachute -> land.
## It is a playable sector prototype, not an 8km aircraft network simulation.
signal touchdown
signal aircraft_audio_changed(active: bool)
signal rival_airdrop_started
const FLIGHT_DIAGNOSTICS=preload("res://scripts/match/flight_diagnostics.gd")
# Optional original-source model. Never replace the working flight physics with GLB geometry.
const C17_ASSET: String="res://assets/vehicles/user_pack/aurora_c17_mobile.glb"

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
# Reuse six small meshes for actual prop rotation; no tweens or new objects
# are allocated during flight or while the pilot is parachuting.
var _fallback_propellers: Array[MeshInstance3D]=[]
const PROPELLER_RADIANS_PER_SECOND: float=13.5
var _route_hud_clock: float=0.0


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
    _route_hud_clock=0.0
    player.begin_aircraft()
    player.global_position=_route_point(0.0)
    _build_craft()
    aircraft_audio_changed.emit(true)
    hud.set_air_stage("aircraft")
    hud.set_aircraft_route_progress(0.0,FLIGHT_SECONDS)
    hud.impact("RUTA EN MINIMAPA / MARCA DESTINO Y SALTA")
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
        _route_hud_clock-=maxf(0.0,delta)
        if _route_hud_clock<=0.0:
            _route_hud_clock=.25
            if is_instance_valid(hud):
                hud.set_aircraft_route_progress(elapsed,FLIGHT_SECONDS)
        if not _aircraft_motion_committed:
            FLIGHT_DIAGNOSTICS.checkpoint("active","aircraft",player,"first_player_motion")
        if _craft:
            _craft.global_position=player.global_position+Vector3(0,.7,-1)
            _advance_visible_propellers(delta)
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
    aircraft_audio_changed.emit(false)
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
    _fallback_propellers.clear()
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
    rival_airdrop_started.emit()


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
    _fallback_propellers.clear()
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
            # Keep mesh vertices relative to the real engine hub. The old
            # vertices were authored in entire-aircraft coordinates, making
            # rotations around each propeller orbit the fuselage instead.
            var blade_mesh:=_panel_mesh([
                normal*.055,
                direction*.9+normal*.17,
                direction*1.04-normal*.03,
                -normal*.055])
            var prop:=MeshInstance3D.new()
            prop.name="AuroraPropeller%d_%d"%[sign,blade]
            prop.mesh=blade_mesh
            prop.position=center
            prop.material_override=stripe
            prop.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            _craft.add_child(prop)
            _fallback_propellers.append(prop)
    # Navigation lights make the actual fallback airframe readable against
    # Aurora's snow and twilight without extra Light3D/shadow passes.
    var lamp_mesh:=SphereMesh.new()
    lamp_mesh.radius=.115
    lamp_mesh.height=.23
    lamp_mesh.radial_segments=8
    lamp_mesh.rings=3
    var port:=StandardMaterial3D.new()
    port.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    port.albedo_color=Color(.94,.17,.18)
    port.emission_enabled=true
    port.emission=port.albedo_color
    port.emission_energy_multiplier=1.6
    var starboard:=StandardMaterial3D.new()
    starboard.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    starboard.albedo_color=Color(.14,.94,.40)
    starboard.emission_enabled=true
    starboard.emission=starboard.albedo_color
    starboard.emission_energy_multiplier=1.6
    var tail_lamp:=StandardMaterial3D.new()
    tail_lamp.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    tail_lamp.albedo_color=Color(.78,.92,1.0)
    tail_lamp.emission_enabled=true
    tail_lamp.emission=tail_lamp.albedo_color
    tail_lamp.emission_energy_multiplier=1.1
    _piece("AuroraPortNavigation",lamp_mesh,
        Vector3(-5.85,-.07,-.15),Vector3.ZERO,port)
    _piece("AuroraStarboardNavigation",lamp_mesh,
        Vector3(5.85,-.07,-.15),Vector3.ZERO,starboard)
    _piece("AuroraTailNavigation",lamp_mesh,
        Vector3(0,.26,3.30),Vector3.ZERO,tail_lamp)
    # The user-supplied C-17 is decorative only. If the verified, optimized
    # GLB is not staged or has invalid geometry, retain the tested Aurora mesh.
    _install_optional_aurora_c17()
    # Physical player and camera remain independent of decorative airplane.


## Physical aircraft movement is unchanged. Only the 6 visible blades
## animate about the two actual engine hubs; no rotation happens after the
## jump or when the original imported C-17 has hidden this fallback model.
func _advance_visible_propellers(delta: float) -> void:
    if not is_instance_valid(_craft):
        return
    for prop in _fallback_propellers:
        if is_instance_valid(prop) and prop.visible:
            prop.rotation.z=wrapf(prop.rotation.z+
                maxf(0.0,delta)*PROPELLER_RADIANS_PER_SECOND,-PI,PI)


func _install_optional_aurora_c17() -> void:
    if not ResourceLoader.exists(C17_ASSET, "PackedScene"):
        return
    var scene: PackedScene=load(C17_ASSET) as PackedScene
    if scene==null:
        push_warning("Aurora C17 import is not a valid PackedScene")
        return
    var visual: Node3D=scene.instantiate() as Node3D
    if visual==null:
        push_warning("Aurora C17 source has no usable Node3D root")
        return
    visual.name="AuroraC17UserVisual"
    _craft.add_child(visual)
    var minimum:=Vector3(INF,INF,INF)
    var maximum:=Vector3(-INF,-INF,-INF)
    var mesh_count: int=0
    for item in visual.find_children("*","MeshInstance3D",true,false):
        var part: MeshInstance3D=item as MeshInstance3D
        if part.mesh==null:
            continue
        mesh_count+=1
        var bounds: AABB=part.get_aabb()
        for vertex in range(8):
            var local_point: Vector3=visual.to_local(
                part.to_global(bounds.get_endpoint(vertex)))
            minimum=minimum.min(local_point)
            maximum=maximum.max(local_point)
    var extent: Vector3=maximum-minimum
    if mesh_count==0 or not extent.is_finite() or (
            maxf(extent.x,maxf(extent.y,extent.z))<.1):
        visual.queue_free()
        push_warning("Aurora C17 lacks finite visible geometry; fallback aircraft retained")
        return
    # The source C17's long fuselage is X; wing span is along Z.
    # Render a ~12.5m aircraft without adopting the model's physics or root motion.
    var fuselage_length: float=maxf(extent.x,extent.z)
    var factor: float=clampf(12.5/fuselage_length,.05,1.0)
    if extent.x>=extent.z:
        visual.rotation.y=-PI*.5
    visual.scale=Vector3.ONE*factor
    var center: Vector3=(minimum+maximum)*.5
    visual.position=-(visual.quaternion*center)*factor
    # Keep old mesh nodes instantiated for compatibility with existing QA,
    # but do not render two superimposed aircraft.
    for item in _craft.get_children():
        if item is MeshInstance3D:
            (item as MeshInstance3D).visible=false
    print("AURORA_C17_SOURCE_ACTIVE meshes=",mesh_count,
        " normalized_length_m=",fuselage_length*factor,
        " flight_physics_unchanged=1")


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
