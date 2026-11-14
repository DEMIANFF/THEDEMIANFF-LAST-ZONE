extends RefCounted
## V75.74 - fail-closed adapter for a FUTURE Godot Android v2 Firebase plugin.
## This release has NO native plugin, no Firebase Auth, no Google session, no
## App Check attestation, no callable traffic and no cloud restore.
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
    for method_name in ["getBridgeStatus","beginGuestSignIn","beginGoogleSignIn"]:
        if not native.has_method(method_name):
            return _blocked("plugin_contract_incomplete")
    var encoded: Variant=native.call("getBridgeStatus")
    if not (encoded is String):
        return _blocked("plugin_status_invalid")
    var state: Variant=JSON.parse_string(encoded)
    if not (state is Dictionary):
        return _blocked("plugin_status_invalid")
    var details: Dictionary=state
    if (int(details.get("api_version",-1))!=API_VERSION or
            details.get("provider")!="play_integrity" or
            details.get("configured")!=true):
        return _blocked("firebase_configuration_incomplete")
    # A plugin loaded without a successful attestation is not trusted.
    if details.get("app_check")!="verified":
        return _blocked("app_check_unverified")
    # This only enables a future *attempt* to authenticate: it is not a
    # claim that any Google or guest session has already been established.
    return {
        "ready":true,
        "reason":"native_transport_ready",
        "firebase_auth":"session_not_asserted",
        "app_check":"verified",
        "player_id":"not_assigned"
    }


static func request_sign_in(provider: String) -> Dictionary:
    if not (provider in ["guest","google"]):
        return {"queued":false,"authenticated":false,"reason":"invalid_provider"}
    var current: Dictionary=status()
    if not bool(current.get("ready",false)):
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
