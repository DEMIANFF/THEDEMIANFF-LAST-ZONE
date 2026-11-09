extends SceneTree
## Verifies actual Godot material normal/tangent data and leg gait transitions.
## No APK export or synthetic screenshot counts as this quality gate.
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,context: String) -> void:
    if not ok:
        failed=true
        push_error("V7510_MATERIAL_MOTION "+context)


func _verify() -> void:
    var world: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(world)
    await physics_frame
    await physics_frame
    var terrain: MeshInstance3D=world.get_node(
        "AuroraTerrain/ContinuousIslandSurface")
    var mesh: ArrayMesh=terrain.mesh as ArrayMesh
    var data: Array=mesh.surface_get_arrays(0)
    var points: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
    var uv: PackedVector2Array=data[Mesh.ARRAY_TEX_UV]
    var tangents: PackedFloat32Array=data[Mesh.ARRAY_TANGENT]
    check(points.size()==(96+1)*(96+1),"terrain vertex grid changed")
    check(tangents.size()==points.size()*4,"tangents missing from world surface")
    check(uv.size()==points.size(),"terrain UV count changed")
    check(uv[1].distance_to(uv[0])>.55,"snow material stretched across entire 450m island")
    var surface: StandardMaterial3D=mesh.surface_get_material(0)
    check(surface!=null,"terrain PBR material absent")
    if surface!=null:
        check(surface.normal_enabled,"terrain normal mapping disabled")
        check(surface.normal_texture!=null,"glacial rock microtexture missing")
        if surface.normal_texture:
            check(surface.normal_texture.get_width()==64,
                "unexpected terrain normal texture memory budget")
    var quarter=world.get_node("PuertoAuroraCoastalQuarter")
    for mat in [quarter._plaster,quarter._sandstone,quarter._paving]:
        check(mat!=null and mat.normal_enabled,
            "whitewash, stone or pavement PBR detail missing")
        if mat:
            check(mat.normal_texture!=null,"coastal material normal map absent")
            if mat.normal_texture:
                check(mat.normal_texture.get_width()<=128,
                    "coastal material exceeds mobile texture budget")
    check(quarter.buildings_built==4 and quarter.accessible_entries==4,
        "real, accessible coastal houses disappeared")
    var plaza: MeshInstance3D=quarter.get_node("AuroraCobblestoneMarketPlaza")
    var plaza_mesh: ArrayMesh=plaza.mesh as ArrayMesh
    var plaza_data: Array=plaza_mesh.surface_get_arrays(0)
    check((plaza_data[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size()>0,
        "cobblestone paving has no tangent basis")

    var player=world.get_node("Operator")
    player.set_physics_process(false)
    var state: Array[String]=[]
    state.append(player._select_locomotion(0.0))
    state.append(player._select_locomotion(1.3))
    state.append(player._select_locomotion(5.5))
    state.append(player._select_locomotion(6.4))
    state.append(player._select_locomotion(5.3))
    state.append(player._select_locomotion(4.7))
    state.append(player._select_locomotion(.8))
    state.append(player._select_locomotion(.2))
    check(state==["Idle","Walk","Walk","Run","Run","Walk","Walk","Idle"],
        "Walk/Run/Idle hysteresis failed: "+str(state))
    var controller=player._animation_controller
    check(controller!=null,"skinned model/AnimationTree not loaded")
    var gait_transitions: int=0
    if controller:
        var machine: AnimationNodeStateMachine=controller.states
        for i in range(machine.get_transition_count()):
            var a: String=str(machine.get_transition_from(i))
            var b: String=str(machine.get_transition_to(i))
            if (a=="AuroraArmedWalk" and b=="AuroraArmedRun") or \
                (a=="AuroraArmedRun" and b=="AuroraArmedWalk"):
                var transition: AnimationNodeStateMachineTransition=machine.get_transition(i)
                check(transition.switch_mode==
                    AnimationNodeStateMachineTransition.SWITCH_MODE_SYNC,
                    "Walk and Run phases still reset on clip change")
                check(not transition.reset and transition.xfade_time>=.19,
                    "footstep phase or leg blending not preserved")
                gait_transitions+=1
    check(gait_transitions==2,"both walk-to-run transitions missing")
    print("V7510_MATERIAL_MOTION PASS terrain_vertices=",points.size(),
        " terrain_tangents=",tangents.size(),
        " houses=",quarter.buildings_built,
        " gait_transitions=",gait_transitions,
        " mobility_hysteresis=",state)
    quit(1 if failed else 0)
