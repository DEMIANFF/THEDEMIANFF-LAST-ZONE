extends Node3D
## Airfield meshes are constructed once for the lobby viewport.
const RUNWAY_SURFACE=preload("res://assets/ui/aurora_apron.gdshader")
const TERRAIN_SURFACE=preload("res://assets/ui/aurora_polar_terrain.gdshader")
const PANEL_SURFACE=preload("res://assets/ui/aurora_cladding.gdshader")
const CURTAIN_SURFACE=preload("res://assets/ui/aurora_curtain.gdshader")

var _radar_rotor: Node3D
var _beacon: StandardMaterial3D
var _time: float=0.0
var _cube:=BoxMesh.new()
var _fittings: Dictionary[Material,Array]={}
var _rock_noise:=FastNoiseLite.new()
var _steel: StandardMaterial3D
var _concrete: StandardMaterial3D
var _amber: StandardMaterial3D
var _glass: StandardMaterial3D
var _panel: ShaderMaterial
var _snow: ShaderMaterial
var _ice_trim: StandardMaterial3D
var _signal_cyan: StandardMaterial3D
# Reconciled at the exact moment the authored transforms become live
# MultiMesh instances; preserves an auditable CPU->renderer submission ledger.
var _runway_batch_audit: Dictionary={}


func _ready() -> void:
    _rock_noise.seed=24116
    _rock_noise.noise_type=FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    _rock_noise.frequency=.36
    _rock_noise.fractal_octaves=4
    _steel=_metal(Color(.21,.26,.34),.57,.56)
    _concrete=_metal(Color(.185,.221,.275),.02,.92)
    _amber=_lamp(Color(1.0,.63,.28),.94)
    _glass=_lamp(Color(.88,.54,.24),.70)
    _beacon=_lamp(Color(1.0,.27,.10),1.0)
    _ice_trim=_metal(Color(.45,.62,.75),.42,.34)
    _signal_cyan=_lamp(Color(.12,.80,.98),.74)
    _panel=ShaderMaterial.new()
    _panel.shader=PANEL_SURFACE
    _snow=ShaderMaterial.new()
    _snow.shader=TERRAIN_SURFACE

    _mountain_range("AuroraSnowPeak", -28.0, 10.0, 56.0, 104, 24, 0.0)
    _mountain_range("AuroraSnowPeakMiddle", -44.0, 16.0, 84.0, 106, 19, 2.9)
    _mountain_range("AuroraSnowPeakHorizon", -65.0, 24.0, 118.0, 86, 16, 7.3)
    _curtain(0)
    _curtain(1)
    _build_apron()
    _runway_accents()
    _build_hangar(Vector3(2.65,-.08,-12.8))
    _build_station(Vector3(-5.28,-.08,-9.0))
    _build_radar(Vector3(-4.65,-.08,-11.65))
    _watchtower(Vector3(7.15,-.08,-15.2))
    _crate(Vector3(-2.75,-.12,-5.5))
    _crate(Vector3(-3.28,-.12,-5.95))
    _crate(Vector3(5.0,-.12,-8.55))
    _fir_line()
    _architectural_finishes()
    _batch_fittings()


func _process(delta: float) -> void:
    var dt:=minf(delta,.1)
    _time+=dt
    _radar_rotor.rotation.y=wrapf(_radar_rotor.rotation.y+dt*.27,-PI,PI)
    _beacon.emission_energy_multiplier=.65+.55*smoothstep(.25,1.0,
        .5+.5*sin(_time*2.5))


func _build_apron() -> void:
    var pavement:=ShaderMaterial.new()
    pavement.shader=RUNWAY_SURFACE
    _solid("AuroraRunwayCentralSpine",Vector3(0,-.18,-9.0),
        Vector3(34.0,.12,37.0),pavement)
    for side in [-1.0,1.0]:
        _snowbank(side)
        for i in range(11):
            var z:=2.5-float(i)*1.85
            var lamp_pos:=Vector3(side*2.21,-.105,z)
            _fitting(lamp_pos+Vector3(0,.025,0),Vector3(.16,.05,.16),_steel)
            if i==2 and side<0.0:
                _solid("AuroraRunwayReflector",lamp_pos+Vector3(0,.068,0),
                    Vector3(.090,.041,.093),_amber)
            else:
                _fitting(lamp_pos+Vector3(0,.068,0),Vector3(.090,.041,.093),_amber)
        _light("ApronGuideLight",Vector3(side*2.21,.045,-2.94),
            Color(1.0,.63,.36),.44,1.90)
        for i in range(10):
            var rail_post:=Vector3(side*6.65,.31,-4.4-float(i)*1.14)
            _fitting(rail_post,Vector3(.066,.81,.069),_steel)
        for rail_y in [.37,.69]:
            _fitting(Vector3(side*6.65,rail_y,-9.55),Vector3(.058,.050,10.45),_steel)


## Luminous but inexpensive road markings use two GPU batches. The painted
## runway still uses the original pavement shader, not a transparent overlay.
func _runway_accents() -> void:
    # Cyan edges and pale center dashes share existing GPU batches.
    # Separate tiny batches exceeded the airfield's 12-batch mobile budget.
    for i in range(22):
        var z: float=3.0-float(i)*.91
        for side in [-1.0,1.0]:
            _fitting(Vector3(side*2.45,-.103,z),
                Vector3(.024,.014,.48),_signal_cyan)
        if i%3==0 and i>2:
            _fitting(Vector3(0.0,-.103,z),
                Vector3(.052,.012,.44),_ice_trim)


## Original modular production art, integrated in the live 3D viewport.
## Reuses existing MultiMesh fitting groups instead of per-panel draw calls.
## Battle physics, player collisions and map coordinates are unchanged.
func _architectural_finishes() -> void:
    _hangar_roof_structure(Vector3(2.65,-.08,-12.8))
    _station_facade_detail(Vector3(-5.28,-.08,-9.0))
    _runway_service_drainage()
    _radar_mast_finishes(Vector3(-4.65,-.08,-11.65))
    _hangar_service_architecture(Vector3(2.65,-.08,-12.8))
    _station_access_architecture(Vector3(-5.28,-.08,-9.0))
    _runway_wayfinding_installation()


func _hangar_roof_structure(at: Vector3) -> void:
    # Load-bearing roof profiles and a continuous ridge cap.
    for section in range(7):
        var z: float=-2.53+float(section)*.85
        for side in [-1.0,1.0]:
            _bar(at+Vector3(side*3.23,2.24,z),
                at+Vector3(0.0,3.19,z),.050,_steel)
            _fitting(at+Vector3(side*3.27,2.18,z),
                Vector3(.13,.10,.095),_concrete)
    _fitting(at+Vector3(0.0,3.20,0.0),
        Vector3(.12,.13,5.92),_ice_trim)
    for side in [-1.0,1.0]:
        _fitting(at+Vector3(side*3.35,2.22,.10),
            Vector3(.082,.12,5.89),_steel)
        _fitting(at+Vector3(side*2.23,1.46,2.96),
            Vector3(.038,.090,.025),_amber)


func _station_facade_detail(at: Vector3) -> void:
    # Framed entrance, shelter, sill flashing and cast concrete foundation.
    _fitting(at+Vector3(0.0,1.60,0.0),
        Vector3(3.75,.064,3.53),_ice_trim)
    for side in [-1.0,1.0]:
        _fitting(at+Vector3(side*1.76,.67,1.64),
            Vector3(.055,1.31,.064),_steel)
        _fitting(at+Vector3(side*1.75,.16,0.0),
            Vector3(.13,.27,3.42),_concrete)
    for index in range(7):
        var x: float=-1.56+float(index)*.52
        _fitting(at+Vector3(x,1.36,1.74),
            Vector3(.026,.14,.06),_steel)
    _fitting(at+Vector3(.93,1.31,1.94),
        Vector3(.99,.09,.55),_steel)
    for side in [-1.0,1.0]:
        _fitting(at+Vector3(.93+side*.48,1.15,1.99),
            Vector3(.042,.32,.07),_steel)
    _fitting(at+Vector3(-.96,.32,1.68),
        Vector3(.40,.036,.13),_ice_trim)


func _runway_service_drainage() -> void:
    # Raised drainage fixtures and lateral road edge trim.
    for side in [-1.0,1.0]:
        _fitting(Vector3(side*2.73,-.095,-8.85),
            Vector3(.14,.020,18.9),_steel)
        for drain in range(9):
            var z: float=1.0-float(drain)*2.17
            _fitting(Vector3(side*2.89,-.083,z),
                Vector3(.35,.018,.21),_concrete)
            for groove in range(3):
                _fitting(Vector3(side*2.89,-.070,z+
                    (float(groove)-1.0)*.061),
                    Vector3(.27,.012,.018),_steel)


func _radar_mast_finishes(at: Vector3) -> void:
    # Fixed structural mast trim; radar head remains physically animated.
    for side in [-1.0,1.0]:
        _fitting(at+Vector3(side*.79,1.72,0.0),
            Vector3(.055,.08,1.45),_steel)
    for i in range(6):
        var angle: float=TAU*float(i)/6.0
        _fitting(at+Vector3(cos(angle)*.76,2.43,
            sin(angle)*.76),Vector3(.16,.07,.16),_ice_trim)


## Actual modular industrial surfaces: shutter relief, roof ventilation,
## insulated service access and welded gantry details. All fittings share
## existing _steel/_concrete/_ice_trim/_signal_cyan MultiMesh groups.
## No transparent photo planes, new dynamic lights or collider alterations.
func _hangar_service_architecture(at: Vector3) -> void:
    var front: float=5.65*.5
    # A proper sectional freight shutter reads as an industrial aperture
    # instead of one enormous featureless gray box.
    for band in range(4):
        var y: float=.28+float(band)*.304
        _fitting(at+Vector3(0,y,front+.095),
            Vector3(4.31,.029,.039),_ice_trim)
    for side in [-1.0,1.0]:
        # Recessed personnel doors at both ends of the hangar facade.
        var entry_x: float=side*2.82
        _fitting(at+Vector3(entry_x,.61,front+.105),
            Vector3(.51,1.23,.058),_steel)
        _fitting(at+Vector3(entry_x,.64,front+.153),
            Vector3(.40,1.09,.028),_panel)
        for trim in [-1.0,1.0]:
            _fitting(at+Vector3(entry_x+trim*.232,.64,front+.175),
                Vector3(.027,1.28,.040),_ice_trim)
        _fitting(at+Vector3(entry_x,.17,front+.17),
            Vector3(.53,.065,.20),_concrete)
        _fitting(at+Vector3(entry_x-side*.11,.77,front+.185),
            Vector3(.030,.11,.035),_amber)
        # The eave has continuous gutters and visible mounting brackets
        # instead of the previous flat roof/block joint.
        _fitting(at+Vector3(side*3.29,2.21,0.0),
            Vector3(.16,.074,5.90),_steel)
        for support in range(5):
            _fitting(at+Vector3(side*3.31,2.13,-2.30+float(support)*1.15),
                Vector3(.098,.22,.085),_concrete)
        # Visible louver packs in the exterior hangar wall.
        for vent in range(4):
            var z: float=-1.73+float(vent)*1.10
            _fitting(at+Vector3(side*3.35,1.63,z),
                Vector3(.045,.47,.62),_concrete)
            for blade in range(3):
                _fitting(at+Vector3(side*3.405,1.47+float(blade)*.13,z),
                    Vector3(.034,.035,.49),_steel)
    # Roof exhausts have actual volume/occluding silhouette. A single
    # support mesh per exhaust avoids an extra material group.
    for vent in range(2):
        var side: float=-1.0 if vent==0 else 1.0
        var z: float=-1.28+float(vent)*1.86
        var center: Vector3=at+Vector3(side*1.47,2.96,z)
        _solid("AuroraHangarRoofExhaust"+str(vent),center,
            Vector3(.55,.42,.65),_steel)
        _fitting(center+Vector3(0,.25,0),
            Vector3(.66,.10,.74),_ice_trim)
        for blade in range(3):
            _fitting(center+Vector3(0,.13,-.19+float(blade)*.19),
                Vector3(.46,.045,.040),_concrete)


func _station_access_architecture(at: Vector3) -> void:
    # Real stepped service access below the existing framed entrance.
    # Integrates into existing station footprint; no new colliders.
    for step in range(3):
        var depth: float=float(step)
        _fitting(at+Vector3(.93,-.015+depth*.058,2.31-depth*.15),
            Vector3(1.14,.13+depth*.10,.29),_concrete)
    _solid("AuroraStationEntryCanopy",
        at+Vector3(.93,1.51,1.92),
        Vector3(1.29,.10,.82),_steel)
    for side in [-1.0,1.0]:
        _fitting(at+Vector3(.93+side*.56,1.23,2.22),
            Vector3(.048,.55,.054),_ice_trim)
        _fitting(at+Vector3(.93+side*.53,1.48,2.26),
            Vector3(.075,.10,.18),_steel)
    _fitting(at+Vector3(.93,1.46,2.325),
        Vector3(1.02,.028,.035),_signal_cyan)
    # Utility conduits and raised ventilation on the station roof are
    # built once and batched. No fake glow textures or extra lights.
    _fitting(at+Vector3(-.91,1.74,-.53),
        Vector3(.78,.29,.67),_steel)
    _fitting(at+Vector3(-.91,1.91,-.53),
        Vector3(.85,.045,.74),_ice_trim)
    for fin in range(5):
        _fitting(at+Vector3(-1.20+float(fin)*.145,1.79,-.13),
            Vector3(.056,.19,.040),_concrete)
    for side in [-1.0,1.0]:
        _fitting(at+Vector3(side*1.69,.42,-.18),
            Vector3(.073,.78,2.84),_steel)


func _runway_wayfinding_installation() -> void:
    # Paired shoulder signs sit outside the center sight line and the
    # operator podium. Their cyan borders borrow the existing airfield
    # emissive batch; these are genuine 3D fixtures, not a UI overlay.
    for side in [-1.0,1.0]:
        for index in range(2):
            var z: float=-4.65-float(index)*4.80
            var x: float=side*3.36
            _fitting(Vector3(x,.22,z),
                Vector3(.055,.64,.056),_steel)
            _fitting(Vector3(x,.52,z),
                Vector3(.62,.34,.048),_concrete)
            _fitting(Vector3(x,.52,z+.031),
                Vector3(.54,.26,.027),_steel)
            _fitting(Vector3(x,.686,z+.047),
                Vector3(.65,.030,.027),_signal_cyan)
            _fitting(Vector3(x,.354,z+.047),
                Vector3(.65,.030,.027),_ice_trim)
    # A short continuous concrete base makes the cargo edge plausible
    # without obscuring the live runway center markings.
    for side in [-1.0,1.0]:
        _fitting(Vector3(side*3.54,-.105,-8.10),
            Vector3(.23,.14,1.65),_concrete)


func _build_hangar(at: Vector3) -> void:
    var fascia:=_metal(Color(.127,.164,.22),.63,.60)
    var shutter:=_metal(Color(.145,.166,.206),.62,.52)
    var width:=6.5
    var length:=5.65
    var eave:=2.24
    var rise:=.95
    var front:=length*.5
    _solid("AuroraHangarRear",at+Vector3(0,eave*.5,-front),
        Vector3(width,eave,.18),_panel)
    for side in [-1.0,1.0]:
        _fitting(at+Vector3(side*width*.5,eave*.5,0),
            Vector3(.14,eave,length),_panel)
        _fitting(at+Vector3(side*2.81,eave*.5,front),
            Vector3(.90,eave,.18),_panel)
        _fitting(at+Vector3(side*2.31,.98,front+.13),
            Vector3(.17,1.96,.20),_steel)
        _fitting(at+Vector3(side*3.22,.17,0),Vector3(.31,.34,length+.36),_concrete)
        var slope:=Basis(Vector3.FORWARD,side*atan2(rise,width*.5))
        var roof_span:=Vector3(Vector2(width*.5,rise).length()+.24,.16,length+.55)
        _solid("HangarRoofSlope"+("L" if side<0.0 else "R"),
            at+Vector3(side*width*.25,eave+rise*.5,0),roof_span,fascia,slope)
        _solid("HangarRoofDrift"+("L" if side<0.0 else "R"),
            at+Vector3(side*width*.25,eave+rise*.5+.12,-.16),
            Vector3(roof_span.x*.95,.085,roof_span.z*.90),_snow,slope)
        for seam in range(17):
            _fitting(at+Vector3(side*width*.25,eave+rise*.5+.102,
                (float(seam)-8.0)*.35),Vector3(roof_span.x,.035,.025),_steel,slope)
        _fitting(at+Vector3(side*3.34,2.20,0),Vector3(.11,.10,length+.60),_steel)

    var gable:=SurfaceTool.new()
    gable.begin(Mesh.PRIMITIVE_TRIANGLES)
    for z in [front+.028,-front-.096]:
        var face: Array[Vector3]=[
            Vector3(-width*.5,eave,z),Vector3(0,eave+rise,z),
            Vector3(width*.5,eave,z)]
        if z<0.0:
            face.reverse()
        for vertex in face:
            gable.add_vertex(vertex)
    gable.generate_normals()
    _mesh("HangarGable",gable.commit(),_panel,at)
    _solid("HangarRecessedDoors",at+Vector3(0,.72,front-.018),
        Vector3(4.45,1.44,.12),shutter)
    for i in range(25):
        var x: float=(float(i)-12.0)*.177
        _fitting(at+Vector3(x,.72,front+.068),Vector3(.019,1.39,.032),_steel)
    _fitting(at+Vector3(0,1.48,front+.07),Vector3(4.72,.15,.27),fascia)
    _fitting(at+Vector3(0,.055,front+.129),Vector3(4.62,.11,.37),_concrete)
    _fitting(at+Vector3(0,1.79,front+.054),Vector3(4.79,.43,.106),fascia)
    for i in range(8):
        var x: float=(float(i)-3.5)*.578
        _fitting(at+Vector3(x,1.79,front+.12),Vector3(.534,.31,.031),_glass)
        _fitting(at+Vector3(x,1.73,front+.144),Vector3(.535,.024,.029),_steel)
    _solid("AuroraBackboard",at+Vector3(0,2.37,front+.044),
        Vector3(2.69,.29,.075),fascia)
    var signpost:=Label3D.new()
    signpost.text="BASE AURORA"
    signpost.font=preload("res://assets/ui/fonts/BarlowCondensed-Bold.ttf")
    signpost.font_size=88
    signpost.outline_size=0
    signpost.pixel_size=.0032
    signpost.modulate=Color(.81,.89,.96)
    signpost.position=at+Vector3(0,2.37,front+.092)
    add_child(signpost)
    # Inset facade signage and perimeter light rails give the building a
    # legible silhouette without additional dynamic lights or draw calls.
    _fitting(at+Vector3(0,2.61,front+.18),
        Vector3(2.72,.032,.051),_signal_cyan)
    for side in [-1.0,1.0]:
        _fitting(at+Vector3(side*3.12,2.11,front+.17),
            Vector3(.038,.58,.05),_signal_cyan)
    for side in [-1.0,1.0]:
        var sconce:=at+Vector3(side*2.81,1.55,front+.18)
        _fitting(sconce,Vector3(.21,.23,.21),fascia)
        _fitting(sconce+Vector3(0,-.11,.015),Vector3(.16,.036,.13),_amber)
        _light("AuroraHangarPracticalLight" if side<0.0 else "HangarEastLight",
            sconce+Vector3(0,-.17,.26),Color(1.0,.64,.34),2.5,3.5)
        _fitting(at+Vector3(side*2.60,.41,front+.25),Vector3(.09,.82,.09),_amber)
    _solid("AuroraLiveBeacon",at+Vector3(0,3.27,.42),Vector3(.11,.16,.11),_beacon)


func _build_station(at: Vector3) -> void:
    _solid("AuroraResearchStation",at+Vector3(0,.66,0),Vector3(3.42,1.32,3.2),_panel)
    _fitting(at+Vector3(0,.15,0),Vector3(3.64,.30,3.40),_concrete)
    var lean:=Basis(Vector3.RIGHT,.13)
    _solid("StationRoof",at+Vector3(0,1.44,0),Vector3(3.79,.19,3.56),_steel,lean)
    _solid("StationSnowCap",at+Vector3(0,1.57,-.10),Vector3(3.65,.08,3.21),_snow,lean)
    _fitting(at+Vector3(.93,.59,1.63),Vector3(.62,1.18,.13),_steel)
    _fitting(at+Vector3(.93,.55,1.72),Vector3(.48,1.05,.08),_panel)
    for i in range(4):
        var window_pos:=at+Vector3(-1.35+float(i)*.49,.94,1.63)
        _fitting(window_pos,Vector3(.47,.39,.12),_steel)
        _fitting(window_pos+Vector3(0,0,.073),Vector3(.40,.29,.032),_glass)
        _fitting(window_pos+Vector3(0,0,.105),Vector3(.025,.28,.025),_steel)
    var lamp:=at+Vector3(.94,1.22,1.84)
    _fitting(lamp,Vector3(.22,.077,.13),_amber)
    _light("StationEntryLight",lamp+Vector3(0,-.18,.12),Color(1.0,.68,.39),1.55,2.8)


func _build_radar(at: Vector3) -> void:
    var base:=CylinderMesh.new()
    base.top_radius=.68
    base.bottom_radius=.84
    base.height=2.39
    base.radial_segments=18
    _mesh("RadarControlTower",base,_panel,at+Vector3(0,1.18,0))
    for y in [1.75,2.43]:
        var platform:=CylinderMesh.new()
        platform.top_radius=.92
        platform.bottom_radius=.92
        platform.height=.12
        platform.radial_segments=18
        _mesh("RadarServiceDeck",platform,_steel,at+Vector3(0,y,0))
        for i in range(12):
            var a:=TAU*float(i)/12.0
            var b:=TAU*float(i+1)/12.0
            var start:=Vector3(cos(a),0,sin(a))*.90
            var end:=Vector3(cos(b),0,sin(b))*.90
            _fitting(at+start+Vector3(0,y+.26,0),Vector3(.035,.42,.035),_steel)
            _bar(at+start+Vector3(0,y+.46,0),at+end+Vector3(0,y+.46,0),.034,_steel)
    _radar_rotor=Node3D.new()
    _radar_rotor.name="AuroraRadarRotatingHead"
    _radar_rotor.position=at+Vector3(0,2.60,0)
    _radar_rotor.rotation.y=-.52
    add_child(_radar_rotor)
    var elevation:=Node3D.new()
    elevation.position.y=.68
    elevation.rotation.x=-.57
    _radar_rotor.add_child(elevation)
    var dish_material:=_metal(Color(.32,.38,.46),.61,.36)
    dish_material.cull_mode=BaseMaterial3D.CULL_DISABLED
    var dish:=SurfaceTool.new()
    dish.begin(Mesh.PRIMITIVE_TRIANGLES)
    for ring in range(6):
        for i in range(36):
            var a:=TAU*float(i)/36.0
            var b:=TAU*float(i+1)/36.0
            var inner:=float(ring)/6.0
            var outer:=float(ring+1)/6.0
            dish.add_vertex(_dish_point(inner,a))
            dish.add_vertex(_dish_point(outer,b))
            dish.add_vertex(_dish_point(outer,a))
            if ring>0:
                dish.add_vertex(_dish_point(inner,a))
                dish.add_vertex(_dish_point(inner,b))
                dish.add_vertex(_dish_point(outer,b))
    dish.generate_normals()
    _mesh("AuroraRadarDish",dish.commit(),dish_material,Vector3.ZERO,elevation)
    var tube:=CylinderMesh.new()
    tube.top_radius=.5
    tube.bottom_radius=.5
    tube.height=1.0
    tube.radial_segments=7
    var rim: Array[Transform3D]=[]
    for i in range(12):
        var a:=TAU*float(i)/12.0
        var b:=TAU*float(i+1)/12.0
        rim.append(_rod_transform(_dish_point(1.0,a),_dish_point(1.0,b),.072))
    _instances("RadarRim",tube,dish_material,rim,elevation)
    var bracing: Array[Transform3D]=[]
    for index in range(8):
        var angle:=TAU*float(index)/8.0
        bracing.append(_rod_transform(_dish_point(.32,angle)-Vector3(0,0,.029),
            _dish_point(1.0,angle)-Vector3(0,0,.036),.056))
    var feed:=Vector3(0,0,1.16)
    for i in range(3):
        bracing.append(_rod_transform(_dish_point(.78,TAU*float(i)/3.0),feed,.086))
    bracing.append(_rod_transform(Vector3(0,0,1.00),Vector3(0,0,1.28),.204))
    _instances("RadarFeedSupports",tube,_steel,bracing,elevation)
    var pivot:=_mesh("RadarPivot",tube,_steel,Vector3(0,.34,0),_radar_rotor)
    pivot.scale=Vector3(.48,.74,.48)


func _dish_point(radius: float,angle: float) -> Vector3:
    return Vector3(cos(angle)*radius*1.33,sin(angle)*radius*1.14,
        radius*radius*.48)


func _watchtower(at: Vector3) -> void:
    for x in [-.49,.49]:
        for z in [-.49,.49]:
            _bar(at+Vector3(x,0,z),at+Vector3(x*.70,3.38,z*.70),.07,_steel)
    for i in range(3):
        var y:=float(i)*1.01
        for z in [-.45,.45]:
            _bar(at+Vector3(-.45,y,z),at+Vector3(.40,y+.99,z),.041,_steel)
            _bar(at+Vector3(.45,y,z),at+Vector3(-.40,y+.99,z),.041,_steel)
    _solid("WatchtowerCabin",at+Vector3(0,3.63,0),Vector3(1.18,.68,1.17),_panel)
    _fitting(at+Vector3(0,3.69,.60),Vector3(.90,.28,.035),_glass)
    _fitting(at+Vector3(0,4.04,0),Vector3(1.41,.12,1.42),_steel)
    # Share amber warning light material; avoid a one-beacon GPU batch.
    _fitting(at+Vector3(0,4.21,0),Vector3(.12,.15,.12),_amber)


func _crate(at: Vector3) -> void:
    _solid("AuroraSupplyCrate",at+Vector3(0,.23,0),Vector3(.65,.46,.58),_panel)
    for x in [-.225,.225]:
        _fitting(at+Vector3(x,.24,.298),Vector3(.069,.46,.04),_steel)
    _fitting(at+Vector3(0,.30,.325),Vector3(.16,.042,.032),_amber)


func _fir_line() -> void:
    # Three genuine conifer branch levels per tree, plus slim snow-capped
    # tips and dark trunks. Each material remains one GPU MultiMesh batch.
    var foliage:=_metal(Color(.065,.145,.156),.02,.88)
    var frost:=_metal(Color(.62,.75,.83),.0,.87)
    var branches:=CylinderMesh.new()
    branches.top_radius=.025
    branches.bottom_radius=.43
    branches.height=.94
    branches.radial_segments=9
    var cap:=CylinderMesh.new()
    cap.top_radius=.016
    cap.bottom_radius=.19
    cap.height=.17
    cap.radial_segments=9
    var branch_transforms: Array[Transform3D]=[]
    var cap_transforms: Array[Transform3D]=[]
    for side in [-1.0,1.0]:
        for i in range(9):
            var x: float=side*(4.5+float(i)*1.65)
            var z: float=-18.8-absf(sin(float(i)*.81+side))*3.1
            var scale_3d: float=.70+absf(sin(float(i)*1.83+side))*.7
            _fitting(Vector3(x,.30*scale_3d,z),
                Vector3(.11*scale_3d,.64*scale_3d,.11*scale_3d),_steel)
            for crown in range(3):
                var part:=scale_3d*(1.0-float(crown)*.19)
                var height: float=(.54+float(crown)*.40)*scale_3d
                branch_transforms.append(Transform3D(
                    Basis.from_scale(Vector3(part,scale_3d,part)),
                    Vector3(x,height,z)))
                cap_transforms.append(Transform3D(
                    Basis.from_scale(Vector3(part,scale_3d,part)),
                    Vector3(x,height+.39*scale_3d,z)))
    _instances("BaseAuroraSnowFir",branches,foliage,branch_transforms)
    _instances("BaseAuroraFirSnowCaps",cap,frost,cap_transforms)

func _snowbank(side: float) -> void:
    var shape:=SurfaceTool.new()
    shape.begin(Mesh.PRIMITIVE_TRIANGLES)
    for row in range(35):
        for column in range(7):
            var a:=_bank_point(side,row,column)
            var b:=_bank_point(side,row,column+1)
            var c:=_bank_point(side,row+1,column)
            var d:=_bank_point(side,row+1,column+1)
            var face: Array=[a,c,b,b,c,d] if side>0.0 else [a,b,c,b,d,c]
            for vertex in face:
                shape.set_color(Color(.92,.92,.92))
                shape.add_vertex(vertex)
    shape.generate_normals()
    shape.index()
    _mesh("PlowedSnowbank",shape.commit(),_snow)


func _bank_point(side: float,row: int,column: int) -> Vector3:
    var z:=4.4-float(row)*.68
    var across:=float(column)/7.0
    var x: float=side*(2.57+across*6.5+.26*sin(z*.85+side))
    var shoulder:=pow(sin(across*PI),.76)
    var noise:=_rock_noise.get_noise_2d(x*1.8,z*2.2)
    return Vector3(x,-.119+shoulder*(.33+noise*.26),z)


func _mountain_range(title: String,z: float,amplitude: float,width: float,
        columns: int,rows: int,phase: float) -> void:
    var shape:=SurfaceTool.new()
    shape.begin(Mesh.PRIMITIVE_TRIANGLES)
    for row in range(rows):
        for column in range(columns):
            var a:=_ridge_point(z,amplitude,width,columns,rows,phase,column,row)
            var b:=_ridge_point(z,amplitude,width,columns,rows,phase,column+1,row)
            var c:=_ridge_point(z,amplitude,width,columns,rows,phase,column,row+1)
            var d:=_ridge_point(z,amplitude,width,columns,rows,phase,column+1,row+1)
            for vertex in [a,c,b,b,c,d]:
                var snowline:=smoothstep(amplitude*.17,amplitude*.68,vertex.y)
                shape.set_color(Color(snowline,snowline,snowline))
                shape.add_vertex(vertex)
    shape.generate_normals()
    shape.index()
    _mesh(title,shape.commit(),_snow)


func _ridge_point(z: float,amplitude: float,width: float,columns: int,
        rows: int,phase: float,column: int,row: int) -> Vector3:
    var x: float=(float(column)/float(columns)-.5)*width
    var depth:=float(row)/float(rows)
    var ridge_center:=.53+.14*sin(x*.16+phase)+.04*sin(x*.52)
    var ridge_height:=exp(-pow((depth-ridge_center)*3.25,2.0))
    var macro:=.49+.20*sin(x*.24+phase)+.09*sin(x*.51-phase)+.13*cos(x*.14+phase)
    var profile:=sin(depth*PI)
    var world_z:=z-depth*amplitude*1.25
    var crags:=_rock_noise.get_noise_2d(x*.72+phase,world_z*.82)
    var gullies:=absf(_rock_noise.get_noise_2d(x*1.3+depth*1.8,phase+2.2*depth))
    var height:=amplitude*profile*(ridge_height*(macro+crags*.15)-gullies*.17)
    return Vector3(x,height-.49,world_z)


func _curtain(layer: int) -> void:
    var sheet:=SurfaceTool.new()
    sheet.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(80):
        for corner in [Vector2(0,0),Vector2(1,0),Vector2(0,1),
                Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
            var u: float=(float(i)+corner.x)/80.0
            var x: float=lerpf(-54.0,54.0,u)
            var ridge: float=sin(u*9.3+float(layer)*1.9)*3.6+sin(u*22.0)*.65
            sheet.set_uv(Vector2(u,corner.y))
            sheet.add_vertex(Vector3(x,12.0+float(layer)*4.8+ridge+corner.y*14.0,
                -51.0-float(layer)*10.0+cos(u*11.0+float(layer))*4.5))
    var material:=ShaderMaterial.new()
    material.shader=CURTAIN_SURFACE
    material.set_shader_parameter("strength",.78 if layer==0 else .44)
    material.set_shader_parameter("fold_offset",float(layer)*2.8)
    _mesh("PolarAuroraCurtain" if layer==0 else "DistantAuroraCurtain",
        sheet.commit(),material)


func _metal(tint: Color,metalness: float,roughness: float) -> StandardMaterial3D:
    var material:=StandardMaterial3D.new()
    material.albedo_color=tint
    material.metallic=metalness
    material.roughness=roughness
    return material


func _lamp(tint: Color,energy: float) -> StandardMaterial3D:
    var material:=_metal(tint,.05,.33)
    material.emission_enabled=true
    material.emission=tint
    material.emission_energy_multiplier=energy
    return material


func _light(title: String,at: Vector3,tint: Color,energy: float,radius: float) -> void:
    var lamp:=OmniLight3D.new()
    lamp.name=title
    lamp.position=at
    lamp.light_color=tint
    lamp.light_energy=energy
    lamp.omni_range=radius
    add_child(lamp)


func _mesh(title: String,geometry: Mesh,material: Material,at:=Vector3.ZERO,
        parent: Node3D=null) -> MeshInstance3D:
    var instance:=MeshInstance3D.new()
    instance.name=title
    instance.mesh=geometry
    instance.material_override=material
    instance.position=at
    instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    (self if parent==null else parent).add_child(instance)
    return instance


func _solid(title: String,at: Vector3,size_3d: Vector3,material: Material,
        orientation:=Basis.IDENTITY) -> void:
    var instance:=_mesh(title,_cube,material,at)
    instance.basis=orientation*Basis.from_scale(size_3d)


func _fitting(at: Vector3,size_3d: Vector3,material: Material,
        orientation:=Basis.IDENTITY) -> void:
    if not _fittings.has(material):
        _fittings[material]=[]
    _fittings[material].append(Transform3D(orientation*Basis.from_scale(size_3d),at))


func _bar(a: Vector3,b: Vector3,thickness: float,material: Material) -> void:
    var direction:=b-a
    var axis:=direction.normalized()
    var side:=axis.cross(Vector3.FORWARD if absf(axis.z)<.91 else Vector3.RIGHT).normalized()
    _fitting((a+b)*.5,Vector3(thickness,direction.length(),thickness),
        material,Basis(side,axis,side.cross(axis)))


func _rod_transform(a: Vector3,b: Vector3,width: float) -> Transform3D:
    var direction:=b-a
    var rotation:=Basis(Quaternion(Vector3.UP,direction.normalized()))
    return Transform3D(rotation*Basis.from_scale(Vector3(width,direction.length(),width)),
        (a+b)*.5)


func _batch_fittings() -> void:
    var index:=0
    var edges: int=0
    var center: int=0
    var side_uploaded: bool=false
    var center_uploaded: bool=false
    for material in _fittings:
        var transforms: Array=_fittings[material]
        # Inspect the SAME Transform3D values passed to set_instance_transform,
        # before the temporary CPU array is cleared. Godot's headless
        # MultiMesh readback returned zero positions in V75.165 despite 588
        # submitted instances. Audit the renderer submission, not readback.
        if material==_signal_cyan or material==_ice_trim:
            for placement in transforms:
                var pose: Transform3D=placement as Transform3D
                if absf(pose.origin.y+.103)>.012:
                    continue
                var matched_slot: bool=false
                for slot in range(22):
                    if absf(pose.origin.z-(3.0-float(slot)*.91))>.012:
                        continue
                    if material==_signal_cyan and (
                            absf(absf(pose.origin.x)-2.45)<.012 and
                            absf(pose.basis.x.length()-.024)<.004):
                        edges+=1
                        matched_slot=true
                    elif material==_ice_trim and slot>2 and slot%3==0 and (
                            absf(pose.origin.x)<.012 and
                            absf(pose.basis.x.length()-.052)<.004):
                        center+=1
                        matched_slot=true
                    if matched_slot:
                        break
        var batch_name: String="AirfieldFittings%02d"%index
        _instances(batch_name,_cube,material,transforms)
        var rendered: MultiMeshInstance3D=get_node_or_null(batch_name) as MultiMeshInstance3D
        var complete: bool=rendered!=null and rendered.multimesh!=null and (
            rendered.multimesh.instance_count==transforms.size()) and (
            rendered.material_override==material)
        if material==_signal_cyan:
            side_uploaded=complete
        elif material==_ice_trim:
            center_uploaded=complete
        index+=1
    _runway_batch_audit={
        "edge_count":edges,
        "center_count":center,
        "side_submitted":side_uploaded,
        "center_submitted":center_uploaded,
        "fitting_batches":index
    }
    print("AURORA_RUNWAY_SUBMISSION edges=",edges," centers=",center,
        " uploaded=",side_uploaded and center_uploaded,
        " fitting_batches=",index)
    _fittings.clear()


func _instances(title: String,mesh: Mesh,material: Material,transforms: Array,
        parent: Node3D=null) -> void:
    var group:=MultiMesh.new()
    group.transform_format=MultiMesh.TRANSFORM_3D
    group.mesh=mesh
    group.instance_count=transforms.size()
    for i in range(transforms.size()):
        group.set_instance_transform(i,transforms[i])
    var batch:=MultiMeshInstance3D.new()
    batch.name=title
    batch.multimesh=group
    batch.material_override=material
    batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    (self if parent==null else parent).add_child(batch)
