#!/usr/bin/env python3
"""Contract tests for native Firebase Auth reuse and true sign-out.

Runs on each push without needing credentials or exposing any tokens.
Full SDK compilation still requires the separate Gradle diagnostic path.
"""
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]
JAVA=ROOT/"firebase-godot-bridge/plugin/src/main/java/com/thedemianff/lastzone/firebasebridge/AuroraFirebasePlugin.java"
GD=ROOT/"native-godot/scripts/persistence/aurora_firebase_bridge.gd"

class SessionRecoveryContract(unittest.TestCase):
    def test_native_restores_existing_identity_once(self):
        java=JAVA.read_text(encoding="utf-8")
        self.assertIn("FirebaseAuth.getInstance().getCurrentUser()",java)
        self.assertIn("restoredAccountUid",java)
        self.assertIn("!uid.equals(restoredAccountUid)",java)
        self.assertIn("authBusy.compareAndSet(false, true)",java)
        self.assertIn("resolveServerIdentity(current)",java)
        self.assertIn("if (ready && current != null",java)
        self.assertIn('getHttpsCallable("ensurePlayerIdentity")',java)
        self.assertIn('getHttpsCallable("getPlayerProfile")',java)

    def test_logout_does_not_fabricate_identity(self):
        java=JAVA.read_text(encoding="utf-8")
        gd=GD.read_text(encoding="utf-8")
        self.assertIn("public void signOut()",java)
        self.assertIn("FirebaseAuth.getInstance().signOut()",java)
        self.assertIn('restoredAccountUid = "";',java)
        self.assertIn('officialPlayerId = "";',java)
        self.assertIn("static func request_sign_out()",gd)
        self.assertIn('payload.get("authenticated")==false',gd)
        self.assertIn('"signed_out":true',gd)
        self.assertNotIn("getIdToken().getResult()",gd)

if __name__=="__main__":
    unittest.main()
