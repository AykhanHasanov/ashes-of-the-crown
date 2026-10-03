extends CharacterBody3D
## Aras in the iso game: movement only (Milestone 1). Combat comes in Milestone 2.
##
## Input is screen-relative — up on the stick is up on the screen — and analog: a half-pushed
## stick walks. The body moves at speeds matched to the clips' own ground speed
## (iso/data/iso_player.json, measured by iso/tools/measure_gait.gd), and the clip is played
## at exactly speed / clip speed, so the feet do not slide. Outside the walls the default gait
## is a run; inside the caravanserai it is a walk; sprint (Shift / left trigger) swaps them.
##
## Weight: acceleration and deceleration are eased; he turns at a limited rate, leans into a
## turn (bank) and slightly into a start (pitch); a sharp reversal from standing becomes a
## short pivot on the spot rather than a snap. The dash is a burst along the input direction
## with a few frames of invulnerability for Milestone 2 to use.
##
## The model is a Human on the AnimationTree driver (Human.tree_driven), the same retargeted
## Mixamo set as everywhere else, under the shared rim overlay.

signal dashed
signal step(at: Vector3, right_foot: bool)

const Human := preload("res://scripts/characters/human.gd")
const IsoPalette := preload("res://iso/scripts/world/iso_palette.gd")
const Effects := preload("res://scripts/world/effects.gd")
const CFG := "res://iso/data/iso_player.json"
## Aras: the hooded ranger, his crimson muted towards oxblood so that fire stays the only
## strong colour on screen.
const LOOK := {"outfit": "Male_Ranger", "hood": true, "beard": true, "hair": "Hair_SimpleParted",
	"hair_color": Color(0.11, 0.08, 0.06), "cloth_hue": [0.18, 0.55, 0.985, 0.62, 0.52], "idle": "Idle_Upright"}

var camera_rig                 # IsoCamera: screen directions come from it
var world                      # IsoWorld: calm zones
var input_locked := false
## Test / capture only: a fixed input direction (screen space, x right, y up) instead of the
## stick. Vector2.ZERO = read the stick.
var auto_input := Vector2.ZERO
var invulnerable := false
var model: Node3D

var _cfg: Dictionary
var _facing := Vector3(0, 0, -1)
var _speed := 0.0
var _yaw_vel := 0.0
var _lean := 0.0
var _pitch := 0.0
var _pivot_t := 0.0
var _pivot_from := 0.0
var _pivot_to := 0.0
var _dash_t := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector3.ZERO
var _lean_root: Node3D
var _step_clock := 0.0
var _right_foot := false


func _ready() -> void:
	_cfg = JSON.parse_string(FileAccess.get_file_as_string(CFG))
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.75
	shape.shape = cap
	shape.position.y = 0.88
	add_child(shape)
	_lean_root = Node3D.new()
	_lean_root.name = "Lean"
	add_child(_lean_root)
	Human.tree_driven = true
	model = Human.build(LOOK)
	model.crowd_variety = false
	_lean_root.add_child(model)
	model.set_overlay(IsoPalette.get_mat("rim"))
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)


func face_towards(p: Vector3) -> void:
	var d := (p - global_position) * Vector3(1, 0, 1)
	if d.length() > 0.01:
		_facing = d.normalized()
		_apply_facing()


func facing() -> Vector3:
	return _facing


func _physics_process(delta: float) -> void:
	var input := _read_input()
	var dir := Vector3.ZERO
	if input.length() > 0.05 and camera_rig != null:
		var sb: Array = camera_rig.screen_basis()
		dir = (sb[0] as Vector3) * input.y + (sb[1] as Vector3) * input.x
		dir = dir.normalized() * minf(input.length(), 1.0)
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	if _dash_t > 0.0:
		_tick_dash(delta)
	else:
		if not input_locked and Input.is_action_just_pressed("dash") and _dash_cd <= 0.0:
			_start_dash(dir)
		_tick_move(dir, delta)
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	_tick_steps(delta)


func _read_input() -> Vector2:
	if auto_input != Vector2.ZERO:
		return auto_input
	if input_locked:
		return Vector2.ZERO
	var v := Input.get_vector("move_left", "move_right", "move_down", "move_up")
	return v


func _tick_move(dir: Vector3, delta: float) -> void:
	var calm: bool = world != null and world.calm_zone.has_point(global_position + Vector3(0, 0.5, 0))
	var swap := Input.is_action_pressed("sprint")
	var running := calm == swap
	var top := float(_cfg["run_speed"] if running else _cfg["walk_speed"])
	var want := top * dir.length()
	if dir.length() > 0.05 and dir.length() < 0.55:
		want = minf(want, float(_cfg["walk_speed"]))     # a half-pushed stick always walks
	var rate := float(_cfg["accel"] if want > _speed else _cfg["decel"])
	_speed = move_toward(_speed, want, rate * delta)
	# turning: a sharp reversal from (almost) standing is a pivot on the spot
	if dir.length() > 0.05:
		var goal := atan2(-dir.x, -dir.z)
		var cur := atan2(-_facing.x, -_facing.z)
		var diff := wrapf(goal - cur, -PI, PI)
		if _pivot_t <= 0.0 and _speed < 0.6 and absf(diff) > deg_to_rad(float(_cfg["turn_in_place_deg"])):
			_pivot_t = float(_cfg["turn_in_place_time"])
			_pivot_from = cur
			_pivot_to = cur + diff
		if _pivot_t > 0.0:
			_pivot_t -= delta
			var k := 1.0 - clampf(_pivot_t / float(_cfg["turn_in_place_time"]), 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			var a := lerpf(_pivot_from, _pivot_to, k)
			_yaw_vel = 0.0
			_facing = Vector3(-sin(a), 0, -cos(a))
			_speed = minf(_speed, 0.3)
		else:
			var step := clampf(diff, -float(_cfg["turn_rate"]) * delta, float(_cfg["turn_rate"]) * delta)
			_yaw_vel = step / maxf(delta, 0.0001)
			var a := cur + step
			_facing = Vector3(-sin(a), 0, -cos(a))
	else:
		_yaw_vel = 0.0
		_pivot_t = 0.0
	_apply_facing()
	var move_dir := _facing if dir.length() > 0.05 else _facing
	velocity.x = move_dir.x * _speed
	velocity.z = move_dir.z * _speed
	_animate(delta, running)


## Where on idle → walk → run he is, and how fast the clips play, from his real speed.
func _animate(delta: float, _running: bool) -> void:
	var walk := float(_cfg["walk_speed"])
	var run := float(_cfg["run_speed"])
	var cw := float(_cfg["clip_speed"]["walk"])
	var cr := float(_cfg["clip_speed"]["run"])
	var blend := 0.0
	var rate := 1.0
	if _pivot_t > 0.0:
		blend = 0.32          # feet shuffling round on the spot
		rate = 1.4
	elif _speed <= walk:
		blend = 0.5 * _speed / walk
		rate = maxf(walk / cw, 0.6)
	else:
		var k := (_speed - walk) / (run - walk)
		blend = 0.5 + 0.5 * k
		rate = lerpf(walk / cw, run / cr, k)
	model.set_gait(blend, rate)
	# lean: bank into a turn, a touch forward when picking up speed
	var bank := clampf(-_yaw_vel * _speed * 0.045, -1.0, 1.0) * deg_to_rad(float(_cfg["lean_deg"]))
	var fwd := clampf(_speed / run, 0.0, 1.0) * deg_to_rad(3.0)
	var s := 1.0 - exp(-float(_cfg["lean_smoothing"]) * delta)
	_lean = lerpf(_lean, bank, s)
	_pitch = lerpf(_pitch, fwd, s)
	model.rotation = Vector3(-_pitch, 0, _lean)


func _apply_facing() -> void:
	_lean_root.rotation.y = atan2(-_facing.x, -_facing.z)


# --- Dash ---------------------------------------------------------------------------------------

func _start_dash(dir: Vector3) -> void:
	_dash_dir = dir.normalized() if dir.length() > 0.1 else _facing
	_facing = _dash_dir
	_apply_facing()
	_dash_t = float(_cfg["dash_time"])
	_dash_cd = float(_cfg["dash_cooldown"]) + _dash_t
	invulnerable = true
	var trail := Effects.ash_trail(0.5, 16)
	trail.position = global_position + Vector3(0, 0.6, 0)
	get_parent().add_child(trail)
	trail.emitting = true
	get_tree().create_timer(1.5).timeout.connect(trail.queue_free)
	dashed.emit()


func _tick_dash(delta: float) -> void:
	_dash_t -= delta
	var total := float(_cfg["dash_time"])
	var k := 1.0 - clampf(_dash_t / total, 0.0, 1.0)
	# fast out, eased into the stop
	var spd := float(_cfg["dash_speed"]) * (1.0 - k * k * 0.75)
	velocity.x = _dash_dir.x * spd
	velocity.z = _dash_dir.z * spd
	_speed = float(_cfg["run_speed"])
	if total - _dash_t >= float(_cfg["dash_iframes"]):
		invulnerable = false
	model.set_gait(1.0, 2.2)
	model.rotation = Vector3(-deg_to_rad(16.0), 0, 0)
	if _dash_t <= 0.0:
		invulnerable = false


# --- Footsteps ------------------------------------------------------------------------------------

## One step per half cycle of whichever clip he is on: footprints and the sound hang off it.
func _tick_steps(delta: float) -> void:
	if _speed < 0.25 or not is_on_floor():
		_step_clock = 0.0
		return
	var walk := float(_cfg["walk_speed"])
	var stride := 0.6 if _speed <= walk else 1.05     # metres per step, walk / run
	_step_clock += _speed * delta
	if _step_clock >= stride:
		_step_clock -= stride
		_right_foot = not _right_foot
		var side := _facing.cross(Vector3.UP) * (-0.12 if _right_foot else 0.12)
		step.emit(global_position + side, _right_foot)
