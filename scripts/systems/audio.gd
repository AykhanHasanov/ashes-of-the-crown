extends Node
## Plays the synthesized SFX (pooled players, random pitch, optional 3D position),
## crossfades the music layers ("ambient" / "battle") and runs the wind ambience.
## Audio files are produced by tools/gen_audio.py into assets/audio.

const DIR := "res://assets/audio/"
const MUSIC := {"ambient": "music_ambient", "battle": "music_battle"}
const MUSIC_DB := -7.0
const POOL_SIZE := 16

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _next := 0
var _next_3d := 0
var _music_players := {}
var _music_level := {}
var _music_target := {}
var _fade_time := 2.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_bus("Music")
	_make_bus("SFX")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = 6.0
		p3.max_distance = 45.0
		p3.attenuation_filter_cutoff_hz = 9000.0
		p3.bus = "SFX"
		add_child(p3)
		_pool_3d.append(p3)
	for key in MUSIC:
		var mp := AudioStreamPlayer.new()
		mp.stream = stream(MUSIC[key])
		mp.volume_db = -80.0
		mp.bus = "Music"
		add_child(mp)
		_music_players[key] = mp
		_music_level[key] = 0.0
		_music_target[key] = 0.0
	var wind := AudioStreamPlayer.new()
	wind.stream = stream("loop_wind")
	wind.volume_db = -16.0
	wind.bus = "SFX"
	add_child(wind)
	wind.play()


## Linear 0..1 volumes for the Music and SFX buses.
func set_volumes(music_level: float, sfx_level: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music_level, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx_level, 0.0001)))


func _make_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func stream(sfx_name: String) -> AudioStream:
	if not _streams.has(sfx_name):
		var path := DIR + sfx_name + ".wav"
		_streams[sfx_name] = load(path) if ResourceLoader.exists(path) else null
	return _streams[sfx_name]


## Plays a sound. With `pos` it is positional; `variants` picks name_0..name_{n-1}.
func play(sfx_name: String, volume_db := 0.0, pitch_var := 0.08, pos: Variant = null, variants := 0) -> void:
	if variants > 0:
		sfx_name = "%s_%d" % [sfx_name, randi() % variants]
	var s := stream(sfx_name)
	if s == null:
		return
	var pitch := 1.0 + randf_range(-pitch_var, pitch_var)
	if pos is Vector3:
		var p3 := _pool_3d[_next_3d]
		_next_3d = (_next_3d + 1) % POOL_SIZE
		p3.stream = s
		p3.volume_db = volume_db
		p3.pitch_scale = pitch
		p3.global_position = pos
		p3.play()
	else:
		var p := _pool[_next]
		_next = (_next + 1) % POOL_SIZE
		p.stream = s
		p.volume_db = volume_db
		p.pitch_scale = pitch
		p.play()


## Crossfades to a music layer ("ambient", "battle") or "" for silence.
func music(layer: String, fade := 2.0) -> void:
	_fade_time = maxf(fade, 0.05)
	for key in _music_target:
		_music_target[key] = 1.0 if key == layer else 0.0
		var mp: AudioStreamPlayer = _music_players[key]
		if key == layer and not mp.playing:
			mp.play()


func _process(delta: float) -> void:
	for key in _music_players:
		var level: float = move_toward(_music_level[key], _music_target[key], delta / _fade_time)
		_music_level[key] = level
		var mp: AudioStreamPlayer = _music_players[key]
		mp.volume_db = MUSIC_DB + linear_to_db(maxf(level, 0.0001))
		if level <= 0.0 and mp.playing and _music_target[key] <= 0.0:
			mp.stop()
