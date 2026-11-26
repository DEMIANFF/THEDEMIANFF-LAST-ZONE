import struct
import unittest
from unittest.mock import patch
import validate_lila_rebind_private as gate


class ReviewGateTest(unittest.TestCase):
    def fixture(self):
        names = sorted(gate.DIGITS | gate.CONTROL_JOINTS | {"Hips"})
        active = [i for i,n in enumerate(names) if n not in gate.CONTROL_JOINTS]
        joints = [(active[i % len(active)],)*4 for i in range(93572)]
        weights = [(1.,0.,0.,0.)]*len(joints)
        return names, joints, weights

    def test_all_digits_have_weights(self):
        names,j,w = self.fixture()
        counts = gate.validate_skin(names,j,w)
        self.assertTrue(all(counts[n] > 0 for n in gate.DIGITS))
        self.assertTrue(all(counts[n] == 0 for n in gate.CONTROL_JOINTS))

    def test_unweighted_digit_rejected(self):
        names,j,w = self.fixture()
        missing = names.index("LeftHandThumb1")
        replacement = names.index("Hips")
        j = [tuple(replacement if i == missing else i for i in row) for row in j]
        with self.assertRaises(ValueError):
            gate.validate_skin(names,j,w)

    def test_bad_weight_rejected(self):
        names,j,w = self.fixture()
        w[0] = (1.,1.,0.,0.)
        with self.assertRaises(ValueError):
            gate.validate_skin(names,j,w)

    def test_bad_index_rejected(self):
        names,j,w = self.fixture()
        j[0] = (len(names),)*4
        with self.assertRaises(ValueError):
            gate.validate_skin(names,j,w)

    def test_accessor_bounds_rejected(self):
        doc = {"accessors":[{"bufferView":0,"componentType":5126,"type":"VEC4","count":2}],
               "bufferViews":[{"byteLength":16}]}
        with self.assertRaises(ValueError):
            list(gate.rows(doc,b"\x00"*16,0))

    def test_bad_glb_rejected(self):
        with self.assertRaises(ValueError):
            gate.parse_glb(b"bad")


if __name__ == "__main__":
    unittest.main()
