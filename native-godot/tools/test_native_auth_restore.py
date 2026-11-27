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

    def test_failed_google_link_never_auto_resumes_old_account(self):
        front=(ROOT/"native-godot/scripts/ui/aurora_frontend.gd").read_text(encoding="utf-8")
        poll=front.split("func _poll_login_state",1)[1].split("func _show_startup_diagnostics",1)[0]
        guard=poll.split("if _is_explicit_auth_failure(failure):",1)[1].split('if bool(session.get("authenticated",false)):',1)[0]
        self.assertIn("_login_last_failure=failure",guard)
        self.assertIn('_login_waiting_provider=""',guard)
        self.assertIn("_auto_resume_on_entry=false",guard)
        self.assertIn("CONTINUAR CON CUENTA ACTUAL",guard)
        self.assertIn("return",guard)
        self.assertLess(poll.index("if _is_explicit_auth_failure(failure):"),
                        poll.index("_resume_native_session_if_ready(session)"))
        helper=front.split("static func _is_explicit_auth_failure",1)[1].split("func _firebase_state_message",1)[0]
        for reason in ("google_account_already_in_use","google_link_failed",
                       "google_selection_failed","google_auth_failed"):
            self.assertIn('"'+reason+'"',helper)

    def test_transient_activity_and_atomic_profile_recovery(self):
        java=JAVA.read_text(encoding="utf-8")
        gd=GD.read_text(encoding="utf-8")
        init=java.split("private void ensureInitialized()",1)[1].split("private void refreshAppCheck()",1)[0]
        missing_activity=init.split("if (host == null)",1)[1].split("if (!EXPECTED_PACKAGE",1)[0]
        self.assertIn("initialized = false;",missing_activity)
        self.assertIn('"activity_unavailable"',missing_activity)
        self.assertIn('"activity_unavailable"',gd)
        recover=java.split("private void resolveServerIdentity(FirebaseUser user)",1)[1].split("public void refreshOnlineStats()",1)[0]
        self.assertIn('if (!uid.equals(activeUid))',recover)
        self.assertIn('onlineStats = "{}";',recover)
        self.assertIn('profileRevision = 0;',recover)
        self.assertIn('nextIdentityAttemptAt = SystemClock.elapsedRealtime() + 30000L;',recover)
        self.assertIn('failIdentity("profile_unavailable")',recover)
        self.assertIn('failIdentity("profile_mismatch")',recover)
        self.assertLess(recover.index('getHttpsCallable("getPlayerProfile")'),recover.index("officialPlayerId = expectedId;"))
        self.assertLess(recover.index("!expectedId.equals(returnedId)"),recover.index("officialPlayerId = expectedId;"))
        self.assertEqual(recover.count("officialPlayerId = expectedId;"),1)

    def test_matchmaking_cancel_invalidates_callbacks(self):
        java=JAVA.read_text(encoding="utf-8")
        front=(ROOT/"native-godot/scripts/ui/aurora_frontend.gd").read_text(encoding="utf-8")
        cancel=java.split("public void cancelOnlineMatch()",1)[1].split("public void beginOnlineMatch",1)[0]
        self.assertIn("matchGeneration++;",cancel)
        self.assertIn("matchBusy = false;",cancel)
        finish=java.split("private void finishOnlineMatch",1)[1].split("public String takeOnlineMatch",1)[0]
        self.assertLess(finish.index("generation != matchGeneration"),finish.index("matchResult = value"))
        self.assertIn(".withTimeout(25, TimeUnit.SECONDS)",java)
        self.assertIn("serial!=_online_search_serial",front)
        self.assertIn('native.call("cancelOnlineMatch")',front)
        self.assertIn('_online_match_notice(_online_search_error("search_timeout"))',front)

    def test_external_backend_is_build_time_only_and_uses_sdk(self):
        java=JAVA.read_text(encoding="utf-8")
        gradle=(ROOT/"firebase-godot-bridge/plugin/build.gradle.kts").read_text(encoding="utf-8")
        self.assertIn("getHttpsCallableFromUrl(new URL(origin",java)
        self.assertIn("AURORA_BACKEND_ORIGIN",gradle)
        self.assertIn("aurora_backend_origin",gradle)
        self.assertIn('failIdentity("backend_origin_missing")',java)
        self.assertIn("onrender",java)
        self.assertNotIn("getIdToken().getResult()",java)

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
