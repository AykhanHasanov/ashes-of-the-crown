extends CharacterBody3D
## Kül Kölgəsi — an ash shade risen from the burned city. Rises from the ground,
## chases Ayxan, telegraphs (eyes flare, arms rise), lunges, then recovers.
## Kinds: "normal", "fast" and "elite" (Kül Cəngavəri, a fallen crown guard).

signal killed(shade: Node)

const Visuals := preload("res://scripts/world/visuals.gd")
const Effects := preload("res://scripts/world/effects.gd")
const SHADE_SHADER := preload("res://shaders/shade.gdshader")

enum State { RISING, CHASE, WINDUP, LUNGE, RECOVER, DEAD }

var kind := "normal"
var display_name := "Kül Kölgəsi"
var max_health := 40.0
var health := 40.0
var damage := 12.0
var speed := 3.4
var windup_time := 0.55
var radius := 0.45
var size := 1.0
var target  # the player node; untyped so its script members resolve at runtime

var _state := State.RISING
var _timer := 0.0
var _lunge_dir := Vector3.FORWARD
var _lunge_hit := false
var _knock := Vector3.ZERO
var _flash := 0.0
var _t := 0.0
var _lean := 0.0
var _arm_raise := 0.0
var _mat: ShaderMaterial
var _eye_mat: StandardMaterial3D
var _model: Node3D
var _arms: Array[Node3D] = []
var _shape: CollisionShape3D


func configure(k: String) -> void:
	kind = k
	match k:
		"fast":
			max_health = 26.0
			damage = 9.0
			speed = 5.4
			windup_time = 0.4
			size = 0.85
		"elite":
			display_name = "Kül Cəngavəri"
			max_health = 260.0
			damage = 24.0
			speed = 3.0
			windup_time = 0.8
			size = 1.7
			radius = 0.8
	health = max_health


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 5
	_t = randf() * 10.0
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = maxf(1.9 * size, radius * 2.0 + 0.1)
	_shape.shape = cap
	_shape.position.y = cap.height * 0.5
	add_child(_shape)
	_build_model()

	# Rise out of the ash
	_model.position.y = -2.2 * size
	_mat.set_shader_parameter("dissolve", 0.9)
	var tw := create_tween().set_parallel()
	tw.tween_property(_model, "position:y", 0.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(v: float): _mat.set_shader_parameter("dissolve", v), 0.9, 0.0, 0.9)
	_timer = 0.9


func _build_model() -> void:
	_model = Node3D.new()
	_model.scale = Vector3.ONE * size
	add_child(_model)
	_mat = Visuals.shader_mat(SHADE_SHADER)
	_eye_mat = Visuals.glow_mat(Color(1.0, 0.45, 0.1), 6.0)

	_model.add_child(Visuals.mesh_node(Visuals.cylinder(0.3, 0.06, 0.8), _mat, Vector3(0, 0.4, 0)))
	_model.add_child(Visuals.mesh_node(Visuals.capsule(0.32, 1.3), _mat, Vector3(0, 1.1, 0), Vector3(8, 0, 0), Vector3(0.9, 1, 0.8)))
	_model.add_child(Visuals.mesh_node(Visuals.sphere(0.2), _mat, Vector3(0, 1.78, -0.12)))
	for x in [-0.075, 0.075]:
		_model.add_child(Visuals.mesh_node(Visuals.sphere(0.035), _eye_mat, Vector3(x, 1.8, -0.3)))
	for x in [-0.34, 0.34]:
		var arm := Node3D.new()
		arm.position = Vector3(x, 1.5, -0.05)
		_model.add_child(arm)
		arm.add_child(Visuals.mesh_node(Visuals.capsule(0.07, 1.15), _mat, Vector3(0, -0.5, -0.08), Vector3(-10, 0, 0)))
		arm.add_child(Visuals.mesh_node(Visuals.box(Vector3(0.14, 0.24, 0.05)), _mat, Vector3(0, -1.1, -0.18), Vector3(-25, 0, 0)))
		_arms.append(arm)

	if kind == "elite":
		# Charred crown-guard helmet, pauldrons and a great blade
		var gold := Visuals.mat(Color(0.35, 0.24, 0.1), 0.4, 0.9)
		_model.add_child(Visuals.mesh_node(Visuals.cylinder(0.2, 0.24, 0.3), gold, Vector3(0, 1.9, -0.12)))
		_model.add_child(Visuals.mesh_node(Visuals.box(Vector3(0.05, 0.3, 0.05)), gold, Vector3(0, 2.12, -0.12)))
		for x in [-0.36, 0.36]:
			_model.add_child(Visuals.mesh_node(Visuals.sphere(0.18), gold, Vector3(x, 1.55, 0), Vector3.ZERO, Vector3(1, 0.7, 1)))
		var blade := Visuals.mesh_node(Visuals.box(Vector3(0.1, 0.03, 1.5)), Visuals.glow_mat(Color(1.0, 0.3, 0.05), 2.0), Vector3(0, -1.1, -0.8))
		_arms[1].add_child(blade)

	var trail := Effects.ash_trail(size, 18 if kind == "elite" else 10)
	trail.position.y = 1.0 * size
	add_child(trail)


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta * 5.0, 0.0)
	_mat.set_shader_parameter("hit_flash", _flash)
	_knock = _knock.move_toward(Vector3.ZERO, 30.0 * delta)
	if _state == State.DEAD:
		return
	_timer -= delta

	var to := Vector3.ZERO
	var has_target: bool = is_instance_valid(target) and not target.dead
	if has_target:
		to = target.global_position - global_position
		to.y = 0.0
	var dist := to.length()
	var move := Vector3.ZERO

	match _state:
		State.RISING:
			if _timer <= 0.0:
				_state = State.CHASE
		State.CHASE:
			if has_target:
				if dist < 1.9 + radius:
					_begin_windup()
				else:
					move = (to.normalized() + _separation() * 1.2).normalized() * speed
				_face(to, delta)
		State.WINDUP:
			_face(to, delta)
			if _timer <= 0.0:
				_state = State.LUNGE
				_timer = 0.22
				_lunge_dir = to.normalized() if dist > 0.01 else -_model.global_basis.z
				_lunge_hit = false
		State.LUNGE:
			move = _lunge_dir * speed * 3.4
			if has_target and not _lunge_hit and dist < 1.3 + radius:
				_lunge_hit = true
				target.take_damage(damage, _lunge_dir * 8.0)
			if _timer <= 0.0:
				_state = State.RECOVER
				_timer = 0.7
		State.RECOVER:
			if _timer <= 0.0:
				_state = State.CHASE

	velocity = Vector3(move.x + _knock.x, 0.0, move.z + _knock.z)
	move_and_slide()
	_animate(delta)


func take_damage(amount: float, knock := Vector3.ZERO) -> void:
	if _state == State.DEAD:
		return
	health -= amount
	_flash = 1.0
	_knock += knock * (0.25 if kind == "elite" else 1.0)
	Fx.hit_spark(global_position + Vector3(0, 1.1 * size, 0))
	if kind != "elite" and _state == State.WINDUP:
		_state = State.RECOVER  # stagger interrupts the lunge
		_timer = 0.35
	if health <= 0.0:
		_die()


func _begin_windup() -> void:
	_state = State.WINDUP
	_timer = windup_time


func _die() -> void:
	_state = State.DEAD
	remove_from_group("enemies")
	_shape.set_deferred("disabled", true)
	Fx.death_burst(global_position, size)
	var tw := create_tween()
	tw.tween_method(func(v: float): _mat.set_shader_parameter("dissolve", v), 0.0, 1.0, 0.7)
	tw.tween_callback(queue_free)
	killed.emit(self)


func _face(dir: Vector3, delta: float) -> void:
	if dir.length() > 0.01:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-10.0 * delta))


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self:
			continue
		var d: Vector3 = global_position - other.global_position
		d.y = 0.0
		var l := d.length()
		if l < 1.4 and l > 0.001:
			push += d / l * (1.4 - l)
	return push


func _animate(delta: float) -> void:
	var want_lean := 0.0
	var want_arms := 0.0
	var eye := 6.0
	match _state:
		State.WINDUP:
			want_lean = -0.35
			want_arms = 1.0
			eye = 18.0
		State.LUNGE:
			want_lean = 0.45
			want_arms = -0.4
			eye = 12.0
	var k := 1.0 - exp(-12.0 * delta)
	_lean = lerpf(_lean, want_lean, k)
	_arm_raise = lerpf(_arm_raise, want_arms, k)
	_model.rotation.x = _lean
	_eye_mat.emission_energy_multiplier = lerpf(_eye_mat.emission_energy_multiplier, eye, k)
	for i in _arms.size():
		var sway := sin(_t * 2.4 + i * 1.7) * 0.15
		_arms[i].rotation.x = _arm_raise * 2.2 + sway
	if _state != State.RISING:
		_model.position.y = sin(_t * 2.0) * 0.06
