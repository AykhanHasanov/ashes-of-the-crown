extends Node
## Performance probe for the iso game, measured the way every figure in docs/PERF_PROFILE.md
## is: a 1280x720 window, vsync off, a settle period thrown away, then the median frame time
## over a few seconds per spot (the 1 % low is printed but too noisy on this machine to gate on).
## Run: --demo=iso_perf --quality=low (or high). Prints one line per spot and quits.

const SETTLE := 2.0
const MEASURE := 5.0

var game
var _spots: Array = []
var _i := -1
var _t := 0.0
var _times: Array = []


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_spots = [
		{"name": "road", "at": Vector3(17.5, 0, 58.0), "night": false},
		{"name": "gate", "at": Vector3(1.0, 0, 21.0), "night": false},
		{"name": "court_day", "at": Vector3(3.0, 0, 3.5), "night": false},
		{"name": "court_night", "at": Vector3(3.0, 0, 3.5), "night": true},
		{"name": "court_night_close", "at": Vector3(-5.0, 0, -4.0), "night": true, "zoom": "close"},
	]
	_next()


func _next() -> void:
	_i += 1
	if _i >= _spots.size():
		print("ISO PERF DONE")
		get_tree().quit()
		return
	var s: Dictionary = _spots[_i]
	game._set_night(bool(s["night"]))
	game.player.global_position = s["at"]
	game.rufet.snap_behind()
	game.rig.set_zoom(String(s.get("zoom", "explore")))
	game.rig.snap()
	_t = 0.0
	_times.clear()


func _process(delta: float) -> void:
	if _i < 0 or _i >= _spots.size():
		return
	_t += delta
	if _t > SETTLE:
		_times.append(delta * 1000.0)
	if _t > SETTLE + MEASURE:
		var sorted := _times.duplicate()
		sorted.sort()
		var med: float = sorted[sorted.size() / 2]
		var low: float = sorted[int(sorted.size() * 0.99)]
		print("ISO PERF %-18s %s  median %.1f ms (%.0f fps)  1%% low %.1f ms" % [
			_spots[_i]["name"], Settings.quality_id(), med, 1000.0 / med, low])
		_next()
