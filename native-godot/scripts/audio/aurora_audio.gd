extends Node3D
## Original offline sound design. Deterministic synthesized PCM is cached once,
## and voices are pooled; no runtime AudioStreamGenerator callbacks on mobile.
## Sound library is original, not borrowed from other games.
const MIX_RATE: int=22050
const CONFIG_PATH: String="user://aurora_audio.cfg"
const VOICES: int=8
const ADDENDUM = preload("res://scripts/audio/aurora_addendum_audio.gd")
const SPATIAL_STEPS: int=3
const SPATIAL_BLASTS: int=3
const STEP_RANGE: float=26.0
const BLAST_RANGE: float=105.0

var _samples: Dictionary={}
var _voices: Array[AudioStreamPlayer]=[]
## Godot 4.7.2 Android: keep positional gunfire via per-voice bus panners,
## not AudioStreamPlayer3D, which swaps audio playback bus details repeatedly.
var _world_voices: Array[AudioStreamPlayer]=[]
var _world_buses: Array[int]=[]
var _world_panners: Array[AudioEffectPanner]=[]
var _world_positions: Array[Vector3]=[]
var _world_cursor: int=0
var _cursor: int=0
var _ambience: AudioStreamPlayer
var _foot_index: int=0
var _sound_enabled: bool=true
var _closing: bool=false
var _steps: AudioStreamPlayer
var _flight_transition: AudioStreamPlayer
var _aircraft_active: bool=false
var _walking_steps: Array[AudioStream]=[]
var _running_steps: Array[AudioStream]=[]
var _spatial_addendum: Array[AudioStreamPlayer]=[]
var _addendum_buses: Array[int]=[]
var _addendum_panners: Array[AudioEffectPanner]=[]
var _addendum_positions: Array[Vector3]=[]
var _step_cursor: int=0
var _blast_cursor: int=0
# Positional sources are stationary for each short sample. Avoid sending
# identical mixer updates on every frame while the camera is unchanged.
# Cache is bounded by the fixed 5 world + 6 positional voice buses.
var _pan_cache: Dictionary={}
var _gain_cache: Dictionary={}
var spatial_pan_writes: int=0
var spatial_gain_writes: int=0
const PAN_EPSILON: float=.005
const GAIN_EPSILON_DB: float=.10


func _ready() -> void:
    _ensure_bus("AuroraSFX")
    _ensure_bus("AuroraAmbience")
    _ensure_bus("AuroraSteps")
    set_mix("AuroraSteps",.70)
    _load_settings()
    var transition: AudioStream=ADDENDUM.imported("aircraft.ogg")
    var blast: AudioStream=ADDENDUM.imported("grenade.ogg")
    var recipes: Dictionary={
        "ar_fire":.25,
        "awm_fire":.62,
        "awm_bolt":.19,
        "scar_fire":.32,
        "mp40_fire":.17,
        "kriss_fire":.13,
        "p90_fire":.20,
        "p90_release":.14,
        "p90_contact":.18,
        "p90_return":.13,
        "shotgun_fire":.58,
        "pistol_fire":.34,
        "knife_swing":.19,
        "distant_fire":.36,
        "mp40_extract":.16,
        "mp40_seat":.20,
        "mp40_bolt":.23,
        "eliminated":.68,
        "impact":.24,
        "hit":.29,
        "reload":.40,
        "foot_stone":.24,
        "foot_snow":.27,
        "heal":.54,
        "jump":.22,
        # One short, original PCM beep reused by the existing 8-voice pool.
        "grenade_fuse":.12,
        "ui":.14,
        "wind":4.0
    }
    for name in recipes:
        _samples[name]=_render(name,float(recipes[name]))
    # Prefer rights-cleared, short one-shot Aurora V3 audio only when staged.
    # No user-supplied recording is embedded in this public repository.
    # Existing original procedural samples remain authoritative fallbacks.
    for name in recipes:
        var external: AudioStream=ADDENDUM.imported("weapons/"+str(name)+".ogg")
        if external!=null:
            _samples[name]=external
    _samples["grenade"]=blast if blast!=null else _render("grenade",2.83)
    for i in range(VOICES):
        var voice:=AudioStreamPlayer.new()
        voice.name="SoundVoice"+str(i)
        voice.bus="AuroraSFX"
        voice.volume_db=-9.0
        add_child(voice)
        _voices.append(voice)
    for i in range(5):
        var bus_name: String="AuroraWorldShot"+str(i)
        _ensure_bus(bus_name,"AuroraSFX")
        var bus_index: int=AudioServer.get_bus_index(bus_name)
        var panner: AudioEffectPanner=null
        if AudioServer.get_bus_effect_count(bus_index)>0:
            panner=AudioServer.get_bus_effect(bus_index,0) as AudioEffectPanner
        if panner==null:
            panner=AudioEffectPanner.new()
            AudioServer.add_bus_effect(bus_index,panner,0)
        var outdoor:=AudioStreamPlayer.new()
        outdoor.name="SpatialWeapon"+str(i)
        outdoor.bus=bus_name
        outdoor.volume_db=-11.0
        add_child(outdoor)
        _world_voices.append(outdoor)
        _world_buses.append(bus_index)
        _world_panners.append(panner)
        _world_positions.append(Vector3.ZERO)
    _ambience=AudioStreamPlayer.new()
    _ambience.name="AuroraWindAmbience"
    _ambience.bus="AuroraAmbience"
    _ambience.volume_db=-22.0
    _ambience.stream=_samples["wind"]
    add_child(_ambience)
    if _sound_enabled:
        _ambience.play()
    _steps=_make_voice("OperatorFootsteps","AuroraSteps",-9.0)
    for i in range(3):
        var walk: AudioStream=ADDENDUM.imported("walk_%d.wav"%i)
        var run: AudioStream=ADDENDUM.imported("run_%d.wav"%i)
        _walking_steps.append(walk if walk!=null else _samples["foot_stone"])
        _running_steps.append(run if run!=null else _samples["foot_stone"])
    _flight_transition=_make_voice("AircraftOverflight","AuroraAmbience",-11.0)
    _flight_transition.stream=transition if transition!=null else _render("aircraft",3.8)
    for i in range(SPATIAL_STEPS+SPATIAL_BLASTS):
        var bus_name: String="AuroraPositionalEffect%d"%i
        _ensure_bus(bus_name,"AuroraSteps" if i<SPATIAL_STEPS else "AuroraSFX")
        var bus: int=AudioServer.get_bus_index(bus_name)
        if AudioServer.get_bus_effect_count(bus)==0:
            AudioServer.add_bus_effect(bus,AudioEffectPanner.new())
        _spatial_addendum.append(_make_voice("PositionalEffect%d"%i,bus_name,
            -15.0 if i<SPATIAL_STEPS else -8.0))
        _addendum_buses.append(bus)
        _addendum_panners.append(AudioServer.get_bus_effect(bus,0) as AudioEffectPanner)
        _addendum_positions.append(Vector3.ZERO)


func _make_voice(voice_name: String,bus_name: String,db: float) -> AudioStreamPlayer:
    var voice:=AudioStreamPlayer.new()
    voice.name=voice_name
    voice.bus=bus_name
    voice.volume_db=db
    add_child(voice)
    return voice


func _ensure_bus(bus_name: String,send_to: String="Master") -> void:
    if AudioServer.get_bus_index(bus_name)>=0:
        return
    AudioServer.add_bus()
    var index: int=AudioServer.bus_count-1
    AudioServer.set_bus_name(index,bus_name)
    AudioServer.set_bus_send(index,send_to)


func _process(_delta: float) -> void:
    if _closing:
        return
    # Update directional position on dedicated buses, NOT playing AudioStream
    # nodes. Updating player.volume_db/bus or using AudioStreamPlayer3D can
    # retire playback bus details from the mix thread concurrently.
    var listener: Camera3D=get_viewport().get_camera_3d()
    if listener!=null:
        for i in range(_world_voices.size()):
            if _world_voices[i].playing:
                _update_world_pan(i,listener)
        for i in range(_spatial_addendum.size()):
            if _spatial_addendum[i].playing:
                _pan_from(_addendum_positions[i],listener,_addendum_panners[i],
                    _addendum_buses[i],STEP_RANGE if i<SPATIAL_STEPS else BLAST_RANGE)
    # Godot 4.7.2 audio-mixer concurrency mitigation: wait for an in-flight
    # mix step at least once per main-loop iteration before retired audio-bus
    # data can be reclaimed. This is a narrow, temporary engine workaround,
    # not a replacement for an upstream AudioServer lifetime fix.
    AudioServer.lock()
    AudioServer.unlock()


func _update_world_pan(index: int,listener: Camera3D,force: bool=false) -> void:
    _pan_from(_world_positions[index],listener,_world_panners[index],_world_buses[index],150.0,force)


func _pan_from(source: Vector3,listener: Camera3D,panner: AudioEffectPanner,
        bus: int,range_metres: float,force: bool=false) -> void:
    if not is_instance_valid(listener) or not is_instance_valid(panner):
        return
    var toward: Vector3=source-listener.global_position
    var distance: float=toward.length()
    toward.y=0.0
    var pan: float=0.0
    if toward.length_squared()>.001:
        pan=clampf(toward.normalized().dot(listener.global_basis.x),-1.0,1.0)
    if force or not _pan_cache.has(bus) or absf(pan-float(_pan_cache[bus]))>=PAN_EPSILON:
        panner.pan=pan
        _pan_cache[bus]=pan
        spatial_pan_writes+=1
    # Keep the same attenuation curve. Compare to the LAST applied gain,
    # not the previous frame, so small movements accumulate correctly.
    var gain: float=pow(clampf(1.0-distance/range_metres,0.001,1.0),2.0)
    var db: float=linear_to_db(gain)
    if force or not _gain_cache.has(bus) or absf(db-float(_gain_cache[bus]))>=GAIN_EPSILON_DB:
        AudioServer.set_bus_volume_db(bus,db)
        _gain_cache[bus]=db
        spatial_gain_writes+=1


func _load_settings() -> void:
    var cfg:=ConfigFile.new()
    if cfg.load(CONFIG_PATH)!=OK:
        return
    _sound_enabled=bool(cfg.get_value("audio","enabled",true))
    set_mix("AuroraSFX",float(cfg.get_value("audio","effects",.75)))
    set_mix("AuroraAmbience",float(cfg.get_value("audio","ambience",.55)))
    set_mix("AuroraSteps",float(cfg.get_value("audio","steps",.70)))


func set_mix(bus_name: String,level: float) -> void:
    if bus_name not in ["AuroraSFX","AuroraAmbience","AuroraSteps"]:
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
    if not _sound_enabled or not at.is_finite():
        return
    var listener: Camera3D=get_viewport().get_camera_3d()
    var distance: float=listener.global_position.distance_to(at) if listener else 0.0
    if distance>=150.0:
        return
    var voice_index: int=_world_cursor
    var source: AudioStreamPlayer=_world_voices[voice_index]
    _world_cursor=(_world_cursor+1)%_world_voices.size()
    source.stop()
    _world_positions[voice_index]=at+Vector3.UP*1.35
    if listener!=null:
        # Each new sound refreshes its reused voice regardless of cache.
        _update_world_pan(voice_index,listener,true)
    source.stream=_samples["distant_fire" if distance>=62.0 else "ar_fire"]
    source.pitch_scale=.91+float(_world_cursor%4)*.04
    source.play()


# Reuse bounded world voices and the original reload sample. No extra
# audio node per remote actor or per reload.
func play_world_reload(at: Vector3) -> void:
    if not _sound_enabled or not at.is_finite() or not _samples.has("reload"):
        return
    var listener: Camera3D=get_viewport().get_camera_3d()
    if listener==null or listener.global_position.distance_to(at)>=26.0:
        return
    var slot: int=_world_cursor
    var voice: AudioStreamPlayer=_world_voices[slot]
    _world_cursor=(_world_cursor+1)%_world_voices.size()
    voice.stop()
    _world_positions[slot]=at+Vector3.UP*1.35
    _update_world_pan(slot,listener,true)
    voice.stream=_samples["reload"]
    voice.pitch_scale=1.0
    voice.play()

func play_footstep(on_stone: bool) -> void:
    _foot_index+=1
    var variation: float=.94+float(_foot_index%5)*.026
    play_event("foot_stone" if on_stone else "foot_snow",variation)


func play_operator_contact(on_stone: bool,running: bool) -> void:
    if not _sound_enabled:
        return
    _steps.stop()
    _steps.stream=_contact_sample(on_stone,running)
    _steps.pitch_scale=1.04 if running else 1.0
    _steps.play()


func _contact_sample(on_stone: bool,running: bool) -> AudioStream:
    _foot_index+=1
    if not on_stone:
        return _samples["foot_snow"]
    var samples: Array[AudioStream]=_running_steps if running else _walking_steps
    return samples[_foot_index%samples.size()]


func play_bot_contact(at: Vector3,running: bool,on_stone: bool) -> void:
    if not _can_hear(at,STEP_RANGE):
        return
    var slot: int=_step_cursor
    _step_cursor=(_step_cursor+1)%SPATIAL_STEPS
    _play_positional(slot,at,_contact_sample(on_stone,running),STEP_RANGE)


func play_grenade_detonation(at: Vector3) -> void:
    if not _can_hear(at,BLAST_RANGE):
        return
    var slot: int=SPATIAL_STEPS+_blast_cursor
    _blast_cursor=(_blast_cursor+1)%SPATIAL_BLASTS
    _play_positional(slot,at,_samples["grenade"],BLAST_RANGE)


func _can_hear(at: Vector3,max_range: float) -> bool:
    var listener: Camera3D=get_viewport().get_camera_3d()
    return _sound_enabled and at.is_finite() and listener!=null and (
        listener.global_position.distance_squared_to(at)<max_range*max_range)


func _play_positional(slot: int,at: Vector3,stream: AudioStream,max_range: float) -> void:
    var voice: AudioStreamPlayer=_spatial_addendum[slot]
    voice.stop()
    _addendum_positions[slot]=at
    _pan_from(at,get_viewport().get_camera_3d(),_addendum_panners[slot],
        _addendum_buses[slot],max_range,true)
    voice.stream=stream
    voice.play()


func set_aircraft_audio(active: bool) -> void:
    if active==_aircraft_active:
        return
    _aircraft_active=active
    if active and _sound_enabled:
        _flight_transition.play()
    else:
        _flight_transition.stop()


func set_enabled(enabled: bool) -> void:
    if _closing:
        return
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
        for voice in _spatial_addendum:
            voice.stop()
        _flight_transition.stop()
        _steps.stop()


## Idempotent scene-owned audio shutdown. Keep the persistent mixer buses
## and preferences intact, but do not leave playing voices in a removed map.
func shutdown() -> void:
    if _closing:
        return
    _closing=true
    _sound_enabled=false
    set_process(false)
    var voices: Array[AudioStreamPlayer]=[]
    voices.append_array(_voices)
    voices.append_array(_world_voices)
    voices.append_array(_spatial_addendum)
    voices.append_array([_ambience,_steps,_flight_transition])
    for voice in voices:
        if is_instance_valid(voice):
            voice.stop()
            voice.stream=null
    # Wait for an in-flight mixer step after stopping, never while holding
    # the server lock across AudioStreamPlayer operations.
    AudioServer.lock()
    AudioServer.unlock()
    _pan_cache.clear()
    _gain_cache.clear()


func _exit_tree() -> void:
    shutdown()


func _render(kind: String,duration: float) -> AudioStreamWAV:
    var count: int=maxi(64,int(ceil(duration*float(MIX_RATE))))
    var pcm:=PackedByteArray()
    # Godot 4.7.2 WAV forward-loop mixer reads the loop_end frame too.
    # A loop_end equal to the frame count without a guard reads beyond PCM
    # storage and can SIGSEGV in AudioTrack (Motorola V75.22/V75.23).
    # Keep the full audible loop and append its first sample as a guard.
    var guard_frames: int=1 if kind=="wind" else 0
    pcm.resize((count+guard_frames)*2)
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
            "awm_bolt":
                # Two short steel contact transients, intentionally distinct
                # from fire and clip replacement. Original procedural audio.
                var pull: float=exp(-pow((t-.018)/.010,2))
                var lock: float=exp(-pow((t-.105)/.014,2))
                value=(.52*middle+.16*sin(TAU*790.0*t))*pull
                value+=(.65*high+.32*sin(TAU*525.0*t))*lock
                value+=.08*low*exp(-t*22.0)
            "scar_fire":
                value=(.77*middle+.46*pulse)*exp(-t*18.0)+.30*high*exp(-t*42.0)
            "mp40_fire":
                value=(.86*high+.34*pulse)*exp(-t*37.0)+.35*middle*exp(-t*16.0)
            "kriss_fire":
                value=(.68*high+.53*middle+.24*pulse)*exp(-t*45.0)
            "p90_fire":
                # Original game SFX, cached PCM; not a source recording.
                value=(.42*high+.54*middle+.30*pulse)*exp(-t*34.0)
                value+=.16*low*exp(-t*13.0)
            "p90_release","p90_contact","p90_return":
                var frequency: float=440.0 if kind=="p90_release" else 620.0 if kind=="p90_contact" else 790.0
                var transient: float=exp(-pow((t-.018)/.012,2))
                var tail: float=exp(-t*28.0)
                value=(.44*middle+.18*sin(TAU*frequency*t))*transient
                value+=(.19*high+.09*low)*tail
                if kind=="p90_contact":
                    value+=.31*middle*exp(-pow((t-.073)/.014,2))
            "shotgun_fire":
                value=(.85*middle+.57*high+.32*pulse)*exp(-t*17.0)
                value+=.27*low*exp(-t*4.4)
            "pistol_fire":
                value=(.83*high+.34*middle+.25*pulse)*exp(-t*27.0)
            "knife_swing":
                value=(.55*high+.24*middle)*exp(-t*26.0)
            "distant_fire":
                value=(.9*low+.17*middle+.16*pulse)*exp(-t*11.0)
                if t>.12:
                    value+=.19*low*exp(-(t-.12)*18.0)
            "mp40_extract","mp40_seat","mp40_bolt":
                var resonance: float=370.0 if kind=="mp40_extract" else 530.0 if kind=="mp40_seat" else 680.0
                value=(.59*middle+.20*sin(TAU*resonance*t))*exp(-t*39.0)
                if kind=="mp40_bolt" and t>.065:
                    value+=.30*high*exp(-(t-.065)*37.0)
            "eliminated":
                value=.35*sin(TAU*(255.0*t-85.0*t*t))*sin(PI*progress)*exp(-t*2.5)
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
            "grenade_fuse":
                # A distinct, pre-rendered 120ms alert; no procedural DSP
                # work, AudioStreamGenerator or allocations during gameplay.
                var envelope: float=sin(PI*progress)
                value=.26*sin(TAU*(780.0*t+110.0*t*t))*envelope
                value+=.075*high*exp(-t*34.0)
            "grenade":
                value=.73*high*exp(-t*44.0)+.7*low*exp(-t*4.0)
                value+=.40*sin(TAU*(43.0*t+1.8*sin(t*2.0)))*exp(-t*4.1)
            "aircraft":
                value=(low*.36+sin(TAU*(49.0*t+2.0*sin(t)))*.10)*sin(PI*progress)
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
    if kind=="wind":
        # The boundary frame must be valid, not uninitialised memory.
        # The loop still spans the original 'count' authored frames;
        # this duplicate is only the decoder's safe extra read.
        pcm[count*2]=pcm[0]
        pcm[count*2+1]=pcm[1]
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
