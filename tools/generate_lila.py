import trimesh
import numpy as np
from trimesh.transformations import translation_matrix as T
from pathlib import Path

scene=trimesh.Scene()
scene.graph.update(frame_to="LilaRoot",frame_from="world",matrix=np.eye(4))
colors={"skin":[235,177,167,255],"hair":[190,160,218,255],"hairlight":[224,200,238,255],"white":[236,242,251,255],"blue":[31,88,203,255],"navy":[19,27,49,255],"black":[29,32,45,255],"metal":[83,97,120,255],"violet":[121,69,166,255],"glow":[78,187,255,255]}
def add(name,xyz,size,color,parent="LilaRoot",sphere=False):
    m=trimesh.creation.icosphere(subdivisions=2,radius=1) if sphere else trimesh.creation.box(extents=size)
    if sphere:m.apply_scale(size)
    m.visual.vertex_colors=colors[color]
    scene.add_geometry(m,node_name=name,parent_node_name=parent,transform=T(xyz))
def pivot(name,xyz):
    scene.graph.update(frame_to=name,frame_from="LilaRoot",matrix=T(xyz))
add("torso",(0,1.55,0),(.38,.55,.25),"skin",sphere=True)
add("waist",(0,1.09,0),(.33,.23,.23),"skin",sphere=True)
add("jacket",(0,1.68,-.045),(.43,.33,.285),"white",sphere=True)
for x in (-.28,.28):
    add("jacket_panel_"+str(x),(x,1.67,.21),(.17,.43,.10),"blue")
    add("vest_strap_"+str(x),(x,1.77,.23),(.075,.46,.09),"navy")
add("chest_led",(0,1.64,.255),(.18,.16,.06),"glow")
add("belt",(0,1.19,0),(.68,.13,.49),"black")
add("shorts",(0,1.01,0),(.66,.30,.47),"navy")
add("buckle",(0,1.2,.255),(.18,.1,.055),"metal")
add("neck",(0,2.03,0),(.12,.16,.12),"skin",sphere=True)
add("head",(0,2.35,.045),(.33,.40,.30),"skin",sphere=True)
for x in (-.135,.135):
    add("eye_"+str(x),(x,2.37,.315),(.075,.075,.025),"violet",sphere=True)
    add("pupil_"+str(x),(x,2.37,.338),(.028,.041,.012),"black",sphere=True)
add("mouth",(0,2.14,.305),(.10,.018,.017),"violet")
add("hair_crown",(0,2.61,-.035),(.365,.23,.345),"hair",sphere=True)
for i,x in enumerate((-.26,-.13,0,.13,.26)):
    add("fringe_"+str(i),(x,2.57,.275),(.115,.16,.085),"hairlight",sphere=True)
for side,sgn in (("left",-1),("right",1)):
    pivot(side+"Arm",(sgn*.46,1.89,0))
    add(side+"_sleeve",(0,-.25,0),(.18,.32,.18),"white",side+"Arm",True)
    add(side+"_stripe",(sgn*.09,-.30,.16),(.08,.38,.055),"blue",side+"Arm")
    add(side+"_glove",(0,-.63,.03),(.16,.17,.17),"black",side+"Arm",True)
    add(side+"_wrist",(0,-.53,.16),(.18,.07,.05),"glow",side+"Arm")
    pivot(side+"Leg",(sgn*.19,1.01,0))
    add(side+"_thigh",(0,-.28,0),(.18,.36,.20),"skin",side+"Leg",True)
    add(side+"_strap",(0,-.37,.205),(.32,.09,.06),"black",side+"Leg")
    add(side+"_shin",(0,-.69,.015),(.15,.33,.17),"skin",side+"Leg",True)
    add(side+"_boot",(0,-.93,.10),(.20,.19,.30),"white",side+"Leg",True)
    add(side+"_toe",(0,-.91,.35),(.28,.13,.08),"blue",side+"Leg")
    add(side+"_sole",(0,-1.085,.14),(.38,.085,.51),"navy",side+"Leg")
    pivot(side+"Hair",(sgn*.30,2.56,-.22))
    add(side+"_hair",(sgn*.10,-.42,-.07),(.20,.58,.18),"hair",side+"Hair",True)
    add(side+"_tip",(sgn*.16,-.92,-.12),(.15,.28,.15),"hairlight",side+"Hair",True)
add("backpack",(0,1.66,-.34),(.52,.62,.23),"black")
add("backpack_led",(0,1.70,-.47),(.20,.20,.035),"glow")
add("utility_pouch",(-.43,1.00,.05),(.18,.27,.25),"navy")
output=Path(__file__).resolve().parent.parent/"app/src/main/assets/models/lila-operator.glb"
output.parent.mkdir(parents=True,exist_ok=True)
scene.export(str(output))
print("Generated",output,output.stat().st_size,"bytes")
