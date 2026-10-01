extends Node3D
## Side-on camera for the 2.5D test (v4): it rides beside a lane (a Curve3D) and watches the
## protagonist from the side with a long lens — Inside / Little Nightmares. The lane may curve
## through the world, so "sideways" turns with it; the camera eases into every change.
##
## It stands in for the third-person rig, so the protagonist and chapter_base need no change:
##   flat_right()    along the lane (left / right walks the strip)
##   flat_forward()  away from the camera (depth: a step into or out of the picture)
## Numbers: data/balance/side_view.json camera.
## Use: a mode returns one from _make_camera() and sets `lane`.

const CFG := "side_view"

var target: Node3D            # the protagonist
var lock_target: Node3D       # kept for the shared interface (unused here)
var in_combat := false
var camera: Camera3D
var lane: Curve3D             # the path the strip follows
var trauma := 0.0
var yaw := 0.0                # kept for the shared interface
var pitch := 0.0

var _cfg: Dictionary
var _offset := 0.0            # where the protagonist is along the lane
var _pos := Vector3.ZERO      # the camera's eased position
var _look := Vector3.ZERO     # the eased point it looks at
var _side := 1.0              # which side of the lane the camera is on
## Fixed frames for places the side view cannot see into (the walled courtyard): while the
## protagonist is inside one, the camera eases to that frame instead of riding the lane.
## [{"from_z": float, "to_z": float, "pos": Vector3, "look": Vector3}]
var zones: Array = []
var _shake := 0.0
var _t := 0.0


func _ready() -> void:
	_cfg = DataDB.balance(CFG)["camera"]
	camera = Camera3D.new()
	camera.fov = float(_cfg["fov"])            # a long lens: the strip reads flat, like a stage
	camera.near = 0.1
	camera.far = 400.0
	add_child(camera)
	camera.current = true


## The lane point nearest `at`, and the direction the lane runs there.
func lane_at(at: Vector3) -> Dictionary:
	if lane == null or lane.point_count < 2:
		return {"pos": at, "dir": Vector3.RIGHT, "offset": 0.0}
	var off := lane.get_closest_offset(at)
	var pos := lane.sample_baked(off)
	var step := 0.4
	var ahead := lane.sample_baked(clampf(off + step, 0.0, lane.get_baked_length()))
	var behind := lane.sample_baked(clampf(off - step, 0.0, lane.get_baked_length()))
	var dir := (ahead - behind)
	dir.y = 0.0
	if dir.length() < 0.001:
		dir = Vector3.RIGHT
	return {"pos": pos, "dir": dir.normalized(), "offset": off}


## Along the lane: this is what left / right does.
func flat_right() -> Vector3:
	if not is_instance_valid(target):
		return Vector3.RIGHT
	return lane_at(target.global_position)["dir"]


## Away from the camera: a step deeper into the picture.
func flat_forward() -> Vector3:
	var right := flat_right()
	var away := right.cross(Vector3.UP).normalized() * _side
	if is_instance_valid(target):
		var to_cam := (_pos - target.global_position) * Vector3(1, 0, 1)
		if to_cam.length() > 0.01 and away.dot(to_cam.normalized()) > 0.0:
			away = -away   # always point away from the lens
	return away


func snap() -> void:
	if not is_instance_valid(target):
		return
	var frame := _frame_for(target.global_position)
	_pos = frame["pos"]
	_look = frame["look"]
	_apply()


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	_t += delta
	var frame := _frame_for(target.global_position)
	# ease, and let the camera lag a little behind a fast walk: the strip breathes
	var k: float = 1.0 - exp(-float(_cfg["smoothing"]) * delta)
	_pos = _pos.lerp(frame["pos"], k)
	_look = _look.lerp(frame["look"], 1.0 - exp(-float(_cfg["look_smoothing"]) * delta))
	_shake = maxf(_shake - delta * float(_cfg["shake_decay"]), 0.0)
	_apply()


## Where the camera belongs for a protagonist at `at`: beside the lane, a little above, looking
## at him with a touch of lead in the direction he faces.
func _frame_for(at: Vector3) -> Dictionary:
	var zone := {}
	for z in zones:
		if at.z >= float(z["from_z"]) and at.z <= float(z["to_z"]):
			zone = z
			if z.has("pos"):
				return {"pos": z["pos"], "look": z["look"]}
	var l := lane_at(at)
	_offset = l["offset"]
	var dir: Vector3 = l["dir"]
	var out := dir.cross(Vector3.UP).normalized() * _side
	var lane_pos: Vector3 = l["pos"]
	var lead := 0.0
	if target.has_method("facing"):
		var f: Vector3 = target.facing()
		lead = clampf(f.dot(dir), -1.0, 1.0) * float(_cfg["lead"])
	# a zone may pull the lens in (a walled space the wide frame cannot see into)
	var dist := float(zone.get("distance", _cfg["distance"]))
	var high := float(zone.get("height", _cfg["height"]))
	var pos := lane_pos + out * dist + Vector3(0, high, 0) + dir * lead
	var look := at + Vector3(0, float(_cfg["look_height"]), 0) + dir * lead * 0.5
	return {"pos": pos, "look": look}


func _apply() -> void:
	var shake := Vector3.ZERO
	if _shake > 0.0:
		var s: float = _shake * _shake * float(_cfg["shake_strength"])
		shake = Vector3(sin(_t * 47.0), cos(_t * 39.0), sin(_t * 31.0)) * s
	global_position = _pos + shake
	look_at(_look, Vector3.UP)
	pitch = global_rotation.x
	yaw = global_rotation.y


# --- The shared camera interface -----------------------------------------------------------------

func add_trauma(amount: float) -> void:
	_shake = minf(_shake + amount, 1.0)


func punch(amount: float) -> void:
	add_trauma(amount * 0.5)


func cinematic(_focus: Vector3, _yaw_deg: float) -> void:
	pass   # the side view is already the frame: dialogue keeps it


func release() -> void:
	pass


func orbit(_center: Vector3, _dist: float) -> void:
	pass
