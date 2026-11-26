extends Area3D
## Touchable actual 3D ammo/medkit cache. Triggered by CharacterBody3D proximity.
const WEAPONS=preload("res://scripts/combat/aurora_weapon_catalog.gd")
const WEAPON_VISUALS=preload("res://scripts/combat/weapon_visuals.gd")
const PRIVATE_GEAR=preload("res://scripts/player/aurora_private_equipment.gd")

var pickup_type: String = "ammo_ar"
var player: CharacterBody3D
var combat: Node3D
var terrain: StaticBody3D
var world_spot: Vector2=Vector2.ZERO
# A valid override is the top surface of an elevated walkable house floor.
# Exterior loot uses the terrain mesh exactly as before.
var surface_height_override: float=NAN
var collected: bool=false
# Remote presentation only: no Area3D monitoring, overlap, grant or local pickup.
var presentation_only: bool=false
# Visual identity for an actual opponent elimination reward.
var from_opponent: bool=false
# -1 means the standard world pickup amount; death caches record a real
# bounded item quantity taken from the victim's remaining inventory.
var quantity: int=-1
var _visual: Node3D
var _phase: float=0.0
var _pickup_clock: float=0.0

func _ready() -> void:
    monitoring=not presentation_only
    monitorable=not presentation_only
    collision_layer=0
    collision_mask=0 if presentation_only else 1
    var surface_y: float=surface_height_override if is_finite(surface_height_override) else         terrain.height_at(world_spot.x,world_spot.y)
    # Pod center is 0.50m above the real support surface (floor/terrain).
    # The previous 1.08m offset detached pickups from indoor floors, and
    # made loot appear misplaced from a third-person camera.
    global_position=Vector3(world_spot.x,surface_y+.50,world_spot.y)
    if not presentation_only:
        var sphere:=SphereShape3D.new()
        sphere.radius=1.65
        var shape:=CollisionShape3D.new()
        shape.name="LootPickupRange"
        shape.shape=sphere
        add_child(shape)
    else:
        set_process(false)
    _visual=Node3D.new()
    _visual.name="SupplyCacheVisual"
    add_child(_visual)
    var item:=MeshInstance3D.new()
    item.name="AuroraSupplyPod"
    if from_opponent:
        # A grounded supply crate is easier to distinguish from world
        # pickups than the old spherical, endlessly spinning death reward.
        # Its underside sits just 4 cm above the actual support surface.
        var crate:=BoxMesh.new()
        crate.size=Vector3(.90,.68,.76)
        item.mesh=crate
        item.position.y=-.12
    else:
        # A sphere is a detection collider, not a suitable game-world prop.
        # Render the actual supply as a recognizable compact gear case:
        # ammo box, medical case, armor carrier or grenades can be picked
        # up using the unchanged Area3D distance/LOS system.
        var case:=BoxMesh.new()
        case.size=Vector3(.69,.38,.46)
        if pickup_type.begins_with("backpack"):
            case.size=Vector3(.54,.72,.35)
        elif pickup_type.begins_with("vest") or pickup_type=="armor_plate":
            case.size=Vector3(.70,.52,.22)
        elif pickup_type.begins_with("helmet"):
            case.size=Vector3(.48,.36,.43)
        elif pickup_type=="grenade":
            case.size=Vector3(.31,.39,.31)
        elif pickup_type=="medkit" or pickup_type=="syringe":
            case.size=Vector3(.56,.29,.38)
        item.mesh=case
        item.position.y=-.10
    var material:=StandardMaterial3D.new()
    material.metallic=.52
    material.roughness=.31
    match pickup_type:
        "medkit": material.albedo_color=Color(.18,.79,.75)
        "syringe": material.albedo_color=Color(.44,.93,.72)
        "grenade": material.albedo_color=Color(.70,.64,.29)
        "ammo_ar": material.albedo_color=Color(.89,.66,.21)
        "cover_charge": material.albedo_color=Color(.26,.71,.97)
        "armor_plate": material.albedo_color=Color(.32,.84,.52)
        "backpack", "backpack_2", "backpack_3":
            material.albedo_color=Color(.93,.51,.23)
        "weapon_awm": material.albedo_color=Color(.98,.34,.40)
        _: material.albedo_color=Color(.56,.43,.95)
    material.emission_enabled=true
    material.emission=material.albedo_color
    material.emission_energy_multiplier=.55
    if from_opponent:
        var armor:=StandardMaterial3D.new()
        armor.albedo_color=Color(.10,.16,.20)
        armor.metallic=.25
        armor.roughness=.66
        item.material_override=armor
    else:
        item.material_override=material
    _visual.add_child(item)
    if from_opponent:
        # Two lightweight meshes share the existing type-colored accent
        # material. No extra lights, texture downloads or rigged assets.
        var band:=MeshInstance3D.new()
        band.name="OpponentCacheBand"
        var belt:=BoxMesh.new()
        belt.size=Vector3(.16,.70,.78)
        band.mesh=belt
        band.position.y=-.12
        band.material_override=material
        _visual.add_child(band)
        var lid:=MeshInstance3D.new()
        lid.name="OpponentCacheLid"
        var lid_mesh:=BoxMesh.new()
        lid_mesh.size=Vector3(.96,.075,.81)
        lid.mesh=lid_mesh
        lid.position.y=.26
        lid.material_override=item.material_override
        _visual.add_child(lid)
    var source_gear: String=""
    var source_scale: float=.48
    match pickup_type:
        "medkit":
            source_gear=PRIVATE_GEAR.MEDKIT
            source_scale=.38
        "backpack", "backpack_2", "backpack_3":
            source_gear=PRIVATE_GEAR.BACKPACK
            source_scale=.56
        "vest_1","vest_2","vest_3":
            source_gear=PRIVATE_GEAR.VEST
            source_scale=.62
        "helmet_1","helmet_2","helmet_3":
            source_gear=PRIVATE_GEAR.HELMET
            source_scale=.34
    if not source_gear.is_empty() and not from_opponent:
        var original: Node3D=PRIVATE_GEAR.mount_optional(_visual,source_gear,
            source_scale,Vector3.ZERO)
        if original:
            original.name="OriginalAuroraGearPickup"
            item.hide()
    if pickup_type=="weapon_awm":
        # Use the actual authored sniper GLB, not a decorative placeholder.
        item.visible=not _add_ground_weapon_visual()
    var slot: int=WEAPONS.pickup_slot(pickup_type)
    if slot>=0:
        var path: String=WEAPONS.ENTRIES[slot]["asset"]
        if ResourceLoader.exists(path):
            var scene:=load(path) as PackedScene
            if scene:
                var weapon:=scene.instantiate() as Node3D
                _visual.add_child(weapon)
                WEAPON_VISUALS.calibrate_expansion(weapon,slot)
                # Place the ACTUAL imported rifle on the real floor; the
                # previous arbitrary +0.12 y offset left huge source-space
                # SCAR models sideways or visually suspended above loot.
                if _seat_ground_weapon(weapon):
                    item.hide()
                else:
                    weapon.hide()
    # Original circular beacons looked like floating prototype tokens.
    # A small rectangular terrain-supported marker matches a gear case
    # and costs just twelve triangles (no radial cylinder silhouette).
    var beacon:=MeshInstance3D.new()
    beacon.name="SupplyBeacon"
    var plate:=BoxMesh.new()
    plate.size=Vector3(.84,.045,.58)
    beacon.mesh=plate
    beacon.position.y=-.41
    beacon.material_override=material
    beacon.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _visual.add_child(beacon)
    var floating_name:=Label3D.new()
    floating_name.name="SupplyLabel"
    match pickup_type:
        "medkit": floating_name.text="BOTIQUIN"
        "syringe": floating_name.text="JERINGA"
        "grenade": floating_name.text="GRANADA"
        "ammo_ar": floating_name.text="MUNICION AR"
        "cover_charge": floating_name.text="BARRERA +1"
        "armor_plate": floating_name.text="CHALECO AURORA"
        "backpack", "backpack_2", "backpack_3":
            floating_name.text="MOCHILA TÁCTICA NV. "+(
                "1" if pickup_type=="backpack" else pickup_type.get_slice("_",1))
        "weapon_awm": floating_name.text="RECOGER AWM"
        "ammo_smg": floating_name.text="MUNICIÓN SMG"
        "weapon_scar", "weapon_mp40", "weapon_kriss", "weapon_hk416", "weapon_p90", "weapon_vss", "weapon_mp5", "weapon_shotgun", "weapon_magnum", "weapon_knife", "weapon_sniper":
            floating_name.text="RECOGER "+str(WEAPONS.ENTRIES[slot]["short"])
        "ammo_shells": floating_name.text="CARTUCHOS ESCOPETA"
        "ammo_pistol": floating_name.text="MUNICIÓN PISTOLA"
        "vest_1", "vest_2", "vest_3": floating_name.text="CHALECO NV. "+pickup_type.get_slice("_",1)
        "helmet_1", "helmet_2", "helmet_3": floating_name.text="CASCO NV. "+pickup_type.get_slice("_",1)
        _: floating_name.text="MUNICION AWM"
    if from_opponent:
        floating_name.text="RIVAL / "+floating_name.text
        if quantity>0:
            floating_name.text+=" x"+str(quantity)
    floating_name.font_size=44 if pickup_type=="weapon_awm" else 38
    floating_name.pixel_size=.005
    floating_name.position.y=1.72 if pickup_type=="weapon_awm" else .94
    floating_name.modulate=Color(1,.89,.48) if pickup_type=="weapon_awm"         else Color(.85,.99,1.0)
    floating_name.no_depth_test=pickup_type=="weapon_awm"
    _visual.add_child(floating_name)
    if pickup_type=="weapon_awm":
        # Distinct amber navigation column at the real weapon pickup:
        # players can spot it among other loot from ground-level camera.
        var beam:=MeshInstance3D.new()
        beam.name="AWMWorldBeacon"
        var pillar:=CylinderMesh.new()
        pillar.top_radius=.055
        pillar.bottom_radius=.055
        pillar.height=5.4
        pillar.radial_segments=8
        beam.mesh=pillar
        beam.position.y=2.5
        var lamp:=StandardMaterial3D.new()
        lamp.albedo_color=Color(1,.68,.12,.48)
        lamp.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
        lamp.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
        lamp.emission_enabled=true
        lamp.emission=Color(1,.64,.09)
        lamp.emission_energy_multiplier=1.5
        beam.material_override=lamp
        _visual.add_child(beam)
    if not presentation_only:
        body_entered.connect(_collect)


func _add_ground_weapon_visual() -> bool:
    var path: String="res://assets/weapons/aurora_awm.glb"
    if not ResourceLoader.exists(path):
        return false
    var packed:=load(path) as PackedScene
    if packed==null:
        return false
    var rifle:=packed.instantiate() as Node3D
    rifle.name="PickupAWMModel"
    _visual.add_child(rifle)
    var lower:=Vector3(INF,INF,INF)
    var upper:=Vector3(-INF,-INF,-INF)
    for node in rifle.find_children("*","MeshInstance3D",true,false):
        var part:=node as MeshInstance3D
        var bounds: AABB=part.get_aabb()
        for corner in range(8):
            var vertex: Vector3=rifle.to_local(part.to_global(bounds.get_endpoint(corner)))
            lower=lower.min(vertex)
            upper=upper.max(vertex)
    var extent: Vector3=upper-lower
    var length: float=maxf(extent.x,maxf(extent.y,extent.z))
    if not is_finite(length) or length<.0001:
        rifle.queue_free()
        return false
    rifle.scale=Vector3.ONE*clampf(1.30/length,.0001,100.0)
    if extent.x>extent.y and extent.x>extent.z:
        rifle.rotation.y=PI*.5
    elif extent.y>extent.z:
        rifle.rotation.x=-PI*.5
    rifle.position.y=.10
    if not _seat_ground_weapon(rifle):
        rifle.queue_free()
        return false
    return true


## Recalculate the real transformed mesh AABB in pickup-local metres.
## Source GLBs have different units and axes; decorative Grip/Muzzle nodes
## are deliberately excluded from visual geometry calculations.
func _weapon_local_bounds(weapon: Node3D) -> AABB:
    var minimum:=Vector3(INF,INF,INF)
    var maximum:=Vector3(-INF,-INF,-INF)
    var count: int=0
    for element in weapon.find_children("*","MeshInstance3D",true,false):
        var mesh: MeshInstance3D=element as MeshInstance3D
        if mesh.mesh==null:
            continue
        count+=1
        var box: AABB=mesh.get_aabb()
        for corner in range(8):
            var point: Vector3=_visual.to_local(
                mesh.to_global(box.get_endpoint(corner)))
            minimum=minimum.min(point)
            maximum=maximum.max(point)
    if count==0 or not minimum.is_finite() or not maximum.is_finite():
        return AABB()
    return AABB(minimum,maximum-minimum)


## The loot collider stays centered 0.50 m above the physical support.
## Position a genuine GLB with its bottom about 7.5 cm above that support,
## and its horizontal centre inside the existing 1.65 m pickup trigger.
## This changes display transforms only, not stored weapons or animations.
func _seat_ground_weapon(weapon: Node3D) -> bool:
    var bounds: AABB=_weapon_local_bounds(weapon)
    if bounds.size.length_squared()<.0001:
        return false
    # Some imports arrive with a vertical long axis; lay the rifle along
    # the existing XZ ground plane before positioning it. No source assets
    # are overwritten, and the held gun's calibrated transform is untouched.
    var horizontal: float=maxf(bounds.size.x,bounds.size.z)
    if bounds.size.y>horizontal*1.10:
        weapon.rotate_x(PI*.5)
        bounds=_weapon_local_bounds(weapon)
    var center: Vector3=bounds.get_center()
    weapon.position+=Vector3(-center.x,-.425-bounds.position.y,-center.z)
    weapon.set_meta("aurora_ground_weapon",true)
    return true


func _process(delta: float) -> void:
    if presentation_only or collected:
        return
    _pickup_clock-=delta
    if _pickup_clock<=0:
        _pickup_clock=.3
        if global_position.distance_to(player.global_position+Vector3.UP)<1.65:
            _collect(player)
    # Collected enemy caches must look physically supported, not float or
    # rotate through the floor. Keep the old animated visual for normal
    # world pickups, whose position/collision/collection are unchanged.
    if not from_opponent and not pickup_type.begins_with("weapon_"):
        _phase+=delta
        _visual.position.y=sin(_phase*2.6)*.045
        _visual.rotation.y+=delta*.95


func _collect(body: Node3D) -> void:
    if presentation_only or collected or body!=player:
        return
    var ray:=PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP,global_position)
    ray.exclude=[player.get_rid()]
    if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
        return
    if combat.collect_sector_loot(pickup_type,quantity,from_opponent):
        collected=true
        set_deferred("monitoring",false)
        _visual.visible=false
        queue_free()
