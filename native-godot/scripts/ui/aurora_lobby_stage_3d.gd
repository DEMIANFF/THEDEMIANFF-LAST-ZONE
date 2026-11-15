extends Node3D

## All motion happens in the actual 3D hangar: no image, video, fake scene.
## The node tree is freed when the player starts a match to release VRAM.
var _radar_rotor: Node3D
var _beacon_material: StandardMaterial3D
var _lobby_time: float=0.0


func _process(delta: float) -> void:
    if delta<=0.0:
        return
    var dt: float=minf(delta,.10)
    _lobby_time+=dt
    if _radar_rotor!=null and is_instance_valid(_radar_rotor):
        _radar_rotor.rotation.y=wrapf(
            _radar_rotor.rotation.y+dt*.27,-PI,PI)
    if _beacon_material!=null:
        _beacon_material.emission_energy_multiplier=(
            .65+.55*(.5+.5*sin(_lobby_time*2.5)))

## V75.79 original interactive winter military base for the Godot lobby.
## No screenshots, trademarked game geometry or external texture downloads.
## Desktop/headless and Motorola share these low-poly mobile-safe meshes.
## The stage is owned by a SubViewport and disposed before gameplay.

func _ready() -> void:
    var asphalt: StandardMaterial3D=_material(Color(.039,.054,.094),.31,.70)
    var metal: StandardMaterial3D=_material(Color(.11,.16,.27),.55,.42)
    var steel: StandardMaterial3D=_material(Color(.065,.090,.16),.68,.34)
    var ice: StandardMaterial3D=_material(Color(.43,.66,.82),.12,.46)
    var snow: StandardMaterial3D=_material(Color(.79,.86,.96),.06,.91)
    var dark: StandardMaterial3D=_material(Color(.024,.030,.063),.44,.62)
    var neon_purple: StandardMaterial3D=_emission(Color(.62,.20,.98),2.1)
    var neon_cyan: StandardMaterial3D=_emission(Color(.12,.81,1.0),1.6)
    var neon_gold: StandardMaterial3D=_emission(Color(1.0,.63,.19),1.1)
    _beacon_material=_emission(Color(1.0,.37,.16),1.2)

    # Large low-poly original snow mountain skyline. The main 3D character
    # remains foregrounded and readable rather than standing in a bare box.
    _box("PolarPlatform",Vector3(0,-.27,-3.5),
        Vector3(25,.20,26),asphalt)
    _box("FrozenRunway",Vector3(0,-.17,-3.5),
        Vector3(17,.05,15),ice)
    for i in range(-6,7):
        var f: float=float(i)
        _peak(Vector3(f*3.1,-.13,-21.0-absf(f)*.23),
            3.7,4.3+absf(sin(f*.8))*2.6,steel,snow)
    for i in range(-4,5):
        _peak(Vector3(float(i)*4.15,-.11,-17.0-absf(float(i))*.19),
            2.25,2.25+float(i%3)*.45,metal,snow)
    # Base Aurora has a layered winter command station rather than two
    # featureless cubes: entrances, frames, windows, sloped roofing and
    # original illuminated signal/billboard elements.
    for side in [-1.0,1.0]:
        var x: float=side*5.15
        _building(x,-8.4,side,metal,steel,dark,
            neon_purple,neon_cyan,snow)
        _watchtower(side*9.0,-10.8,steel,metal,
            neon_cyan,neon_gold)
        for step in range(6):
            var z: float=2.4-float(step)*1.22
            _box("RunwayGuidance",Vector3(side*3.8,-.11,z),
                Vector3(.065,.018,.46),neon_cyan)
        for crate in range(3):
            _crate(Vector3(x+side*float(crate%2)*.75,-.02,
                -3.5-float(crate)*.74),metal,steel,neon_gold)
        _pine(side*10.5,-6.0,2.7,steel,snow)
        _pine(side*12.0,-12.5,3.5,steel,snow)

    # Radar array and small structures give depth to the original Base
    # Aurora scene. No physical collision work runs in the lobby.
    _radar(Vector3(-7.1,2.75,-8.3),steel,neon_cyan)
    _box("AuroraHangarRear",Vector3(0,.86,-12.5),
        Vector3(5.6,1.72,2.9),steel)
    _box("AuroraHangarRoof",Vector3(0,1.79,-12.5),
        Vector3(6.0,.20,3.3),metal)
    _box("AuroraHangarDoor",Vector3(0,.66,-10.97),
        Vector3(2.5,1.28,.11),dark)
    for i in range(4):
        var x: float=(float(i)-1.5)*1.25
        _box("HangarWarningLight",Vector3(x,1.72,-10.95),
            Vector3(.28,.055,.045),neon_gold)

    _box("AuroraLiveBeacon",Vector3(0,2.11,-10.82),
        Vector3(.22,.11,.16),_beacon_material)
    var practical:=OmniLight3D.new()
    practical.name="AuroraHangarPracticalLight"
    practical.position=Vector3(0,2.04,-10.8)
    practical.light_color=Color(.41,.79,1.0)
    practical.light_energy=.42
    practical.omni_range=5.0
    practical.shadow_enabled=false
    add_child(practical)

    # Brand identity uses original Aurora panel motifs, no copied logos.
    _box("AuroraBackboard",Vector3(3.45,2.35,-10.15),
        Vector3(3.1,1.45,.11),dark)
    _box("AuroraBackboardTop",Vector3(3.45,3.11,-10.06),
        Vector3(3.25,.065,.14),neon_purple)
    _box("AuroraBackboardLeft",Vector3(1.83,2.35,-10.06),
        Vector3(.055,1.55,.14),neon_cyan)
    _box("AuroraBackboardRight",Vector3(5.07,2.35,-10.06),
        Vector3(.055,1.55,.14),neon_cyan)
    for i in range(4):
        _box("AuroraEmblemBar",Vector3(3.45,
            2.25+float(i)*.17,-10.03),
            Vector3(1.7-float(i)*.26,.055,.04),
            neon_purple if i%2==0 else neon_cyan)

    # Original aurora ribbons stay in the distant sky and retain QA name.
    _ribbon(Color(.15,.95,.87,.22),6.9,-25.0,.4)
    _ribbon(Color(.70,.27,1.0,.25),7.7,-26.0,2.4)
    _ribbon(Color(.27,.47,1.0,.18),8.4,-27.0,4.6)

    # Industrial panel seams and reflected runway lights.
    for row in range(5):
        var z: float=1.3-float(row)*2.8
        _box("RunwaySeam",Vector3(0,-.125,z),
            Vector3(10,.007,.018),metal)
    for col in range(-5,6):
        _box("RunwayLightReflection",Vector3(float(col)*1.5,
            -.118,-5.7),Vector3(.15,.004,.36),
            neon_purple if col%2==0 else neon_cyan)


func _building(x: float,z: float,side: float,
        wall: Material,steel: Material,dark: Material,
        violet: Material,cyan: Material,snow: Material) -> void:
    _box("AuroraResearchStation",Vector3(x,.90,z),
        Vector3(3.65,1.84,3.0),wall)
    _box("StationBasement",Vector3(x,-.01,z),
        Vector3(3.90,.32,3.25),steel)
    _box("StationRoof",Vector3(x,1.90,z),
        Vector3(4.05,.16,3.4),steel)
    _box("StationSnowCap",Vector3(x,2.02,z),
        Vector3(4.03,.085,3.36),snow)
    _box("StationFacadeTrim",Vector3(x,1.64,z+1.53),
        Vector3(3.70,.07,.06),violet)
    _box("Entrance",Vector3(x-side*.75,.56,z+1.535),
        Vector3(.76,1.11,.08),dark)
    _box("EntranceFrame",Vector3(x-side*.75,1.15,z+1.575),
        Vector3(.91,.055,.07),cyan)
    for j in range(4):
        var nx: float=x+(float(j)-1.5)*.76
        _box("ResearchWindow",Vector3(nx,1.19,z+1.53),
            Vector3(.39,.40,.045),cyan)
        _box("ResearchWindowFrame",Vector3(nx,1.43,z+1.58),
            Vector3(.48,.04,.05),steel)
    _box("SignalBanner",Vector3(x+side*1.34,1.05,z+1.59),
        Vector3(.27,.82,.06),violet)
    for j in range(3):
        _box("RoofVent",Vector3(x+(float(j)-1.0)*.9,
            2.25,z-.6),Vector3(.30,.46,.34),steel)


func _watchtower(x: float,z: float,
        dark: Material,steel: Material,
        light: Material,amber: Material) -> void:
    for dx in [-.42,.42]:
        for dz in [-.38,.38]:
            _beam(Vector3(x+dx,0,z+dz),
                Vector3(x+dx,3.55,z+dz),.060,dark)
    for y in [.62,1.32,2.03,2.72,3.50]:
        _box("WatchtowerBeam",Vector3(x,y,z),
            Vector3(1.18,.07,1.15),steel)
    _box("WatchtowerCabin",Vector3(x,3.58,z),
        Vector3(1.35,.74,1.35),dark)
    for side in [-1.0,1.0]:
        _box("WatchtowerWindow",Vector3(x+side*.69,
            3.66,z),Vector3(.035,.36,.8),light)
    _box("WatchtowerRoof",Vector3(x,4.01,z),
        Vector3(1.48,.15,1.49),steel)
    _box("WatchtowerBeacon",Vector3(x,4.17,z),
        Vector3(.20,.18,.20),amber)


func _crate(pos: Vector3,
        material: Material,trim: Material,beacon: Material) -> void:
    _box("AuroraSupplyCrate",pos+Vector3(0,.35,0),
        Vector3(.72,.69,.72),material)
    for i in [-.26,.26]:
        _box("CrateBrace",pos+Vector3(i,.36,.37),
            Vector3(.075,.66,.04),trim)
    _box("CrateLatch",pos+Vector3(0,.48,.386),
        Vector3(.17,.07,.025),beacon)


func _pine(x: float,z: float,height: float,
        bark: Material,snow: Material) -> void:
    _beam(Vector3(x,0,z),Vector3(x,height*.85,z),.12,bark)
    for j in range(3):
        var cone:=CylinderMesh.new()
        cone.top_radius=0
        cone.bottom_radius=.72-float(j)*.16
        cone.height=height*(.50-float(j)*.065)
        cone.radial_segments=7
        var pine:=MeshInstance3D.new()
        pine.name="BaseAuroraSnowFir"
        pine.mesh=cone
        pine.material_override=snow
        pine.position=Vector3(x,height*(.35+float(j)*.20),z)
        pine.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(pine)


func _radar(origin: Vector3,dark: Material,accent: Material) -> void:
    _beam(origin-Vector3(0,2.7,0),origin,.08,dark)
    _radar_rotor=Node3D.new()
    _radar_rotor.name="AuroraRadarRotatingHead"
    _radar_rotor.position=origin
    add_child(_radar_rotor)
    var dish:=MeshInstance3D.new()
    dish.name="AuroraRadarDish"
    var mesh:=SphereMesh.new()
    mesh.radial_segments=12
    mesh.rings=6
    dish.mesh=mesh
    dish.scale=Vector3(.85,.10,.62)
    dish.position=Vector3(0,.35,0)
    dish.rotation_degrees=Vector3(-23,12,0)
    dish.material_override=dark
    dish.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _radar_rotor.add_child(dish)
    var radar_tip:=MeshInstance3D.new()
    radar_tip.name="RadarDishBeacon"
    var bulb:=BoxMesh.new()
    bulb.size=Vector3(.16,.16,.16)
    radar_tip.mesh=bulb
    radar_tip.position=Vector3(0,.42,.38)
    radar_tip.material_override=accent
    radar_tip.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _radar_rotor.add_child(radar_tip)


func _material(color: Color,metal: float,roughness: float) -> StandardMaterial3D:
    var m:=StandardMaterial3D.new()
    m.albedo_color=color
    m.metallic=metal
    m.roughness=roughness
    return m


func _emission(color: Color,energy: float) -> StandardMaterial3D:
    var m:=_material(color,.23,.28)
    m.emission_enabled=true
    m.emission=color
    m.emission_energy_multiplier=energy
    m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    return m


func _box(title: String,at: Vector3,extents: Vector3,mat: Material) -> void:
    var instance:=MeshInstance3D.new()
    instance.name=title
    var mesh:=BoxMesh.new()
    mesh.size=extents
    instance.mesh=mesh
    instance.position=at
    instance.material_override=mat
    instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(instance)


func _beam(a: Vector3,b: Vector3,r: float,mat: Material) -> void:
    var pipe:=MeshInstance3D.new()
    pipe.name="AuroraIndustrialBeam"
    var mesh:=CylinderMesh.new()
    mesh.radial_segments=7
    mesh.height=a.distance_to(b)
    mesh.top_radius=r
    mesh.bottom_radius=r
    pipe.mesh=mesh
    pipe.position=(a+b)*.5
    pipe.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
    pipe.material_override=mat
    pipe.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(pipe)


func _peak(at: Vector3,width: float,height: float,
        stone: Material,white: Material) -> void:
    _pyramid(at,width,height,stone)
    _pyramid(at+Vector3.UP*height*.70,width*.30,height*.30,white)


func _pyramid(at: Vector3,width: float,height: float,mat: Material) -> void:
    var builder:=SurfaceTool.new()
    builder.begin(Mesh.PRIMITIVE_TRIANGLES)
    var corners: Array[Vector3]=[
        Vector3(-width,0,-width),Vector3(width,0,-width),
        Vector3(width,0,width),Vector3(-width,0,width)]
    for i in range(4):
        builder.add_vertex(corners[i])
        builder.add_vertex(corners[(i+1)%4])
        builder.add_vertex(Vector3(0,height,0))
    builder.generate_normals()
    var shape:=MeshInstance3D.new()
    shape.name="AuroraSnowPeak"
    shape.mesh=builder.commit()
    shape.position=at
    shape.material_override=mat
    shape.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(shape)


func _ribbon(tint: Color,alt: float,depth: float,phase: float) -> void:
    var paint:=SurfaceTool.new()
    paint.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(32):
        var x: float=-17.0+float(i)*34.0/32.0
        var nx: float=-17.0+float(i+1)*34.0/32.0
        var y: float=alt+sin(x*.31+phase)*.75
        var ny: float=alt+sin(nx*.31+phase)*.75
        for v in [
            Vector3(x,y,depth),Vector3(nx,ny,depth),
            Vector3(x,y+.92,depth),Vector3(nx,ny,depth),
            Vector3(nx,ny+.92,depth),Vector3(x,y+.92,depth)]:
            paint.add_vertex(v)
    paint.generate_normals()
    var item:=MeshInstance3D.new()
    item.name="PolarAuroraCurtain"
    item.mesh=paint.commit()
    var mat:=StandardMaterial3D.new()
    mat.albedo_color=tint
    mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode=BaseMaterial3D.CULL_DISABLED
    mat.emission_enabled=true
    mat.emission=Color(tint.r,tint.g,tint.b)
    mat.emission_energy_multiplier=1.5
    item.material_override=mat
    item.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(item)
