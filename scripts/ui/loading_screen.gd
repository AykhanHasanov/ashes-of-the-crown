extends CanvasLayer
## The loading screen: instead of a black (or frozen) picture while a scene changes, a cold
## ember in the ash slowly catches fire, with one short line under it (LOADING_LINE — a
## PLACEHOLDER until the story writes it).
## It is drawn first, then the scene is changed under it, and it stays until the new scene is
## READY (scripts/core/scene_ready.gd: set up, nothing streaming in) plus READY_FRAMES more
## drawn frames — so the load, first-launch shader compilation and the first half second of
## streaming hitches all happen behind it. Then it fades out.
## Use: const LoadingScreen := preload("res://scripts/ui/loading_screen.gd")
##      LoadingScreen.go(get_tree(), "res://scenes/world.tscn")   # instead of change_scene_to_file

const SceneReady := preload("res://scripts/core/scene_ready.gd")
const READY_FRAMES := 30      # frames drawn after "ready" before it lifts
const MIN_SECONDS := 0.8      # never a flash
const CAP_SECONDS := 30.0     # a scene that never reports ready must not hide the game forever
const FADE := 0.45
const KINDLE_SECONDS := 6.0   # how long the ember takes to catch (it then burns until ready)

static var active: CanvasLayer   # the one on screen (null when none)

var target := ""
var _t := 0.0
var _changed := false
var _ready_frames := 0
var _fading := false
var _art: Control
var _line: Label
var _preview := false


## Shows the screen and changes to `path` under it. Safe to call while one is already up
## (the scene is changed at once under the existing screen).
static func go(tree: SceneTree, path: String) -> void:
	tree.paused = false
	if active != null and is_instance_valid(active):
		active.target = path
		active._changed = false
		active._ready_frames = 0
		return
	var s: CanvasLayer = load("res://scripts/ui/loading_screen.gd").new()
	s.target = path
	active = s
	tree.root.add_child.call_deferred(s)   # (deferred: the caller may be inside a _ready)


## The screen alone, for a screenshot (--demo=loading): it never leaves.
static func preview(tree: SceneTree) -> CanvasLayer:
	var s: CanvasLayer = load("res://scripts/ui/loading_screen.gd").new()
	s._preview = true
	tree.root.add_child.call_deferred(s)   # (deferred: the caller may be inside a _ready)
	return s


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.03, 0.028)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_art = Control.new()
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.draw.connect(_draw_ember)
	add_child(_art)
	_line = Label.new()
	_line.text = tr("LOADING_LINE")
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.add_theme_font_size_override("font_size", 20)
	_line.add_theme_color_override("font_color", Color(0.78, 0.7, 0.6))
	_line.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_line.anchor_left = 0.0
	_line.anchor_right = 1.0
	_line.anchor_top = 0.5
	_line.anchor_bottom = 0.5
	_line.offset_top = 96.0
	_line.offset_bottom = 130.0
	_line.offset_left = 0.0
	_line.offset_right = 0.0
	add_child(_line)


func _exit_tree() -> void:
	if active == self:
		active = null


func _process(delta: float) -> void:
	_t += delta
	_art.queue_redraw()
	if _preview or _fading:
		return
	var tree := get_tree()
	if not _changed:
		if _t < 0.05:
			return   # let this screen be drawn once before the (blocking) load starts
		_changed = true
		tree.change_scene_to_file(target)
		return
	var scene := tree.current_scene
	var is_up: bool = scene != null and scene.scene_file_path == target and SceneReady.is_ready_or_plain(scene)
	_ready_frames = _ready_frames + 1 if is_up else 0
	if (_ready_frames >= READY_FRAMES and _t >= MIN_SECONDS) or _t >= CAP_SECONDS:
		_fade_out()


func _fade_out() -> void:
	_fading = true
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for c in get_children():
		if c is CanvasItem:
			tw.parallel().tween_property(c, "modulate:a", 0.0, FADE)
	tw.tween_callback(queue_free)


## How far the ember has caught, 0 (cold) .. 1 (burning).
func kindle() -> float:
	return clampf(1.0 - exp(-_t / (KINDLE_SECONDS * 0.4)), 0.0, 1.0)


## The ember: a low mound of ash, a coal that goes from dull red to orange, a glow that
## grows, and a small flame that rises as it catches.
func _draw_ember() -> void:
	var c := _art.size * 0.5 + Vector2(0, -10)
	var k := kindle()
	var flick := 0.9 + 0.07 * sin(_t * 9.0) + 0.05 * sin(_t * 23.0 + 1.3)
	# ash
	_art.draw_set_transform(c + Vector2(0, 26), 0.0, Vector2(1.0, 0.32))
	_art.draw_circle(Vector2.ZERO, 120.0, Color(0.10, 0.095, 0.09))
	_art.draw_circle(Vector2.ZERO, 78.0, Color(0.14, 0.13, 0.125))
	_art.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# glow
	for i in 7:
		var r := 22.0 + i * (18.0 + 26.0 * k)
		_art.draw_circle(c, r, Color(1.0, 0.42, 0.12, (0.05 + 0.10 * k) * flick / (1.0 + i * 0.7)))
	# flame: a teardrop that grows with k
	if k > 0.12:
		var h := (14.0 + 58.0 * k) * flick
		var w := 9.0 + 13.0 * k
		var sway := sin(_t * 3.1) * 3.0 * k
		var outer := PackedVector2Array([c + Vector2(-w, 0), c + Vector2(-w * 0.55, -h * 0.45), c + Vector2(sway, -h),
			c + Vector2(w * 0.55, -h * 0.45), c + Vector2(w, 0)])
		_art.draw_colored_polygon(outer, Color(0.95, 0.38, 0.08, 0.55 * k))
		var inner := PackedVector2Array([c + Vector2(-w * 0.5, 0), c + Vector2(-w * 0.28, -h * 0.3), c + Vector2(sway * 0.6, -h * 0.62),
			c + Vector2(w * 0.28, -h * 0.3), c + Vector2(w * 0.5, 0)])
		_art.draw_colored_polygon(inner, Color(1.0, 0.72, 0.3, 0.7 * k))
	# the coal
	var coal := Color(0.22, 0.05, 0.03).lerp(Color(1.0, 0.5, 0.16), k * flick)
	_art.draw_circle(c, 11.0, coal)
	_art.draw_circle(c + Vector2(-3, -3), 4.0, coal.lightened(0.25 * k))
