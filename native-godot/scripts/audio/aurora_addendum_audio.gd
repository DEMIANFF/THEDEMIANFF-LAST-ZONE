extends RefCounted

const MEDIA_PATH: String="res://assets/audio/aurora_v3_addendum/"


static func imported(file: String) -> AudioStream:
    var path: String=MEDIA_PATH+file
    return load(path) as AudioStream if ResourceLoader.exists(path,"AudioStream") else null
