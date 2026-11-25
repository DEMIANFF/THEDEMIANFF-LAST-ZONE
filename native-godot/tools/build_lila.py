import argparse
import hashlib
import json
import math
from pathlib import Path
import struct


SOURCE_SHA256 = "62da843e0649b4274f5af4dfc75dfa3fa557d094224922c002498d5c28e15cbd"
IDENTITY = (0., 0., 0., 1.)
ZERO = (0., 0., 0.)
# GLB reference space is Y-up and the model faces +Z. Grip coordinates are in
# the unscaled skeleton, relative to Spine2. The gameplay transform handles metres.
READY = ((.11, -.13, .15), (.04, -.17, .30))
AIM = ((.10, -.045, .15), (.04, -.075, .33))
AIM_AWM = ((.105, -.035, .14), (.035, -.07, .345))
CROUCH = ((.11, -.16, .14), (.04, -.19, .295))


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def scale(a, k):
    return tuple(x * k for x in a)


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def cross(a, b):
    x, y, z = a
    p, q, r = b
    return (y*r-z*q, z*p-x*r, x*q-y*p)


def unit(v):
    return scale(v, 1. / math.sqrt(dot(v, v)))


def mul(a, b):
    av, bv = a[:3], b[:3]
    return (*add(add(scale(bv, a[3]), scale(av, b[3])), cross(av, bv)),
            a[3]*b[3] - dot(av, bv))


def inverse(q):
    return (*scale(q[:3], -1.), q[3])


def rotate(q, v):
    return mul(mul(q, (*v, 0.)), inverse(q))[:3]


def axis(angle, component):
    q = [0., 0., 0., math.cos(angle / 2.)]
    q[component] = math.sin(angle / 2.)
    return tuple(q)


def aim_vector(source, target):
    a, b = unit(source), unit(target)
    if dot(a, b) < -.99999:
        return (*unit(cross(a, (0., 0., 1.))), 0.)
    return unit((*cross(a, b), 1. + dot(a, b)))


def smooth_window(progress, peak, end, start=0.):
    if progress <= start or progress >= end:
        return 0.
    f = ((progress - start) / (peak - start) if progress < peak
         else (end - progress) / (end - peak))
    return f * f * (3. - 2. * f)


def solve_hinge(ray, preferred_elbow, upper, lower):
    upper_len = math.sqrt(dot(upper, upper))
    lower_len = math.sqrt(dot(lower, lower))
    direction = unit(ray)
    distance = max(abs(upper_len - lower_len) + .001,
                   min(math.sqrt(dot(ray, ray)), upper_len + lower_len - .001))
    along = (upper_len**2 - lower_len**2 + distance**2) / (2. * distance)
    side = unit(sub(preferred_elbow, scale(direction, dot(preferred_elbow, direction))))
    elbow = add(scale(direction, along),
                scale(side, math.sqrt(max(0., upper_len**2 - along**2))))
    return elbow, sub(scale(direction, distance), elbow)


class LilaAsset:
    def __init__(self, raw):
        magic, version, length, json_size, json_type = struct.unpack_from("<5I", raw)
        assert (magic, version, length, json_type) == (0x46546c67, 2, len(raw), 0x4e4f534a)
        self.doc = json.loads(raw[20:20 + json_size])
        binary_size, binary_type = struct.unpack_from("<2I", raw, 20 + json_size)
        assert binary_type == 0x004e4942 and binary_size == len(raw) - 28 - json_size
        self.binary = bytearray(raw[28 + json_size:])
        self.nodes = self.doc["nodes"]
        self.indices = {self.nodes[i]["name"]: i for i in self.doc["skins"][0]["joints"]}
        assert len(self.indices) == 56
        self.parents = {child: i for i, node in enumerate(self.nodes)
                        for child in node.get("children", [])}
        self.sources = {clip["name"]: clip for clip in self.doc["animations"]}
        assert len(self.sources) == 57
        self.doc["animations"] = []

    def values(self, index):
        accessor = self.doc["accessors"][index]
        assert accessor["componentType"] == 5126
        view = self.doc["bufferViews"][accessor["bufferView"]]
        start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        components = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[accessor["type"]]
        assert view.get("byteStride", components * 4) == components * 4
        return list(struct.iter_unpack("<" + "f" * components,
                    self.binary[start:start + accessor["count"] * components * 4]))

    def add_values(self, values, kind):
        components = len(values[0])
        data = b"".join(struct.pack("<" + "f" * components, *value) for value in values)
        views = self.doc["bufferViews"]
        accessors = self.doc["accessors"]
        views.append({"buffer": 0, "byteOffset": len(self.binary), "byteLength": len(data)})
        self.binary.extend(data)
        accessors.append({
            "bufferView": len(views) - 1, "componentType": 5126,
            "count": len(values), "type": kind,
            "min": [min(row[j] for row in values) for j in range(components)],
            "max": [max(row[j] for row in values) for j in range(components)],
        })
        return len(accessors) - 1

    def transforms(self, pose):
        globals_by_node = {self.indices["Root"]: (ZERO, IDENTITY)}

        def transform(node):
            if node not in globals_by_node:
                origin, orientation = transform(self.parents[node])
                local_position = pose.get((node, "translation"), self.nodes[node].get("translation", ZERO))
                local_rotation = pose.get((node, "rotation"), self.nodes[node].get("rotation", IDENTITY))
                globals_by_node[node] = (add(origin, rotate(orientation, local_position)),
                                         mul(orientation, local_rotation))
            return globals_by_node[node]

        return transform

    def ground_stance(self, pose, deepen, stable=False):
        at = self.transforms(pose)
        hips = self.indices["Hips"]
        # The source clips do not share a planted-foot reference. Use the
        # standing clip's lowest toe height so stride clips do not float above
        # the capsule or sink into the floor during a crouch.
        toe_height = min(at(self.indices[side + "ToeBase"])[0][1] for side in ("Left", "Right"))
        grounding = (0., -.46 - toe_height, 0.)
        lowering = (0., -.079 if deepen else -.012 if stable else 0., 0.)
        changes = {(hips, "translation"): add(pose[hips, "translation"], add(grounding, lowering))}
        if stable or deepen:
            # Lower the crouch at the hips while holding the imported ankle
            # positions and soles. The collider uses a real crouched height.
            for side in ("Left", "Right"):
                thigh, shin, ankle = [self.indices[side + part] for part in ("UpLeg", "Leg", "Foot")]
                start, thigh_rotation = at(thigh)
                knee, shin_rotation = at(shin)
                foot, foot_rotation = at(ankle)
                upper = self.nodes[shin]["translation"]
                lower = self.nodes[ankle]["translation"]
                target = foot
                pole = sub(knee, start)
                if stable:
                    # The supplied Idle is a narrow, inward-pointing fashion
                    # stance. Derive a planted combat stance WITHOUT changing
                    # the mesh, bind lengths, weights, textures or finger clips.
                    sign = -1. if side == "Left" else 1.
                    toe = at(self.indices[side + "ToeBase"])[0]
                    toe_ray = sub(toe, foot)
                    flat = math.sqrt(max(.0001, dot(toe_ray, toe_ray) - .037**2))
                    toe_target = (sign * flat * math.sin(.10), -.037, flat * math.cos(.10))
                    foot_rotation = mul(aim_vector(toe_ray, toe_target), foot_rotation)
                    target = (sign * (.100 if deepen else .095), -.423 - grounding[1],
                              .035 if side == "Left" else -.040)
                    pole = (sign * .10, -.03, .25)
                bend, rest = solve_hinge(sub(target, add(start, lowering)), pole, upper, lower)
                new_thigh = mul(aim_vector(rotate(thigh_rotation, upper), bend), thigh_rotation)
                new_shin = mul(aim_vector(rotate(shin_rotation, lower), rest), shin_rotation)
                changes[thigh, "rotation"] = unit(mul(inverse(at(self.parents[thigh])[1]), new_thigh))
                changes[shin, "rotation"] = unit(mul(inverse(new_thigh), new_shin))
                changes[ankle, "rotation"] = unit(mul(inverse(new_shin), foot_rotation))
        return changes

    def overlay(self, tracks, frame, profile, ground, deepen, stable=False):
        pose = {target: values[frame] for target, values in tracks.items()}
        changes = self.ground_stance(pose, deepen, stable) if ground else {}
        pose.update(changes)
        grip, pitch, roll = profile
        hips = self.indices["Hips"]
        spine = self.indices["Spine2"]
        neck = self.indices["Neck"]
        pitch_node = hips if abs(pitch) > .35 else spine
        changes[pitch_node, "rotation"] = unit(mul(
            pose[pitch_node, "rotation"], mul(axis(pitch, 0), axis(roll, 2))))
        changes[neck, "rotation"] = unit(mul(
            pose[neck, "rotation"], mul(axis(-pitch * .28, 0), axis(-roll * .6, 2))))
        pose.update(changes)
        transform = self.transforms(pose)
        center, _ = transform(spine)
        for side, target_offset in zip(("Right", "Left"), grip):
            arm = self.indices[side + "Arm"]
            forearm = self.indices[side + "ForeArm"]
            hand = self.indices[side + "Hand"]
            shoulder_pos, shoulder_rot = transform(arm)
            parent_rot = transform(self.parents[arm])[1]
            upper_rest = self.nodes[forearm]["translation"]
            lower_rest = self.nodes[hand]["translation"]
            target = add(center, target_offset)
            pole = (.75 if side == "Right" else -.75, -1., -.32)
            elbow, lower = solve_hinge(sub(target, shoulder_pos), pole, upper_rest, lower_rest)
            arm_rot = mul(aim_vector(rotate(shoulder_rot, upper_rest), elbow), shoulder_rot)
            lower_base = mul(arm_rot, pose[forearm, "rotation"])
            lower_rot = mul(aim_vector(rotate(lower_base, lower_rest), lower), lower_base)
            # Keep wrists aligned with forearms and reuse the GLB's hand/finger poses.
            changes[arm, "rotation"] = unit(mul(inverse(parent_rot), arm_rot))
            changes[forearm, "rotation"] = unit(mul(inverse(arm_rot), lower_rot))
            # Wrist orientation is a grip constraint, not the forearm's new
            # IK rotation. Previously solving the elbow also twisted the
            # closed fingers sideways through the receiver. Keep the source
            # finger articulation, with the support palm turned upward.
            hand_rotation = transform(hand)[1]
            if side == "Left":
                hand_rotation = mul(axis(math.pi * .5, 2), hand_rotation)
            changes[hand, "rotation"] = unit(mul(inverse(lower_rot), hand_rotation))

        return changes

    def clip(self, name, source_name, action=None, seconds=None, ground=False, deepen=False, stable=False):
        source = self.sources[source_name]
        out = {"name": name, "samplers": [], "channels": []}
        tracks = {}
        if action or ground:
            for channel in source["channels"]:
                target = channel["target"]
                sampler = source["samplers"][channel["sampler"]]
                tracks[target["node"], target["path"]] = self.values(sampler["output"])
            assert len({len(values) for values in tracks.values()}) == 1
            count = len(next(iter(tracks.values())))
            poses = [(self.overlay(tracks, i, action(i / (count - 1)), ground, deepen, stable)
                      if action else self.ground_stance(
                          {key: values[i] for key, values in tracks.items()}, deepen, stable))
                     for i in range(count)]
        timelines = {}
        for channel in source["channels"]:
            target = channel["target"]
            node, path = target["node"], target["path"]
            is_pelvis = self.nodes[node]["name"] == "Hips"
            if path != "rotation" and not (is_pelvis and path == "translation"):
                # Bind translations/scale and the root stay fixed. Authored pelvis
                # motion is retained for stance height and weight transfer in place.
                continue
            if self.nodes[node]["name"] == "Root":
                continue
            sampler = dict(source["samplers"][channel["sampler"]])
            input_idx = sampler["input"]
            if input_idx not in timelines:
                times = [key[0] for key in self.values(input_idx)]
                assert all(math.isfinite(t) and t >= 0. for t in times)
                # The browser export can contain two keys at the same
                # timestamp. Keep the last value and give Godot ordered keys.
                last_frame = {t: i for i, t in enumerate(times)}
                ordered_times = sorted(last_frame)
                keep = [last_frame[t] for t in ordered_times]
                if keep == list(range(len(times))):
                    keep = None
                if seconds is not None:
                    ordered_times = [t / ordered_times[-1] * seconds for t in ordered_times]
                new_input = (self.add_values([(t,) for t in ordered_times], "SCALAR")
                             if keep is not None or seconds is not None else input_idx)
                timelines[input_idx] = (new_input, keep)
            sampler["input"], keep = timelines[input_idx]
            values = None
            if (action or ground) and any((node, path) in pose for pose in poses):
                values = [pose.get((node, path), tracks[node, path][i]) for i, pose in enumerate(poses)]
            if keep is not None:
                if values is None:
                    values = self.values(sampler["output"])
                values = [values[i] for i in keep]
            if values is not None:
                if path == "rotation":
                    for i in range(1, len(values)):
                        if dot(values[i - 1], values[i]) < 0.:
                            values[i] = scale(values[i], -1.)
                sampler["output"] = self.add_values(values, "VEC4" if path == "rotation" else "VEC3")
            out["channels"].append({"sampler": len(out["samplers"]), "target": target})
            out["samplers"].append(sampler)
        self.doc["animations"].append(out)

    def outfit_mask(self):
        primitive = self.doc["meshes"][0]["primitives"][0]
        mask = []
        for x, y, z in self.values(primitive["attributes"]["POSITION"]):
            # Fade out above the collar and toward exposed forearms. The shader
            # also protects skin-coloured texels on the torso and thighs.
            collar = min(1., max(0., (.252 - y) / .07))
            arms = min(1., max(0., (.178 - abs(x)) / .035))
            mask.append((collar * arms, 0.))
        primitive["attributes"]["TEXCOORD_1"] = self.add_values(mask, "VEC2")

    def packed(self):
        used_accessors = set()
        for mesh in self.doc["meshes"]:
            for p in mesh["primitives"]:
                used_accessors.update(p["attributes"].values())
                used_accessors.add(p["indices"])
        used_accessors.update(s["inverseBindMatrices"] for s in self.doc["skins"])
        used_accessors.update(s[k] for clip in self.doc["animations"]
                              for s in clip["samplers"] for k in ("input", "output"))
        old_accessors, old_views = self.doc["accessors"], self.doc["bufferViews"]
        accessors = {old: new for new, old in enumerate(sorted(used_accessors))}
        used_views = {old_accessors[i]["bufferView"] for i in used_accessors}
        used_views.update(i["bufferView"] for i in self.doc["images"])
        views = {old: new for new, old in enumerate(sorted(used_views))}
        packed = bytearray()
        self.doc["bufferViews"] = []
        for old in views:
            v = dict(old_views[old])
            offset = v.get("byteOffset", 0)
            v["byteOffset"] = len(packed)
            packed.extend(self.binary[offset:offset + v["byteLength"]])
            packed.extend(b"\0" * (-len(packed) % 4))
            self.doc["bufferViews"].append(v)
        self.doc["accessors"] = [dict(old_accessors[i], bufferView=views[old_accessors[i]["bufferView"]])
                                 for i in accessors]
        for mesh in self.doc["meshes"]:
            for p in mesh["primitives"]:
                p["indices"] = accessors[p["indices"]]
                p["attributes"] = {k: accessors[v] for k, v in p["attributes"].items()}
        for skin in self.doc["skins"]:
            skin["inverseBindMatrices"] = accessors[skin["inverseBindMatrices"]]
        for image in self.doc["images"]:
            image["bufferView"] = views[image["bufferView"]]
        for clip in self.doc["animations"]:
            for sampler in clip["samplers"]:
                for key in ("input", "output"):
                    sampler[key] = accessors[sampler[key]]
        self.doc["buffers"] = [{"byteLength": len(packed)}]
        scene = json.dumps(self.doc, separators=(",", ":")).encode()
        scene += b" " * (-len(scene) % 4)
        return (struct.pack("<5I", 0x46546c67, 2, 28 + len(scene) + len(packed), len(scene), 0x4e4f534a)
                + scene + struct.pack("<2I", len(packed), 0x004e4942) + packed)


def build(source, output):
    raw = source.read_bytes()
    if hashlib.sha256(raw).hexdigest() != SOURCE_SHA256:
        raise ValueError("Expected the verified original rigged-model(1).glb")
    model = LilaAsset(raw)
    model.clip("AuroraIdle", "Idle", ground=True, stable=True)
    for name, source_name, pose in (
        ("ArmedIdle", "Idle", READY), ("ArmedWalk", "Walk", READY),
        ("ArmedRun", "Sprint", READY), ("ArmedStrafeLeft", "Jog Left", AIM),
        ("ArmedStrafeRight", "Jog Right", AIM), ("ArmedBackpedal", "Jog Backward", AIM),
        ("Crouch", "Crouch Idle", CROUCH), ("CrouchWalk", "Crouch Forward", CROUCH),
        ("Aim", "Idle", AIM), ("AimAWM", "Idle", AIM_AWM),
        ("Jump", "Jump", READY), ("Land", "Jump Land", READY),
    ):
        duration = {"Jump": .86, "Land": .37}.get(name)
        model.clip("Aurora" + name, source_name, lambda _, grip=pose: (grip, 0., 0.),
                   duration, ground=duration is None, deepen=name == "Crouch",
                   stable=name in ("ArmedIdle", "Aim", "AimAWM", "Crouch"))
    model.clip("AuroraHeal", "Bandage", seconds=3.0)
    model.clip("AuroraFreefall", "Jump", lambda p: (
        ((.34, -.08 + .025*math.sin(math.tau*p), .13),
         (-.34, -.08 - .025*math.sin(math.tau*p), .13)), .76, 0.))
    model.clip("AuroraParachute", "Idle", lambda p: (
        ((.166, .21 + .012*math.sin(math.tau*p), .075),
         (-.166, .21 - .012*math.sin(math.tau*p), .075)), -.08, 0.))
    for tag, grip, recoil, duration in (
        ("Fire", AIM, .022, .2), ("FireAWM", AIM_AWM, .062, .5)
    ):
        def firing(p):
            kick = smooth_window(p, .13, .64)
            return tuple(add(hand, (0., .024*kick, -recoil*kick)) for hand in grip), -.65*recoil*kick, 0.

        model.clip("Aurora" + tag, "Idle", firing, duration)

    def rifle_reload(p):
        lower = smooth_window(p, .47, .82)
        return (add(READY[0], (0., -.035*lower, -.03*lower)),
                add(READY[1], (-.04*lower, -.18*lower, -.14*lower))), .08*lower, 0.

    def sniper_reload(p):
        bolt = smooth_window(p, .22, .52)
        feed = smooth_window(p, .61, .91, .34)
        return (add(AIM_AWM[0], (.045*bolt, .085*bolt, -.077*bolt)),
                add(AIM_AWM[1], (-.08*feed, -.17*feed, -.1*feed))), .08*feed, 0.

    model.clip("AuroraReloadAR", "Idle", rifle_reload, 1.55)
    model.clip("AuroraReloadAWM", "Idle", sniper_reload, 3.1)

    def mp40_reload(p):
        reach = smooth_window(p, .21, .35, .06)
        magazine = smooth_window(p, .39, .69, .18)
        charge = smooth_window(p, .85, .99, .71)
        right = add(READY[0], (-.014*magazine, -.021*magazine, -.032*magazine))
        left = add(READY[1], (-.07*magazine + .036*charge,
                              -.20*magazine - .075*reach + .093*charge,
                              -.12*magazine - .09*reach - .08*charge))
        return (right, left), .095*magazine, -.04*reach

    model.clip("AuroraReloadMP40", "Idle", mp40_reload, 1.85)
    for direction, pitch, roll in (
        ("", .12, 0.), ("Front", .17, 0.), ("Back", -.16, 0.),
        ("Left", .02, -.19), ("Right", .02, .19)
    ):
        def hit(p):
            pulse = smooth_window(p, .21, .88)
            return READY, pitch*pulse, roll*pulse

        model.clip("AuroraHit" + direction, "Idle", hit, .39)
    model.outfit_mask()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(model.packed())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Prepare the verified Lila GLB for Godot")
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    build(args.source, args.output)
