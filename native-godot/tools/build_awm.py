"""Original modular Aurora AWM-style bolt-action sniper.
Creates an actual lightweight glTF 2.0 mesh, not a UI-only weapon switch.
Original geometry authored in this project, no extracted game assets.
Run: blender --background --python build_awm.py -- output.glb
Origin: pistol grip / right hand; barrel points along -Z; length ~1.43m.
"""
import bpy
import math
import sys
from pathlib import Path
from mathutils import Vector

out=Path(sys.argv[sys.argv.index("--")+1])
out.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name,color,metallic,roughness,emission=None):
    m=bpy.data.materials.new(name)
    m.use_nodes=True
    p=m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value=(*color,1.0)
    p.inputs["Metallic"].default_value=metallic
    p.inputs["Roughness"].default_value=roughness
    if emission:
        p.inputs["Emission"].default_value=(*emission,1.0) if "Emission" in p.inputs else p.inputs["Base Color"].default_value
    return m

body=material("Aurora | graphite anodized",(.065,.088,.105),.68,.37)
polymer=material("Aurora | dark rifle polymer",(.041,.058,.081),.14,.66)
steel=material("Aurora | brushed blued steel",(.16,.20,.24),.83,.28)
blue=material("Aurora | tactical sapphire",(.035,.25,.46),.57,.28)
rubber=material("Aurora | textured rubber",(.045,.047,.052),.0,.88)
glass=material("Aurora | dark optical lenses",(.015,.11,.16),.24,.11)
marker=material("Aurora | white indicator",(.67,.78,.81),.25,.37)
metal_dark=material("Aurora | matte bolt",(.18,.22,.26),.73,.31)

def mat(obj,m):
    obj.data.materials.append(m)
    return obj

def box(name,loc,scale,m,bevel=.0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    o=bpy.context.object
    o.name=name
    o.dimensions=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new("Machined radiused edges","BEVEL")
        mod.width=bevel
        mod.segments=2
        mod.affect='EDGES' if hasattr(mod,"affect") else None
        bpy.context.view_layer.objects.active=o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return mat(o,m)

def cyl(name,start,stop,radius,m,verts=12,radius2=None):
    a,b=Vector(start),Vector(stop)
    mid=(a+b)*.5
    d=b-a
    bpy.ops.mesh.primitive_cone_add(vertices=verts,radius1=radius,radius2=radius if radius2 is None else radius2,
      depth=d.length,location=mid)
    o=bpy.context.object
    o.name=name
    o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
    return mat(o,m)

def spine(name,points,radius,m):
    for i in range(len(points)-1):
        cyl(name+"_"+str(i),points[i],points[i+1],radius,m,10)

def prism(name,verts,faces,m):
    mesh=bpy.data.meshes.new(name+"_mesh")
    mesh.from_pydata(verts,[],faces)
    mesh.update()
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    return mat(obj,m)

# Central receiver / action, stock comb and adjustable cheek rise.
box("Tactical chassis | machined receiver",(0,.018,-.20),(.115,.126,.44),body,.018)
box("Milled bolt-channel top",(0,.081,-.20),(.117,.028,.27),steel,.009)
box("Forward bedding rail",(0,-.014,-.46),(.095,.068,.28),blue,.013)
for i in range(7):
    z=-.21-i*.048
    box("Picatinny top tooth %02d"%i,(0,.10,z),(.108,.015,.016),steel,.002)
# Slender long heavy barrel with stepped muzzle, muzzle device and vents.
cyl("Fluted 26 inch sniper barrel",(0,.018,-.50),(0,.018,-1.21),.022,steel,16)
cyl("Barrel protector at shroud",(0,.018,-.49),(0,.018,-.75),.030,body,18)
for j in range(5):
    z=-.54-j*.045
    cyl("Floating shroud ring %02d"%j,(0,.018,z),(0,.018,z-.012),.035,body,16)
cyl("Muzzle brake",(0,.018,-1.21),(0,.018,-1.32),.034,steel,14)
for side in (-1,1):
    for j in range(3):
        box("Muzzle side port %d-%d"%(side,j),(side*.032,.021,-1.235-j*.028),(.004,.025,.012),body,.002)
# Buttstock: tapered ergonomic rail, reinforced cheek rest and adjustable recoil pad.
box("Adjustable stock rear tube",(0,-.012,.244),(.068,.086,.435),body,.014)
box("Carbon buttstock pad",(0,-.012,.486),(.096,.205,.065),rubber,.017)
box("Rear recoil skeleton lower",(0,-.076,.286),(.076,.026,.34),body,.008)
box("Comb raiser",(0,.067,.296),(.096,.055,.26),polymer,.016)
box("Grip tang",(0,-.051,.016),(.073,.10,.13),steel,.014)
grip=box("Pistol grip diamond pattern",(0,-.19,.034),(.080,.22,.105),rubber,.018)
grip.rotation_euler.x=math.radians(-16)
for side in (-1,1):
    box("Grip anti-slip panel "+str(side),(side*.044,-.198,.027),(.007,.12,.081),polymer,.003)
# Five-round polymer magazine, distinct from AR curved rifle magazine.
mag=box("AWM detachable box magazine",(0,-.14,-.232),(.095,.19,.13),polymer,.017)
mag.rotation_euler.x=math.radians(6)
box("Magazine baseplate",(0,-.236,-.220),(.106,.027,.145),blue,.008)
# Bolt handle on the right, and separate cycling knob.
cyl("Steel bolt stem",(.052,.045,-.16),(.116,.030,-.13),.010,metal_dark,12)
cyl("Raised bolt lever",(.116,.030,-.13),(.132,-.05,-.10),.013,steel,10)
cyl("Bolt actuator knob",(.132,-.05,-.10),(.139,-.080,-.091),.022,polymer,16)
# Trigger guard and distinct trigger.
spine("Trigger protection",[(.0,-.07,-.008),(.0,-.125,-.025),(.0,-.137,.081),(.0,-.072,.105)],.012,steel)
cyl("Single-action trigger",(0,-.05,.032),(0,-.10,.047),.007,metal_dark,10)
# Telescope optic: raised mounts, main body, elevation turrets, objective lens.
for z in (-.16,-.44):
    box("High-rise optic mount z="+str(z),(0,.145,z),(.066,.078,.052),body,.007)
cyl("Variable sniper optic tube",(0,.195,-.03),(0,.195,-.56),.043,steel,18)
cyl("Objective bell",(0,.195,-.55),(0,.195,-.675),.066,body,20)
cyl("Objective glass",(0,.195,-.675),(0,.195,-.679),.055,glass,24)
cyl("Eye piece",(0,.195,.001),(0,.195,-.075),.055,rubber,20)
cyl("Rear eyepiece glass",(0,.195,.004),(0,.195,.001),.042,glass,24)
cyl("Elevation turret",(0,.240,-.255),(0,.293,-.255),.031,blue,16)
cyl("Windage turret",(.040,.195,-.254),(.086,.195,-.254),.032,body,16)
for i in range(8):
    z=-.083+i*.006
    cyl("Focus collar rib %02d"%i,(0,.195,z),(0,.195,z+.002),.058,rubber,18)
# Folded bipod legs, support rails and contrasting serial plates.
for side in (-1,1):
    cyl("Folded bipod support", (side*.036,-.05,-.69),(side*.05,-.11,-.83),.012,steel,10)
    cyl("Folded bipod foot",(side*.05,-.11,-.83),(side*.05,-.11,-.875),.018,rubber,10)
    box("Barrel-side identification stripe "+str(side),(side*.055,.025,-.34),(.007,.025,.14),blue,.002)
box("Safety indicator",(0,.096,-.099),(.034,.006,.035),marker,.002)

objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
assert len(objects)>=38,len(objects)
# Keep simple meshes authored as individual pieces: Godot importer can merge by material.
for o in objects:
    if o.data.polygons:
        for p in o.data.polygons:
            p.use_smooth=o.name.startswith(("Fluted","Variable sniper","Muzzle","Objective"))
bpy.ops.export_scene.gltf(filepath=str(out),export_format="GLB",export_apply=False,
    export_animations=False,export_image_format='JPEG')
print("AURORA_AWM_GLTF_EXPORTED",out,out.stat().st_size,"mesh_parts",len(objects))
assert out.stat().st_size>25_000 and out.stat().st_size<3_000_000
