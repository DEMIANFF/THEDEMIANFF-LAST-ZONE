"""Bake a lobby-only upper-body excerpt from Siff onto Lila's existing joints."""
import argparse
from bisect import bisect_right
from functools import lru_cache
import hashlib
import json
from pathlib import Path
import struct

from build_lila import IDENTITY, ZERO, add, aim_vector, dot, inverse, mul, rotate, scale, sub, unit


SOURCE_SHA = "53e39259ccbcf83ce749da6f688e19bbdf0485fa1f10bd40371c9776bfaac2cb"
START = 9.5
SECONDS = 12.0
FPS = 15
SKELETON_PATH = "Node/AuxScene/Lila_Escala_Humana_1_70m/Node2/Lila_Aurora_Raiz/Skeleton3D"
SOURCE_SPINE = {
    "Spine": "Bip001_Spine_07", "Spine1": "Bip001_Spine1_08", "Spine2": "Bip001_Spine2_09",
    "Neck": "Bip001_Neck_010", "Head": "Bip001_Head_055",
}
SOURCE_ARMS = {
    "Left": ("Bip001_L_UpperArm_012", "Bip001_L_Forearm_013", "Bip001_L_Hand_014", "Bip001_L_Finger2_021"),
    "Right": ("Bip001_R_UpperArm_034", "Bip001_R_Forearm_035", "Bip001_R_Hand_036", "Bip001_R_Finger2_043"),
}


def mix(a, b, weight):
    return tuple(x+(y-x)*weight for x,y in zip(a,b))


def blend_rotation(a, b, weight):
    return unit(mix(a, b if dot(a,b)>=0.0 else scale(b,-1.0), weight))


def to_lila_vector(vector):
    x,y,z=vector
    return -x,z,-y


def to_lila_delta(rotation):
    # Rotation axes are pseudovectors under this change of handedness.
    return (*scale(to_lila_vector(rotation[:3]),-1.0),rotation[3])


class Rig:
    def __init__(self, raw, animation):
        size=struct.unpack_from("<I",raw,12)[0]
        self.doc=json.loads(raw[20:20+size])
        self.binary=raw[28+size:]
        self.nodes=self.doc["nodes"]
        self.by_name={n["name"]:i for i,n in enumerate(self.nodes) if "name" in n}
        self.parent={child:i for i,n in enumerate(self.nodes) for child in n.get("children",[])}
        animation=next(a for a in self.doc["animations"] if a["name"]==animation)
        self.tracks={}
        for channel in animation["channels"]:
            target=channel["target"]
            sampler=animation["samplers"][channel["sampler"]]
            times=[key[0] for key in self._read_values(sampler["input"])]
            self.tracks[target["node"],target["path"]]=(times,self._read_values(sampler["output"]))

    @lru_cache(maxsize=None)
    def _read_values(self,index):
        a=self.doc["accessors"][index]
        v=self.doc["bufferViews"][a["bufferView"]]
        n={"SCALAR":1,"VEC3":3,"VEC4":4}[a["type"]]
        assert a["componentType"]==5126
        start=v.get("byteOffset",0)+a.get("byteOffset",0)
        stride=v.get("byteStride",n*4)
        return [struct.unpack_from("<"+"f"*n,self.binary,start+i*stride) for i in range(a["count"])]

    def local(self,node,kind,time,default):
        track=self.tracks.get((node,kind))
        if track is None:
            return self.nodes[node].get(kind,default)
        ts, values=track
        i=max(0,bisect_right(ts,time)-1)
        if i+1==len(ts) or time<=ts[i]:
            return values[i]
        weight=(time-ts[i])/(ts[i+1]-ts[i])
        operation=blend_rotation if kind=="rotation" else mix
        return operation(values[i],values[i+1],weight)

    def pose(self,time,root=None,overrides=None):
        @lru_cache(maxsize=None)
        def evaluate(i):
            if i==root:
                return ZERO,IDENTITY,(1.,1.,1.)
            position=self.local(i,"translation",time,ZERO)
            rotation=(overrides[i] if overrides and i in overrides else
                      self.local(i,"rotation",time,IDENTITY))
            extent=self.local(i,"scale",time,(1.,1.,1.))
            if i not in self.parent:
                return position,rotation,extent
            origin,basis,stretch=evaluate(self.parent[i])
            length=tuple(x*y for x,y in zip(position,stretch))
            return add(origin,rotate(basis,length)),unit(mul(basis,rotation)),tuple(
                x*y for x,y in zip(stretch,extent))
        return evaluate


def solve_sample(source,target,sampled,origin,idle,weight):
    root=target.by_name["Root"]
    rotations={}

    def set_world(name,desired):
        node=target.by_name[name]
        parents=target.pose(0.0,root,rotations)
        parent_rotation=parents(target.parent[node])[1]
        current=target.local(node,"rotation",0.0,IDENTITY)
        rotations[node]=blend_rotation(current,unit(mul(inverse(parent_rotation),desired)),weight)

    for name,source_name in SOURCE_SPINE.items():
        src=source.by_name[source_name]
        delta=mul(sampled(src)[1],inverse(origin(src)[1]))
        influence=.58 if name in ("Head","Neck") else .38
        basis=idle(target.by_name[name])[1]
        set_world(name,mul(blend_rotation(IDENTITY,to_lila_delta(delta),influence),basis))

    for side,source_chain in SOURCE_ARMS.items():
        target_chain=[side+part for part in ("Arm","ForeArm","Hand","HandMiddle1")]
        for i in range(3):
            name,child=target_chain[i:i+2]
            old=idle(target.by_name[name])[1]
            direction=target.local(target.by_name[child],"translation",0.0,ZERO)
            from_point,to_point=(sampled(source.by_name[j])[0] for j in source_chain[i:i+2])
            desired=to_lila_vector(sub(to_point,from_point))
            # Preserve Lila's wrist/finger styling, using gentle orientation only.
            aligned=mul(aim_vector(rotate(old,direction),desired),old)
            set_world(name,blend_rotation(old,aligned,.62 if i==2 else .96))
    return {target.nodes[i]["name"]:q for i,q in rotations.items()}


def build(source_path,target_path,output):
    raw=source_path.read_bytes()
    if hashlib.sha256(raw).hexdigest()!=SOURCE_SHA:
        raise ValueError("siff.glb does not match the verified source")
    source=Rig(raw,"Motion")
    target=Rig(target_path.read_bytes(),"AuroraIdle")
    start=source.pose(START)
    idle=target.pose(0.0,target.by_name["Root"])
    keys={}
    for i in range(round(SECONDS*FPS)+1):
        time=i/FPS
        edge=max(0.0,min(1.0,time/.55,(SECONDS-time)/.65))
        pose=solve_sample(source,target,source.pose(START+time),start,idle,edge*edge*(3-2*edge))
        for name,rotation in pose.items():
            stored=keys.setdefault(name,[])
            if stored and dot(stored[-4:],rotation)<0:
                rotation=scale(rotation,-1.)
            stored.extend((time,1.0,*rotation))
    lines=['[gd_resource type="Animation" format=3]','','[resource]',
           'resource_name = "Motion"',f'length = {SECONDS}']
    for idx,(bone,data) in enumerate(keys.items()):
        tag=f"tracks/{idx}"
        lines.extend((f'{tag}/type = "rotation_3d"',f'{tag}/imported = false',f'{tag}/enabled = true',
                      f'{tag}/path = NodePath("{SKELETON_PATH}:{bone}")',f'{tag}/interp = 1',
                      f'{tag}/loop_wrap = false',f'{tag}/keys = PackedFloat32Array('+", ".join(
                          f"{value:.7g}" for value in data)+")"))
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text('\n'.join(lines)+'\n',encoding="utf-8")
    print(f"{len(keys)} rotation tracks, {SECONDS:g} seconds at {FPS} Hz: {output}")


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("source",type=Path)
    parser.add_argument("target",type=Path)
    parser.add_argument("output",type=Path)
    args=parser.parse_args()
    build(args.source,args.target,args.output)
