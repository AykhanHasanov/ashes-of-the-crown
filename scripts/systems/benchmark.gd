extends Node
## First-launch benchmark: times every frame for a few seconds in the first gameplay scene
## (the title screen is too light to tell anything), at Medium with vsync off (a 60 Hz cap
## would hide the difference), then lets Settings pick the preset from the MEDIAN frame rate
## (Settings.finish_benchmark) and tells the player for a few seconds.
##   - It starts on READY, not on a clock: the scene's _begin has run, the streamer has
##     nothing pending, and ready_frames more frames were drawn (scripts/core/scene_ready.gd).
##     If that never comes it starts after ready_cap seconds anyway. So the tail of loading
##     and shader compilation are never measured, on any machine.
##   - The median, not the mean: a few hitches must not decide the preset. The 1 % low
##     (the frame rate of the slowest 1 % of frames) is logged with it.
##   - A dead zone between low_fps and medium_fps: there it runs at Medium and the preset is
##     saved only when the next launch's measurement agrees (two agreeing results).
##   - On an integrated GPU (Intel UHD / Iris, AMD Vega / Radeon Graphics ...) High is never
##     picked automatically.
## Numbers: data/world/lighting.json benchmark. NOTE: the thresholds are calibrated on the
## valley as it is now and MUST BE RECALIBRATED AFTER ART PART 2 (terrain, the modular kit).
## If the scene is left before it finishes nothing is saved and the next launch measures
## again; no frames measured → Medium.

const SceneReady := preload("res://scripts/core/scene_ready.gd")
const INTEGRATED_HINTS := ["intel", "uhd", "iris", "vega", "radeon(tm) graphics", "radeon graphics", "adreno", "mali"]
const DISCRETE_HINTS := ["geforce", "rtx", "gtx", "radeon rx", "radeon pro", "arc a", "arc b", "quadro"]

enum Phase { WAIT_READY, MEASURE, DONE }

var mode: Node                   # the scene being measured (chapter_base sets it)
var result := {}                 # after the run: {median, low1, mean, frames, integrated, preset, final, waited}
var _cfg: Dictionary
var _phase := Phase.WAIT_READY
var _created_us := 0
var _ready_frames := 0
var _start_us := 0
var _last_us := 0
var _waited := 0.0
var _frame_us := PackedInt64Array()
var _vsync := DisplayServer.VSYNC_ENABLED
var _label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cfg = DataDB.world("lighting")["benchmark"]
	_vsync = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_created_us = Time.get_ticks_usec()


func _exit_tree() -> void:
	DisplayServer.window_set_vsync_mode(_vsync)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	match _phase:
		Phase.WAIT_READY:
			# READY: set up, nothing streaming in, and a few frames drawn after that
			_ready_frames = _ready_frames + 1 if SceneReady.is_ready(mode if mode != null else get_parent()) else 0
			var waited := (now - _created_us) / 1000000.0
			if _ready_frames >= int(_cfg["ready_frames"]) or waited >= float(_cfg["ready_cap"]):
				_waited = waited
				_phase = Phase.MEASURE
				_start_us = now
				_last_us = now
		Phase.MEASURE:
			_frame_us.append(now - _last_us)
			_last_us = now
			if (now - _start_us) / 1000000.0 >= float(_cfg["seconds"]):
				_phase = Phase.DONE
				_finish()


func _finish() -> void:
	DisplayServer.window_set_vsync_mode(_vsync)
	result = stats(_frame_us)
	result["integrated"] = is_integrated_gpu()
	result["waited"] = _waited
	result["zone"] = Settings.benchmark_zone(float(result["median"]), _cfg, result["integrated"])
	result["final"] = Settings.finish_benchmark(float(result["median"]), result["integrated"])
	result["preset"] = Settings.quality_id()
	print("BENCHMARK median=%.1f low1=%.1f mean=%.1f frames=%d ready_after=%.1fs integrated=%s gpu=\"%s\" zone=%s → %s%s" % [
		result["median"], result["low1"], result["mean"], result["frames"], _waited, result["integrated"],
		RenderingServer.get_video_adapter_name(), result["zone"], result["preset"],
		"" if result["final"] else " (dead zone: measured again on the next launch)"])
	if result["final"]:
		_notify(tr("BENCH_RESULT") % Settings.quality_name())   # only a final choice is announced
		await get_tree().create_timer(float(_cfg["notice_seconds"]), true, false, true).timeout
	queue_free()


## {median, low1, mean, frames} in frames per second from frame times in microseconds.
## low1: the frame rate over the slowest 1 % of frames (their mean frame time).
static func stats(frame_us: PackedInt64Array) -> Dictionary:
	if frame_us.is_empty():
		return {"median": 0.0, "low1": 0.0, "mean": 0.0, "frames": 0}
	var sorted := Array(frame_us)
	sorted.sort()
	var n := sorted.size()
	var median_us: float = float(sorted[n / 2]) if n % 2 == 1 else (float(sorted[n / 2 - 1]) + float(sorted[n / 2])) * 0.5
	var worst := maxi(n / 100, 1)   # the slowest 1 % of frames (at least one)
	var p99_us := 0.0
	for i in worst:
		p99_us += float(sorted[n - 1 - i])
	p99_us /= worst
	var total := 0.0
	for us in sorted:
		total += float(us)
	return {"median": 1000000.0 / maxf(median_us, 1.0), "low1": 1000000.0 / maxf(p99_us, 1.0),
		"mean": n * 1000000.0 / maxf(total, 1.0), "frames": n}


## The adapter type the driver reports, else its name.
static func is_integrated_gpu() -> bool:
	match RenderingServer.get_video_adapter_type():
		RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
			return true
		RenderingDevice.DEVICE_TYPE_DISCRETE_GPU:
			return false
	return is_integrated_name(RenderingServer.get_video_adapter_name())


static func is_integrated_name(adapter: String) -> bool:
	var a := adapter.to_lower()
	if DISCRETE_HINTS.any(func(h): return a.contains(h)):
		return false
	return INTEGRATED_HINTS.any(func(h): return a.contains(h))


## The on-screen notice: top centre, for notice_seconds.
func _notify(text: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_label = Label.new()
	_label.name = "BenchNotice"
	_label.text = text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.98, 0.9, 0.72))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_label.offset_top = 118.0
	layer.add_child(_label)
