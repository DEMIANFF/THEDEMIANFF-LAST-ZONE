extends Node3D
## Offline native weapons training only. Real rays, ammo counts and impact bodies.
const AR_DAMAGE: int=26
const AWM_DAMAGE: int=115
const AWM_BOLT_SECONDS: float=.50

var operator: CharacterBody3D
var hud: CanvasLayer
var terrain: StaticBody3D
var weapon_index: int=0
var ammo: Array[int]=[30,5]
var reserve: Array[int]=[180,30]
var trigger_held: bool=false
var aim_active: bool=false
var cooldown: float=0.0
var reload_timer: float=0.0
var _targets: Array[StaticBody3D]=[]


func _ready() -> void:
    hud.fire_pressed.connect(_on_fire_pressed)
    hud.fire_released.connect(_on_fire_released)
    hud.aim_pressed.connect(_on_aim)
    hud.reload_pressed.connect(_on_reload)
    hud.weapon_pressed.connect(_on_weapon)
    _make_targets()
    _draw_weapon_rig()
    _sync_hud()


func _process(dt: float) -> void:
    cooldown=maxf(0,cooldown-dt)
    if reload_timer>0:
        reload_timer=maxf(0,reload_timer-dt)
        if reload_timer==0:
            var cap: int=5 if weapon_index==1 else 30
            var taken: int=mini(cap-ammo[weapon_index],reserve[weapon_index])
            ammo[weapon_index]+=taken
            reserve[weapon_index]-=taken
            hud.impact("RECARGA COMPLETADA")
            _sync_hud()
    if trigger_held and weapon_index==0 and cooldown<=0 and reload_timer<=0:
        _shoot()


func _on_fire_pressed() -> void:
    trigger_held=true
    if weapon_index==1:
        _shoot()  # One press, one bolt-action AWM round.
    elif cooldown<=0:
        _shoot()


func _on_fire_released() -> void:
    trigger_held=false


func _on_weapon() -> void:
    weapon_index=1-weapon_index
    trigger_held=false
    cooldown=.20
    reload_timer=0
    aim_active=false
    operator.set_ads(false,1.0)
    hud.set_aim(false,"MIRA LIBRE")
    _sync_hud()


func _on_aim() -> void:
    aim_active=not aim_active
    var zoom: float=8.0 if weapon_index==1 else 2.0
    operator.set_ads(aim_active,zoom)
    hud.set_aim(aim_active,"AWM / MIRA 8X" if weapon_index==1 else "AR / MIRA 2X")


func _on_reload() -> void:
    if reload_timer>0:
        return
    var cap: int=5 if weapon_index==1 else 30
    if ammo[weapon_index]>=cap or reserve[weapon_index]<=0:
        hud.impact("SIN NECESIDAD DE RECARGA")
        return
    reload_timer=3.1 if weapon_index==1 else 1.55
    hud.impact("RECARGANDO")


func _shoot() -> void:
    if cooldown>0 or reload_timer>0:
        return
    if ammo[weapon_index]<=0:
        _on_reload()
        return
    ammo[weapon_index]-=1
    cooldown=AWM_BOLT_SECONDS if weapon_index==1 else .105
    _sync_hud()
    operator.apply_recoil(.02 if weapon_index==1 else .005)
    var camera:=operator.get_node_or_null("CameraPivot/ThirdPersonCamera") as Camera3D
    if camera==null:
        return
    var from: Vector3=camera.global_position
    var direction: Vector3=-camera.global_transform.basis.z
    var query:=PhysicsRayQueryParameters3D.create(from,from+direction*250)
    query.exclude=[operator.get_rid()]
    var hit: Dictionary=operator.get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return
    var body=hit.get("collider")
    if body is StaticBody3D and body.is_in_group("training_target"):
        var hp: int=int(body.get_meta("target_hp",100))
        hp-=AWM_DAMAGE if weapon_index==1 else AR_DAMAGE
        body.set_meta("target_hp",hp)
        if hp<=0:
            hud.impact("OBJETIVO NEUTRALIZADO")
            body.set_meta("target_hp",100)
        else:
            hud.impact("IMPACTO CONFIRMADO / "+str(maxi(0,hp))+" VIDA")


func _sync_hud() -> void:
    hud.set_weapon("AWM / FRANCOTIRADOR" if weapon_index==1 else "AR-7 / ASALTO",ammo[weapon_index],reserve[weapon_index])


func _make_targets() -> void:
    var points: Array[Vector2]=[
        Vector2(0,-28),Vector2(-12,-14),Vector2(33,8),
        Vector2(-31,-47),Vector2(58,-4),Vector2(30,-58)]
    for i in range(points.size()):
        var p: Vector2=points[i]
        var dummy:=StaticBody3D.new()
        dummy.name="TrainingDummy"+str(i+1)
        dummy.add_to_group("training_target")
        dummy.position=Vector3(p.x,terrain.height_at(p.x,p.y)+.9,p.y)
        dummy.set_meta("target_hp",100)
        add_child(dummy)
        var shape:=CollisionShape3D.new()
        var capsule:=CapsuleShape3D.new()
        capsule.radius=.48
        capsule.height=1.75
        shape.shape=capsule
        dummy.add_child(shape)
        var torso:=MeshInstance3D.new()
        torso.mesh=CapsuleMesh.new()
        torso.mesh.radius=.44
        torso.mesh.height=1.65
        var material:=StandardMaterial3D.new()
        material.albedo_color=Color(.68,.39,.24)
        material.metallic=.42
        material.roughness=.48
        torso.material_override=material
        dummy.add_child(torso)
        var ring:=MeshInstance3D.new()
        ring.mesh=TorusMesh.new()
        ring.mesh.inner_radius=.22
        ring.mesh.outer_radius=.30
        ring.rotation.x=PI*.5
        ring.position=Vector3(0,.14,.43)
        var ring_material:=StandardMaterial3D.new()
        ring_material.albedo_color=Color(.82,.91,.93)
        ring.material_override=ring_material
        dummy.add_child(ring)
        _targets.append(dummy)


func _draw_weapon_rig() -> void:
    var rig:=Node3D.new()
    rig.name="VisibleTrainingRifle"
    rig.position=Vector3(.43,1.32,-.26)
    operator.add_child(rig)
    var gun_material:=StandardMaterial3D.new()
    gun_material.albedo_color=Color(.11,.16,.20)
    gun_material.metallic=.72
    gun_material.roughness=.37
    for data in [
        [Vector3(0,0,-.33),.09,.92],
        [Vector3(0,.09,-.65),.042,.84],
        [Vector3(.02,-.15,-.1),.075,.24]
    ]:
        var segment:=MeshInstance3D.new()
        var cylinder:=CylinderMesh.new()
        cylinder.top_radius=data[1]
        cylinder.bottom_radius=data[1]
        cylinder.height=data[2]
        cylinder.radial_segments=10
        segment.mesh=cylinder
        segment.rotation.x=PI*.5
        segment.position=data[0]
        segment.material_override=gun_material
        rig.add_child(segment)
    var optic:=MeshInstance3D.new()
    var optic_mesh:=CylinderMesh.new()
    optic_mesh.top_radius=.09
    optic_mesh.bottom_radius=.09
    optic_mesh.height=.31
    optic_mesh.radial_segments=14
    optic.mesh=optic_mesh
    optic.rotation.x=PI*.5
    optic.position=Vector3(0,.18,-.30)
    optic.material_override=gun_material
    rig.add_child(optic)
