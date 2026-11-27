extends RefCounted
## V75.77 - fail-closed Godot transport for the native Android Firebase
## plugin. Only the separate Gradle APK includes native SDK + Google Services.
## A transport-ready state is not a server-authenticated account.
## Never store, expose or print Firebase Auth tokens or App Check tokens.
const PLUGIN_NAME: String="AuroraFirebase"
const API_VERSION: int=1

static func contract() -> Dictionary:
    return {
        "singleton":PLUGIN_NAME,
        "api_version":API_VERSION,
        "status_method":"getBridgeStatus",
        "guest_method":"beginGuestSignIn",
        "google_method":"beginGoogleSignIn",
        "session_method":"getSessionState",
        "signout_method":"signOut",
        "requires_gradle":true,
        "requires_app_check":true
    }


static func _blocked(why: String) -> Dictionary:
    return {
        "ready":false,
        "reason":why,
        "firebase_auth":"not_connected",
        "app_check":"not_verified",
        "player_id":"not_assigned"
    }


static func status() -> Dictionary:
    if not OS.has_feature("android"):
        return _blocked("android_device_required")
    if not Engine.has_singleton(PLUGIN_NAME):
        return _blocked("android_plugin_missing")
    var native: Object=Engine.get_singleton(PLUGIN_NAME)
    # Godot's Android plugin is a JNISingleton, whose dynamic Java methods
    # are NOT guaranteed to appear in Object.has_method(). Godot 4.7 exposes
    # JNISingleton.has_java_method(StringName) for this exact contract check.
    if not native.has_method("has_java_method"):
        return _blocked("android_jni_method_api_unavailable")
    for method_name in ["getBridgeStatus","beginGuestSignIn",
            "beginGoogleSignIn","getSessionState"]:
        if not bool(native.call("has_java_method",StringName(method_name))):
            # Only a public method name is exposed; no tokens or private data.
            return _blocked("plugin_contract_incomplete:"+method_name)
    var encoded: Variant=native.call("getBridgeStatus")
    if not (encoded is String):
        return _blocked("plugin_status_invalid")
    var state: Variant=JSON.parse_string(encoded)
    if not (state is Dictionary):
        return _blocked("plugin_status_invalid")
    var details: Dictionary=state
    if (int(details.get("api_version",-1))!=API_VERSION or
            details.get("provider")!="play_integrity"):
        return _blocked("firebase_configuration_incomplete")
    if details.get("configured")!=true:
        var reason: String=str(details.get("reason",""))
        if reason not in ["activity_unavailable","incorrect_android_package",
                "google_services_configuration_missing","firebase_init_failed"]:
            reason="firebase_configuration_incomplete"
        return _blocked(reason)
    # A token returned by the SDK is NOT a server-verified attestation.
    # Only protected Firebase Functions can perform that validation.
    if details.get("app_check")!="token_ready":
        var pending: Dictionary=_blocked(str(details.get("app_check_reason","app_check_unverified")))
        pending["auth_available"]=true
        return pending
    # This only enables a future *attempt* to authenticate: it is not a
    # claim that any Google or guest session has already been established.
    return {
        "ready":true,
        "auth_available":true,
        "reason":"native_transport_ready",
        "firebase_auth":"session_not_asserted",
        "app_check":"token_ready",
        "player_id":"not_assigned"
    }


static func request_sign_in(provider: String) -> Dictionary:
    if not (provider in ["guest","google"]):
        return {"queued":false,"authenticated":false,"reason":"invalid_provider"}
    var current: Dictionary=status()
    if not bool(current.get("auth_available",false)):
        return {
            "queued":false,
            "authenticated":false,
            "reason":current.get("reason","not_available")
        }
    # Only an installed and verified Android plugin may initiate a request.
    # The actual auth result will arrive asynchronously from native code.
    var native: Object=Engine.get_singleton(PLUGIN_NAME)
    if provider=="guest":
        native.call("beginGuestSignIn")
    else:
        native.call("beginGoogleSignIn")
    return {"queued":true,"authenticated":false,"reason":"request_dispatched"}


## This metadata is for display only, never an input authorizing Firestore
## writes. Firebase callables must verify Auth UID and App Check server-side.
static func session_state() -> Dictionary:
    var current: Dictionary=status()
    if not bool(current.get("auth_available",false)):
        return {
            "authenticated":false,
            "identity_confirmed":false,
            "reason":current.get("reason","not_available")
        }
    var native: Object=Engine.get_singleton(PLUGIN_NAME)
    var raw: Variant=native.call("getSessionState")
    if not (raw is String):
        return {"authenticated":false,"identity_confirmed":false,
            "reason":"invalid_native_session"}
    var parsed: Variant=JSON.parse_string(raw)
    if not (parsed is Dictionary):
        return {"authenticated":false,"identity_confirmed":false,
            "reason":"invalid_native_session"}
    var payload: Dictionary=parsed
    if payload.get("authenticated")!=true:
        # Credential Manager may still be open or FirebaseAuth may still be
        # awaiting its network response. Preserve the SDK's actual pending
        # flag so the frontend does not clear the user's login intent.
        return {"authenticated":false,"identity_confirmed":false,
            "online_ready":false,"pending":payload.get("pending")==true,
            "reason":str(payload.get("reason","not_signed_in"))}
    var provider: String=str(payload.get("provider",""))
    if not (provider in ["guest","google"]):
        return {"authenticated":false,"identity_confirmed":false,
            "reason":"provider_invalid"}
    var id: String=str(payload.get("official_id",""))
    var confirmed: bool=payload.get("identity_confirmed")==true
    var transport_ready: bool=bool(current.get("ready",false))
    if confirmed:
        if (id.length()!=5 or not id.is_valid_int() or
                int(id)<1 or int(id)>99999 or
                str(int(id)).pad_zeros(5)!=id):
            return {"authenticated":true,"identity_confirmed":false,
                "provider":provider,"reason":"official_id_invalid"}
    var name: String=str(payload.get("display_name",""))
    return {
        "authenticated":true,
        "identity_confirmed":confirmed,
        "online_ready":confirmed and transport_ready,
        "app_check_reason":str(payload.get("app_check_reason","app_check_unverified")),
        "official_id":id if confirmed else "",
        "display_name":name if confirmed else "",
        "online_stats":payload.get("online_stats",{}) if confirmed and payload.get("online_stats",{}) is Dictionary else {},
        "profile_write_status":str(payload.get("profile_write_status","idle")),
        "provider":provider,
        "pending":payload.get("pending")==true,
        "reason":str(payload.get("reason","identity_pending"))
    }


## Real Firebase Auth sign-out is allowed even if App Check cannot refresh,
## because local sign-out must work offline. Never pretend a provider was
## disconnected: verify the Java SDK's getSessionState after calling it.
static func request_sign_out() -> Dictionary:
    if not OS.has_feature("android") or not Engine.has_singleton(PLUGIN_NAME):
        return {"signed_out":false,"reason":"android_plugin_missing"}
    var native: Object=Engine.get_singleton(PLUGIN_NAME)
    if not native.has_method("has_java_method") or not bool(
            native.call("has_java_method",&"signOut")):
        return {"signed_out":false,"reason":"native_signout_unavailable"}
    native.call("signOut")
    var raw: Variant=native.call("getSessionState")
    var payload: Variant=JSON.parse_string(raw) if raw is String else null
    if payload is Dictionary and payload.get("authenticated")==false:
        return {"signed_out":true,"reason":"native_session_closed"}
    return {"signed_out":false,"reason":"native_session_still_active"}
