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

    def test_auth_selection_independent_from_attestation(self):
        java=JAVA.read_text(encoding="utf-8")
        gd=GD.read_text(encoding="utf-8")
        for method in ("beginGoogleSignIn", "beginGuestSignIn"):
            body=java.split("public void "+method+"()",1)[1].split("runOnHostThread",1)[0]
            self.assertIn("isAuthSdkReady()",body)
            self.assertNotIn("isTransportReady()",body)
        self.assertIn("identity_waiting_app_check",java)
        self.assertIn("nextAttestationAt",java)
        self.assertIn('"online_ready":confirmed and transport_ready',gd)
        self.assertNotIn("DebugAppCheckProviderFactory",java)

    def test_frontend_preserves_native_auth_error_until_retry(self):
        front=(ROOT/"native-godot/scripts/ui/aurora_frontend.gd").read_text(encoding="utf-8")
        begin=front.split("func _begin_welcome_auth",1)[1].split("static func _can_resume_native_session",1)[0]
        poll=front.split("func _poll_login_state",1)[1].split("func _show_startup_diagnostics",1)[0]
        self.assertIn('_login_last_failure=""',begin)
        self.assertIn('if not _login_last_failure.is_empty():',poll)
        self.assertIn('str(session.get("reason","identity_pending"))',poll)
        self.assertIn('google_web_client_id_missing',front)
        self.assertIn('server_identity_unavailable',front)

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
