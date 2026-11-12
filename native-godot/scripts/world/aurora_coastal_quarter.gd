extends Node3D
## Puerto Aurora coastal quarter. Walkable two-storey houses, openings, roof
## colliders and ramps: actual level geometry, not a 2D lobby illustration.
## Materials and tile/arch meshes are authored here, not third-party branding.

const RESIDENTIAL=preload("res://scripts/world/coastal_residential_layout.gd")
const RENDER_BATCHER=preload("res://scripts/world/aurora_static_mesh_batcher.gd")
const HOUSE_COUNT: int=8
var terrain: StaticBody3D
var navigation_points: Array[Vector3]=[]
var cover_points: Array[Vector3]=[]
var buildings_built: int=0
var accessible_entries: int=0
var tile_instances: int=0
var collision_bodies: int=0
var cargo_caches_built: int=0
var visual_draws_saved: int=0
# Exact raised walkable floor surfaces, shared with the real BR pickup system.
# No terrain-height guess for objects inside elevated houses.
var interior_supply_spots: Array[Vector3]=[]
var furnished_interiors: int=0

var _plaster: StandardMaterial3D
var _sandstone: StandardMaterial3D
var _roof: StandardMaterial3D
var _wood: StandardMaterial3D
var _glass: StandardMaterial3D
var _iron: StandardMaterial3D
var _paving: StandardMaterial3D
var _green: StandardMaterial3D


func _ready() -> void:
    _build_materials()
    # Terrain and houses consume the SAME layout. This ensures the 3D
    # foundations physically sit on the levelled residential heightfield,
    # never on hills with hidden gaps below the walkable floor.
    for seed in range(HOUSE_COUNT):
        var site: Vector4=RESIDENTIAL.SITES[seed]
        _villa(Vector2(site.x,site.y),site.z,site.w,
            RESIDENTIAL.YAWS[seed],seed)
    _plaza(Vector2(20,28),Vector2(64,25))
    _plaza(Vector2(2,60),Vector2(65,12))
    # Western pedestrian lane: triangulated to the same terrain grid,
    # with real cover/navigation points from its adjacent residences.
    _plaza(Vector2(-31,31),Vector2(48,11))
    _planter(Vector2(2,26),1.65)
    _planter(Vector2(29,26),1.50)
    _planter(Vector2(49,26),1.85)
    _planter(Vector2(-38,22),1.60)
    _planter(Vector2(75,22),1.50)
    _palm(Vector2(5,20),1.0)
    _palm(Vector2(32,21),1.10)
    _palm(Vector2(57,13),0.9)
    _palm(Vector2(-57,24),1.08)
    _palm(Vector2(80,31),1.0)
    _freight_cache(Vector2(13,13),0)
    _freight_cache(Vector2(38,12),1)
    print("AURORA_COASTAL_QUARTER houses=",buildings_built,
        " doors=",accessible_entries," roof_tiles=",tile_instances,
        " solids=",collision_bodies," cargo_caches=",cargo_caches_built,
        " furnished_rooms=",furnished_interiors,
        " estimated_draws_saved=",visual_draws_saved,
        " interior_supply_sites=",interior_supply_spots.size())


func _material(color: Color, roughness: float, metal: float=0.0) -> StandardMaterial3D:
    var result:=StandardMaterial3D.new()
    result.albedo_color=color
    result.roughness=roughness
    result.metallic=metal
    return result


func _build_materials() -> void:
    _plaster=_material(Color(.96,.95,.91),.94)
    _sandstone=_material(Color(.64,.52,.38),.85)
    _roof=_material(Color(.70,.31,.19),.85)
    _roof.cull_mode=BaseMaterial3D.CULL_DISABLED
    _wood=_material(Color(.23,.14,.10),.78)
    _glass=_material(Color(.09,.30,.37,.62),.14)
    _glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
    _glass.metallic=.22
    _iron=_material(Color(.12,.16,.18),.46,.51)
    _paving=_material(Color(.63,.58,.50),.94)
    _paving.cull_mode=BaseMaterial3D.CULL_DISABLED
    _green=_material(Color(.10,.29,.18),.93)
    # Original tile and masonry detail texture, deterministic on every build.
    var image:=Image.create(128,128,false,Image.FORMAT_RGB8)
    for y in range(128):
        for x in range(128):
            var row: int=int(y/19)
            var column: int=int((x+(row%2)*13)/26)
            var mortar: bool=y%19<=1 or (x+(row%2)*13)%26<=1
            var variation: float=float(posmod(column*19+row*37,23))/120.0
            var grain: float=sin(float(x)*.91+float(y)*.43)*.022
            var brightness: float=.34 if mortar else clampf(.77+variation+grain,.5,.99)
            image.set_pixel(x,y,Color(brightness,brightness*.97,brightness*.91))
    var masonry:=ImageTexture.create_from_image(image)
    _sandstone.albedo_texture=masonry
    _paving.albedo_texture=masonry
    # A whitewashed wall has irregular lime wear, not black mortar seams.
    var whitewash:=Image.create(128,128,false,Image.FORMAT_RGB8)
    for py in range(128):
        for px in range(128):
            var age: float=sin(float(px)*.113+sin(float(py)*.061))*.021
            age+=sin(float(py)*.18+float(px)*.079)*.014
            age+=cos(float(px)*.63+float(py)*.82)*.009
            var value: float=clampf(.94+age,.88,1.0)
            whitewash.set_pixel(px,py,Color(value,value*.99,value*.95))
    _plaster.albedo_texture=ImageTexture.create_from_image(whitewash)
    # Three physically shaded material families, without height/parallax
    # shaders or large downloaded textures. The normal images are generated
    # once, packed in 128x128 RAM textures and reused on all four buildings.
    _plaster.normal_texture=_normal_from_height(whitewash,2.0)
    _plaster.normal_enabled=true
    _plaster.normal_scale=.40
    _sandstone.normal_texture=_normal_from_height(image,1.9)
    _sandstone.normal_enabled=true
    _sandstone.normal_scale=.55
    _paving.normal_texture=_sandstone.normal_texture
    _paving.normal_enabled=true
    _paving.normal_scale=.40


func _normal_from_height(height_image: Image,strength: float) -> ImageTexture:
    var width: int=height_image.get_width()
    var height: int=height_image.get_height()
    var output:=Image.create(width,height,false,Image.FORMAT_RGB8)
    for y in range(height):
        for x in range(width):
            var left: float=height_image.get_pixel((x+width-1)%width,y).r
            var right: float=height_image.get_pixel((x+1)%width,y).r
            var up: float=height_image.get_pixel(x,(y+height-1)%height).r
            var down: float=height_image.get_pixel(x,(y+1)%height).r
            var tangent:=Vector3((left-right)*strength,(up-down)*strength,1.0).normalized()
            output.set_pixel(x,y,Color(tangent.x*.5+.5,tangent.y*.5+.5,
                tangent.z*.5+.5))
    return ImageTexture.create_from_image(output)


func _ground(x: float,z: float) -> float:
    return terrain.height_at(x,z) if terrain!=null else 0.0


func _panel(root: Node3D,label: String,center: Vector3,extent: Vector3,
        surface: Material,solid: bool=true) -> void:
    var draw:=MeshInstance3D.new()
    draw.name=label+"Mesh"
    var mesh:=BoxMesh.new()
    mesh.size=extent
    draw.mesh=mesh
    draw.material_override=surface
    draw.position=center
    root.add_child(draw)
    if solid:
        var body:=StaticBody3D.new()
        body.name=label+"Solid"
        body.position=center
        body.collision_layer=1
        var shape:=CollisionShape3D.new()
        var box:=BoxShape3D.new()
        box.size=extent
        shape.shape=box
        body.add_child(shape)
        root.add_child(body)
        collision_bodies+=1


func _beam(root: Node3D,label: String,at: Vector3,length: Vector3,material: Material,
        radius: float=.07) -> void:
    var mesh:=CylinderMesh.new()
    mesh.top_radius=radius
    mesh.bottom_radius=radius
    mesh.height=length.length()
    mesh.radial_segments=8
    var draw:=MeshInstance3D.new()
    draw.name=label
    draw.mesh=mesh
    draw.position=at+length*.5
    draw.quaternion=Quaternion(Vector3.UP,length.normalized())
    draw.material_override=material
    root.add_child(draw)


func _portal_arch(root: Node3D,center: Vector3,half_width: float,rise: float) -> void:
    # Curved stone segment ring above a genuinely open, traversable door.
    var tool:=SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(16):
        var a: float=PI-float(i)*PI/16.0
        var b: float=PI-float(i+1)*PI/16.0
        var inner_a:=Vector3(cos(a)*half_width,sin(a)*rise,0)
        var inner_b:=Vector3(cos(b)*half_width,sin(b)*rise,0)
        var outer_a:=Vector3(cos(a)*(half_width+.28),sin(a)*(rise+.29),0)
        var outer_b:=Vector3(cos(b)*(half_width+.28),sin(b)*(rise+.29),0)
        tool.set_color(Color(.91,.85,.74) if i%3 else Color(.68,.57,.43))
        for vertex in [inner_a,outer_a,outer_b,inner_a,outer_b,inner_b]:
            tool.add_vertex(center+vertex)
    tool.generate_normals()
    var visual:=MeshInstance3D.new()
    visual.name="CarvedStoneDoorArch"
    visual.mesh=tool.commit()
    var stone:=_material(Color(.72,.63,.52),.91)
    stone.vertex_color_use_as_albedo=true
    stone.cull_mode=BaseMaterial3D.CULL_DISABLED
    visual.material_override=stone
    root.add_child(visual)


func _roof_mesh(root: Node3D,w: float,d: float,ridge_height: float) -> void:
    var roof_mesh:=SurfaceTool.new()
    roof_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
    var mid: float=ridge_height+.95
    for side in [-1.0,1.0]:
        var a:=Vector3(0,mid,-d*.55)
        var b:=Vector3(side*w*.56,ridge_height,-d*.55)
        var c:=Vector3(0,mid,d*.55)
        var e:=Vector3(side*w*.56,ridge_height,d*.55)
        for p in [a,b,c,b,e,c]:
            roof_mesh.set_uv(Vector2(p.x/maxf(w,1),p.z/maxf(d,1)))
            roof_mesh.add_vertex(p)
    roof_mesh.generate_normals()
    var surface: ArrayMesh=roof_mesh.commit()
    var visual:=MeshInstance3D.new()
    visual.name="TerracottaGableRoof"
    visual.mesh=surface
    visual.material_override=_roof
    root.add_child(visual)
    var collider:=StaticBody3D.new()
    collider.name="WalkableRoofCollision"
    collider.collision_layer=3
    var shape:=CollisionShape3D.new()
    shape.shape=surface.create_trimesh_shape()
    collider.add_child(shape)
    root.add_child(collider)
    collision_bodies+=1
    # Actual curved half-cylinder barrel tiles, GPU-instanced; not box roofs.
    var tube:=SurfaceTool.new()
    tube.begin(Mesh.PRIMITIVE_TRIANGLES)
    var tile_len: float=.52
    for t in range(9):
        var first: float=PI*float(t)/9.0
        var next: float=PI*float(t+1)/9.0
        var v0:=Vector3(cos(first)*.19,sin(first)*.13,-tile_len*.5)
        var v1:=Vector3(cos(next)*.19,sin(next)*.13,-tile_len*.5)
        var v2:=Vector3(cos(first)*.19,sin(first)*.13,tile_len*.5)
        var v3:=Vector3(cos(next)*.19,sin(next)*.13,tile_len*.5)
        for p in [v0,v1,v2,v1,v3,v2]:
            tube.add_vertex(p)
    tube.generate_normals()
    var barrel:=tube.commit()
    barrel.surface_set_material(0,_roof)
    var count_x: int=maxi(1,int(floor(w/.39)))
    var count_z: int=maxi(1,int(floor(d/.51)))
    var amount: int=count_x*count_z*2
    var collection:=MultiMesh.new()
    collection.transform_format=MultiMesh.TRANSFORM_3D
    collection.mesh=barrel
    collection.instance_count=amount
    var index: int=0
    for side in [-1.0,1.0]:
        for ix in range(count_x):
            var run: float=(float(ix)+.5)/float(count_x)*w*.55
            var x: float=float(side)*run
            var y: float=mid-(run/(w*.56))*.95+.025
            for iz in range(count_z):
                var z: float=-d*.52+(float(iz)+.5)/float(count_z)*d*1.04
                var basis:=Basis(Vector3.FORWARD,atan2(.95,w*.56)*float(side))
                collection.set_instance_transform(index,Transform3D(basis,Vector3(x,y,z)))
                index+=1
    var tiles:=MultiMeshInstance3D.new()
    tiles.name="InstancedCurvedTerracottaTiles"
    tiles.multimesh=collection
    tiles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(tiles)
    tile_instances+=amount


func _door_frame(root: Node3D,z: float,width: float,top: float) -> void:
    for side in [-1.0,1.0]:
        _panel(root,"CutStoneDoorJamb",Vector3(side*(width*.5+.13),top*.5,z),
            Vector3(.28,top,.35),_sandstone,false)
    _portal_arch(root,Vector3(0,top,z+.22),width*.5,.54)
    # Open doorway: no mesh or collider is placed across the lower entrance.
    _panel(root,"HalfOpenOakDoor",Vector3(-width*.5+.30,top*.46,z+.26),
        Vector3(.53,top*.88,.13),_wood,false)
    _beam(root,"DoorHandle",Vector3(-width*.5+.53,1.1,z+.37),Vector3(.01,.13,0),_iron,.04)


func _window_frame(root: Node3D,at: Vector3,width: float=1.45,height: float=1.45) -> void:
    _panel(root,"ShadedWindowGlass",at,Vector3(width,height,.06),_glass,false)
    for side in [-1.0,1.0]:
        _panel(root,"WindowFrame",at+Vector3(side*width*.5,0,.06),
            Vector3(.10,height+.12,.12),_wood,false)
    for level in [-1.0,1.0]:
        _panel(root,"WindowTrim",at+Vector3(0,level*height*.5,.08),
            Vector3(width+.25,.10,.18),_sandstone,false)
    _panel(root,"WindowCrossbar",at+Vector3(0,0,.10),
        Vector3(.06,height,.13),_wood,false)


func _stair_ramp(root: Node3D,front: float,w: float,at: Vector2) -> void:
    # Convex physical slope spans exterior terrain to the raised entrance;
    # fine decorative paving lines are visual only, never invisible stair walls.
    var near: float=front+.35
    var far: float=front+7.5
    var ramp_start_world: Vector3=root.to_global(Vector3(0,0,far))
    var low: float=_ground(ramp_start_world.x,ramp_start_world.z)-root.position.y
    var high: float=.24
    var bottom: float=minf(low,high)-.35
    var points:=PackedVector3Array([
        Vector3(-w,low,far),Vector3(w,low,far),
        Vector3(-w,high,near),Vector3(w,high,near),
        Vector3(-w,bottom,far),Vector3(w,bottom,far),
        Vector3(-w,bottom,near),Vector3(w,bottom,near)])
    var body:=StaticBody3D.new()
    body.name="TraversableDoorRamp"
    body.collision_layer=3
    var hull:=ConvexPolygonShape3D.new()
    hull.points=points
    var collision:=CollisionShape3D.new()
    collision.shape=hull
    body.add_child(collision)
    root.add_child(body)
    collision_bodies+=1
    var mesh:=SurfaceTool.new()
    mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
    for ix in [0,1,2,1,3,2]:
        var vertex: Vector3=points[ix]+Vector3.UP*.015
        mesh.set_uv(Vector2(vertex.x/2.0,vertex.z/2.0))
        mesh.add_vertex(vertex)
    mesh.generate_normals()
    mesh.generate_tangents()
    var visible:=MeshInstance3D.new()
    visible.name="AccessibleStoneEntry"
    visible.mesh=mesh.commit()
    visible.material_override=_paving
    root.add_child(visible)
    for j in range(1,10):
        var t: float=float(j)/10.0
        var z: float=lerpf(near,far,t)
        var y: float=lerpf(high,low,t)+.019
        _beam(root,"PavedRampJoint",Vector3(-w,y,z),Vector3(w*2.0,0,0),_sandstone,.025)
    accessible_entries+=1
    navigation_points.append(root.to_global(Vector3(0,high+.08,near)))
    navigation_points.append(root.to_global(Vector3(0,low+.08,far)))


func _villa(at: Vector2,w: float,d: float,rotation: float,seed: int) -> void:
    # The complete rotated footprint has a flat 7m terrain platform in
    # island_terrain.gd. Use the actual center height, not the highest
    # corner, which previously lifted entire houses above sloping ground.
    var foot_y: float=_ground(at.x,at.y)
    var building:=Node3D.new()
    building.name="AuroraCoastalVilla"+str(seed)
    building.position=Vector3(at.x,foot_y+.025,at.y)
    # Nearly parallel façades preserve paths and navigation on varied ground.
    building.rotation.y=rotation
    add_child(building)
    var height: float=5.85
    var door_width: float=2.65
    var front: float=d*.5
    var remainder: float=(w-door_width)*.5
    # The shallow, buried masonry edge visually grounds the façade while
    # the original solid walkable floor remains the sole interior support.
    _panel(building,"BuriedMasonryFoundation",Vector3(0,-.095,0),
        Vector3(w-.12,.24,d-.12),_sandstone,false)
    _panel(building,"WalkableInteriorFloor",Vector3(0,.12,0),
        Vector3(w-.30,.24,d-.30),_paving)
    _panel(building,"LeftDoorWall",Vector3(-(w+door_width)*.25,height*.5,front),
        Vector3(remainder,height,.38),_plaster)
    _panel(building,"RightDoorWall",Vector3((w+door_width)*.25,height*.5,front),
        Vector3(remainder,height,.38),_plaster)
    _panel(building,"DoorLintel",Vector3(0,(height+3.22)*.5,front),
        Vector3(door_width,height-3.22,.38),_plaster)
    _door_frame(building,front+.20,door_width,2.8)
    _panel(building,"RearWall",Vector3(0,height*.5,-front),
        Vector3(w,height,.39),_plaster)
    for side in [-1.0,1.0]:
        var x: float=side*w*.5
        _panel(building,"SideBase",Vector3(x,1.10,0),
            Vector3(.40,2.20,d),_plaster)
        _panel(building,"SideTop",Vector3(x,(height+4.5)*.5,0),
            Vector3(.40,height-4.5,d),_plaster)
        for zside in [-1.0,1.0]:
            _panel(building,"SideWindowPier",Vector3(x,3.35,zside*(d+2.1)*.25),
                Vector3(.40,2.30,(d-2.1)*.5),_plaster)
    _window_frame(building,Vector3(-w*.29,3.6,front+.22),1.4,1.45)
    _window_frame(building,Vector3(w*.29,3.6,front+.22),1.4,1.45)
    _furnish_interior(building,w,d,seed)
    _roof_mesh(building,w,d,height)
    # Continuous interior ceiling: do not depend on winding/culling of
    # sloped roof triangles to close the room when the camera looks up.
    _panel(building,"SealedVillaCeiling",Vector3(0,height-.12,0),
        Vector3(w-.25,.24,d-.25),_wood,true)
    _stair_ramp(building,front,door_width*.64,at)
    # Walkable terrace: physical railing and ground-level cover, balcony visual.
    # Ramp is the ONLY collision support across this threshold. A second
    # raised porch box previously formed an invisible 20-cm movement step.
    _panel(building,"EntryStonePorch",Vector3(0,.12,front+.95),
        Vector3(door_width+1.2,.22,1.65),_sandstone,false)
    for x in [-w*.32,w*.32]:
        _panel(building,"BalconyCorner",Vector3(x,2.73,front+.46),
            Vector3(.27,.28,1.2),_sandstone,false)
    _panel(building,"DecorativeBalconySlab",Vector3(0,2.7,front+.60),
        Vector3(w*.75,.20,1.3),_sandstone,false)
    for i in range(13):
        var xx: float=-w*.35+(float(i)/12.0)*w*.70
        _beam(building,"ForgedBalconyRail",Vector3(xx,2.81,front+1.2),
            Vector3(0,.79,0),_iron,.033)
    _beam(building,"BalconyTopRail",Vector3(-w*.35,3.61,front+1.2),
        Vector3(w*.70,0,0),_iron,.050)
    # Merge stationary meshes by material: all solid collision bodies,
    # floor support, roof tiles and navigation nodes remain unchanged.
    var batch_report: Dictionary=RENDER_BATCHER.merge_building(building)
    visual_draws_saved+=int(batch_report["estimated_draws_saved"])
    for x in [-w*.5-2.5,w*.5+2.5]:
        for z in [-d*.5-2.5,d*.5+2.5]:
            var p:=building.to_global(Vector3(x,0,z))
            navigation_points.append(Vector3(p.x,_ground(p.x,p.z)+.08,p.z))
    var entrance:=building.to_global(Vector3(0,.30,front+2.4))
    cover_points.append(entrance+Vector3(3.0,0,0))
    # The loot capsule is centered over the actual floor, not the exterior
    # heightfield (which lies lower beneath some raised house foundations).
    # Place it beyond the open doorway, out of the two side furniture bays.
    interior_supply_spots.append(building.to_global(Vector3(0,.28,-d*.18)))
    buildings_built+=1



func _furnish_interior(building: Node3D,w: float,d: float,seed: int) -> void:
    # Low, collidable furniture gives physical cover without turning rooms
    # into text-only scenery. Preserve a >3m unobstructed center aisle from
    # the door to the interior, including an opening for the player capsule.
    for side in [-1.0,1.0]:
        var x: float=side*w*.36
        var label: String="RoomWorkbench"+str(int(side+1.0))
        _panel(building,label,Vector3(x,.60,-d*.15),
            Vector3(1.40,.90,1.35),_wood,true)
        _panel(building,"RoomWorkbenchMetalLip"+str(int(side+1.0)),
            Vector3(x,1.10,-d*.15),
            Vector3(1.50,.10,1.42),_iron,false)
        # Low crates on the rear side of each house are projectile cover;
        # they never occupy the doorway's X center line.
        _panel(building,"RoomStorage"+str(int(side+1.0)),
            Vector3(x,.48,-d*.36),
            Vector3(1.05,.70,.95),_sandstone,true)
    _panel(building,"RearInteriorTrim",Vector3(0,2.05,-d*.5+.22),
        Vector3(w*.56,.10,.08),_wood,false)
    furnished_interiors+=1


func _plaza(center: Vector2,area: Vector2) -> void:
    # Reuse EXACTLY the world terrain's 96x96 lattice and diagonal split.
    # An independent paving tessellation intersected the terrain between
    # its sample points, producing visible cut-outs and flickering.
    var step: float=450.0/96.0
    var first_x: int=clampi(int(floor((center.x-area.x*.5+225.0)/step)),0,95)
    var last_x: int=clampi(int(ceil((center.x+area.x*.5+225.0)/step)),1,96)
    var first_z: int=clampi(int(floor((center.y-area.y*.5+225.0)/step)),0,95)
    var last_z: int=clampi(int(ceil((center.y+area.y*.5+225.0)/step)),1,96)
    var tool:=SurfaceTool.new()
    tool.begin(Mesh.PRIMITIVE_TRIANGLES)
    for ix in range(first_x,last_x):
        for iz in range(first_z,last_z):
            var x: float=-225.0+float(ix)*step
            var z: float=-225.0+float(iz)*step
            var a:=Vector3(x,_ground(x,z)+.055,z)
            var b:=Vector3(x+step,_ground(x+step,z)+.055,z)
            var c:=Vector3(x,_ground(x,z+step)+.055,z+step)
            var d:=Vector3(x+step,_ground(x+step,z+step)+.055,z+step)
            # Same diagonal and vertex order as island_terrain.gd.
            for point in [a,b,c,b,d,c]:
                tool.set_uv(Vector2(point.x/2.0,point.z/2.0))
                tool.add_vertex(point)
    tool.generate_normals()
    tool.generate_tangents()
    var cobbles:=MeshInstance3D.new()
    cobbles.name="AuroraCobblestoneMarketPlaza"
    cobbles.mesh=tool.commit()
    cobbles.material_override=_paving
    add_child(cobbles)
    for i in range(21):
        var x: float=center.x+float(i-10)*2.0
        navigation_points.append(Vector3(x,_ground(x,center.y)+.06,center.y))


func _freight_cache(at: Vector2,index: int) -> void:
    # Gameplay cover, not a backdrop: stacked armoured supply trunks stop
    # player/enemy bullets through world-layer collision. Their low profile
    # keeps the waterfront pathways visible and the entrance ramps clear.
    var depot:=Node3D.new()
    depot.name="AuroraFreightCache"+str(index)
    depot.position=Vector3(at.x,_ground(at.x,at.y)+.04,at.y)
    add_child(depot)
    var crates: Array[Vector3]=[
        Vector3(-1.15,.56,0.0),
        Vector3(.58,.56,-.25),
        Vector3(-.25,1.62,-.20)
    ]
    for j in range(crates.size()):
        var point: Vector3=crates[j]
        var extent:=Vector3(1.65,1.08,1.27) if j<2 else Vector3(1.32,1.03,1.14)
        _panel(depot,"SolidCargoCover"+str(j),point,extent,_wood,true)
        _panel(depot,"CargoFrontPlating",point+Vector3(0,0,extent.z*.5+.035),
            Vector3(extent.x*.93,extent.y*.70,.065),_iron,false)
        for side in [-1.0,1.0]:
            _panel(depot,"CargoSteelCorner",point+Vector3(
                side*(extent.x*.5-.08),0,extent.z*.5+.065),
                Vector3(.10,extent.y+.05,.10),_sandstone,false)
        _panel(depot,"CargoLid",point+Vector3(0,extent.y*.5+.04,0),
            Vector3(extent.x+.12,.10,extent.z+.11),_iron,false)
    # These are safe, reachable cover positions around the physical crate
    # footprints. Both AI route seeds and cover scoring use actual terrain.
    for offset in [Vector2(-3.6,0.0),Vector2(3.4,0.0),
                   Vector2(0.0,-2.7),Vector2(0.0,2.65)]:
        var x: float=at.x+offset.x
        var z: float=at.y+offset.y
        var point:=Vector3(x,_ground(x,z)+.08,z)
        navigation_points.append(point)
        cover_points.append(point)
    cargo_caches_built+=1


func _planter(at: Vector2,radius: float) -> void:
    var base:=Node3D.new()
    base.name="UrbanGardenCover"
    base.position=Vector3(at.x,_ground(at.x,at.y),at.y)
    add_child(base)
    var wall:=CylinderMesh.new()
    wall.top_radius=radius
    wall.bottom_radius=radius*1.03
    wall.height=.78
    wall.radial_segments=14
    var visual:=MeshInstance3D.new()
    visual.name="CutStoneCircularPlanter"
    visual.mesh=wall
    visual.position.y=.39
    visual.material_override=_sandstone
    base.add_child(visual)
    var body:=StaticBody3D.new()
    body.name="UrbanPlanterPhysicalCover"
    body.collision_layer=1
    var shape:=CollisionShape3D.new()
    var cylinder:=CylinderShape3D.new()
    cylinder.radius=radius
    cylinder.height=.78
    shape.shape=cylinder
    shape.position.y=.39
    body.add_child(shape)
    base.add_child(body)
    collision_bodies+=1
    var soil:=MeshInstance3D.new()
    soil.name="PlanterGardenBed"
    var disk:=CylinderMesh.new()
    disk.top_radius=radius*.88
    disk.bottom_radius=radius*.88
    disk.height=.10
    disk.radial_segments=14
    soil.mesh=disk
    soil.material_override=_green
    soil.position.y=.82
    base.add_child(soil)
    for j in range(7):
        var a: float=float(j)*TAU/7.0
        var plant:=MeshInstance3D.new()
        var leaf:=SphereMesh.new()
        leaf.radius=.24
        leaf.height=.50
        leaf.radial_segments=8
        leaf.rings=4
        plant.mesh=leaf
        plant.material_override=_green
        plant.position=Vector3(cos(a)*radius*.52,1.12+float(j%3)*.1,sin(a)*radius*.52)
        base.add_child(plant)
    for i in range(8):
        var angle: float=TAU*float(i)/8.0
        var p:=base.position+Vector3(cos(angle)*(radius+1.25),0,sin(angle)*(radius+1.25))
        p.y=_ground(p.x,p.z)+.05
        cover_points.append(p)
        navigation_points.append(p)


func _palm(at: Vector2,scale: float) -> void:
    var tree:=Node3D.new()
    tree.name="MediterraneanAuroraPalm"
    tree.position=Vector3(at.x,_ground(at.x,at.y),at.y)
    tree.scale=Vector3.ONE*scale
    add_child(tree)
    var trunk:=CylinderMesh.new()
    trunk.radial_segments=10
    trunk.top_radius=.23
    trunk.bottom_radius=.38
    trunk.height=5.0
    var bark:=_material(Color(.29,.22,.14),.93)
    var shaft:=MeshInstance3D.new()
    shaft.name="TexturedPalmTrunk"
    shaft.mesh=trunk
    shaft.position.y=2.5
    shaft.material_override=bark
    tree.add_child(shaft)
    var leaves:=SurfaceTool.new()
    leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
    for direction in range(10):
        var a: float=TAU*float(direction)/10.0
        var vec:=Vector3(cos(a),0,sin(a))
        for j in range(5):
            var first: float=float(j)/5.0
            var second: float=float(j+1)/5.0
            var p:=Vector3(0,5.2,0)+vec*(first*3.8)+Vector3(0,sin(first*PI)*.45-first*.7,0)
            var q:=Vector3(0,5.2,0)+vec*(second*3.8)+Vector3(0,sin(second*PI)*.45-second*.7,0)
            var width: float=(1.0-first)*.40
            var cross:=Vector3(-vec.z,0,vec.x)
            for vertex in [p-cross*width,p+cross*width,q]:
                leaves.add_vertex(vertex)
    leaves.generate_normals()
    var crown:=MeshInstance3D.new()
    crown.name="ModeledPalmFronds"
    crown.mesh=leaves.commit()
    var foliage:=_material(Color(.12,.35,.16),.89)
    foliage.cull_mode=BaseMaterial3D.CULL_DISABLED
    crown.material_override=foliage
    tree.add_child(crown)
    var body:=StaticBody3D.new()
    body.name="PalmTrunkPhysical"
    body.collision_layer=1
    var collider:=CollisionShape3D.new()
    var shape:=CapsuleShape3D.new()
    shape.radius=.35
    shape.height=5.2
    collider.shape=shape
    collider.position.y=2.5
    body.add_child(collider)
    tree.add_child(body)
    collision_bodies+=1
