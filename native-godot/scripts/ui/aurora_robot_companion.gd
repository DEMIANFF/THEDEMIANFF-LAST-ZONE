extends Node3D
## Aurora Sentinel: original lobby-only robotic companion.
## Rounded chassis, articulated silhouette and restrained cyan/violet accents.
## Static repeated details are submitted as MultiMeshes (not one draw per box).
## Does not create a pet entitlement, light source, collider or network state.

var _tail_pivot: Node3D
var _pulse: float=0.0
var _unit_box:=BoxMesh.new()
var _unit_round:=SphereMesh.new()
var _unit_joint:=CylinderMesh.new()
var _batches: Dictionary={}


func _ready() -> void:
    name="AuroraSentinelCompanion"
    _unit_box.size=Vector3.ONE
    _unit_round.radius=.5
    _unit_round.height=1.0
    _unit_round.radial_segments=12
    _unit_round.rings=6
    _unit_joint.top_radius=.5
    _unit_joint.bottom_radius=.5
    _unit_joint.height=1.0
    _unit_joint.radial_segments=10

    var alloy:=_mat(Color(.095,.13,.19),.43)
    var armor:=_mat(Color(.19,.18,.29),.52)
    var rubber:=_mat(Color(.11,.14,.19),.90)
    var violet:=_mat(Color(.35,.26,.57),.40,true,.64)
    var cyan:=_mat(Color(.25,.77,.91),.38,true,.74)

    # Continuous volumes replace the stacked toy blocks in the prior lobby.
    _part("AlloyShell",_unit_round,alloy,
        Vector3(0,.67,-.09),Vector3(.53,.43,.84))
    _part("ArmorShell",_unit_round,armor,
        Vector3(0,.80,-.16),Vector3(.48,.22,.69))
    _part("ArmorShell",_unit_round,armor,
        Vector3(0,.69,.27),Vector3(.43,.40,.29))
    for ridge in range(3):
        _part("ArmorPanels",_unit_box,armor,
            Vector3(0,.895,-.37+float(ridge)*.24),Vector3(.38,.047,.15))
    # A real three-dimensional head, muzzle, brow and softly lit visor.
    _part("ArmorShell",_unit_round,armor,
        Vector3(0,1.01,.48),Vector3(.40,.34,.37))
    _part("AlloyShell",_unit_round,alloy,
        Vector3(0,.91,.72),Vector3(.28,.20,.28))
    _part("Rubber",_unit_round,rubber,
        Vector3(0,.91,.865),Vector3(.17,.085,.065))
    _part("Cyan",_unit_box,cyan,
        Vector3(0,1.05,.674),Vector3(.275,.075,.032))
    _part("Violet",_unit_box,violet,
        Vector3(0,.91,.38),Vector3(.42,.065,.12))

    for side in [-1.0,1.0]:
        # Tapered antenna ears with a readable three-quarter profile.
        var ear_angle:=Basis(Vector3.FORWARD,side*.22)
        _part("ArmorShell",_unit_round,armor,
            Vector3(side*.158,1.255,.48),Vector3(.115,.29,.12),ear_angle)
        _part("Violet",_unit_box,violet,
            Vector3(side*.157,1.268,.558),Vector3(.043,.16,.025),ear_angle)
        _part("Cyan",_unit_round,cyan,
            Vector3(side*.125,1.075,.705),Vector3(.079,.052,.036))
        _part("ArmorShell",_unit_round,armor,
            Vector3(side*.265,.67,.23),Vector3(.21,.25,.28))
        _part("Violet",_unit_box,violet,
            Vector3(side*.259,.76,-.17),Vector3(.032,.055,.38))
        for front in [-1.0,1.0]:
            var z: float=.28 if front>0 else -.39
            # Mechanical shoulder/hip pivot, lower strut, rubber gaiter.
            _part("AlloyJoints",_unit_joint,alloy,
                Vector3(side*.255,.45,z),Vector3(.145,.175,.145))
            _part("AlloyJoints",_unit_joint,alloy,
                Vector3(side*.26,.29,z+.025),Vector3(.087,.31,.087))
            _part("Rubber",_unit_round,rubber,
                Vector3(side*.257,.22,z+.045),Vector3(.18,.17,.17))
            _part("ArmorShell",_unit_round,armor,
                Vector3(side*.26,.10,z+.095),Vector3(.22,.15,.30))
            _part("Cyan",_unit_box,cyan,
                Vector3(side*.257,.13,z+.235),Vector3(.125,.023,.022))

    # A segmented mobile tail remains separate from the static MultiMeshes.
    _tail_pivot=Node3D.new()
    _tail_pivot.name="CompanionTailPivot"
    _tail_pivot.position=Vector3(0,.76,-.49)
    _tail_pivot.rotation_degrees.x=-18
    add_child(_tail_pivot)
    _tail_piece("TailLink",_unit_joint,armor,
        Vector3(0,.115,-.20),Vector3(.105,.37,.105),
        Basis(Vector3.RIGHT,PI*.5))
    _tail_piece("TailTip",_unit_round,alloy,
        Vector3(0,.20,-.43),Vector3(.17,.17,.23))
    _tail_piece("TailLight",_unit_round,violet,
        Vector3(0,.23,-.49),Vector3(.10,.10,.095))
    _submit_batches()
    set_process(true)


func _process(delta: float) -> void:
    _pulse=fmod(_pulse+minf(delta,.1),TAU*3.0)
    if is_instance_valid(_tail_pivot):
        _tail_pivot.rotation.y=sin(_pulse*1.2)*.16


func _mat(tint: Color,roughness: float,emissive: bool=false,
        energy: float=0.0) -> StandardMaterial3D:
    var material:=StandardMaterial3D.new()
    material.albedo_color=tint
    material.roughness=roughness
    material.metallic=.38
    if emissive:
        material.emission_enabled=true
        material.emission=tint
        material.emission_energy_multiplier=energy
    return material


func _part(group: String,mesh: Mesh,material: Material,
        at: Vector3,dimensions: Vector3,rotation:=Basis.IDENTITY) -> void:
    if not _batches.has(group):
        _batches[group]={"mesh":mesh,"material":material,"poses":[]}
    var poses: Array=_batches[group]["poses"]
    poses.append(Transform3D(rotation*Basis.from_scale(dimensions),at))


func _submit_batches() -> void:
    for key in _batches:
        var data: Dictionary=_batches[key]
        var poses: Array=data["poses"]
        var instances:=MultiMesh.new()
        instances.transform_format=MultiMesh.TRANSFORM_3D
        instances.mesh=data["mesh"]
        instances.instance_count=poses.size()
        for i in range(poses.size()):
            instances.set_instance_transform(i,poses[i])
        var visual:=MultiMeshInstance3D.new()
        visual.name="Sentinel"+str(key)
        visual.multimesh=instances
        visual.material_override=data["material"]
        visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(visual)
    _batches.clear()


func _tail_piece(title: String,mesh: Mesh,material: Material,
        at: Vector3,dimensions: Vector3,rotation:=Basis.IDENTITY) -> void:
    var visual:=MeshInstance3D.new()
    visual.name=title
    visual.mesh=mesh
    visual.material_override=material
    visual.transform=Transform3D(rotation*Basis.from_scale(dimensions),at)
    visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _tail_pivot.add_child(visual)
