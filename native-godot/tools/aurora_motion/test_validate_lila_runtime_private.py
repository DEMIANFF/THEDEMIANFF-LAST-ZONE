import json,struct,unittest
import validate_lila_runtime_private as gate

class RuntimeGateTest(unittest.TestCase):
    def fixture(self):
        return {"animations":[{"name":n} for n in sorted(gate.EXPECTED)],
            "skins":[{"joints":list(range(56))}],
            "meshes":[{"primitives":[{"attributes":{"POSITION":0,"TEXCOORD_1":2},
            "indices":1}]}],"accessors":[{"count":93572},{"count":95885*3},{"count":93572}]}
    def raw(self,d):
        j=json.dumps(d).encode()
        j+=b" "*(-len(j)%4)
        return struct.pack("<5I",0x46546c67,2,28+len(j),len(j),0x4e4f534a)+j+struct.pack("<2I",0,0x004e4942)
    def test_exact_contract(self):
        self.assertEqual(gate.inspect(self.raw(self.fixture()))["runtime_clips"],27)
    def test_missing_action_rejected(self):
        d=self.fixture();d["animations"].pop()
        with self.assertRaises(ValueError):gate.inspect(self.raw(d))
    def test_missing_outfit_mask_rejected(self):
        d=self.fixture();del d["meshes"][0]["primitives"][0]["attributes"]["TEXCOORD_1"]
        with self.assertRaises(ValueError):gate.inspect(self.raw(d))
    def test_bad_header_rejected(self):
        with self.assertRaises(ValueError):gate.inspect(b"bad")

    def test_all_private_revisions_are_pinned(self):
        self.assertEqual(set(gate.CANDIDATES.values()), {"Rev2", "Rev3", "Rev4", "Rev5", "Rev6", "Rev7", "Rev8"})
        self.assertEqual(len(gate.CANDIDATES),7)
        self.assertTrue(all(len(s)==64 for s in gate.CANDIDATES))

    def compact_fixture(self, joint_value=55, component=5121):
        d=self.fixture()
        d["meshes"][0]["primitives"][0]["attributes"]["JOINTS_0"]=3
        d["accessors"].append({"bufferView":0,"componentType":component,
                               "type":"VEC4","count":93572})
        payload=bytes([joint_value])*93572*4
        d["bufferViews"]=[{"buffer":0,"byteLength":len(payload)}]
        j=json.dumps(d).encode()
        j+=b" "*(-len(j)%4)
        return (struct.pack("<5I",0x46546c67,2,28+len(j)+len(payload),len(j),0x4e4f534a)
                +j+struct.pack("<2I",len(payload),0x004e4942)+payload)

    def test_rev4_joint_index_encoding(self):
        self.assertEqual(gate.inspect(self.compact_fixture(),True)["joints"],56)
        with self.assertRaises(ValueError):
            gate.inspect(self.compact_fixture(joint_value=56),True)
        with self.assertRaises(ValueError):
            gate.inspect(self.compact_fixture(component=5123),True)

    def test_direct_digit_support_not_just_bone_names(self):
        names=sorted(gate.HAND_DIGITS)
        joints=[(i,i,i,i) for i in range(len(names)) for _ in range(30)]
        weights=[(1.,0.,0.,0.)]*len(joints)
        counts=gate.digit_counts(names,joints,weights)
        self.assertEqual(min(counts.values()),30)
        with self.assertRaises(ValueError):
            gate.digit_counts(names,joints[:-1],weights[:-1])
        weights[0]=(1.,1.,0.,0.)
        with self.assertRaises(ValueError):
            gate.digit_counts(names,joints,weights)
