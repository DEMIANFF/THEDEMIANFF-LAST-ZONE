extends RefCounted
# HMAC signed, room-scoped, expiring credentials. No Firebase token or UID.
static func verify(ticket: String,key: PackedByteArray,room: String,protocol: int,now: int) -> Dictionary:
    if ticket.length()>2048 or key.size()!=32:
        return {}
    var parts: PackedStringArray=ticket.split(".")
    if parts.size()!=2 or parts[1].length()!=64:
        return {}
    var received: PackedByteArray=parts[1].hex_decode()
    var crypto:=Crypto.new()
    var expected: PackedByteArray=crypto.hmac_digest(HashingContext.HASH_SHA256,key,parts[0].to_utf8_buffer())
    if received.size()!=32 or not crypto.constant_time_compare(received,expected):
        return {}
    var bytes: PackedByteArray=Marshalls.base64_to_raw(parts[0])
    var raw: Variant=JSON.parse_string(bytes.get_string_from_utf8())
    if not (raw is Dictionary):
        return {}
    var claims: Dictionary=raw
    if int(claims.get("v",-1))!=protocol or str(claims.get("room",""))!=room:
        return {}
    var expiry: int=int(claims.get("exp",0))
    var sub: String=str(claims.get("sub",""))
    var nonce: String=str(claims.get("nonce",""))
    if expiry<=now or expiry>now+60 or sub.length()!=64 or nonce.length()!=36:
        return {}
    if sub.hex_decode().size()!=32 or nonce.hex_decode().size()!=18:
        return {}
    return claims
