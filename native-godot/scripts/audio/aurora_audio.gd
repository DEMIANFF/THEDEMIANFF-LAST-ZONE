extends Node3D
## Original offline sound design. Deterministic synthesized PCM is cached once,
## and voices are pooled; no runtime AudioStreamGenerator callbacks on mobile.
## Sound library is original, not borrowed from other games.
const MIX_RATE: int=22050
const CONFIG_PATH: String="user://aurora_audio.cfg"
const VOICES: int=8

var _samples: Dictionary={}
var _voices: Array[AudioStreamPlayer]=[]
var _world_voices: Array[AudioStreamPlayer3D]=[]
var _world_cursor: int=0
var _cursor: int=0
var _ambience: AudioStreamPlayer
var _foot_index: int=0
var _sound_enabled: bool=true


func _ready() -> void:
    _ensure_bus("AuroraSFX")
    _ensure_bus("AuroraAmbience")
    _load_settings()
    var recipes: Dictionary={
        "ar_fire":.25,
        "awm_fire":.62,
        "impact":.24,
        "hit":.29,
        "reload":.40,
        "foot_stone":.24,
        "foot_snow":.27,
        "heal":.54,
        "jump":.22,
        "ui":.14,
        "wind":4.0
    }
    for name in recipes:
        _samples[name]=_render(name,float(recipes[name]))
    for i in range(VOICES):
        var voice:=AudioStreamPlayer.new()
        voice.name="SoundVoice"+str(i)
        voice.bus="AuroraSFX"
        voice.volume_db=-9.0
        add_child(voice)
        _voices.append(voice)
    for i in range(5):
        var outdoor:=AudioStreamPlayer3D.new()
        outdoor.name="SpatialWeapon"+str(i)
        outdoor.bus="AuroraSFX"
        outdoor.volume_db=-11.0
        outdoor.unit_size=8.0
        outdoor.max_distance=90.0
        add_child(outdoor)
        _world_voices.append(outdoor)
    _ambience=AudioStreamPlayer.new()
    _ambience.name="AuroraWindAmbience"
    _ambience.bus="AuroraAmbience"
    _ambience.volume_db=-22.0
    _ambience.stream=_samples["wind"]
    add_child(_ambience)
    if _sound_enabled:
        _ambience.play()


func _ensure_bus(bus_name: String) -> void:
    if AudioServer.get_bus_index(bus_name)>=0:
        return
    AudioServer.add_bus()
    var index: int=AudioServer.bus_count-1
    AudioServer.set_bus_name(index,bus_name)
    AudioServer.set_bus_send(index,"Master")


func _load_settings() -> void:
    var cfg:=ConfigFile.new()
    if cfg.load(CONFIG_PATH)!=OK:
        return
    _sound_enabled=bool(cfg.get_value("audio","enabled",true))
    set_mix("AuroraSFX",float(cfg.get_value("audio","effects",.75)))
    set_mix("AuroraAmbience",float(cfg.get_value("audio","ambience",.55)))


func set_mix(bus_name: String,level: float) -> void:
    if bus_name!="AuroraSFX" and bus_name!="AuroraAmbience":
        return
    var index: int=AudioServer.get_bus_index(bus_name)
    if index<0:
        return
    var amount: float=clampf(level,0.0,1.0)
    AudioServer.set_bus_volume_db(index,linear_to_db(maxf(.001,amount)))
    AudioServer.set_bus_mute(index,amount<=.001)


func play_event(kind: String,pitch: float=1.0) -> void:
    if not _sound_enabled or not _samples.has(kind):
        return
    var voice: AudioStreamPlayer=_voices[_cursor]
    _cursor=(_cursor+1)%_voices.size()
    voice.stop()
    voice.stream=_samples[kind]
    voice.pitch_scale=clampf(pitch,.78,1.23)
    voice.volume_db=-12.0 if kind=="impact" else -8.0
    voice.play()


func play_world_shot(at: Vector3) -> void:
    if not _sound_enabled:
        return
    var source: AudioStreamPlayer3D=_world_voices[_world_cursor]
    _world_cursor=(_world_cursor+1)%_world_voices.size()
    source.stop()
    source.global_position=at+Vector3.UP*1.35
    source.stream=_samples["ar_fire"]
    source.pitch_scale=.91+float(_world_cursor%4)*.04
    source.play()


func play_footstep(on_stone: bool) -> void:
    _foot_index+=1
    var variation: float=.94+float(_foot_index%5)*.026
    play_event("foot_stone" if on_stone else "foot_snow",variation)


func set_enabled(enabled: bool) -> void:
    _sound_enabled=enabled
    if _ambience:
        if enabled and not _ambience.playing:
            _ambience.play()
        elif not enabled:
            _ambience.stop()
    if not enabled:
        for voice in _voices:
            voice.stop()
        for voice in _world_voices:
            voice.stop()


func _render(kind: String,duration: float) -> AudioStreamWAV:
    var count: int=maxi(64,int(ceil(duration*float(MIX_RATE))))
    var pcm:=PackedByteArray()
    pcm.resize(count*2)
    var rng:=RandomNumberGenerator.new()
    rng.seed=175780+int(duration*10000)+kind.hash()
    var low: float=0.0
    var middle: float=0.0
    for i in range(count):
        var t: float=float(i)/float(MIX_RATE)
        var progress: float=float(i)/float(count)
        var white: float=rng.randf_range(-1.0,1.0)
        low=lerpf(low,white,.032)
        middle=lerpf(middle,white,.28)
        var high: float=white-middle
        var pulse: float=sin(TAU*(85.0*t+35.0*t*t))
        var value: float=0.0
        match kind:
            "ar_fire":
                value=.8*high*exp(-t*32.0)+.48*pulse*exp(-t*20.0)+.24*low*exp(-t*11.0)
            "awm_fire":
                value=.96*high*exp(-t*18.0)+.66*sin(TAU*(72.0*t+38.0*t*t))*exp(-t*7.0)
                value+=.25*middle*exp(-t*5.0)
            "impact":
                value=.65*middle*exp(-t*32.0)+.29*sin(TAU*145.0*t)*exp(-t*25.0)
            "hit":
                value=.37*high*exp(-t*17.0)+.40*sin(TAU*(225.0-110*t)*t)*exp(-t*10.0)
            "reload":
                var click_a: float=exp(-pow((t-.07)/.014,2))
                var click_b: float=exp(-pow((t-.26)/.017,2))
                value=middle*(click_a*.65+click_b*.58)+low*exp(-t*5.0)*.14
            "foot_stone":
                value=high*exp(-t*22.0)*.30+middle*exp(-t*37.0)*.34
            "foot_snow":
                value=high*exp(-t*15.0)*.33+low*exp(-t*11.0)*.26
            "heal":
                value=.21*sin(TAU*(330.0*t+240.0*t*t))*sin(PI*progress)
                value+=.10*middle*sin(PI*progress)
            "jump":
                value=.19*low*exp(-t*14.0)+.14*sin(TAU*(160.0-100.0*t)*t)*exp(-t*16.0)
            "ui":
                value=.14*sin(TAU*650.0*t)*exp(-t*31.0)
                value+=.08*sin(TAU*970.0*t)*exp(-t*34.0)
            "wind":
                var envelope: float=minf(1.0,minf(t*2.0,(duration-t)*2.0))
                value=(low*.40+middle*.045)*maxf(0.0,envelope)
        value=clampf(value*.82,-.96,.96)
        var signed: int=clampi(int(round(value*32767.0)),-32768,32767)
        if signed<0:
            signed+=65536
        pcm[i*2]=signed&255
        pcm[i*2+1]=(signed>>8)&255
    var stream:=AudioStreamWAV.new()
    stream.mix_rate=MIX_RATE
    stream.format=AudioStreamWAV.FORMAT_16_BITS
    stream.stereo=false
    stream.data=pcm
    if kind=="wind":
        stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
        stream.loop_begin=0
        stream.loop_end=count
    return stream


func sound_count() -> int:
    return _samples.size()
