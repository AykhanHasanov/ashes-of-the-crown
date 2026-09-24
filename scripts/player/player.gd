extends CharacterBody3D
## Ayxan — the last heir of Atəşan, hooded in exile (KayKit Rogue with the Knight's sword).
##
## Combat: a three-hit sword combo (diagonal → horizontal → heavy chop) with input
## buffering, a forward lunge on each swing and damage dealt on the impact frame;
## Kül addımı (dodge roll with i-frames); Alov Dalğası (ember nova) which burns the
## next memory. As memories burn, ember cracks spread over his armor.

signal health_changed(current: float, maximum: float)
signal died

const CharacterModel := preload("res://scripts/characters/character_model.gd")
const Effects := preload("res://scripts/world/effects.gd")
const OVERLAY := preload("res://shaders/ash_overlay.gdshader")
const MODEL_PATH := "res://assets/characters/adventurers/Rogue_Hooded.glb"
const SWORD_DONOR := "res://assets/characters/adventurers/Knight.glb"
const HIDDEN := ["Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable"]

const MAX_HEALTH := 100.0
const SPEED := 6.2
const ACCEL := 50.0
const LUNGE_SPEED := 7.5
const DASH_SPEED := 15.0
const DASH_TIME := 0.26
const DASH_COOLDOWN := 0.55
const POWER_RADIUS := 7.0
const POWER_DAMAGE := 75.0
const POWER_COOLDOWN := 1.0
const CAST_TRIGGER := 0.26
const CAST_TIME := 0.5
const HURT_STUN := 0.25

## impact/cancel are real seconds after the swing starts.
const COMBO := [
	{"clip": "1H_Melee_Attack_Slice_Diagonal", "speed": 1.9, "impact": 0.22, "cancel": 0.34, "damage": 18.0, "knock": 6.0, "dot": 0.4, "range": 2.5, "heavy": false},
	{"clip": "1H_Melee_Attack_Slice_Horizontal", "speed": 1.9, "impact": 0.23, "cancel": 0.36, "damage": 21.0, "knock": 7.0, "dot": 0.35, "range": 2.6, "heavy": false},
	{"clip": "1H_Melee_Attack_Chop", "speed": 1.55, "impact": 0.3, "cancel": 0.5, "damage": 38.0, "knock": 13.0, "dot": 0.25, "range": 2.9, "heavy": true},
]

var health := MAX_HEALTH
var dead := false
var input_locked := false
var camera: Camera3D

var _model
var _overlay: ShaderMaterial
var _cloth: Array = []
var _ember: Node3D
var _ember_light: OmniLight3D
var _ember_mat: StandardMaterial3D

var _aim := Vector3.FORWARD
var _facing := Vector3.FORWARD
var _attack_step := -1
var _attack_t := 0.0
var _impact_done := false
var _buffered := false
var _dash_time := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector3.FORWARD
var _power_cd := 0.0
var _cast_t := -1.0
var _stun := 0.0
var _invuln := 0.0
var _flash := 0.0
var _step_dist := 0.0


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

	_model = CharacterModel.new()
	add_child(_model)
	_model.setup(MODEL_PATH, HIDDEN, 0.82)
	# Green rogue cloth becomes the deep crimson of the royal house
	_cloth = _model.recolor(0.18, 0.55, 0.0, 1.15, 0.7)
	_model.borrow(SWORD_DONOR, "1H_Sword", "handslot.r")
	_overlay = ShaderMaterial.new()
	_overlay.shader = OVERLAY
	_overlay.set_shader_parameter("intensity", 0.0)
	_overlay.set_shader_parameter("scale", 9.0)
	_overlay.set_shader_parameter("flash_color", Color(0.6, 0.05, 0.02))
	_model.set_overlay(_overlay)

	# The crown's ember, kept on the chest bone every frame
	_ember = Node3D.new()
	_ember.top_level = true
	add_child(_ember)
	_ember_mat = StandardMaterial3D.new()
	_ember_mat.albedo_color = Color(1.0, 0.45, 0.1)
	_ember_mat.emission_enabled = true
	_ember_mat.emission = Color(1.0, 0.45, 0.1)
	_ember_mat.emission_energy_multiplier = 3.0
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	core.mesh = sphere
	core.material_override = _ember_mat
	_ember.add_child(core)
	_ember_light = OmniLight3D.new()
	_ember_light.light_color = Color(1.0, 0.5, 0.2)
	_ember_light.light_energy = 1.2
	_ember_light.omni_range = 3.5
	_ember.add_child(_ember_light)
	_ember.add_child(Effects.ember_trail())

	# Soft "hero light" keeps Ayxan readable against the dark ground.
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
	_power_cd -= delta
	_invuln -= delta
	_stun -= delta
	_flash = maxf(_flash - delta * 4.0, 0.0)
	_overlay.set_shader_parameter("hit_flash", _flash)
	if dead:
		velocity = Vector3.ZERO
		return

	var input := Vector2.ZERO
	if not input_locked:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move := _to_world(input)

	if not input_locked and _stun <= 0.0:
		if Input.is_action_just_pressed("dash"):
			dash(move)
		if Input.is_action_just_pressed("attack"):
			attack()
		if Input.is_action_just_pressed("ember_power"):
			ember_power()

	var want := Vector3.ZERO
	if _dash_time > 0.0:
		_dash_time -= delta
		want = _dash_dir * DASH_SPEED
		velocity.x = want.x
		velocity.z = want.z
	else:
		if _attack_step >= 0:
			want = _update_attack(delta, move)
		elif _cast_t >= 0.0:
			_update_cast(delta)
		elif _stun <= 0.0:
			want = move * SPEED
		velocity.x = move_toward(velocity.x, want.x, ACCEL * delta)
		velocity.z = move_toward(velocity.z, want.z, ACCEL * delta)
	velocity.y = -0.5 if is_on_floor() else velocity.y - 30.0 * delta
	move_and_slide()

	if _attack_step >= 0 or _cast_t >= 0.0:
		_facing = _aim
	elif move.length() > 0.1 and _stun <= 0.0:
		_facing = move.normalized()
	var yaw := atan2(-_facing.x, -_facing.z)
	_model.rotation.y = lerp_angle(_model.rotation.y, yaw, 1.0 - exp(-20.0 * delta))

	var speed := Vector2(velocity.x, velocity.z).length()
	_model.set_locomotion(speed > 0.6, clampf(speed / SPEED, 0.6, 1.2))
	_footsteps(delta, speed)


func _process(_delta: float) -> void:
	var fwd: Vector3 = -_model.global_basis.z
	_ember.global_position = _model.bone_position("chest") + fwd * 0.3 + Vector3(0, 0.05, 0)


## Ayxan lies unconscious in the ash (title screen and opening).
func lie_down() -> void:
	input_locked = true
	_model.play_action("Lie_Idle", 1.0, 0.0, true)


## Gets up out of the ash; await it before handing control back.
func stand_up() -> void:
	_model.play_action("Lie_StandUp", 1.3, 0.1)
	await get_tree().create_timer(1.4).timeout
	_model.cancel_action()
	input_locked = false


func face_towards(point: Vector3) -> void:
	var d := point - global_position
	d.y = 0.0
	if d.length() > 0.01:
		_facing = d.normalized()
		_model.rotation.y = atan2(-_facing.x, -_facing.z)


# --- Sword combo ---------------------------------------------------------------

func attack() -> void:
	if dead or _cast_t >= 0.0 or _dash_time > 0.0:
		return
	if _attack_step < 0:
		_start_attack(0)
	elif _attack_t > 0.08:
		_buffered = true


func _start_attack(step: int) -> void:
	var a: Dictionary = COMBO[step]
	_attack_step = step
	_attack_t = 0.0
	_impact_done = false
	_buffered = false
	_update_aim()
	_aim = _assist(_aim, 4.5)
	_facing = _aim
	_model.rotation.y = atan2(-_aim.x, -_aim.z)
	_model.play_action(a["clip"], a["speed"], 0.05)
	Audio.play("swing", -4.0 if a["heavy"] else -7.0, 0.1, null, 3)


## Runs the current swing; returns the desired velocity (forward lunge).
func _update_attack(delta: float, move: Vector3) -> Vector3:
	var a: Dictionary = COMBO[_attack_step]
	_attack_t += delta
	if not _impact_done and _attack_t >= a["impact"]:
		_impact_done = true
		_impact(a)
	if _attack_t >= a["cancel"]:
		if _buffered:
			_start_attack((_attack_step + 1) % COMBO.size())
			return Vector3.ZERO
		if move.length() > 0.1 or _attack_t >= a["cancel"] + 0.3:
			_end_attack()
		return Vector3.ZERO
	# Step into the swing unless an enemy is already in the face
	if _attack_t < 0.14 and not _enemy_within(1.3):
		return _aim * LUNGE_SPEED * (1.4 if a["heavy"] else 1.0)
	return Vector3.ZERO


func _end_attack() -> void:
	_attack_step = -1
	_buffered = false
	_model.cancel_action()


func _impact(a: Dictionary) -> void:
	var side := -1.0 if _attack_step == 1 else 1.0
	Fx.slash(global_position + Vector3(0, 1.0, 0), _aim, side, a["heavy"])
	var hits := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist <= a["range"] + e.radius and (dist < 0.7 or to.normalized().dot(_aim) >= a["dot"]):
			var dmg: float = a["damage"] * randf_range(0.9, 1.1)
			var dir := to.normalized() if dist > 0.01 else _aim
			e.take_damage(dmg, dir * a["knock"], a["heavy"])
			hits += 1
	if hits == 0:
		return
	if a["heavy"]:
		Audio.play("hit_heavy", 0.0, 0.06)
		Fx.hitstop(0.11)
		Fx.shake(0.5)
		Fx.punch(1.0)
	else:
		Audio.play("hit", -2.0, 0.1, null, 3)
		Fx.hitstop(0.055)
		Fx.shake(0.22)


# --- Dodge, ember, damage -----------------------------------------------------

func dash(move: Vector3) -> void:
	if _dash_cd > 0.0 or dead:
		return
	if _attack_step >= 0:
		_end_attack()
	_cast_t = -1.0
	_dash_cd = DASH_COOLDOWN
	_dash_time = DASH_TIME
	_invuln = maxf(_invuln, DASH_TIME + 0.1)
	_dash_dir = move.normalized() if move.length() > 0.1 else _facing
	_facing = _dash_dir
	_model.rotation.y = atan2(-_dash_dir.x, -_dash_dir.z)
	_model.play_action("Dodge_Forward", 1.35, 0.04)
	Fx.ash_puff(global_position)
	Audio.play("dash", -6.0, 0.1)


## Alov Dalğası: raise the ember, then a ring of fire. Burns the next memory.
func ember_power() -> void:
	if _power_cd > 0.0 or dead or _cast_t >= 0.0:
		return
	if not Memory.can_burn():
		Fx.notify("Yandırılacaq xatirə qalmayıb...")
		return
	if _attack_step >= 0:
		_end_attack()
	_power_cd = POWER_COOLDOWN
	_cast_t = 0.0
	_invuln = maxf(_invuln, CAST_TIME)
	_update_aim()
	_model.play_action("Spellcast_Raise", 2.8, 0.05)


func _update_cast(delta: float) -> void:
	var before := _cast_t
	_cast_t += delta
	if before < CAST_TRIGGER and _cast_t >= CAST_TRIGGER:
		_release_nova()
	if _cast_t >= CAST_TIME:
		_cast_t = -1.0
		_model.cancel_action()


func _release_nova() -> void:
	Memory.burn_next()
	Fx.fire_nova(global_position, POWER_RADIUS)
	Fx.shake(0.8)
	Fx.punch(1.0)
	Fx.hitstop(0.1)
	Audio.play("nova", 0.0, 0.04)
	Audio.play("memory_burn", -4.0, 0.0)
	get_tree().create_timer(0.6).timeout.connect(func(): Audio.play("whisper", -6.0, 0.1))
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist <= POWER_RADIUS + e.radius:
			var dmg := POWER_DAMAGE * lerpf(1.0, 0.55, clampf(dist / POWER_RADIUS, 0.0, 1.0))
			var dir := to.normalized() if dist > 0.01 else Vector3.FORWARD
			e.take_damage(dmg, dir * 16.0, true)


func take_damage(amount: float, knock := Vector3.ZERO) -> void:
	if dead or _invuln > 0.0:
		return
	health = maxf(health - amount, 0.0)
	_invuln = 0.4
	_flash = 1.0
	velocity += knock
	health_changed.emit(health, MAX_HEALTH)
	Fx.shake(0.45)
	Fx.hitstop(0.05)
	Audio.play("player_hurt", -2.0, 0.08)
	if health <= 0.0:
		_die()
		return
	if _dash_time <= 0.0 and _cast_t < 0.0:
		if _attack_step >= 0:
			_end_attack()
		_stun = HURT_STUN
		_model.play_action("Hit_A", 1.7, 0.05)


func heal(amount: float) -> void:
	if dead:
		return
	health = minf(health + amount, MAX_HEALTH)
	health_changed.emit(health, MAX_HEALTH)


func _die() -> void:
	dead = true
	_attack_step = -1
	_cast_t = -1.0
	_model.play_action("Death_A", 1.0, 0.1, true)
	create_tween().tween_property(_ember_light, "light_energy", 0.0, 1.5)
	died.emit()


func _on_memory_burned(_memory: Dictionary) -> void:
	# The ember feeds on what Ayxan forgets: it burns brighter, his armor turns to ash.
	var n := Memory.burned.size()
	var t := float(n) / Memory.MEMORIES.size()
	_ember_light.light_energy = 1.2 + n * 0.45
	_ember_light.omni_range = 3.5 + n * 0.4
	_ember_mat.emission_energy_multiplier = 3.0 + n * 1.5
	_overlay.set_shader_parameter("intensity", t * 0.9)
	for m in _cloth:
		m.set_shader_parameter("ash", t * 0.6)


# --- Helpers -------------------------------------------------------------------

func _footsteps(delta: float, speed: float) -> void:
	if speed < 0.6 or _dash_time > 0.0:
		_step_dist = 0.0
		return
	_step_dist += speed * delta
	if _step_dist > 1.7:
		_step_dist = 0.0
		Audio.play("footstep", -15.0, 0.15, null, 3)


func _enemy_within(dist: float) -> bool:
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) < dist + e.radius:
			return true
	return false


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
	var best_dot := 0.45
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
