extends Node3D
## Isometric-style follow camera (south-east, looking north-west) with trauma-based
## shake, a cinematic close-up mode for dialogue and a slow orbit for the title screen.

const YAW := 45.0
const PITCH := -50.0
const DISTANCE := 19.0
const FOV := 42.0
const CINE_PITCH := -12.0
const CINE_DISTANCE := 6.5
const CINE_FOV := 32.0

var target: Node3D
var camera: Camera3D
var trauma := 0.0

var _cine := false
var _cine_focus := Vector3.ZERO
var _cine_yaw := 0.0
var _focus := Vector3.ZERO
var _yaw := YAW
var _pitch := PITCH
var _dist := DISTANCE
var _punch := 0.0
var _orbit := false
var _orbit_center := Vector3.ZERO
var _orbit_dist := 24.0


func _ready() -> void:
	top_level = true
	camera = Camera3D.new()
	camera.fov = FOV
	camera.far = 250.0
	add_child(camera)
	camera.current = true


func snap() -> void:
	if is_instance_valid(target):
		_focus = target.global_position + Vector3(0, 1.0, 0)
	_place()


func cinematic(focus: Vector3, yaw_deg: float) -> void:
	_cine = true
	_cine_focus = focus
	_cine_yaw = yaw_deg


func release() -> void:
	_cine = false
	_orbit = false


## Slow circling shot around `center` (title screen). Ends with release().
func orbit(center: Vector3, dist: float) -> void:
	_orbit = true
	_orbit_center = center
	_orbit_dist = dist
	_focus = center
	_pitch = -24.0
	_dist = dist
	_place()


func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


## Short zoom-in that springs back (finishers, ember blasts).
func punch(amount: float) -> void:
	_punch = maxf(_punch, amount)


func _process(delta: float) -> void:
	if _orbit:
		_yaw += delta * 3.5
		_focus = _orbit_center
		_pitch = -24.0
		_dist = _orbit_dist
		camera.fov = FOV
		_place()
		return
	var want_focus := _focus
	if _cine:
		want_focus = _cine_focus
	elif is_instance_valid(target):
		want_focus = target.global_position + Vector3(0, 1.0, 0)
	var k := 1.0 - exp(-delta * (2.5 if _cine else 7.0))
	_focus = _focus.lerp(want_focus, k)
	_yaw = rad_to_deg(lerp_angle(deg_to_rad(_yaw), deg_to_rad(_cine_yaw if _cine else YAW), k))
	_pitch = lerpf(_pitch, CINE_PITCH if _cine else PITCH, k)
	_dist = lerpf(_dist, CINE_DISTANCE if _cine else DISTANCE, k)
	camera.fov = lerpf(camera.fov, CINE_FOV if _cine else FOV, k)
	trauma = maxf(trauma - delta * 1.6, 0.0)
	_punch = maxf(_punch - delta * 3.0, 0.0)
	_place()


func _place() -> void:
	var b := Basis.from_euler(Vector3(deg_to_rad(_pitch), deg_to_rad(_yaw), 0.0))
	var pos := _focus + b * Vector3(0, 0, _dist * (1.0 - 0.12 * _punch * _punch))
	var s := trauma * trauma
	var t := Time.get_ticks_msec() * 0.001
	var off := Vector3(sin(t * 43.0), sin(t * 37.0 + 1.3), 0.0) * s * 0.45
	camera.global_position = pos + b * off
	camera.look_at(_focus + b * off * 0.5, Vector3.UP)
