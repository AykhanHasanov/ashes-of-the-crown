extends CharacterBody3D
## Ayxan — the last heir of Atəşan. Moves, swings his sword, dashes (Kül addımı)
## and wields the crown's ember (Alov Dalğası). Each blast burns a memory, and the
## ember visibly grows brighter while his armor fades to ash.

signal health_changed(current: float, maximum: float)
signal died

const Visuals := preload("res://scripts/world/visuals.gd")
const Effects := preload("res://scripts/world/effects.gd")

const MAX_HEALTH := 100.0
const SPEED := 6.2
const ACCEL := 45.0
const DASH_SPEED := 20.0
const DASH_TIME := 0.17
const DASH_COOLDOWN := 0.75
const ATTACK_COOLDOWN := 0.38
const ATTACK_RANGE := 2.5
const ATTACK_DOT := 0.45
const ATTACK_DAMAGE := 20.0
const POWER_RADIUS := 7.0
const POWER_DAMAGE := 75.0
const POWER_COOLDOWN := 1.0
const SWORD_REST := Vector3(-30, 20, 0)

var health := MAX_HEALTH
var dead := false
var input_locked := false
var camera: Camera3D

var _dash_time := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector3.FORWARD
var _attack_cd := 0.0
var _power_cd := 0.0
var _invuln := 0.0
var _face_lock := 0.0
var _aim := Vector3.FORWARD
var _facing := Vector3.FORWARD
var _walk := 0.0
var _swing_side := 1.0

var _model: Node3D
var _sword: Node3D
var _ember_light: OmniLight3D
var _ember_mat: StandardMaterial3D
var _armor_base: Color
var _cloak_base: Color


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)

	_model = Visuals.humanoid(Color(0.4, 0.05, 0.04), Color(0.46, 0.33, 0.15), Color(0.8, 0.62, 0.5), Color(0.12, 0.07, 0.05))
	add_child(_model)
	_sword = _model.get_node("SwordPivot")
	_armor_base = _model.get_meta("armor_mat").albedo_color
	_cloak_base = _model.get_meta("cloak_mat").albedo_color

	var chest: Node3D = _model.get_node("Chest")
	_ember_mat = Visuals.glow_mat(Color(1.0, 0.45, 0.1), 3.0)
	chest.add_child(Visuals.mesh_node(Visuals.sphere(0.075), _ember_mat))
	_ember_light = OmniLight3D.new()
	_ember_light.light_color = Color(1.0, 0.5, 0.2)
	_ember_light.light_energy = 1.2
	_ember_light.omni_range = 3.5
	_ember_light.position = Vector3(0, 0, -0.25)
	chest.add_child(_ember_light)
	chest.add_child(Effects.ember_trail())

	# Soft "hero light" above Ayxan keeps him readable against the dark ground.
	var hero := OmniLight3D.new()
	hero.light_color = Color(1.0, 0.85, 0.7)
	hero.light_energy = 0.55
	hero.omni_range = 7.0
	hero.position = Vector3(0, 4.0, 0.8)
	add_child(hero)

	Memory.memory_burned.connect(_on_memory_burned)
	health_changed.emit.call_deferred(health, MAX_HEALTH)


func _physics_process(delta: float) -> void:
	_dash_cd -= delta
	_attack_cd -= delta
	_power_cd -= delta
	_invuln -= delta
	_face_lock -= delta
	if dead:
		velocity = Vector3.ZERO
		return

	var input := Vector2.ZERO
	if not input_locked:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move := _to_world(input)

	if _dash_time > 0.0:
		_dash_time -= delta
		velocity = _dash_dir * DASH_SPEED
	else:
		var target := move * SPEED
		velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
		velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)
	velocity.y = -0.5 if is_on_floor() else velocity.y - 30.0 * delta
	move_and_slide()

	if not input_locked:
		if Input.is_action_just_pressed("dash"):
			dash(move)
		if Input.is_action_just_pressed("attack"):
			attack()
		if Input.is_action_just_pressed("ember_power"):
			ember_power()

	if _face_lock > 0.0:
		_facing = _aim
	elif move.length() > 0.1:
		_facing = move.normalized()
	var yaw := atan2(-_facing.x, -_facing.z)
	_model.rotation.y = lerp_angle(_model.rotation.y, yaw, 1.0 - exp(-18.0 * delta))
	_animate(delta, Vector2(velocity.x, velocity.z).length())


func face_towards(point: Vector3) -> void:
	var d := point - global_position
	d.y = 0.0
	if d.length() > 0.01:
		_facing = d.normalized()
		_model.rotation.y = atan2(-_facing.x, -_facing.z)


func attack() -> void:
	if _attack_cd > 0.0 or dead:
		return
	_attack_cd = ATTACK_COOLDOWN
	_update_aim()
	_aim = _assist(_aim, 4.0)
	_face_lock = 0.3
	_facing = _aim
	_model.rotation.y = atan2(-_aim.x, -_aim.z)
	_swing_side = -_swing_side
	_swing_sword(_swing_side)
	Fx.slash(global_position + Vector3(0, 1.0, 0), _aim, _swing_side)

	var hit := false
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist <= ATTACK_RANGE + e.radius and (dist < 0.6 or to.normalized().dot(_aim) >= ATTACK_DOT):
			e.take_damage(ATTACK_DAMAGE, to.normalized() * 7.0)
			hit = true
	if hit:
		Fx.shake(0.22)
		Fx.hitstop(0.05)


func dash(move: Vector3) -> void:
	if _dash_cd > 0.0 or dead:
		return
	_dash_cd = DASH_COOLDOWN
	_dash_time = DASH_TIME
	_invuln = maxf(_invuln, DASH_TIME + 0.08)
	_dash_dir = move.normalized() if move.length() > 0.1 else _facing
	Fx.ash_puff(global_position)


## Alov Dalğası: a ring of fire around Ayxan. Burns the next memory in the queue.
func ember_power() -> void:
	if _power_cd > 0.0 or dead:
		return
	if not Memory.can_burn():
		Fx.notify("Yandırılacaq xatirə qalmayıb...")
		return
	_power_cd = POWER_COOLDOWN
	Memory.burn_next()
	_invuln = maxf(_invuln, 0.4)
	Fx.fire_nova(global_position, POWER_RADIUS)
	Fx.shake(0.75)
	Fx.hitstop(0.09)
	var tw := create_tween()
	tw.tween_property(_model, "scale", Vector3.ONE * 1.15, 0.06)
	tw.tween_property(_model, "scale", Vector3.ONE, 0.2)
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist <= POWER_RADIUS + e.radius:
			var falloff := lerpf(1.0, 0.55, clampf(dist / POWER_RADIUS, 0.0, 1.0))
			var dir := to.normalized() if dist > 0.01 else Vector3.FORWARD
			e.take_damage(POWER_DAMAGE * falloff, dir * 16.0)


func take_damage(amount: float, knock := Vector3.ZERO) -> void:
	if dead or _invuln > 0.0:
		return
	health = maxf(health - amount, 0.0)
	_invuln = 0.35
	velocity += knock
	health_changed.emit(health, MAX_HEALTH)
	Fx.shake(0.4)
	if health <= 0.0:
		_die()


func heal(amount: float) -> void:
	if dead:
		return
	health = minf(health + amount, MAX_HEALTH)
	health_changed.emit(health, MAX_HEALTH)


func _die() -> void:
	dead = true
	died.emit()
	var tw := create_tween().set_parallel()
	tw.tween_property(_model, "rotation:x", -PI * 0.5, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_model, "position:y", 0.3, 0.6)
	tw.tween_property(_ember_light, "light_energy", 0.0, 1.5)


func _on_memory_burned(_memory: Dictionary) -> void:
	# The ember feeds on what Ayxan forgets.
	var n := Memory.burned.size()
	var t := float(n) / Memory.MEMORIES.size()
	_ember_light.light_energy = 1.2 + n * 0.45
	_ember_light.omni_range = 3.5 + n * 0.4
	_ember_mat.emission_energy_multiplier = 3.0 + n * 1.5
	var ash := Color(0.32, 0.3, 0.29)
	_model.get_meta("armor_mat").albedo_color = _armor_base.lerp(ash, t * 0.7)
	_model.get_meta("cloak_mat").albedo_color = _cloak_base.lerp(ash * 0.6, t * 0.6)


func _to_world(v: Vector2) -> Vector3:
	if v == Vector2.ZERO or camera == null:
		return Vector3.ZERO
	var b := camera.global_transform.basis
	var fwd := -b.z
	fwd.y = 0.0
	var right := b.x
	right.y = 0.0
	var m := right.normalized() * v.x - fwd.normalized() * v.y
	return m.limit_length(1.0)


func _update_aim() -> void:
	if camera == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	var hit = Plane(Vector3.UP, global_position.y + 1.0).intersects_ray(origin, dir)
	if hit == null:
		return
	var d: Vector3 = hit - global_position
	d.y = 0.0
	if d.length() > 0.3:
		_aim = d.normalized()


## Soft aim assist: snap to the enemy closest to the aim direction within reach.
func _assist(dir: Vector3, reach: float) -> Vector3:
	var best := dir
	var best_dot := 0.5
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > reach or dist < 0.01:
			continue
		var d := to.normalized().dot(dir)
		if d > best_dot:
			best_dot = d
			best = to.normalized()
	return best


func _swing_sword(side: float) -> void:
	_sword.rotation_degrees = Vector3(-10, 85 * side, 0)
	var tw := create_tween()
	tw.tween_property(_sword, "rotation_degrees", Vector3(-10, -85 * side, 0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sword, "rotation_degrees", SWORD_REST, 0.25)


func _animate(delta: float, speed: float) -> void:
	var k := clampf(speed / SPEED, 0.0, 1.0)
	_walk += delta * speed * 2.2
	_model.position.y = absf(sin(_walk)) * 0.07 * k
	_model.rotation.x = lerpf(_model.rotation.x, -0.12 * k, 1.0 - exp(-10.0 * delta))
	# Flicker while invulnerable after a hit
	_model.visible = not (_invuln > 0.0 and _dash_time <= 0.0 and int(_invuln * 30.0) % 2 == 0 and health < MAX_HEALTH)
