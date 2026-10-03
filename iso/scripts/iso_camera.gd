extends Node3D
## The iso camera. Fixed yaw (45°) and pitch (~40°): the player never turns it. Perspective
## with a narrow lens by default — it keeps a sense of depth with almost no distortion — or
## orthographic, switched at run time; the orthographic size is derived from the same
## distance and lens, so switching keeps the framing.
##
## It follows a point a little ahead of the player in the direction he is moving (smoothed,
## so a turn does not whip the frame), eases between two zoom levels (exploring / close), and
## can pull out for a moment (the reveal outside the gate).
##
## Occlusion: every frame, anything the level marked as an occluder whose box crosses the
## line from the lens to the player's feet, waist or head is dithered away
## (iso_surface.gdshader's `fade`), and eased back when it no longer is. So a wall, an arch or
## a gallery roof never hides him — the rule is "the player is never hidden", not "most
## walls fade".
##
## Input is screen-relative: screen_basis() gives the world directions of screen-up and
## screen-right, flattened, for the controller to map the stick onto.
## Numbers: iso/data/iso_camera.json.

const CFG := "res://iso/data/iso_camera.json"

var target: Node3D
var camera: Camera3D
var occluders: Array = []
## Inside a building, everything in `cutaway` comes off at once (cut_active), whether or not it
## is in the line of sight: you see the whole room, not a hole around the player. Walls are
## cut down to `cut_height` (their foot stays, capped dark, so the plan still reads); roofs
## (`cut_roofs`) fade right out.
var cutaway: Array = []
var cut_roofs: Array = []
var cut_active := false
var _cut := 0.0             # 0 … 1, eased
var orthographic := false
var zoom := "explore"
var yaw := 45.0
var pitch := 40.0
var fov := 22.0
var trauma := 0.0

var _cfg: Dictionary
var _focus := Vector3.ZERO
var _ahead := Vector3.ZERO
var _dist := 40.0
var _dist_goal := 40.0
var _pull := 0.0            # 0 … 1: how far into the pull-out reveal
var _pull_tween: Tween
var _faded: Dictionary = {}  # MeshInstance3D → current fade
var _t := 0.0


func _ready() -> void:
	_cfg = JSON.parse_string(FileAccess.get_file_as_string(CFG))
	yaw = float(_cfg["yaw"])
	pitch = float(_cfg["pitch"])
	fov = float(_cfg["fov"])
	orthographic = String(_cfg["projection"]) == "orthographic"
	camera = Camera3D.new()
	camera.near = 0.5
	camera.far = 400.0
	add_child(camera)
	camera.current = true
	_dist = float(_cfg["distance"][zoom])
	_dist_goal = _dist
	_apply_projection()


func set_zoom(level: String) -> void:
	zoom = level
	_dist_goal = float(_cfg["distance"][level])


func toggle_zoom() -> void:
	set_zoom("close" if zoom == "explore" else "explore")


func toggle_projection() -> void:
	orthographic = not orthographic
	_apply_projection()


func _apply_projection() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL if orthographic else Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = fov


## World directions of screen-up and screen-right on the ground plane.
func screen_basis() -> Array:
	var y := deg_to_rad(yaw)
	var up := Vector3(-sin(y), 0, -cos(y))
	var right := Vector3(cos(y), 0, -sin(y))
	return [up, right]


func snap() -> void:
	if not is_instance_valid(target):
		return
	_focus = target.global_position
	_ahead = Vector3.ZERO
	_dist = _dist_goal
	_place()


## The reveal: the lens backs off and lowers for a moment, then settles again.
func pull_out() -> void:
	var p: Dictionary = _cfg["pull_out"]
	if _pull_tween != null and _pull_tween.is_valid():
		_pull_tween.kill()
	_pull_tween = create_tween()
	_pull_tween.tween_property(self, "_pull", 1.0, float(p["in"])).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pull_tween.tween_interval(float(p["hold"]))
	_pull_tween.tween_property(self, "_pull", 0.0, float(p["out"])).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	_t += delta
	# a point ahead of him in the direction he is going, eased so a turn does not whip it
	var vel: Vector3 = target.get("velocity") if target.get("velocity") != null else Vector3.ZERO
	vel.y = 0.0
	var want_ahead := vel.normalized() * float(_cfg["look_ahead"]) * clampf(vel.length() / 3.0, 0.0, 1.0)
	_ahead = _ahead.lerp(want_ahead, 1.0 - exp(-float(_cfg["look_ahead_smoothing"]) * delta))
	var goal: Vector3 = target.global_position + _ahead
	_focus = _focus.lerp(goal, 1.0 - exp(-float(_cfg["follow"]) * delta))
	var zt := float(_cfg["zoom_time"])
	_dist = lerpf(_dist, _dist_goal, 1.0 - exp(-delta * 4.0 / maxf(zt, 0.05)))
	trauma = maxf(trauma - delta * 2.2, 0.0)
	_place()
	_fade(delta)


func _place() -> void:
	var p: Dictionary = _cfg["pull_out"]
	var dist := _dist + float(p["extra"]) * _pull
	var pt := deg_to_rad(pitch - float(p["pitch_drop"]) * _pull)
	var y := deg_to_rad(yaw)
	var look := _focus + Vector3(0, float(_cfg["target_height"]), 0)
	var back := Vector3(sin(y) * cos(pt), sin(pt), cos(y) * cos(pt))
	var shake := Vector3.ZERO
	if trauma > 0.0:
		var s := trauma * trauma * 0.25
		shake = Vector3(sin(_t * 41.0), cos(_t * 37.0), sin(_t * 29.0)) * s
	global_position = look + back * dist + shake
	look_at(look + shake, Vector3.UP)
	if orthographic:
		camera.size = 2.0 * dist * tan(deg_to_rad(fov) * 0.5)


## Fade whatever stands between the lens and him; bring it back once it does not.
func _fade(delta: float) -> void:
	var want := {}
	var from := camera.global_position
	var reach: float = from.distance_to(target.global_position) + 3.0
	for h in [0.25, 1.0, 1.9]:
		var to: Vector3 = target.global_position + Vector3(0, h, 0)
		for mi in occluders:
			if want.has(mi) or not is_instance_valid(mi):
				continue
			var m := mi as MeshInstance3D
			if m.global_position.distance_to(from) > reach + 30.0:
				continue
			var inv: Transform3D = m.global_transform.affine_inverse()
			var box: AABB = m.get_aabb().grow(0.12)
			if box.intersects_segment(inv * from, inv * to):
				want[mi] = true
	_cut = move_toward(_cut, 1.0 if cut_active else 0.0, delta * 2.2)
	var h := lerpf(12.0, float(_cfg["cut_height"]), _cut * _cut * (3.0 - 2.0 * _cut))
	for mi in cutaway:
		if is_instance_valid(mi):
			(mi as MeshInstance3D).set_instance_shader_parameter("cut_height", h if _cut > 0.001 else 1000.0)
	if cut_active:
		for mi in cut_roofs:
			want[mi] = true
	for mi in _faded.keys():
		if not want.has(mi):
			want[mi] = false
	var speed := float(_cfg["fade_speed"])
	for mi in want:
		if not is_instance_valid(mi):
			_faded.erase(mi)
			continue
		var goal: float = (float(_cfg["cut_to"]) if cut_active and mi in cut_roofs else float(_cfg["fade_to"])) if want[mi] else 0.0
		var now: float = move_toward(float(_faded.get(mi, 0.0)), goal, speed * delta * (1.0 if want[mi] else 0.6))
		(mi as MeshInstance3D).set_instance_shader_parameter("fade", now)
		if now <= 0.001:
			_faded.erase(mi)
		else:
			_faded[mi] = now
