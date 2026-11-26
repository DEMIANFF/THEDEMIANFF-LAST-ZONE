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

    def test_both_private_revisions_are_pinned(self):
        self.assertEqual(set(gate.CANDIDATES.values()), {"Rev2", "Rev3"})
        self.assertEqual(len(gate.CANDIDATES),2)
        self.assertTrue(all(len(s)==64 for s in gate.CANDIDATES))
