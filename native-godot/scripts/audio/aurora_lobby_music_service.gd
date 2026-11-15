extends Node

const MEDIA = preload("res://scripts/audio/aurora_addendum_audio.gd")
const BUS: StringName=&"Music"
const TRACK: String="aurora_lobby_loop.ogg"
const AUDIO_PATH: String="user://aurora_audio.cfg"
const DEFAULT_LEVEL: float=.55

var _player: AudioStreamPlayer
var _in_lobby: bool=false
var _suspended: bool=false


func _ready() -> void:
    process_mode=Node.PROCESS_MODE_ALWAYS
    if AudioServer.get_bus_index(BUS)<0:
        AudioServer.add_bus()
        AudioServer.set_bus_name(AudioServer.bus_count-1,BUS)
    var cfg:=ConfigFile.new()
    cfg.load(AUDIO_PATH)
    set_mix(float(cfg.get_value("audio","music",DEFAULT_LEVEL)))
    _player=AudioStreamPlayer.new()
    _player.name="LobbyBGM"
    _player.bus=BUS
    _player.volume_db=-10.0
    add_child(_player)


func enter_lobby() -> void:
    if _in_lobby:
        return
    _in_lobby=true
    if _player.stream==null:
        _player.stream=MEDIA.imported(TRACK)
    if _player.stream==null:
        return
    var ogg:=_player.stream as AudioStreamOggVorbis
    if ogg!=null:
        ogg.loop=true
    _player.play()
    _player.stream_paused=_suspended


func leave_lobby() -> void:
    if not _in_lobby:
        return
    _in_lobby=false
    _player.stop()


func _exit_tree() -> void:
    if is_instance_valid(_player):
        _player.stop()
        _player.stream=null


func set_mix(level: float) -> void:
    var index: int=AudioServer.get_bus_index(BUS)
    var gain: float=clampf(level,0.0,1.0)
    AudioServer.set_bus_volume_db(index,linear_to_db(maxf(.001,gain)))
    AudioServer.set_bus_mute(index,gain<=.001)


func _notification(what: int) -> void:
    match what:
        NOTIFICATION_APPLICATION_PAUSED:
            _suspended=true
        NOTIFICATION_APPLICATION_RESUMED:
            _suspended=false
        _:
            return
    if _player!=null and _in_lobby:
        _player.stream_paused=_suspended
