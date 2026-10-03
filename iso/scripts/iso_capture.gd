extends Node
## Capture mode: the same framings, every run, saved to captures/iso/ — so two builds can be
## compared shot for shot. Run with --demo=iso_capture (and --quality=high or low).
##
## Shots: the road by day, the courtyard by day and by night, the pull-out outside the gate,
## and a walk from the road into the courtyard saved as frames (captures/iso/walk/) for a GIF.
## Every shot waits for the picture to settle (TAA, SDFGI, the camera's own easing) first.
## Each file name carries the quality tier.

const OUT := "res://captures/iso/"
const SETTLE := 2.2            # seconds before a still is taken
const WALK_EVERY := 6
const WALK_FRAMES := 150

var game
var _shots: Array = []
var _i := -1
var _wait := 0.0
var _walking := false
var _walk_n := 0
var _walk_frame := 0
var _route: Array = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "walk"))
	# a fixed window, so every run is the same picture and frame rates compare: --res=WxH
	# (default 1280x720, the size every performance figure in this project is measured at)
	var res := Vector2i(1280, 720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--res="):
			var p := arg.trim_prefix("--res=").split("x")
			res = Vector2i(int(p[0]), int(p[1]))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(res)
	_shots = [
		{"name": "road_day", "at": Vector3(17.5, 0, 58.0), "face": Vector3(-0.6, 0, -1), "night": false, "zoom": "explore"},
		{"name": "courtyard_day", "at": Vector3(3.0, 0, 3.5), "face": Vector3(-1, 0, -0.6), "night": false, "zoom": "explore"},
		{"name": "courtyard_night", "at": Vector3(3.0, 0, 3.5), "face": Vector3(-1, 0, -0.6), "night": true, "zoom": "explore"},
		{"name": "courtyard_night_close", "at": Vector3(-5.0, 0, -4.0), "face": Vector3(-1, 0, -0.4), "night": true, "zoom": "close"},
		{"name": "gate_pullout", "at": Vector3(0, 0, 13.0), "face": Vector3(0, 0, 1), "night": false, "zoom": "explore", "pull": true},
		{"name": "walk", "walk": true},
	]
	if Settings.demo.begins_with("iso_shot_"):
		var only := Settings.demo.trim_prefix("iso_shot_")
		_shots = _shots.filter(func(s): return s["name"] == only)
	elif Settings.demo == "iso_gif":
		_shots = [{"name": "walk", "walk": true}]
	_next()


func _next() -> void:
	_i += 1
	if _i >= _shots.size():
		print("ISO CAPTURE DONE")
		get_tree().quit()
		return
	var s: Dictionary = _shots[_i]
	if s.get("walk", false):
		_start_walk()
		return
	game._set_night(bool(s["night"]))
	game.player.global_position = s["at"]
	game.player.face_towards(s["at"] + s["face"])
	game.rufet.snap_behind()
	game.rig.set_zoom(String(s["zoom"]))
	game.rig.snap()
	_wait = SETTLE
	if s.get("pull", false):
		# he walks out through the gate; the shot is taken at the height of the reveal
		game.player.auto_input = Vector2(-0.707, -0.707)
		_wait = 4.8


func _process(delta: float) -> void:
	if _walking:
		_tick_walk()
		return
	if _i < 0 or _i >= _shots.size() or _wait <= -1.0:
		return
	_wait -= delta
	if _wait <= 0.0:
		_wait = -1.0
		await RenderingServer.frame_post_draw
		var s: Dictionary = _shots[_i]
		var path := "%s%s_%s.png" % [OUT, s["name"], Settings.quality_id()]
		get_viewport().get_texture().get_image().save_png(path)
		print("ISO SHOT %s fps=%d" % [path, Engine.get_frames_per_second()])
		game.player.auto_input = Vector2.ZERO
		_next()


# --- The walk ------------------------------------------------------------------------------------

## From the road, past the village and the smithy, in through the gate to the hearth.
func _start_walk() -> void:
	game._set_night(false)
	game.rig.set_zoom("explore")
	_route = [Vector3(3.6, 0, 32.0), Vector3(0.6, 0, 22.0), Vector3(0, 0, 14.0),
		Vector3(0, 0, 6.0), Vector3(1.5, 0, 2.5)]
	game.player.global_position = Vector3(7.5, 0, 42.0)
	game.player.face_towards(_route[0])
	game.rufet.snap_behind()
	game.rig.snap()
	_walking = true
	_walk_n = 0
	_walk_frame = 0


func _tick_walk() -> void:
	_walk_frame += 1
	var p: Vector3 = game.player.global_position
	while not _route.is_empty() and Vector2(p.x - _route[0].x, p.z - _route[0].z).length() < 1.2:
		_route.pop_front()
	if _route.is_empty():
		game.player.auto_input = Vector2.ZERO
	else:
		# the world direction to the next waypoint, put back into screen space for the controller
		var d: Vector3 = (_route[0] - p) * Vector3(1, 0, 1)
		var sb: Array = game.rig.screen_basis()
		var v := Vector2(d.dot(sb[1]), d.dot(sb[0])).normalized()
		game.player.auto_input = v
	if _walk_frame > 30 and _walk_frame % WALK_EVERY == 0:
		_save_walk_frame(_walk_n)
		_walk_n += 1
		if _walk_n >= WALK_FRAMES:
			_walking = false
			game.player.auto_input = Vector2.ZERO
			_next()


func _save_walk_frame(n: int) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%swalk/%03d.png" % [OUT, n])
