extends Node
## Global settings: graphics quality, input bindings and debug capture options.
##
## Command-line user args (after `--`):
##   --quality=low|high     force a graphics preset (default: auto-detect GPU)
##   --capture=<path.png>   save a screenshot at --frame and quit
##   --frame=<n>            frame number for --capture (default 150)
##   --demo=<mode>          explore | dialogue | fight | combat | victory (skips the intro;
##                          "combat" also swings and fires the ember before the capture)

signal quality_changed

enum Quality { LOW, HIGH }

var quality: Quality = Quality.LOW
var capture_path := ""
var capture_frame := 150
var demo := ""
var show_fps := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	quality = _detect_quality()
	_parse_args()


func is_high() -> bool:
	return quality == Quality.HIGH


func toggle_quality() -> void:
	quality = Quality.HIGH if quality == Quality.LOW else Quality.LOW
	quality_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_quality"):
		toggle_quality()
	elif event.is_action_pressed("toggle_fps"):
		show_fps = not show_fps
	elif event.is_action_pressed("toggle_fullscreen"):
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)


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
	_bind_keys("quit", [KEY_ESCAPE])
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
