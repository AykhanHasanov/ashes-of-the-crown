extends Node
## StoryDirector — plays the story's beats (data/story/<act>_beats.json) in any V3 mode.
## A beat is data: WHEN something happens (a trigger), IF a condition holds, DO a list of
## actions, in order. Beats play once (persisted in WorldState story.beats) unless "repeat".
##
## Beat: {"id", "on", "arg"?, "where"?, "if"?, "repeat"?, "radius"?, "do": [...]}
##   on       enter (the region a mode starts in) · phase (dawn/day/dusk/night) · flag (a flag became true)
##            dialogue_end (the dialogue's end event) · interact (an id the mode fires)
##            rest (checkpoint id) · encounter_end (encounter id) · encounter_wave
##            ("<encounter id>:<wave>", e.g. Rüfət charges in at wave 2) · near (a spot id the mode
##            places: story_spot(id) -> Vector3 or null; within "radius", default 4 m)
##            health_below (the protagonist's health fraction under "below"; with
##            "during": only while that encounter runs)
##   arg      what the trigger must match ("" or absent = anything)
##   where    only in this region (WorldState region)
##   if       condition language (scripts/core/conditions.gd)
## Actions (strings, "verb:arg"):
##   dialogue:<graph>     play data/story/dialogue/<graph>.json and wait for it to end
##   whisper:<KEY> · banner:<KEY> · card:<TITLE_KEY>[:<SUB_KEY>]   HUD, through tr() + Names
##   encounter:<id>[:<spot>]   the mode's start_encounter at the spot (or the protagonist)
##   wait:<seconds>
##   anything WorldState.apply knows (set:, thread:, item:, move_npc:, reveal_name:, grief:)
##   else the mode's on_story_action(action) (e.g. door_script: in the hub)
## The director holds no state of its own; nodes are views (CLAUDE.md rule 3).
## Use: const StoryDirector := preload("res://scripts/story/story_director.gd")

const DialogueGraphs := preload("res://scripts/story/dialogue_graphs.gd")
const Names := preload("res://scripts/core/names.gd")
const ACTS := ["act1"]
const DIR := "res://data/story/"

signal beat_started(id: String)
signal beat_finished(id: String)

var mode: Node          # the chapter_base mode that owns this director
var enabled := true
var _beats: Array = []
var _queue: Array = []  # beats waiting while another plays
var _running := ""
var _encounter := ""    # the encounter running now (for "during")


func _ready() -> void:
	_beats = load_beats()
	EventBus.time_of_day_changed.connect(func(p): fire("phase", String(p)))
	EventBus.flag_changed.connect(_on_flag)
	EventBus.checkpoint_rested.connect(func(c): fire("rest", String(c)))
	EventBus.encounter_started.connect(func(e): _encounter = String(e))
	EventBus.encounter_finished.connect(func(e):
		_encounter = ""
		fire("encounter_end", String(e)))
	EventBus.encounter_wave_started.connect(func(e, w, _t, _k): fire("encounter_wave", "%s:%d" % [e, w]))
	if mode != null and mode.get("dialogue") != null:
		mode.dialogue.finished.connect(func(ev): fire("dialogue_end", String(ev)))


## Every act's beats, in file order.
static func load_beats() -> Array:
	var out: Array = []
	for act in ACTS:
		var path: String = DIR + act + "_beats.json"
		if not FileAccess.file_exists(path):
			continue
		var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
		if raw is Dictionary:
			out.append_array(raw.get("beats", []))
		else:
			push_error("StoryDirector: cannot read %s" % path)
	return out


static func beat(id: String) -> Dictionary:
	for b in load_beats():
		if String(b["id"]) == id:
			return b
	return {}


func _on_flag(key: StringName, _old: Variant, value: Variant) -> void:
	if value == true:
		fire("flag", String(key))


## Something happened: every beat waiting for it (and allowed now) plays, in order.
func fire(trigger: String, arg := "") -> void:
	if not enabled:
		return
	for b in _beats:
		if String(b["on"]) == trigger and _matches(b, arg) and can_play(b):
			_enqueue(b)


func _matches(b: Dictionary, arg: String) -> bool:
	var want := String(b.get("arg", ""))
	return want == "" or want == arg


## Not yet played (or repeatable), in its region, its condition true, not already queued.
func can_play(b: Dictionary) -> bool:
	if not b.get("repeat", false) and WorldState.is_beat_done(String(b["id"])):
		return false
	if b.has("where") and String(b["where"]) != String(WorldState.get_region()):
		return false
	if _running == String(b["id"]) or _queue.any(func(q): return q["id"] == b["id"]):
		return false
	return WorldState.check(String(b.get("if", "")))


func _enqueue(b: Dictionary) -> void:
	_queue.append(b)
	if _running == "":
		_next()


func _next() -> void:
	while not _queue.is_empty():
		var b: Dictionary = _queue.pop_front()
		if not can_play(b):
			continue
		_running = String(b["id"])
		if not b.get("repeat", false):
			WorldState.mark_beat_done(_running)   # before the actions: a save mid-beat never replays it
		beat_started.emit(_running)
		for action in b.get("do", []):
			await run(String(action))
			if not is_inside_tree():
				return
		beat_finished.emit(_running)
		_running = ""


func is_busy() -> bool:
	return _running != ""


## One action (awaitable: dialogue and wait take time).
func run(action: String) -> void:
	var verb := action.get_slice(":", 0)
	var arg := action.get_slice(":", 1)
	var hud = mode.get("hud") if mode != null else null
	match verb:
		"dialogue":
			if not DialogueGraphs.has(arg):
				push_error("StoryDirector: no dialogue graph '%s'" % arg)
				return
			mode.dialogue.start(DialogueGraphs.load_graph(arg), DialogueGraphs.start_of(arg))
			await mode.dialogue.finished
		"whisper":
			if hud:
				hud.show_whisper(Names.fill(tr(arg)))
		"banner":
			if hud:
				hud.banner(Names.fill(tr(arg)))
		"card":
			if hud:
				var sub := action.get_slice(":", 2)
				hud.title_card(Names.fill(tr(arg)), Names.fill(tr(sub)) if sub != "" else "", 3.0)
		"encounter":
			if mode != null and mode.has_method("start_encounter"):
				var spot := action.get_slice(":", 2)
				var at: Variant = spot_position(spot) if spot != "" else null
				mode.start_encounter(StringName(arg), at if at is Vector3 else mode.player.global_position)
		"wait":
			await get_tree().create_timer(float(arg)).timeout
		_:
			if not WorldState.apply(action):
				if mode != null and mode.has_method("on_story_action"):
					mode.on_story_action(action)
				else:
					push_warning("StoryDirector: nobody handles '%s'" % action)


func spot_position(id: String) -> Variant:
	return mode.story_spot(id) if mode != null and mode.has_method("story_spot") else null


func _physics_process(_delta: float) -> void:
	if not enabled or mode == null or mode.get("player") == null:
		return
	for b in _beats:
		match String(b["on"]):
			"near":
				if not can_play(b):
					continue
				var at: Variant = spot_position(String(b.get("arg", "")))
				if at is Vector3 and mode.player.global_position.distance_to(at) < float(b.get("radius", 4.0)):
					_enqueue(b)
			"health_below":
				if b.has("during") and String(b["during"]) != _encounter:
					continue
				var p = mode.player
				if p.health / p.max_health < float(b.get("below", 0.3)) and can_play(b):
					_enqueue(b)
