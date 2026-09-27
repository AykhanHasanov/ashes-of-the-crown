extends Node
## Enemy voices (autoload "Barks"). Lines and cries come from data/voices/manifest.json
## (built by tools/gen_voices.py). A bark is played in 3D from the speaker's head with a
## short subtitle under it. Rules keep a fight readable instead of a shouting crowd:
## at most two voices at once, a pause per speaker, cooldowns per event across the
## whole group, and the same line is never repeated back to back.

const MANIFEST := "res://data/voices/manifest.json"
const MAX_VOICES := 2
## Seconds before anyone may bark this event again (anyone, not just this speaker)
const EVENT_COOLDOWN := {"attack": 1.6, "hurt": 0.8, "taunt": 9.0, "idle": 7.0, "spot": 1.2, "search": 4.0,
	"suspicious": 3.0, "ally_died": 4.0, "call_help": 5.0, "victory": 6.0}
## Must-hear events skip the voice limit
const URGENT := ["death", "explode", "surrender", "war_cry", "resurrect", "phase"]
const SUBTITLE_COLORS := {"ash": Color(1.0, 0.62, 0.4), "bandit": Color(0.95, 0.88, 0.72), "beast": Color(0.9, 0.9, 0.9)}

var _profiles := {}
var _enemies := {}
var _event_until := {}     # event -> ms
var _last := {}            # "profile/event" -> index
var _speaking: Array = []  # AudioStreamPlayer3D currently talking


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if AudioServer.get_bus_index("Voice") < 0:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "Voice")
		AudioServer.set_bus_send(idx, "Master")
	if FileAccess.file_exists(MANIFEST):
		var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		_profiles = m["profiles"]
		_enemies = m["enemies"]


func set_volume(level: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), linear_to_db(maxf(level, 0.0001)))


## A voice for an enemy type; varied per individual (bandits sound different).
func voice_for(enemy_id: String, seed_value: int) -> String:
	var list: Array = _enemies.get(enemy_id, [])
	return "" if list.is_empty() else list[absi(seed_value) % list.size()]


func has_line(profile: String, event: String) -> bool:
	return _profiles.get(profile, {}).has(event)


## Speaks `event` from `speaker` (a Node3D with a head at `head_height`). Returns true if it played.
func say(speaker: Node3D, profile: String, event: String, chance := 1.0, head_height := 1.9) -> bool:
	if profile == "" or not is_instance_valid(speaker) or randf() > chance:
		return false
	var lines: Array = _profiles.get(profile, {}).get(event, [])
	if lines.is_empty():
		return false
	var now := Time.get_ticks_msec()
	var urgent: bool = event in URGENT
	if not urgent:
		if now < int(_event_until.get(event, 0)):
			return false
		if now < int(speaker.get_meta("bark_until", 0)):
			return false
		_speaking = _speaking.filter(func(p): return is_instance_valid(p) and p.playing)
		if _speaking.size() >= MAX_VOICES:
			return false
	_event_until[event] = now + int(float(EVENT_COOLDOWN.get(event, 1.0)) * 1000.0)
	# Pick a line, never the one we just heard
	var key := profile + "/" + event
	var i := randi() % lines.size()
	if lines.size() > 1 and i == int(_last.get(key, -1)):
		i = (i + 1) % lines.size()
	_last[key] = i
	var entry: Dictionary = lines[i]
	var stream: AudioStream = load(entry["file"])
	if stream == null:
		return false
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = "Voice"
	p.unit_size = 9.0
	p.max_distance = 55.0
	p.volume_db = 2.0 if urgent else 0.0
	p.pitch_scale = randf_range(0.97, 1.03)
	p.attenuation_filter_cutoff_hz = 12000.0
	p.position = Vector3(0, head_height, 0)
	speaker.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	_speaking.append(p)
	speaker.set_meta("bark_until", now + int(stream.get_length() * 1000.0) + 1800)
	if entry.get("text", "") != "" and Settings.subtitles:
		_subtitle(speaker, entry["text"], head_height, stream.get_length())
	return true


func _subtitle(speaker: Node3D, text: String, head: float, seconds: float) -> void:
	var old = speaker.get_node_or_null("BarkSubtitle")
	if old:
		old.queue_free()
	var l := Label3D.new()
	l.name = "BarkSubtitle"
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 34
	l.pixel_size = 0.0045
	l.outline_size = 10
	l.width = 900.0
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.no_depth_test = true
	l.fixed_size = false
	var faction: String = speaker.get("faction") if speaker.get("faction") != null else ""
	l.modulate = SUBTITLE_COLORS.get(faction, Color.WHITE)
	l.position = Vector3(0, head + 0.35, 0)
	speaker.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(maxf(seconds * 0.8, 1.4))
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)
