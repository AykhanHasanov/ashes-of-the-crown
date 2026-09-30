extends Node
## Player settings (saved to user://settings.cfg), input bindings and debug options.
##
## Command-line user args (after `--`):
##   --quality=low|medium|high  force a graphics preset (default: saved value or GPU auto-detect)
##   --gi=on|off            the experimental global illumination (SDFGI) setting
##   --benchmark            run the first-launch benchmark now, at Medium, without saving
##   --capture=<path.png>   save a screenshot at --frame and quit
##   --frame=<n>            frame number for --capture (default 150)
##   --demo=<mode>          menu | explore | dialogue | fight | combat | victory | pause |
##                          settings | keys | echoes | echo | journal | chapter_end |
##                          radial | offer | strike | whirl | unstoppable (self-test)
##                          (Chapter 2 scene, run with scenes/chapter2.tscn as the scene:)
##                          c2 | c2_talk
##                          (V3 open world, scenes/world.tscn: see world_mode.gd _demo_setup)
##                          (anything but "menu" skips the title screen; "combat" also
##                          swings and fires the ember before the capture)

signal changed

enum Quality { LOW, MEDIUM, HIGH }
const QUALITY_IDS := ["low", "medium", "high"]
const QUALITY_KEYS := ["QUALITY_LOW", "QUALITY_MEDIUM", "QUALITY_HIGH"]

const PATH := "user://settings.cfg"

var quality: Quality = Quality.LOW
var global_illumination := false   # SDFGI, experimental: off unless the player turns it on
var benchmark_done := false         # the first-launch benchmark has picked a preset (or the player did)
var bench_candidate := ""          # a dead-zone result waiting for the next launch to agree
var _quality_forced := false        # --quality on the command line: no benchmark this run
var benchmark_dry_run := false      # --benchmark: measure now (even in a capture) but save nothing
var music_volume := 0.8
var sfx_volume := 0.9
var voice_volume := 1.0
var subtitles := true
var screen_shake := 1.0
var fullscreen := false
var damage_numbers := false
var show_fps := false

var capture_path := ""
var capture_frame := 150
var demo := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	quality = Quality.MEDIUM   # until the first-launch benchmark (scripts/systems/benchmark.gd) decides
	_load()
	_parse_args()
	apply.call_deferred()


## High only: full shadows, SSIL, SDFGI, dense foliage.
func is_high() -> bool:
	return quality == Quality.HIGH


## Medium or high: the cheaper screen effects (SSAO, volumetric fog) are on.
func at_least_medium() -> bool:
	return quality != Quality.LOW


func quality_id() -> String:
	return QUALITY_IDS[quality]


func quality_name() -> String:
	return tr(QUALITY_KEYS[quality])


static func quality_from(id: String) -> Quality:
	var i := QUALITY_IDS.find(id)
	return Quality.LOW if i < 0 else i as Quality


## Pushes the current values to the engine (window, audio buses) and notifies listeners.
func apply() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if capture_path == "" and DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	Audio.set_volumes(music_volume, sfx_volume)
	if has_node("/root/Barks"):
		get_node("/root/Barks").set_volume(voice_volume)
	changed.emit()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "quality", quality_id())
	cfg.set_value("video", "global_illumination", global_illumination)
	cfg.set_value("video", "benchmarked", benchmark_done)
	cfg.set_value("video", "bench_candidate", bench_candidate)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "voice", voice_volume)
	cfg.set_value("game", "subtitles", subtitles)
	cfg.set_value("game", "screen_shake", screen_shake)
	cfg.set_value("game", "damage_numbers", damage_numbers)
	cfg.save(PATH)


func toggle_quality() -> void:
	choose_quality(((quality + 1) % QUALITY_IDS.size()) as Quality)   # low → medium → high → low
	save()
	apply()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_quality"):
		toggle_quality()
	elif event.is_action_pressed("toggle_fps"):
		show_fps = not show_fps
	elif event.is_action_pressed("toggle_fullscreen"):
		fullscreen = not fullscreen
		save()
		apply()


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	if cfg.has_section_key("video", "quality"):
		quality = quality_from(String(cfg.get_value("video", "quality")))
	# an older settings file with a quality in it: that was the player's choice
	benchmark_done = cfg.get_value("video", "benchmarked", cfg.has_section_key("video", "quality"))
	bench_candidate = String(cfg.get_value("video", "bench_candidate", ""))
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	global_illumination = cfg.get_value("video", "global_illumination", global_illumination)
	music_volume = cfg.get_value("audio", "music", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	voice_volume = cfg.get_value("audio", "voice", voice_volume)
	subtitles = cfg.get_value("game", "subtitles", subtitles)
	screen_shake = cfg.get_value("game", "screen_shake", screen_shake)
	damage_numbers = cfg.get_value("game", "damage_numbers", damage_numbers)


## The first launch measures the frame rate once and picks the preset (the player can change
## it any time; a saved choice is never overridden). Not in a --demo, a capture, headless or
## with --quality.
func needs_benchmark() -> bool:
	if benchmark_dry_run:
		return true
	return not benchmark_done and not _quality_forced and demo == "" and capture_path == "" 		and DisplayServer.get_name() != "headless"


## What a measured (median) frame rate means (data/world/lighting.json benchmark), measured
## at Medium: "high" (fast, and not an integrated GPU), "medium", "low", or "between" — the
## dead zone between low_fps and medium_fps, where one measurement is not enough to decide.
## No measurement (fps <= 0) → "medium".
static func benchmark_zone(fps: float, cfg: Dictionary, integrated_gpu := false) -> String:
	if fps <= 0.0:
		return "medium"
	if fps >= float(cfg["high_fps"]) and not integrated_gpu:
		return "high"
	if fps >= float(cfg["medium_fps"]):
		return "medium"
	if fps <= float(cfg["low_fps"]):
		return "low"
	return "between"


## Applies a benchmark result. A clear result is saved at once. In the dead zone the game
## runs at Medium and remembers a candidate; the preset is saved only when the NEXT launch's
## measurement agrees (two agreeing results). Returns true when the choice is final.
func finish_benchmark(fps: float, integrated_gpu := false) -> bool:
	var zone := benchmark_zone(fps, DataDB.world("lighting")["benchmark"], integrated_gpu)
	var decided := zone != "between" or bench_candidate == "medium"
	quality = quality_from("medium" if zone == "between" else zone)
	if benchmark_dry_run:
		apply()   # a dry run changes this session only
		return decided
	benchmark_done = decided
	bench_candidate = "" if decided else "medium"
	save()
	apply()
	return decided


## The player picked a preset (settings screen, F9): that is final, no benchmark after it.
func choose_quality(q: Quality) -> void:
	quality = q
	benchmark_done = true
	bench_candidate = ""


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		if arg.begins_with("--quality="):
			quality = quality_from(value)
			_quality_forced = true
		elif arg == "--benchmark":
			benchmark_dry_run = true
			quality = Quality.MEDIUM
		elif arg.begins_with("--gi="):
			global_illumination = value == "on"
		elif arg.begins_with("--capture="):
			capture_path = value
		elif arg.begins_with("--frame="):
			capture_frame = int(value)
		elif arg.begins_with("--demo="):
			demo = value


## Actions the player may rebind, with their Azerbaijani labels (settings → Düymələr).
const REBINDABLE := [
	["move_up", "İleri"], ["move_down", "Geri"], ["move_left", "Sola"], ["move_right", "Sağa"],
	["attack", "Hafif saldırı"], ["heavy", "Ağır saldırı (basılı: yükle)"], ["block", "Blok / savuşturma"],
	["dash", "Kül adımı"], ["sprint", "Koşu"], ["jump", "Zıplama"],
	["ember_power", "Köz / Alev Dalgası"], ["lock_on", "Hedefe kilitlen"],
	["drink", "Nar Şerbeti"], ["interact", "Konuş / dokun / infaz"],
	["skill_1", "Yuva 1"], ["skill_2", "Yuva 2"], ["skill_3", "Yuva 3"], ["skill_4", "Yuva 4"],
	["journal", "Günlük"], ["map", "Harita"], ["pause", "Duraklat"],
]
const INPUT_PATH := "user://input.cfg"


func _setup_input() -> void:
	_bind_keys("move_up", [KEY_W, KEY_UP])
	_bind_keys("move_down", [KEY_S, KEY_DOWN])
	_bind_keys("move_left", [KEY_A, KEY_LEFT])
	_bind_keys("move_right", [KEY_D, KEY_RIGHT])
	_bind_keys("dash", [KEY_SPACE])
	_bind_keys("sprint", [KEY_SHIFT])
	_bind_keys("jump", [KEY_X])
	_bind_keys("heavy", [KEY_F])
	_bind_keys("interact", [KEY_E])
	_bind_keys("ember_power", [KEY_Q])
	_bind_keys("attack", [KEY_J])
	_bind_keys("lock_on", [KEY_C])
	_bind_keys("drink", [KEY_R])
	_bind_keys("restart", [KEY_R])
	_bind_keys("pause", [KEY_ESCAPE, KEY_P])
	_bind_keys("journal", [KEY_TAB])
	_bind_keys("toggle_quality", [KEY_F9])
	_bind_keys("toggle_fps", [KEY_F3])
	_bind_keys("toggle_fullscreen", [KEY_F11])
	_bind_keys("debug_menu", [KEY_F10])
	_bind_keys("map", [KEY_M])
	_bind_keys("debug_stream", [KEY_F6])
	_bind_keys("debug_ai", [KEY_F4])
	_bind_keys("continue", [KEY_ENTER, KEY_KP_ENTER])
	_bind_keys("echo_keep", [KEY_E])      # echo choice screen: keep the memory
	_bind_keys("echo_burn", [KEY_Q])      # echo choice screen: hold to burn it
	for i in 9:
		_bind_keys("choice_%d" % (i + 1), [KEY_1 + i])
	for i in 4:
		_bind_keys("skill_%d" % (i + 1), [KEY_1 + i])
	_bind_mouse("attack", MOUSE_BUTTON_LEFT)
	_bind_mouse("block", MOUSE_BUTTON_RIGHT)
	_bind_mouse("lock_on", MOUSE_BUTTON_MIDDLE)
	_bind_mouse("lock_next", MOUSE_BUTTON_WHEEL_DOWN)
	_bind_mouse("lock_prev", MOUSE_BUTTON_WHEEL_UP)
	# Gamepad (Xbox layout names; works for any SDL-mapped pad)
	_bind_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_bind_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_bind_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_bind_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_bind_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_bind_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_bind_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_bind_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_bind_axis("heavy", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_bind_axis("sprint", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_bind_button("attack", JOY_BUTTON_RIGHT_SHOULDER)
	_bind_button("block", JOY_BUTTON_LEFT_SHOULDER)
	_bind_button("dash", JOY_BUTTON_B)
	_bind_button("jump", JOY_BUTTON_A)
	_bind_button("interact", JOY_BUTTON_X)
	_bind_button("continue", JOY_BUTTON_A)
	_bind_button("ember_power", JOY_BUTTON_Y)
	_bind_button("lock_on", JOY_BUTTON_RIGHT_STICK)
	_bind_button("lock_next", JOY_BUTTON_DPAD_RIGHT)
	_bind_button("lock_prev", JOY_BUTTON_DPAD_LEFT)
	_bind_button("drink", JOY_BUTTON_DPAD_DOWN)
	_bind_button("pause", JOY_BUTTON_START)
	_bind_button("journal", JOY_BUTTON_BACK)
	_bind_button("map", JOY_BUTTON_DPAD_UP)
	_load_bindings()


func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.3)


func _bind_keys(action: StringName, keys: Array) -> void:
	_ensure_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)


func _bind_mouse(action: StringName, button: MouseButton) -> void:
	_ensure_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _bind_button(action: StringName, button: JoyButton) -> void:
	_ensure_action(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _bind_axis(action: StringName, axis: JoyAxis, sign_value: float) -> void:
	_ensure_action(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = sign_value
	InputMap.action_add_event(action, ev)


# --- Rebinding -------------------------------------------------------------------------------

## Keyboard/mouse events of an action (gamepad bindings are kept separately).
func pc_events(action: String) -> Array:
	return InputMap.action_get_events(action).filter(func(e): return e is InputEventKey or e is InputEventMouseButton)


## Replaces an action's keyboard/mouse binding with `event` and saves it. If another
## rebindable action already used that input, the two swap so nothing is left unbound.
func rebind(action: String, event: InputEvent) -> void:
	var previous: Array = pc_events(action)
	for pair in REBINDABLE:
		var other: String = pair[0]
		if other == action:
			continue
		for e in pc_events(other):
			if _same_input(e, event):
				InputMap.action_erase_event(other, e)
				if not previous.is_empty():
					InputMap.action_add_event(other, previous[0])
	for e in previous:
		InputMap.action_erase_event(action, e)
	InputMap.action_add_event(action, event)
	_save_bindings()


## Restores the default controls and forgets the saved ones.
func reset_bindings() -> void:
	if FileAccess.file_exists(INPUT_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(INPUT_PATH))
	InputMap.load_from_project_settings()
	_setup_input()


func _same_input(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return a.physical_keycode == b.physical_keycode
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return a.button_index == b.button_index
	return false


func event_label(event: InputEvent) -> String:
	if event is InputEventKey:
		return OS.get_keycode_string(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				return "Sol tık"
			MOUSE_BUTTON_RIGHT:
				return "Sağ tık"
			MOUSE_BUTTON_MIDDLE:
				return "Orta tuş"
			MOUSE_BUTTON_WHEEL_UP:
				return "Tekerlek yukarı"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "Tekerlek aşağı"
		return "Fare %d" % event.button_index
	return "?"


func _save_bindings() -> void:
	var cfg := ConfigFile.new()
	for pair in REBINDABLE:
		var events := []
		for e in pc_events(pair[0]):
			if e is InputEventKey:
				events.append({"key": e.physical_keycode})
			else:
				events.append({"mouse": e.button_index})
		cfg.set_value("bindings", pair[0], events)
	cfg.save(INPUT_PATH)


func _load_bindings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(INPUT_PATH) != OK:
		return
	for pair in REBINDABLE:
		var action: String = pair[0]
		if not cfg.has_section_key("bindings", action):
			continue
		for e in pc_events(action):
			InputMap.action_erase_event(action, e)
		for d in cfg.get_value("bindings", action):
			if d.has("key"):
				var k := InputEventKey.new()
				k.physical_keycode = int(d["key"])
				InputMap.action_add_event(action, k)
			elif d.has("mouse"):
				var m := InputEventMouseButton.new()
				m.button_index = int(d["mouse"])
				InputMap.action_add_event(action, m)