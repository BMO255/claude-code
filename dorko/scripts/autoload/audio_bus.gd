extends Node
## SFX + music playback with crossfade. Creates the Music/SFX buses in code
## (no .tres bus layout on disk). All streams come from AssetLib's synth cache.

const SFX_POOL_SIZE := 12

var _sfx_players: Array = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_active: AudioStreamPlayer
var current_music: String = ""
var _footstep_flip := false


func _ready() -> void:
	_make_bus("Music")
	_make_bus("SFX")
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for m in [_music_a, _music_b]:
		m.bus = "Music"
		add_child(m)
	_music_active = _music_a


func _make_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


# ------------------------------------------------------------------ SFX

## Plays a named synth SFX; returns the player so callers can stop() loops.
func play_sfx(name: String, pitch := 1.0, vol_db := 0.0) -> AudioStreamPlayer:
	return play_stream(AssetLib.sfx(name), pitch, vol_db)


func play_stream(stream: AudioStream, pitch := 1.0, vol_db := 0.0) -> AudioStreamPlayer:
	var p := _free_player()
	if p == null:
		return null
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = vol_db
	p.play()
	return p


func _free_player() -> AudioStreamPlayer:
	for p in _sfx_players:
		if not p.playing:
			return p
	return _sfx_players[0]  # steal the oldest slot rather than dropping


## Voice blip for dialogue; per-character identity comes from pitch.
func blip(pitch := 1.0, vol_db := -8.0) -> void:
	play_sfx("blip", pitch * randf_range(0.97, 1.03), vol_db)


func footstep(surface: String) -> void:
	_footstep_flip = not _footstep_flip
	var idx := "1" if _footstep_flip else "2"
	play_sfx("thud_%s_%s" % [surface, idx], randf_range(0.95, 1.05), -6.0)


# ------------------------------------------------------------------ music

func play_music(name: String, crossfade := 1.2) -> void:
	if name == current_music:
		return
	current_music = name
	var incoming := _music_b if _music_active == _music_a else _music_a
	var outgoing := _music_active
	_music_active = incoming
	incoming.stream = AssetLib.music(name)
	incoming.volume_db = -40.0
	incoming.play()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(incoming, "volume_db", 0.0, crossfade)
	if outgoing.playing:
		tw.tween_property(outgoing, "volume_db", -40.0, crossfade)
		tw.chain().tween_callback(outgoing.stop)


func stop_music(fade := 0.8) -> void:
	current_music = ""
	if _music_active and _music_active.playing:
		var out := _music_active
		var tw := create_tween()
		tw.tween_property(out, "volume_db", -40.0, fade)
		tw.tween_callback(out.stop)


# ------------------------------------------------------------------ volume

func set_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clamp(linear, 0.0001, 1.0)))


func get_volume(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))
