extends CharacterBody3D
## A survivor at Son Ocaq, driven by a small utility AI.
##
## Three needs drain over time — warmth, company and duty. Every so often the
## survivor scores the activities that would restore them (sit by the hearth,
## talk to someone, tend their own station, wander) and picks the most pressing
## one, with a little randomness and a personality weighting. The result is a camp
## where people drift between the fire, each other and their posts on their own.
##
## Modes let the chapter take over: HOLD (stop for a conversation), FLEE (hide during an attack).

const CharacterModel := preload("res://scripts/characters/character_model.gd")
const Survivors := preload("res://scripts/story/survivors.gd")

enum Mode { LIVE, HOLD, FLEE }

const WALK := 1.7
const RUN := 4.2

var id := ""
var display_name := ""
var mode := Mode.LIVE
## Set by the chapter: hearth centre, yard half-size, hiding place.
var hearth := Vector3.ZERO
var yard := 15.0
var hide_spot := Vector3.ZERO

var _model
var _station := Vector3.ZERO
var _station_clip := "Idle"
var _station_yaw := 0.0
var _needs := {"warmth": 1.0, "company": 1.0, "duty": 1.0}
## How quickly each need drains for this person (personality).
var _drain := {"warmth": 0.02, "company": 0.02, "duty": 0.02}
var _activity := ""
var _target := Vector3.ZERO
var _target_clip := "Idle"
var _target_yaw := NAN
var _partner
var _time_left := 0.0
var _arrived := false


func setup(survivor_id: String) -> void:
	id = survivor_id
	display_name = Survivors.display_name(id)
	var p: Dictionary = Survivors.PEOPLE[id]
	_station = p["station"][0]
	_station_clip = p["station"][1]
	_station_yaw = deg_to_rad(p["station"][2])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	for k in _drain:
		_drain[k] = rng.randf_range(0.01, 0.035)
	for k in _needs:
		_needs[k] = rng.randf_range(0.5, 1.0)


func _ready() -> void:
	add_to_group("survivors")
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)

	var p: Dictionary = Survivors.PEOPLE[id]
	_model = CharacterModel.new()
	add_child(_model)
	_model.setup(Survivors.model_path(id), p["hidden"], 0.82)
	_model.move_anim = "Walking_A"
	var rc: Array = p["recolor"]
	if rc.size() == 5:
		_model.recolor(rc[0], rc[1], rc[2], rc[3], rc[4])
	if id == "rufet":
		var cape: MeshInstance3D = _model.mesh("Knight_Cape")
		if cape:
			var blue := StandardMaterial3D.new()
			blue.albedo_color = Color(0.1, 0.15, 0.3)
			cape.material_override = blue
	global_position = _station
	_model.rotation.y = _station_yaw
	_start("work")


func face(point: Vector3) -> void:
	var d := point - global_position
	d.y = 0.0
	if d.length() > 0.01:
		_model.rotation.y = atan2(-d.x, -d.z)


## Stop and look at the protagonist (conversation), or resume life.
func hold(on: bool) -> void:
	if mode == Mode.LIVE and on:
		mode = Mode.HOLD
	elif mode == Mode.HOLD and not on:
		mode = Mode.LIVE
		_start(_pick_activity())


func flee() -> void:
	if mode in [Mode.LIVE, Mode.HOLD]:
		mode = Mode.FLEE
		_arrived = false


## Back to normal life once the danger has passed.
func return_to_camp() -> void:
	if mode == Mode.FLEE:
		mode = Mode.LIVE
		_start("work")


func _physics_process(delta: float) -> void:
	for k in _needs:
		_needs[k] = maxf(_needs[k] - _drain[k] * delta, 0.0)

	var goal := global_position
	var speed := 0.0
	match mode:
		Mode.LIVE:
			goal = _partner.global_position if _activity == "talk" and is_instance_valid(_partner) else _target
			speed = WALK
		Mode.HOLD:
			goal = global_position
		Mode.FLEE:
			goal = hide_spot
			speed = RUN

	var to := goal - global_position
	to.y = 0.0
	var reach := 1.6 if _activity == "talk" else 0.3
	var moving := to.length() > reach and speed > 0.0
	if moving:
		var dir := (to.normalized() + _separation() * 0.8).normalized()
		velocity = Vector3(dir.x * speed, -0.5, dir.z * speed)
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-8.0 * delta))
		_model.move_anim = "Running_A" if speed > WALK * 1.5 else "Walking_A"
		_arrived = false
	else:
		velocity = Vector3(0, -0.5, 0)
		if not _arrived:
			_arrived = true
			_on_arrived()
	move_and_slide()
	_model.set_locomotion(moving, 1.0)

	if mode == Mode.LIVE and _arrived:
		_satisfy(delta)
		_time_left -= delta
		if _time_left <= 0.0:
			_start(_pick_activity())


func _on_arrived() -> void:
	match mode:
		Mode.LIVE:
			_model.set_idle(_target_clip)
			if not is_nan(_target_yaw):
				_model.rotation.y = _target_yaw
			elif _activity == "talk" and is_instance_valid(_partner):
				face(_partner.global_position)
			elif _activity == "warm":
				face(hearth)
		Mode.FLEE:
			_model.set_idle("Sit_Floor_Idle")


func _satisfy(delta: float) -> void:
	var need: String = {"warm": "warmth", "talk": "company", "work": "duty"}.get(_activity, "")
	if need != "":
		_needs[need] = minf(_needs[need] + 0.12 * delta, 1.0)


## Scores every activity from how badly its need is felt and picks the best.
func _pick_activity() -> String:
	var scores := {
		"warm": (1.0 - _needs["warmth"]) * 1.2,
		"talk": (1.0 - _needs["company"]) * 1.0,
		"work": (1.0 - _needs["duty"]) * 1.1 + 0.15,
		"wander": 0.12,
	}
	var best := "work"
	var best_score := -1.0
	for a in scores:
		var s: float = scores[a] + randf() * 0.2
		if a == _activity:
			s -= 0.25  # prefer variety
		if s > best_score:
			best_score = s
			best = a
	return best


func _start(activity: String) -> void:
	_activity = activity
	_arrived = false
	_partner = null
	_target_yaw = NAN
	_time_left = randf_range(9.0, 18.0)
	match activity:
		"work":
			_target = _station
			_target_clip = _station_clip
			_target_yaw = _station_yaw
		"warm":
			var a := randf() * TAU
			_target = hearth + Vector3(cos(a), 0, sin(a)) * randf_range(2.4, 3.2)
			_target_clip = "Sit_Floor_Idle" if randf() < 0.6 else "Idle"
		"talk":
			var others := get_tree().get_nodes_in_group("survivors").filter(func(s): return s != self and s.mode == Mode.LIVE)
			if others.is_empty():
				_start("work")
				return
			_partner = others.pick_random()
			_target_clip = "Idle"
		"wander":
			_target = Vector3(randf_range(-yard, yard), 0, randf_range(-yard, yard * 0.7))
			_target_clip = "Idle"
			_time_left = randf_range(3.0, 6.0)


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("survivors"):
		if other == self:
			continue
		var d: Vector3 = global_position - other.global_position
		d.y = 0.0
		var l := d.length()
		if l < 1.0 and l > 0.001:
			push += d / l * (1.0 - l)
	return push
