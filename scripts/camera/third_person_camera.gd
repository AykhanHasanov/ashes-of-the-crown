extends Node3D
## Over-the-shoulder camera (V3). A yaw/pitch pivot follows the protagonist; a SpringArm3D
## pulls the camera in when a wall gets between them. The mouse (captured) or the
## right stick turns it. Lock-on swings it so player and target share the frame;
## in combat it drifts back and widens. It also keeps the old rig's API
## (cinematic/release/orbit/add_trauma/punch/snap/camera) for dialogues and Fx.

var target: Node3D          # The protagonist
var lock_target: Node3D     # a Combatant, or null
var in_combat := false
var camera: Camera3D
var trauma := 0.0
var yaw := 0.0
var pitch := deg_to_rad(-18.0)

var _cfg: Dictionary
var _pivot: Node3D
var _spring: SpringArm3D
var _punch := 0.0
var _cine := false
var _cine_focus := Vector3.ZERO
var _cine_yaw := 0.0
var _cine_blend := 0.0
var _orbit := false
var _orbit_center := Vector3.ZERO
var _orbit_dist := 24.0


func _ready() -> void:
	_cfg = DataDB.balance("combat")["camera"]
	top_level = true
	_pivot = Node3D.new()
	add_child(_pivot)
	_spring = SpringArm3D.new()
	_spring.collision_mask = 1
	_spring.margin = 0.2
	_spring.spring_length = _cfg["distance"]
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	_spring.shape = probe
	_pivot.add_child(_spring)
	camera = Camera3D.new()
	camera.fov = _cfg["fov"]
	camera.far = 600.0
	camera.near = 0.08
	_spring.add_child(camera)
	camera.current = true


func snap() -> void:
	if is_instance_valid(target):
		global_position = target.global_position
		yaw = target.global_rotation.y
		if target is CollisionObject3D:
			_spring.add_excluded_object(target.get_rid())


## Camera-relative flat basis for movement input.
func flat_forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func flat_right() -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _cine:
		var sens: float = _cfg["mouse_sensitivity"]
		yaw -= event.relative.x * sens
		pitch = clampf(pitch - event.relative.y * sens, deg_to_rad(_cfg["pitch_min"]), deg_to_rad(_cfg["pitch_max"]))


func _process(delta: float) -> void:
	if _orbit:
		_do_orbit(delta)
		return
	if not is_instance_valid(target):
		return
	var real_delta := delta / maxf(Engine.time_scale, 0.001)
	# Right stick
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look.length() > 0.1 and not _cine:
		var ps: float = _cfg["pad_sensitivity"]
		yaw -= look.x * ps * real_delta
		pitch = clampf(pitch - look.y * ps * 0.6 * real_delta, deg_to_rad(_cfg["pitch_min"]), deg_to_rad(_cfg["pitch_max"]))

	var height: float = _cfg["height"]
	var want_pos: Vector3 = target.global_position + Vector3(0, height, 0)
	var want_len: float = _cfg["combat_distance"] if in_combat else _cfg["distance"]
	var want_fov: float = _cfg["combat_fov"] if in_combat else _cfg["fov"]
	var want_shoulder: float = _cfg["shoulder"]
	if is_instance_valid(lock_target) and not lock_target.dead:
		# Look from behind the protagonist toward the target, a little from above
		var to: Vector3 = lock_target.global_position - target.global_position
		to.y = 0.0
		if to.length() > 0.3:
			var want_yaw := atan2(-to.x, -to.z)
			yaw = lerp_angle(yaw, want_yaw, 1.0 - exp(-8.0 * real_delta))
			pitch = lerpf(pitch, deg_to_rad(_cfg["lock_pitch"]), 1.0 - exp(-4.0 * real_delta))
		want_len = _cfg["lock_distance"]
		want_shoulder = _cfg["lock_shoulder"]  # step aside so the protagonist doesn't hide the target
		want_pos = want_pos.lerp(lock_target.global_position + Vector3(0, height * 0.7, 0), 0.3)

	global_position = global_position.lerp(want_pos, 1.0 - exp(-14.0 * real_delta))
	_spring.spring_length = lerpf(_spring.spring_length, want_len * (1.0 - 0.1 * _punch * _punch), 1.0 - exp(-5.0 * real_delta))
	camera.fov = lerpf(camera.fov, want_fov, 1.0 - exp(-4.0 * real_delta))
	_pivot.rotation = Vector3(pitch, yaw, 0.0)
	camera.h_offset = lerpf(camera.h_offset, 0.0 if _cine else want_shoulder, 1.0 - exp(-6.0 * real_delta))

	# Dialogue close-up overrides the orbit
	_cine_blend = move_toward(_cine_blend, 1.0 if _cine else 0.0, real_delta * 1.6)
	if _cine_blend > 0.0:
		var b := Basis.from_euler(Vector3(deg_to_rad(-12.0), deg_to_rad(_cine_yaw), 0.0))
		var cine_pos := _cine_focus + b * Vector3(0, 0, 6.0)
		var k := _cine_blend * _cine_blend * (3.0 - 2.0 * _cine_blend)
		camera.global_position = camera.global_position.lerp(cine_pos, k)
		var look_at_point := _cine_focus.lerp(_pivot.global_position - _pivot.global_basis.z * 3.0, 1.0 - k)
		camera.look_at(look_at_point, Vector3.UP)

	# Shake
	trauma = maxf(trauma - delta * 1.8, 0.0)
	_punch = maxf(_punch - delta * 3.0, 0.0)
	var s := trauma * trauma
	var t := Time.get_ticks_msec() * 0.001
	camera.v_offset = sin(t * 37.0 + 1.3) * s * 0.25
	camera.h_offset += sin(t * 43.0) * s * 0.25


func _do_orbit(delta: float) -> void:
	yaw += delta * deg_to_rad(3.5)
	pitch = deg_to_rad(-24.0)
	global_position = _orbit_center
	_spring.spring_length = _orbit_dist
	_pivot.rotation = Vector3(pitch, yaw, 0.0)


# --- API shared with the old rig (dialogue, Fx, title screen) ---------------------------------

func cinematic(focus: Vector3, yaw_deg: float) -> void:
	_cine = true
	_cine_focus = focus
	_cine_yaw = yaw_deg


func release() -> void:
	_cine = false
	_orbit = false


func orbit(center: Vector3, dist: float) -> void:
	_orbit = true
	_orbit_center = center
	_orbit_dist = dist


func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


func punch(amount: float) -> void:
	_punch = maxf(_punch, amount)
