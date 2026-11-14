extends Node3D
## Original lightweight Aurora sentinel companion for the real 3D lobby.
## All geometry is generated with Godot meshes, not third-party game assets.
## Purely visual: no fictitious owned pet, purchases or network status.
var _tail_pivot: Node3D
var _pulse: float=0.0


func _ready() -> void:
    name="AuroraSentinelCompanion"
    var alloy:=_mat(Color(.075,.093,.16),.57)
    var armor:=_mat(Color(.15,.13,.27),.46)
    var soft:=_mat(Color(.25,.25,.33),.76)
    var light:=_mat(Color(.65,.16,.95),.13,true)
    var cyan:=_mat(Color(.28,.86,1),.12,true)
    _box("BodyArmor",Vector3(0,.59,-.07),Vector3(.48,.38,.88),alloy)
    _box("BackPlating",Vector3(0,.82,-.10),Vector3(.44,.13,.68),armor)
    _box("Chest",Vector3(0,.64,.36),Vector3(.40,.46,.28),armor)
    _box("Collar",Vector3(0,.88,.38),Vector3(.50,.15,.18),light)
    _box("Head",Vector3(0,.96,.52),Vector3(.39,.32,.36),armor)
    _box("Muzzle",Vector3(0,.87,.75),Vector3(.30,.18,.30),alloy)
    _box("Nose",Vector3(0,.90,.91),Vector3(.16,.08,.06),soft)
    for side in [-1.0,1.0]:
        _box("Ear",Vector3(side*.14,1.23,.48),
            Vector3(.12,.28,.11),armor)
        _box("EarLight",Vector3(side*.14,1.25,.55),
            Vector3(.065,.14,.03),light)
        _box("Eye",Vector3(side*.115,1.01,.715),
            Vector3(.084,.052,.024),cyan)
        _box("Shoulder",Vector3(side*.27,.68,.27),
            Vector3(.16,.23,.26),armor)
        for fore in [-1.0,1.0]:
            var z: float=.28 if fore>0 else -.38
            _box("Joint",Vector3(side*.24,.49,z),
                Vector3(.16,.19,.17),light)
            _box("LegArmor",Vector3(side*.24,.26,z),
                Vector3(.15,.36,.16),alloy)
            _box("Foot",Vector3(side*.24,.085,z+.07),
                Vector3(.21,.12,.26),armor)
        _box("FlankLight",Vector3(side*.243,.70,-.12),
            Vector3(.027,.07,.48),light)
    _tail_pivot=Node3D.new()
    _tail_pivot.name="CompanionTailPivot"
    _tail_pivot.position=Vector3(0,.72,-.52)
    add_child(_tail_pivot)
    _tail_pivot.rotation_degrees.x=-20
    _tail_box("TailLink",Vector3(0,.12,-.15),
        Vector3(.12,.12,.42),armor)
    _tail_box("TailLight",Vector3(0,.22,-.32),
        Vector3(.09,.09,.12),light)
    set_process(true)


func _process(delta: float) -> void:
    _pulse=fmod(_pulse+delta,TAU*3.0)
    if _tail_pivot!=null:
        _tail_pivot.rotation.y=sin(_pulse*1.2)*.19


func _mat(tint: Color,roughness: float,emissive: bool=false) -> StandardMaterial3D:
    var material:=StandardMaterial3D.new()
    material.albedo_color=tint
    material.roughness=roughness
    material.metallic=.36
    if emissive:
        material.emission_enabled=true
        material.emission=tint
        material.emission_energy_multiplier=1.8
    return material


func _box(title: String,where: Vector3,extents: Vector3,
        material: Material) -> void:
    var item:=MeshInstance3D.new()
    item.name=title
    var box:=BoxMesh.new()
    box.size=extents
    item.mesh=box
    item.material_override=material
    item.position=where
    item.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(item)


func _tail_box(title: String,where: Vector3,extents: Vector3,
        material: Material) -> void:
    var item:=MeshInstance3D.new()
    item.name=title
    var box:=BoxMesh.new()
    box.size=extents
    item.mesh=box
    item.material_override=material
    item.position=where
    item.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _tail_pivot.add_child(item)
