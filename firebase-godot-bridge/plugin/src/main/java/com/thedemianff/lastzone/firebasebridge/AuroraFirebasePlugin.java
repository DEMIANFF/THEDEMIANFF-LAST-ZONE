package com.thedemianff.lastzone.firebasebridge;

import android.app.Activity;
import android.os.SystemClock;

import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;
import androidx.credentials.Credential;
import androidx.credentials.CredentialManager;
import androidx.credentials.CredentialManagerCallback;
import androidx.credentials.CustomCredential;
import androidx.credentials.GetCredentialRequest;
import androidx.credentials.GetCredentialResponse;
import androidx.credentials.exceptions.GetCredentialException;

import com.google.android.libraries.identity.googleid.GetGoogleIdOption;
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential;
import com.google.firebase.FirebaseApp;
import com.google.firebase.appcheck.FirebaseAppCheck;
import com.google.firebase.appcheck.playintegrity.PlayIntegrityAppCheckProviderFactory;
import com.google.firebase.auth.AuthCredential;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthUserCollisionException;
import com.google.firebase.auth.FirebaseUser;
import com.google.firebase.auth.GoogleAuthProvider;
import com.google.firebase.functions.FirebaseFunctions;
import com.google.firebase.functions.HttpsCallableResult;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Source-only Godot Android v2 plugin for a FUTURE Gradle/App Check APK.
 *
 * This module is not in the current signed Vulkan preview APK.
 * The Firebase Auth/App Check SDK owns the tokens; neither access nor App Check
 * tokens are returned to GDScript, written to disk, or printed in logcat.
 * Callable requests use the Firebase SDK's authenticated and attested transport.
 */
public final class AuroraFirebasePlugin extends GodotPlugin {
    private static final String PLUGIN_NAME = "AuroraFirebase";
    private static final String EXPECTED_PACKAGE = "com.thedemianff.lastzone.nativepreview";
    private static final long TOKEN_MAX_AGE_MS = 25L * 60L * 1000L;

    private final AtomicBoolean authBusy = new AtomicBoolean(false);
    private final Object stateLock = new Object();

    private boolean initialized = false;
    private boolean configured = false;
    private boolean appCheckPending = false;
    private boolean tokenReady = false;
    private long tokenCheckedAt = 0;
    private long nextAttestationAt = 0;
    private int attestationFailures = 0;
    private String appCheckReason = "app_check_pending";
    private long nextIdentityAttemptAt = 0;
    private String lastError = "none";
    private String activeUid = "";
    private String officialPlayerId = "";
    private String accountName = "";
    private int profileRevision = 0;
    private String onlineStats = "{}";
    private String profileWriteStatus = "idle";
    private final AtomicBoolean statsBusy = new AtomicBoolean(false);
    private final AtomicBoolean profileWriteBusy = new AtomicBoolean(false);
    private String provider = "none";
    // One automatic identity recovery per Firebase Auth UID per process.
    // Retry requires an explicit login request; never flood callables.
    private String restoredAccountUid = "";

    public AuroraFirebasePlugin(Godot godot) {
        super(godot);
    }

    @NonNull
    @Override
    public String getPluginName() {
        return PLUGIN_NAME;
    }

    private void setError(String category) {
        synchronized (stateLock) {
            lastError = category;
        }
    }

    private static String json(JSONObject result) {
        return result.toString();
    }

    private void ensureInitialized() {
        synchronized (stateLock) {
            if (initialized) return;
            initialized = true;
        }
        Activity host = getActivity();
        if (host == null || !EXPECTED_PACKAGE.equals(host.getPackageName())) {
            setError("incorrect_android_package");
            return;
        }
        try {
            // This requires an exact-package Google Services configuration in
            // the future Gradle host, NOT the legacy WebView application's JSON.
            FirebaseApp app = FirebaseApp.initializeApp(host.getApplicationContext());
            if (app == null) {
                setError("google_services_configuration_missing");
                return;
            }
            FirebaseAppCheck.getInstance().installAppCheckProviderFactory(
                PlayIntegrityAppCheckProviderFactory.getInstance());
            synchronized (stateLock) {
                configured = true;
            }
            refreshAppCheck();
        } catch (RuntimeException invalidConfig) {
            setError("firebase_init_failed");
        }
    }

    private void refreshAppCheck() {
        synchronized (stateLock) {
            if (!configured || appCheckPending || SystemClock.elapsedRealtime() < nextAttestationAt) return;
            if (tokenReady && SystemClock.elapsedRealtime() - tokenCheckedAt < TOKEN_MAX_AGE_MS) {
                return;
            }
            tokenReady = false;
            appCheckPending = true;
        }
        try {
            FirebaseAppCheck.getInstance().getAppCheckToken(false)
                .addOnCompleteListener(result -> {
                    synchronized (stateLock) {
                        appCheckPending = false;
                        // Only observe whether the SDK actually obtained a
                        // token; never retain the token string in application
                        // code or pass it to Godot.
                        tokenReady = result.isSuccessful() && result.getResult() != null
                            && result.getResult().getToken() != null
                            && !result.getResult().getToken().isEmpty();
                        tokenCheckedAt = SystemClock.elapsedRealtime();
                        if (tokenReady) {
                            attestationFailures = 0;
                            nextAttestationAt = 0;
                            appCheckReason = "none";
                        } else {
                            attestationFailedLocked(result.getException());
                        }
                    }
                });
        } catch (RuntimeException problem) {
            synchronized (stateLock) {
                appCheckPending = false;
                tokenReady = false;
                attestationFailedLocked(problem);
            }
        }
    }

    // No raw exception message, attestation token or account data crosses JNI.
    private void attestationFailedLocked(Exception problem) {
        attestationFailures = Math.min(4, attestationFailures + 1);
        nextAttestationAt = SystemClock.elapsedRealtime()
            + Math.min(60000L, 5000L << (attestationFailures - 1));
        String message = problem == null || problem.getMessage() == null ? "" :
            problem.getMessage().toLowerCase(java.util.Locale.ROOT);
        appCheckReason = message.contains("403") || message.contains("attestation failed")
            ? "app_check_attestation_rejected"
            : message.contains("429") || message.contains("too many")
                ? "app_check_rate_limited" : "app_check_unavailable";
    }

    private boolean isAuthSdkReady() {
        ensureInitialized();
        synchronized (stateLock) { return configured; }
    }

    private boolean isTransportReady() {
        ensureInitialized();
        refreshAppCheck();
        synchronized (stateLock) {
            return configured && tokenReady;
        }
    }

    /**
     * This returns token availability on the client, NOT confirmation by the
     * backend. Cloud Functions with enforceAppCheck validates every request.
     */
    @UsedByGodot
    public String getBridgeStatus() {
        boolean ready = isTransportReady();
        try {
            JSONObject out = new JSONObject();
            out.put("api_version", 1);
            out.put("configured", configured);
            out.put("provider", "play_integrity");
            out.put("app_check", ready ? "token_ready" : "unverified");
            synchronized (stateLock) {
                out.put("app_check_reason", appCheckPending ? "app_check_pending" : appCheckReason);
            }
            out.put("auth_request_pending", authBusy.get());
            synchronized (stateLock) {
                out.put("reason", lastError);
            }
            return json(out);
        } catch (JSONException invalidJson) {
            return "{\"api_version\":1,\"configured\":false,\"app_check\":\"unverified\"}";
        }
    }

    /**
     * Pollable authenticated state. UID is only account metadata, never an
     * authorization input: Firebase SDK callables use the current session.
     */
    @UsedByGodot
    public String getSessionState() {
        boolean ready = isTransportReady();
        FirebaseUser current = configured ? FirebaseAuth.getInstance().getCurrentUser() : null;
        String uid = current == null ? "" : current.getUid();
        boolean restoreExistingIdentity = false;
        synchronized (stateLock) {
            if (!uid.equals(activeUid)) {
                activeUid = uid;
                officialPlayerId = "";
                accountName = "";
                profileRevision = 0;
                onlineStats = "{}";
                profileWriteStatus = "idle";
                provider = current == null ? "none" : current.isAnonymous() ? "guest" : "google";
                restoredAccountUid = "";
                nextIdentityAttemptAt = 0;
            }
            // FirebaseAuth persists its own real Google/Guest user. After
            // App Check is ready, fetch the server ID/profile once; never
            // call signInAnonymously on startup or fabricate a UID.
            if (ready && current != null && officialPlayerId.isEmpty()
                    && (!uid.equals(restoredAccountUid)
                        || SystemClock.elapsedRealtime() >= nextIdentityAttemptAt)
                    && authBusy.compareAndSet(false, true)) {
                restoredAccountUid = uid;
                nextIdentityAttemptAt = SystemClock.elapsedRealtime() + 30000L;
                restoreExistingIdentity = true;
            }
        }
        if (restoreExistingIdentity) {
            resolveServerIdentity(current);
        }
        synchronized (stateLock) {
            try {
                JSONObject out = new JSONObject();
                out.put("authenticated", current != null);
                out.put("provider", provider);
                out.put("uid_present", current != null);
                out.put("official_id", officialPlayerId);
                out.put("display_name", accountName);
                out.put("online_stats", new JSONObject(onlineStats));
                out.put("profile_revision", profileRevision);
                out.put("profile_write_status", profileWriteStatus);
                out.put("identity_confirmed", !officialPlayerId.isEmpty());
                out.put("app_check_ready", ready);
                out.put("app_check_reason", appCheckPending ? "app_check_pending" : appCheckReason);
                out.put("pending", authBusy.get());
                out.put("reason", lastError);
                return json(out);
            } catch (JSONException invalidJson) {
                return "{\"authenticated\":false,\"identity_confirmed\":false}";
            }
        }
    }

    /** Actual Firebase logout; no credentials are copied into Godot. */
    @UsedByGodot
    public void signOut() {
        ensureInitialized();
        if (!configured) {
            setError("firebase_not_initialized");
            return;
        }
        if (authBusy.get()) {
            setError("auth_request_pending");
            return;
        }
        try {
            FirebaseAuth.getInstance().signOut();
            synchronized (stateLock) {
                activeUid = "";
                restoredAccountUid = "";
                officialPlayerId = "";
                accountName = "";
                profileRevision = 0;
                onlineStats = "{}";
                profileWriteStatus = "idle";
                matchResult = "{\"status\":\"idle\"}";
                profileRevision = 0;
                onlineStats = "{}";
                profileWriteStatus = "idle";
                provider = "none";
                lastError = "none";
            }
        } catch (RuntimeException problem) {
            setError("firebase_logout_failed");
        }
    }

    // Only the single-use game ticket crosses JNI. Firebase Auth and App
    // Check credentials remain inside the official SDK.
    private final AtomicBoolean matchBusy = new AtomicBoolean(false);
    private String matchResult = "{\"status\":\"idle\"}";

    @UsedByGodot
    public void beginOnlineMatch(String mode, int protocol) {
        if (!matchBusy.compareAndSet(false, true)) return;
        synchronized (stateLock) { matchResult = "{\"status\":\"pending\"}"; }
        if (!isTransportReady() || FirebaseAuth.getInstance().getCurrentUser() == null) {
            finishOnlineMatch("{\"status\":\"unavailable\"}");
            return;
        }
        final String uid = FirebaseAuth.getInstance().getCurrentUser().getUid();
        try {
            FirebaseFunctions.getInstance("us-central1")
                .getHttpsCallable("requestOnlineMatch")
                .call(Map.of("mode", mode, "protocol", protocol))
                .addOnCompleteListener(task -> {
                    FirebaseUser current = FirebaseAuth.getInstance().getCurrentUser();
                    if (!task.isSuccessful() || current == null || !uid.equals(current.getUid())) {
                        finishOnlineMatch("{\"status\":\"unavailable\"}");
                        return;
                    }
                    try {
                        Object data = task.getResult().getData();
                        if (!(data instanceof Map)) throw new JSONException("invalid response");
                        Map<?, ?> result = (Map<?, ?>) data;
                        JSONObject out = new JSONObject();
                        out.put("status", "ready");
                        out.put("endpoint", result.get("endpoint"));
                        out.put("ticket", result.get("ticket"));
                        finishOnlineMatch(out.toString());
                    } catch (Exception problem) {
                        finishOnlineMatch("{\"status\":\"unavailable\"}");
                    }
                });
        } catch (RuntimeException problem) {
            finishOnlineMatch("{\"status\":\"unavailable\"}");
        }
    }

    private void finishOnlineMatch(String value) {
        synchronized (stateLock) { matchResult = value; }
        matchBusy.set(false);
    }

    @UsedByGodot
    public String takeOnlineMatch() {
        synchronized (stateLock) {
            String value = matchResult;
            if (!matchBusy.get()) matchResult = "{\"status\":\"idle\"}";
            return value;
        }
    }

    /** Guest does not overwrite a linked Google account or create a fake ID. */
    @UsedByGodot
    public void beginGuestSignIn() {
        // Auth can request the real SDK credential even while attestation
        // is pending; protected identity and matchmaking calls still require it.
        if (!isAuthSdkReady()) {
            setError("firebase_not_initialized");
            return;
        }
        if (!authBusy.compareAndSet(false, true)) {
            setError("another_auth_request_pending");
            return;
        }
        runOnHostThread(() -> {
            try {
                FirebaseAuth auth = FirebaseAuth.getInstance();
                if (auth.getCurrentUser() != null) {
                    resolveServerIdentity(auth.getCurrentUser());
                    return;
                }
                auth.signInAnonymously().addOnCompleteListener(task -> {
                    if (task.isSuccessful() && task.getResult() != null) {
                        resolveServerIdentity(task.getResult().getUser());
                    } else {
                        setError("guest_auth_failed");
                        authBusy.set(false);
                    }
                });
            } catch (RuntimeException e) {
                setError("guest_auth_failed");
                authBusy.set(false);
            }
        });
    }

    /** Google Identity Credential Manager; link anonymous UID instead of replacing it. */
    @UsedByGodot
    public void beginGoogleSignIn() {
        // Auth can request the real SDK credential even while attestation
        // is pending; protected identity and matchmaking calls still require it.
        if (!isAuthSdkReady()) {
            setError("firebase_not_initialized");
            return;
        }
        if (!authBusy.compareAndSet(false, true)) {
            setError("another_auth_request_pending");
            return;
        }
        runOnHostThread(() -> {
            Activity host = getActivity();
            if (host == null) {
                setError("activity_unavailable");
                authBusy.set(false);
                return;
            }
            int clientRes = host.getResources().getIdentifier(
                "default_web_client_id", "string", host.getPackageName());
            if (clientRes == 0 || host.getString(clientRes).isEmpty()) {
                setError("google_web_client_id_missing");
                authBusy.set(false);
                return;
            }
            try {
                GetGoogleIdOption option = new GetGoogleIdOption.Builder()
                    .setServerClientId(host.getString(clientRes))
                    .setFilterByAuthorizedAccounts(false)
                    .setAutoSelectEnabled(false)
                    .build();
                GetCredentialRequest request = new GetCredentialRequest.Builder()
                    .addCredentialOption(option)
                    .build();
                CredentialManager.create(host).getCredentialAsync(
                    host, request, null, ContextCompat.getMainExecutor(host),
                    new CredentialManagerCallback<GetCredentialResponse, GetCredentialException>() {
                        @Override
                        public void onResult(GetCredentialResponse response) {
                            Credential credential = response.getCredential();
                            if (!(credential instanceof CustomCredential)) {
                                setError("google_credential_type_invalid");
                                authBusy.set(false);
                                return;
                            }
                            CustomCredential custom = (CustomCredential) credential;
                            if (!GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL
                                    .equals(custom.getType())) {
                                setError("google_credential_type_invalid");
                                authBusy.set(false);
                                return;
                            }
                            try {
                                // The token only flows into FirebaseAuth. It is
                                // never exposed to Godot, logs or application disk.
                                String idToken = GoogleIdTokenCredential
                                    .createFrom(custom.getData()).getIdToken();
                                AuthCredential firebaseCredential =
                                    GoogleAuthProvider.getCredential(idToken, null);
                                FirebaseAuth auth = FirebaseAuth.getInstance();
                                FirebaseUser current = auth.getCurrentUser();
                                if (current != null && current.isAnonymous()) {
                                    current.linkWithCredential(firebaseCredential)
                                        .addOnCompleteListener(task -> {
                                            if (task.isSuccessful() && task.getResult() != null) {
                                                resolveServerIdentity(task.getResult().getUser());
                                            } else {
                                                // Collision never silently switches
                                                // to another account and loses guest UID.
                                                setError(task.getException()
                                                    instanceof FirebaseAuthUserCollisionException
                                                        ? "google_account_already_in_use"
                                                        : "google_link_failed");
                                                authBusy.set(false);
                                            }
                                        });
                                } else {
                                    auth.signInWithCredential(firebaseCredential)
                                        .addOnCompleteListener(task -> {
                                            if (task.isSuccessful() && task.getResult() != null) {
                                                resolveServerIdentity(task.getResult().getUser());
                                            } else {
                                                setError("google_auth_failed");
                                                authBusy.set(false);
                                            }
                                        });
                                }
                            } catch (RuntimeException problem) {
                                setError("google_token_invalid");
                                authBusy.set(false);
                            }
                        }

                        @Override
                        public void onError(@NonNull GetCredentialException problem) {
                            setError("google_selection_failed");
                            authBusy.set(false);
                        }
                    });
            } catch (RuntimeException problem) {
                setError("google_selection_failed");
                authBusy.set(false);
            }
        });
    }

    private void resolveServerIdentity(FirebaseUser user) {
        if (user == null) {
            setError("firebase_session_missing");
            authBusy.set(false);
            return;
        }
        String uid = user.getUid();
        synchronized (stateLock) {
            activeUid = uid;
            officialPlayerId = "";
            accountName = "";
            provider = user.isAnonymous() ? "guest" : "google";
            lastError = "identity_pending";
            restoredAccountUid = uid;
            nextIdentityAttemptAt = SystemClock.elapsedRealtime() + 30000L;
        }
        if (!isTransportReady()) {
            synchronized (stateLock) {
                lastError = "identity_waiting_app_check";
                restoredAccountUid = "";
            }
            authBusy.set(false);
            return;
        }
        // Request body contains no UID or chosen ID. Existing callable uses
        // request.auth.uid and a Firestore transaction for ID 00001..99999.
        FirebaseFunctions.getInstance("us-central1")
            .getHttpsCallable("ensurePlayerIdentity")
            .call()
            .addOnCompleteListener(task -> {
                if (!uid.equals(FirebaseAuth.getInstance().getCurrentUser() == null
                        ? "" : FirebaseAuth.getInstance().getCurrentUser().getUid())) {
                    setError("account_switched");
                    authBusy.set(false);
                    return;
                }
                Object payload = task.isSuccessful() && task.getResult() != null
                    ? task.getResult().getData() : null;
                Object value = payload instanceof Map
                    ? ((Map<?, ?>) payload).get("number") : null;
                int number = value instanceof Number ? ((Number) value).intValue() : 0;
                if (number < 1 || number > 99999) {
                    setError("server_identity_unavailable");
                    authBusy.set(false);
                    return;
                }
                synchronized (stateLock) {
                    officialPlayerId = String.format(java.util.Locale.ROOT, "%05d", number);
                    lastError = "profile_loading";
                }
                // getPlayerProfile is App Check enforced on the backend.
                FirebaseFunctions.getInstance("us-central1")
                    .getHttpsCallable("getPlayerProfile")
                    .call()
                    .addOnCompleteListener(info -> {
                        if (!uid.equals(FirebaseAuth.getInstance().getCurrentUser() == null
                                ? "" : FirebaseAuth.getInstance().getCurrentUser().getUid())) {
                            setError("account_switched");
                            authBusy.set(false);
                            return;
                        }
                        Object response = info.isSuccessful() && info.getResult() != null
                            ? info.getResult().getData() : null;
                        if (response instanceof Map) {
                            Object name = ((Map<?, ?>) response).get("displayName");
                            Object returnedId = ((Map<?, ?>) response).get("playerId");
                            if (name instanceof String && returnedId instanceof String &&
                                    returnedId.equals(officialPlayerId)) {
                                synchronized (stateLock) {
                                    accountName = (String) name;
                                    Object revision = ((Map<?, ?>) response).get("revision");
                                    profileRevision = revision instanceof Number ? ((Number)revision).intValue() : 0;
                                    lastError = "none";
                                }
                            } else {
                                setError("profile_mismatch");
                            }
                        } else {
                            setError("profile_unavailable");
                        }
                        authBusy.set(false);
                        refreshOnlineStats();
                    });
            });
    }

    @UsedByGodot
    public void refreshOnlineStats() {
        if (!isTransportReady() || !statsBusy.compareAndSet(false, true)) return;
        FirebaseUser user=FirebaseAuth.getInstance().getCurrentUser();
        if (user==null) {statsBusy.set(false);return;}
        final String uid=user.getUid();
        FirebaseFunctions.getInstance("us-central1").getHttpsCallable("getOnlineStats").call()
            .addOnCompleteListener(task->{
                try {
                    FirebaseUser current=FirebaseAuth.getInstance().getCurrentUser();
                    if(current==null||!uid.equals(current.getUid())||!task.isSuccessful()) return;
                    Object payload=task.getResult().getData();
                    if(!(payload instanceof Map))return;
                    Map<?,?> values=(Map<?,?>)payload;
                    JSONObject next=new JSONObject();
                    for(String field:new String[]{"played","wins","kills","hits","abandoned","seconds"}) {
                        Object value=values.get(field);
                        if(!(value instanceof Number)||((Number)value).longValue()<0)return;
                        next.put(field,((Number)value).longValue());
                    }
                    synchronized(stateLock){if(uid.equals(activeUid))onlineStats=next.toString();}
                } catch(JSONException invalid) {
                    // Never replace verified stats with fabricated data.
                } finally {statsBusy.set(false);}
            });
    }

    @UsedByGodot
    public void saveOnlineDisplayName(String name) {
        if(!isTransportReady()||!profileWriteBusy.compareAndSet(false,true))return;
        FirebaseUser user=FirebaseAuth.getInstance().getCurrentUser();
        if(user==null){profileWriteBusy.set(false);return;}
        final String uid=user.getUid();
        final int revision;
        synchronized(stateLock){revision=profileRevision;profileWriteStatus="pending";}
        FirebaseFunctions.getInstance("us-central1").getHttpsCallable("setPlayerDisplayName")
            .call(Map.of("displayName",name,"expectedRevision",revision))
            .addOnCompleteListener(task->{
                try {
                    FirebaseUser current=FirebaseAuth.getInstance().getCurrentUser();
                    if(current==null||!uid.equals(current.getUid()))return;
                    Object payload=task.isSuccessful()?task.getResult().getData():null;
                    synchronized(stateLock){
                        if(!uid.equals(activeUid))return;
                        if(payload instanceof Map) {
                            Map<?,?> values=(Map<?,?>)payload;
                            Object returnedName=values.get("displayName"),returnedId=values.get("playerId"),returnedRevision=values.get("revision");
                            if(returnedName instanceof String&&officialPlayerId.equals(returnedId)&&returnedRevision instanceof Number){
                                accountName=(String)returnedName;profileRevision=((Number)returnedRevision).intValue();
                                profileWriteStatus="saved";return;
                            }
                        }
                        profileWriteStatus="failed";
                    }
                } finally {profileWriteBusy.set(false);}
            });
    }
}
