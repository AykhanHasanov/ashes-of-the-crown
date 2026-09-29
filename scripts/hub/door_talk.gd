extends Node
## Talking with Son Ocaq's people, by day and through their doors at night
## (data/hub/door_talk.json — placeholder keys only; the story writes the lines).
##
## By day: face to face, from the NPC's day pool.
## At night Aras knocks. Then, from the data:
##   - an empty room, a silent_if condition (asleep / refuses), or a door that refused him
##     earlier this night: SILENCE — a short ambient beat, no dialogue box;
##   - allows_night_open (Peri Nene): the door opens and they talk face to face;
##   - otherwise the DOOR MODE: the camera closes on the door, the NPC stays unseen, their
##     voice comes muffled through the "Door" audio bus (Aras's own lines do not), the words
##     are subtitles, and a shadow crosses the light under the door while they speak. The
##     NPC may first ask who is there (a name_challenge node): a burned name cannot answer,
##     the NPC refuses, and that door stays silent until morning.
## Aras's own door at night: he cannot open it, only listen — and the small shade knocks
## in its rhythm (knocks.narin; placeholder rhythm until the lullaby exists).
## The conversation itself runs in the mode's DialogueUI with context {door_mode: bool}.

signal finished

const HubData := preload("res://scripts/hub/hub_data.gd")
const NpcRegistry := preload("res://scripts/core/npc_registry.gd")
const HubNights := preload("res://scripts/hub/hub_nights.gd")
const DialogueGraphs := preload("res://scripts/story/dialogue_graphs.gd")
const PATH := "res://data/hub/door_talk.json"
const DOOR_BUS := "Door"
const VOICE_BUS := "Voice"
const DOOR_CUTOFF_HZ := 750.0
const STAND_OFF := 2.9            # where Aras stands during the door shot: behind the camera
const CAMERA_OFF := 2.2

var dialogue                       # DialogueUI
var level                          # HubLevel (doors)
var mode                           # the hub mode (camera, player, spawner)

## What happened last (for the mode and the tests): "talk" | "door" | "open" | "silent" | "listen".
var last_outcome := ""
var last_bus := {}                 # speaker ("protagonist" or NPC id) -> bus of their last line
var knock_log: Array = []
## The story's own conversations at a door, per NPC: npc id -> dialogue graph id
## (data/story/dialogue). Set by the story (StoryDirector); cleared with clear_script().
var scripted: Dictionary = {}          # seconds after the first knock of the last rhythm played
var door_camera: Camera3D
var talking_door = null            # Door
var talking_npc: StringName = &""

var _data: Dictionary
var _turn := {}                    # npc|pool -> index (plain keys take turns)
var _refused := {}                 # door ids that refused Aras this night
var _knock_t := 0.0
var _voice: AudioStreamPlayer


func _ready() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	_ensure_door_bus()
	_voice = AudioStreamPlayer.new()
	add_child(_voice)
	EventBus.time_of_day_changed.connect(func(_p): _refused.clear())   # a new night, a new chance
	dialogue.line_shown.connect(_on_line)
	dialogue.finished.connect(_on_finished)
	dialogue.pause_changed.connect(_on_pause)
	dialogue.action_requested.connect(on_action)


## The muffled bus for voices through a door: a low-pass into the Voice bus.
static func _ensure_door_bus() -> void:
	if AudioServer.get_bus_index(DOOR_BUS) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, DOOR_BUS)
	AudioServer.set_bus_send(idx, VOICE_BUS if AudioServer.get_bus_index(VOICE_BUS) >= 0 else "Master")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = DOOR_CUTOFF_HZ
	AudioServer.add_bus_effect(idx, lp)


## Which bus a line plays on: an NPC through a closed door is muffled; everyone else, and
## Aras always, is heard plainly.
static func bus_for(speaker: StringName, door_mode: bool) -> String:
	if door_mode and speaker != &"" and speaker != &"protagonist":
		return DOOR_BUS
	return VOICE_BUS


# --- Entry points ------------------------------------------------------------------------------

## Day: face to face with someone standing in the courtyard.
func talk(npc: StringName) -> void:
	talking_npc = npc
	last_outcome = "talk"
	dialogue.start({"start": {"speaker_id": String(npc), "text_key": _pick(npc, "day"), "end": true}}, "start", {"door_mode": false})


## Night: Aras knocks on `door`. Returns the outcome ("door", "open", "silent", "listen").
func knock(door) -> String:
	Audio.play("door_knock", -2.0, 0.05, door.global_position + Vector3(0, 1.2, 0))
	var place := HubData.place(door.place_id)
	if (place.get("residents", []) as Array).has(HubData.PROTAGONIST):
		return listen(door)
	var npc := _occupant(door.place_id)
	if npc == &"" or _refused.has(door.door_id) or _silent(npc):
		_silence(door)
		return last_outcome
	talking_door = door
	talking_npc = npc
	var def: Resource = NpcRegistry.get_def(npc)
	if def.allows_night_open:
		last_outcome = "open"
		door.hold_open(true)
		mode.night_guest(npc, true)
		if scripted.has(npc):
			var g: String = scripted[npc]
			dialogue.start(DialogueGraphs.load_graph(g), DialogueGraphs.start_of(g), {"door_mode": false})
		else:
			dialogue.start({"start": {"speaker_id": String(npc), "text_key": _pick(npc, "night"), "end": true}}, "start", {"door_mode": false})
		return last_outcome
	last_outcome = "door"
	_door_camera(door)
	if scripted.has(npc):
		var gid: String = scripted[npc]
		dialogue.start(DialogueGraphs.load_graph(gid), DialogueGraphs.start_of(gid), {"door_mode": true})
		return last_outcome
	var tree := {
		"line": {"speaker_id": String(npc), "text_key": _pick(npc, "night"), "end": true},
		"refuse": {"speaker_id": String(npc), "text_key": _data["refusal_key"], "end": true, "event": "refused"},
		"unknown": {"speaker_id": String(npc), "text_key": "HUB_NAME_UNKNOWN_RESPONSE", "end": true},
	}
	if _setting(npc, "challenge"):
		tree["start"] = {"type": "name_challenge", "speaker_id": String(npc), "text_key": _data["challenge_key"], "pass": "line", "fail": "refuse", "unknown": "unknown"}
	else:
		tree["start"] = tree["line"]
	dialogue.start(tree, "start", {"door_mode": true})
	return last_outcome


## Aras's own door at night: it does not open; he listens — the small shade's knock.
func listen(door) -> String:
	last_outcome = "listen"
	play_knock_rhythm(door, &"narin")
	mode.hud.show_whisper(tr("HUB_LISTEN_PLACEHOLDER"))
	return last_outcome


## The knock of `who` (knocks.<who>.rhythm, seconds) on `door`.
func play_knock_rhythm(door, who: StringName) -> void:
	var rhythm: Array = _data["knocks"][String(who)]["rhythm"]
	knock_log.clear()
	var start := Time.get_ticks_msec()
	for t in rhythm:
		get_tree().create_timer(float(t), false).timeout.connect(func():
			if is_instance_valid(door):
				knock_log.append((Time.get_ticks_msec() - start) / 1000.0)
				Audio.play("door_knock", -4.0, 0.02, door.global_position + Vector3(0, 0.9, 0.3)))


## The story's door actions (dialogue "do"): "silence_door:<door id>" — that door stays
## silent until morning; "lights_out:<door id>" — its light is out tonight.
func on_action(action: String) -> void:
	var door = level.doors.get(action.get_slice(":", 1))
	match action.get_slice(":", 0):
		"silence_door":
			if door != null:
				_refused[door.door_id] = true
		"lights_out":
			if door != null:
				door.set_lights_out(true)


func _on_pause(paused: bool) -> void:
	if talking_door != null:
		talking_door.freeze_shadow(paused)   # the shadow under the door stops while they fall silent


func set_script_for(npc: StringName, graph_id: String) -> void:
	scripted[npc] = graph_id


func clear_script(npc: StringName) -> void:
	scripted.erase(npc)


func is_silenced(door_id: StringName) -> bool:
	return _refused.has(door_id)


# --- Night rhythm on Aras's door -----------------------------------------------------------------

func _process(delta: float) -> void:
	if level == null or WorldState.get_phase() != &"night" or dialogue.is_active():
		_knock_t = 0.0
		return
	var k: Dictionary = _data["knocks"]["narin"]
	var door = level.doors.get(k["door"])
	if door == null or mode.player.global_position.distance_to(door.global_position) > float(k["near"]):
		return
	_knock_t += delta
	if _knock_t >= float(k["every"]):
		_knock_t = 0.0
		play_knock_rhythm(door, &"narin")


# --- The conversation ---------------------------------------------------------------------------

func _on_line(node: Dictionary) -> void:
	var speaker := StringName(node.get("speaker_id", ""))
	var door_mode: bool = dialogue.check("door_mode")
	if talking_door != null:
		talking_door.set_speaking(door_mode and speaker != &"")
	if speaker == &"":
		return
	last_bus[String(speaker)] = bus_for(speaker, door_mode)
	var def: Resource = NpcRegistry.get_def(speaker) if NpcRegistry.has(speaker) else null
	var stream: AudioStream = Barks.voice_stream(def.voice_profile, "idle") if def != null and def.voice_profile != "" else null
	if stream:
		_voice.stop()
		_voice.stream = stream
		_voice.bus = bus_for(speaker, door_mode)
		_voice.play()
	# Aras's answer (a choice) is his own line: never through the door bus
	if (node.get("choices", []) as Array).any(func(c): return c.get("own", false)):
		last_bus["protagonist"] = bus_for(&"protagonist", door_mode)


func _on_finished(event: String) -> void:
	if event == "refused" and talking_door != null:
		_refused[talking_door.door_id] = true
	if talking_door != null:
		talking_door.set_speaking(false)
		if talking_door.held_open:
			talking_door.hold_open(false)
			mode.night_guest(talking_npc, false)
	talking_door = null
	_voice.stop()
	if door_camera:
		door_camera.queue_free()
		door_camera = null
		mode.rig.camera.make_current()
		level.set_door_scene(null)
		mode.hud.visible = true
	finished.emit()


## The door shot: Aras steps back out of frame (behind the camera); the camera stands before
## the door at chest height, the door in the middle and the light under it above the
## subtitles. No part of him — no cut-off body or sword — is in the picture.
func _door_camera(door) -> void:
	var xf: Transform3D = door.global_transform
	var stand: Vector3 = xf.origin + xf.basis.z * STAND_OFF
	mode.player.global_position = Vector3(stand.x, mode.player.global_position.y, stand.z)
	mode.player.face_towards(xf.origin)
	door_camera = Camera3D.new()
	door_camera.name = "DoorCamera"
	door_camera.fov = 60.0
	add_child(door_camera)
	door_camera.global_position = xf.origin + xf.basis.z * CAMERA_OFF + xf.basis.x * 0.15 + Vector3(0, 1.1, 0)
	door_camera.look_at(xf.origin + Vector3(0, 0.85, 0))
	door_camera.make_current()
	level.set_door_scene(door)
	mode.hud.visible = false   # only the door, the light and the words


func _silence(door) -> void:
	last_outcome = "silent"
	get_tree().create_timer(0.5, false).timeout.connect(func():
		Audio.play("door_hush", -6.0, 0.0, door.global_position + Vector3(0, 1.0, 0)))
	mode.hud.show_whisper(tr("HUB_SILENCE"))


# --- Data --------------------------------------------------------------------------------------

## Who answers behind a door: the first resident of that place who is home.
func _occupant(place_id: String) -> StringName:
	for r in HubData.residents_of(place_id):
		if r != HubData.PROTAGONIST and HubData.is_home(r):
			return StringName(r)
	return &""


func _setting(npc: StringName, key: String) -> Variant:
	var own: Dictionary = _data["npcs"].get(String(npc), {})
	return own.get(key, _data["defaults"].get(key))


func _silent(npc: StringName) -> bool:
	var conds: Array = (_data["defaults"].get("silent_if", []) as Array) + (_data["npcs"].get(String(npc), {}).get("silent_if", []) as Array)
	return conds.any(func(c): return WorldState.check(c))


## A line from the NPC's day or night pool: the first {key, condition} whose condition
## holds, else the plain keys in turn.
func _pick(npc: StringName, pool: String) -> String:
	if pool == "night" and HubNights.is_warned(npc):
		return "HUB_WARNING_%s" % String(npc).to_upper()   # the warning night: their line turns
	var entries: Array = _data["npcs"].get(String(npc), {}).get(pool, [])
	var plain: Array = []
	for e in entries:
		if e is Dictionary:
			if WorldState.check(e["condition"]):
				return e["key"]
		else:
			plain.append(e)
	if plain.is_empty():
		return "HUB_SILENCE"
	var k := String(npc) + "|" + pool
	var i: int = _turn.get(k, 0)
	_turn[k] = i + 1
	return plain[i % plain.size()]


func pool(npc: StringName, which: String) -> Array:
	return (_data["npcs"].get(String(npc), {}).get(which, []) as Array).map(func(e): return e["key"] if e is Dictionary else e)
