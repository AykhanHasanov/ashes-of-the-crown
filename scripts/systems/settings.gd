extends Node
## Player settings (saved to user://settings.cfg), input bindings and debug options.
##
## Command-line user args (after `--`):
##   --quality=low|high     force a graphics preset (default: saved value or GPU auto-detect)
##   --capture=<path.png>   save a screenshot at --frame and quit
##   --frame=<n>            frame number for --capture (default 150)
##   --demo=<mode>          menu | explore | dialogue | fight | combat | victory | pause |
##                          settings | echoes | echo | journal | chapter_end
##                          (anything but "menu" skips the title screen; "combat" also
##                          swings and fires the ember before the capture)

signal changed

enum Quality { LOW, HIGH }

const PATH := "user://settings.cfg"

var quality: Quality = Quality.LOW
var music_volume := 0.8
var sfx_volume := 0.9
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
	quality = _detect_quality()
	_load()
	_parse_args()
	apply.call_deferred()


func is_high() -> bool:
	return quality == Quality.HIGH


## Pushes the current values to the engine (window, audio buses) and notifies listeners.
func apply() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if capture_path == "" and DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	Audio.set_volumes(music_volume, sfx_volume)
	changed.emit()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "quality", "high" if is_high() else "low")
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("game", "screen_shake", screen_shake)
	cfg.set_value("game", "damage_numbers", damage_numbers)
	cfg.save(PATH)


func toggle_quality() -> void:
	quality = Quality.HIGH if quality == Quality.LOW else Quality.LOW
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
		quality = Quality.HIGH if cfg.get_value("video", "quality") == "high" else Quality.LOW
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	music_volume = cfg.get_value("audio", "music", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	screen_shake = cfg.get_value("game", "screen_shake", screen_shake)
	damage_numbers = cfg.get_value("game", "damage_numbers", damage_numbers)


func _detect_quality() -> Quality:
	var adapter := RenderingServer.get_video_adapter_name().to_lower()
	for hint in ["geforce", "rtx", "gtx", "radeon rx", "arc a"]:
		if adapter.contains(hint):
			return Quality.HIGH
	return Quality.LOW


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		if arg.begins_with("--quality="):
			quality = Quality.HIGH if value == "high" else Quality.LOW
		elif arg.begins_with("--capture="):
			capture_path = value
		elif arg.begins_with("--frame="):
			capture_frame = int(value)
		elif arg.begins_with("--demo="):
			demo = value


func _setup_input() -> void:
	_bind_keys("move_up", [KEY_W, KEY_UP])
	_bind_keys("move_down", [KEY_S, KEY_DOWN])
	_bind_keys("move_left", [KEY_A, KEY_LEFT])
	_bind_keys("move_right", [KEY_D, KEY_RIGHT])
	_bind_keys("dash", [KEY_SPACE])
	_bind_keys("interact", [KEY_E])
	_bind_keys("ember_power", [KEY_Q])
	_bind_keys("attack", [KEY_J])
	_bind_keys("restart", [KEY_R])
	_bind_keys("pause", [KEY_ESCAPE, KEY_P])
	_bind_keys("journal", [KEY_TAB])
	_bind_keys("toggle_quality", [KEY_F9])
	_bind_keys("toggle_fps", [KEY_F3])
	_bind_keys("toggle_fullscreen", [KEY_F11])
	_bind_keys("choice_1", [KEY_1])
	_bind_keys("choice_2", [KEY_2])
	_bind_keys("choice_3", [KEY_3])
	_bind_mouse("attack", MOUSE_BUTTON_LEFT)
	_bind_mouse("ember_power", MOUSE_BUTTON_RIGHT)


func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


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
