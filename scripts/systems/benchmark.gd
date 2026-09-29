extends Node
## First-launch benchmark: counts real frames for a few seconds (after a warm-up) in the
## first gameplay scene (the title screen is too light to tell anything), at Medium with
## vsync off (a 60 Hz cap would hide the difference), then lets Settings pick the preset
## (Settings.finish_benchmark) and says so on screen. Numbers: data/world/lighting.json benchmark. If the scene is left
## before it finishes nothing is saved and the next launch measures again; a measurement
## that saw no frames keeps Medium.

var _cfg: Dictionary
var _start_ms := 0
var _frames := 0
var _measuring := false
var _vsync := DisplayServer.VSYNC_ENABLED


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cfg = DataDB.world("lighting")["benchmark"]
	_start_ms = Time.get_ticks_msec()
	_vsync = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _exit_tree() -> void:
	DisplayServer.window_set_vsync_mode(_vsync)


func _process(_delta: float) -> void:
	var t := (Time.get_ticks_msec() - _start_ms) / 1000.0
	var warm := float(_cfg["warmup"])
	if t < warm:
		return
	if not _measuring:
		_measuring = true
		_frames = 0
		_start_ms = Time.get_ticks_msec() - int(warm * 1000.0)
		return
	_frames += 1
	var span := t - warm
	if span >= float(_cfg["seconds"]):
		var fps := _frames / span if span > 0.0 else 0.0
		Settings.finish_benchmark(fps)
		print("BENCHMARK fps=%.1f → %s" % [fps, Settings.quality_id()])
		Fx.notify(tr("BENCH_RESULT") % Settings.quality_name())
		queue_free()
