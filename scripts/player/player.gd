extends CharacterBody3D
## Ayxan — the last heir of Atəşan, hooded in exile (KayKit Rogue with the Knight's sword).
##
## Sword: a three-hit combo (diagonal → horizontal → heavy chop) with input buffering,
## a forward lunge on each swing and damage on the impact frame.
## Kül addımı: dodge roll with i-frames; started just before an enemy strike lands it
## becomes a perfect dodge (slow motion, +ember, ash trail).
## Fire, in two layers:
##   • tap Q / right mouse — Köz Zərbəsi, a cone of fire paid for with the ember meter;
##   • hold Q / right mouse — the memory wheel opens; releasing on a memory casts
##     Alov Dalğası and burns that memory for good.
## At ≤ 15 health, once per fight, Kül Şahı offers to save him for a memory of his choosing.

signal health_changed(current: float, maximum: float)
signal ember_changed(current: float, maximum: float)
signal died

const Balance := preload("res://scripts/systems/balance.gd")
const CharacterModel := preload("res://scripts/characters/character_model.gd")
const Effects := preload("res://scripts/world/effects.gd")
const OVERLAY := preload("res://shaders/ash_overlay.gdshader")
const MODEL_PATH := "res://assets/characters/adventurers/Rogue_Hooded.glb"
const SWORD_DONOR := "res://assets/characters/adventurers/Knight.glb"
const HIDDEN := ["Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable"]
const MAX_HEALTH := Balance.PLAYER_HEALTH

var health := MAX_HEALTH
var ember := 0.0
var dead := false
var input_locked := false
var camera: Camera3D
## UI hooks set by the chapter.
var radial
var offer
## Real-time ms of the last hit taken (hearths refuse to heal right after).
var last_hurt_ms := -100000

var _model
var _overlay: ShaderMaterial
var _cloth: Array = []
var _ember_node: Node3D
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
var _strike_cd := 0.0
var _wave_cd := 0.0
var _cast_t := -1.0
var _cast_memory := ""
var _stun := 0.0
var _invuln := 0.0
var _flash := 0.0
var _step_dist := 0.0
var _fire_down_ms := -1
var _last_ember_gain_ms := -100000
var _offer_used := false


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
	_ember_node = Node3D.new()
	_ember_node.top_level = true
	add_child(_ember_node)
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
	_ember_node.add_child(core)
	_ember_light = OmniLight3D.new()
	_ember_light.light_color = Color(1.0, 0.5, 0.2)
	_ember_light.light_energy = 1.2
	_ember_light.omni_range = 3.5
	_ember_node.add_child(_ember_light)
	_ember_node.add_child(Effects.ember_trail())

	# Soft "hero light" keeps Ayxan readable against the dark ground.
	var hero := OmniLight3D.new()
	hero.light_color = Color(1.0, 0.85, 0.7)
	hero.light_energy = 0.55
	hero.omni_range = 7.0
	hero.position = Vector3(0, 4.0, 0.8)
	add_child(hero)

	EventBus.memory_burned.connect(_on_memory_burned)
	EventBus.state_replaced.connect(_refresh_burn_look)
	health_changed.emit.call_deferred(health, MAX_HEALTH)
	ember_changed.emit.call_deferred(ember, Balance.EMBER_MAX)


## A new fight begins: Kül Şahı may make his offer again.
func begin_encounter() -> void:
	_offer_used = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ember_power") and not event.is_echo():
		_fire_down_ms = Time.get_ticks_msec() if _can_act() else -1
	elif event.is_action_released("ember_power") and _fire_down_ms >= 0:
		var held := (Time.get_ticks_msec() - _fire_down_ms) / 1000.0
		_fire_down_ms = -1
		if radial != null and radial.is_open:
			_release_wheel()
		elif held < Balance.TAP_THRESHOLD:
			ember_strike()


func _process(_delta: float) -> void:
	var fwd: Vector3 = -_model.global_basis.z
	_ember_node.global_position = _model.bone_position("chest") + fwd * 0.3 + Vector3(0, 0.05, 0)
	# Holding fire past the tap threshold opens the memory wheel (in real time).
	if _fire_down_ms >= 0 and radial != null and not radial.is_open:
		if (Time.get_ticks_msec() - _fire_down_ms) / 1000.0 >= Balance.TAP_THRESHOLD:
			_open_wheel()
	if not _can_act() and radial != null and radial.is_open:
		radial.close()
		Fx.release_time("radial")
	# Ember cools once the fighting stops
	if ember > 0.0 and Time.get_ticks_msec() - _last_ember_gain_ms > Balance.EMBER_DECAY_DELAY * 1000.0:
		_set_ember(ember - Balance.EMBER_DECAY * _delta)


func _physics_process(delta: float) -> void:
	_dash_cd -= delta
	_strike_cd -= delta
	_wave_cd -= delta
	_invuln -= delta
	_stun -= delta
	_flash = maxf(_flash - delta * 4.0, 0.0)
	_overlay.set_shader_parameter("hit_flash", _flash)
	if dead:
		velocity = Vector3.ZERO
		return

	var input := Vector2.ZERO
	var wheel_open: bool = radial != null and radial.is_open
	if not input_locked and not wheel_open:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move := _to_world(input)

	if not input_locked and not wheel_open and _stun <= 0.0:
		if Input.is_action_just_pressed("dash"):
			dash(move)
		if Input.is_action_just_pressed("attack"):
			attack()

	var want := Vector3.ZERO
	if _dash_time > 0.0:
		_dash_time -= delta
		want = _dash_dir * Balance.DASH_SPEED
		velocity.x = want.x
		velocity.z = want.z
	else:
		if _attack_step >= 0:
			want = _update_attack(delta, move)
		elif _cast_t >= 0.0:
			_update_cast(delta)
		elif _stun <= 0.0:
			want = move * Balance.PLAYER_SPEED
		velocity.x = move_toward(velocity.x, want.x, Balance.PLAYER_ACCEL * delta)
		velocity.z = move_toward(velocity.z, want.z, Balance.PLAYER_ACCEL * delta)
	velocity.y = -0.5 if is_on_floor() else velocity.y - 30.0 * delta
	move_and_slide()

	if _attack_step >= 0 or _cast_t >= 0.0:
		_facing = _aim
	elif move.length() > 0.1 and _stun <= 0.0:
		_facing = move.normalized()
	var yaw := atan2(-_facing.x, -_facing.z)
	_model.rotation.y = lerp_angle(_model.rotation.y, yaw, 1.0 - exp(-20.0 * delta))

	var speed := Vector2(velocity.x, velocity.z).length()
	_model.set_locomotion(speed > 0.6, clampf(speed / Balance.PLAYER_SPEED, 0.6, 1.2))
	_footsteps(delta, speed)


## Ayxan lies unconscious in the ash (title screen and opening).
func lie_down() -> void:
	input_locked = true
	_model.play_action("Lie_Idle", 1.0, 0.0, true)


## Instantly back on his feet with control (resuming a save).
func wake() -> void:
	_model.cancel_action()
	_model.set_locomotion(false)
	input_locked = false


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


func _can_act() -> bool:
	return not dead and not input_locked and _stun <= 0.0 and _cast_t < 0.0


# --- Sword combo ---------------------------------------------------------------

func attack() -> void:
	if dead or _cast_t >= 0.0 or _dash_time > 0.0:
		return
	if _attack_step < 0:
		_start_attack(0)
	elif _attack_t > 0.08:
		_buffered = true


func _start_attack(step: int) -> void:
	var a: Dictionary = Balance.COMBO[step]
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
	var a: Dictionary = Balance.COMBO[_attack_step]
	_attack_t += delta
	if not _impact_done and _attack_t >= a["impact"]:
		_impact_done = true
		_impact(a)
	if _attack_t >= a["cancel"]:
		if _buffered:
			_start_attack((_attack_step + 1) % Balance.COMBO.size())
			return Vector3.ZERO
		if move.length() > 0.1 or _attack_t >= a["cancel"] + 0.3:
			_end_attack()
		return Vector3.ZERO
	# Step into the swing unless an enemy is already in the face
	if _attack_t < 0.14 and not _enemy_within(1.3):
		return _aim * Balance.LUNGE_SPEED * (1.4 if a["heavy"] else 1.0)
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
	gain_ember(Balance.EMBER_ON_HIT)
	if a["heavy"]:
		Audio.play("hit_heavy", 0.0, 0.06)
		Fx.hitstop(0.11)
		Fx.shake(0.5)
		Fx.punch(1.0)
	else:
		Audio.play("hit", -2.0, 0.1, null, 3)
		Fx.hitstop(0.055)
		Fx.shake(0.22)


# --- Ember meter and Köz Zərbəsi -------------------------------------------------------

func gain_ember(amount: float) -> void:
	_last_ember_gain_ms = Time.get_ticks_msec()
	_set_ember(ember + amount)


## Called by shades as they die.
func on_enemy_killed() -> void:
	gain_ember(Balance.EMBER_ON_KILL)


func _set_ember(v: float) -> void:
	var nv := clampf(v, 0.0, Balance.EMBER_MAX)
	if absf(nv - ember) > 0.001:
		ember = nv
		ember_changed.emit(ember, Balance.EMBER_MAX)


## Tap fire: a cone of flame in front of Ayxan, paid for with the ember meter.
func ember_strike() -> void:
	if not _can_act() or _strike_cd > 0.0:
		return
	if ember < Balance.STRIKE_COST:
		Fx.notify("Köz yetmiyor...")
		return
	if _attack_step >= 0:
		_end_attack()
	_strike_cd = Balance.STRIKE_COOLDOWN
	_set_ember(ember - Balance.STRIKE_COST)
	_update_aim()
	_aim = _assist(_aim, Balance.STRIKE_RANGE + 1.0)
	_facing = _aim
	_model.rotation.y = atan2(-_aim.x, -_aim.z)
	_model.play_action("Spellcast_Shoot", 2.2, 0.04)
	Fx.ember_cone(global_position, _aim, Balance.STRIKE_RANGE)
	Fx.shake(0.3)
	Audio.play("nova", -8.0, 0.12)
	for e in get_tree().get_nodes_in_group("enemies"):
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist <= Balance.STRIKE_RANGE + e.radius and (dist < 0.8 or to.normalized().dot(_aim) >= Balance.STRIKE_CONE_DOT):
			var dir := to.normalized() if dist > 0.01 else _aim
			e.take_damage(Balance.STRIKE_DAMAGE, dir * Balance.STRIKE_KNOCK, false)
	Fx.hitstop(0.05)


# --- Alov Dalğası: the memory wheel ---------------------------------------------------

func _open_wheel() -> void:
	if not _can_act() or _wave_cd > 0.0:
		_fire_down_ms = -1
		return
	if not Memory.can_burn():
		# Nothing left to give: an empty gesture, and the Ash Shah laughs.
		_fire_down_ms = -1
		_model.play_action("Spellcast_Raise", 2.8, 0.05)
		Audio.play("whisper", -2.0, 0.0)
		Fx.notify("...he he... hiçbir şey kalmadı, küçük şah...")
		return
	if _attack_step >= 0:
		_end_attack()
	radial.open()
	Fx.hold_time("radial", Balance.RADIAL_TIME_SCALE)


func _release_wheel() -> void:
	var id: String = radial.close()
	Fx.release_time("radial")
	if id == "":
		return
	if not WorldState.has_flag(&"wave_confirmed"):
		radial.ask_confirm()
		var ok: bool = await radial.confirmed
		if not ok:
			return
		WorldState.set_flag(&"wave_confirmed")
	cast_wave(id)


## Raises the ember and burns `memory_id`; the nova goes off on the cast trigger.
func cast_wave(memory_id: String) -> void:
	if dead or _cast_t >= 0.0:
		return
	_wave_cd = Balance.WAVE_COOLDOWN
	_cast_t = 0.0
	_cast_memory = memory_id
	_invuln = maxf(_invuln, Balance.WAVE_CAST_TIME)
	_update_aim()
	_model.play_action("Spellcast_Raise", 2.8, 0.05)


func _update_cast(delta: float) -> void:
	var before := _cast_t
	_cast_t += delta
	if before < Balance.WAVE_CAST_TRIGGER and _cast_t >= Balance.WAVE_CAST_TRIGGER:
		_release_nova()
	if _cast_t >= Balance.WAVE_CAST_TIME:
		_cast_t = -1.0
		_model.cancel_action()


func _release_nova() -> void:
	Memory.burn(_cast_memory)
	Fx.fire_nova(global_position, Balance.WAVE_RADIUS)
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
		if dist <= Balance.WAVE_RADIUS + e.radius:
			var dmg := Balance.WAVE_DAMAGE * lerpf(1.0, Balance.WAVE_EDGE_FALLOFF, clampf(dist / Balance.WAVE_RADIUS, 0.0, 1.0))
			var dir := to.normalized() if dist > 0.01 else Vector3.FORWARD
			e.take_damage(dmg, dir * Balance.WAVE_KNOCK, true)


# --- Dodge, damage, Kül Şahının təklifi -------------------------------------------------

func dash(move: Vector3) -> void:
	if _dash_cd > 0.0 or dead:
		return
	if _attack_step >= 0:
		_end_attack()
	_cast_t = -1.0
	_dash_cd = Balance.DASH_COOLDOWN
	_dash_time = Balance.DASH_TIME
	_invuln = maxf(_invuln, Balance.DASH_TIME + 0.1)
	_dash_dir = move.normalized() if move.length() > 0.1 else _facing
	_facing = _dash_dir
	_model.rotation.y = atan2(-_dash_dir.x, -_dash_dir.z)
	_model.play_action("Dodge_Forward", 1.35, 0.04)
	Fx.ash_puff(global_position)
	Audio.play("dash", -6.0, 0.1)
	if _is_perfect_dodge():
		_perfect_dodge()


## A dodge counts as perfect when a nearby shade's strike is about to land on Ayxan.
func _is_perfect_dodge() -> bool:
	var window := perfect_window()
	for e in get_tree().get_nodes_in_group("enemies"):
		if global_position.distance_to(e.global_position) > 4.5 + e.radius:
			continue
		if e.time_to_strike() <= window:
			return true
	return false


func perfect_window() -> float:
	return Balance.PERFECT_WINDOW


func _perfect_dodge() -> void:
	Fx.slowmo(Balance.PERFECT_SLOWMO_SCALE, Balance.PERFECT_SLOWMO_TIME)
	Fx.ash_trail(global_position)
	gain_ember(Balance.PERFECT_EMBER)
	Audio.play("memory_burn", -14.0, 0.2)
	Fx.notify("Kusursuz kaçış")


func take_damage(amount: float, knock := Vector3.ZERO) -> void:
	if dead or _invuln > 0.0:
		return
	health = maxf(health - amount, 0.0)
	_invuln = Balance.HURT_INVULN
	_flash = 1.0
	last_hurt_ms = Time.get_ticks_msec()
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
		_stun = Balance.HURT_STUN
		_model.play_action("Hit_A", 1.7, 0.05)
	if health <= Balance.OFFER_HEALTH:
		_maybe_offer()


func _maybe_offer() -> void:
	if _offer_used or offer == null or offer.is_open or Memory.unburned().is_empty():
		return
	_offer_used = true
	offer.open()
	var accepted: bool = await offer.resolved
	if accepted and not dead:
		var m := Memory.burn_random()
		health = MAX_HEALTH
		health_changed.emit(health, MAX_HEALTH)
		Fx.fire_nova(global_position, 3.0)
		Audio.play("memory_burn", -2.0, 0.0)
		if m != null:
			Fx.notify("Kül Şahı «%s» hatırasını seçti." % tr(m.display_name_key))


func heal(amount: float) -> void:
	if dead:
		return
	health = minf(health + amount, MAX_HEALTH)
	health_changed.emit(health, MAX_HEALTH)


func _die() -> void:
	dead = true
	_attack_step = -1
	_cast_t = -1.0
	if radial != null and radial.is_open:
		radial.close()
		Fx.release_time("radial")
	_model.play_action("Death_A", 1.0, 0.1, true)
	create_tween().tween_property(_ember_light, "light_energy", 0.0, 1.5)
	died.emit()


func _on_memory_burned(_id: StringName) -> void:
	_refresh_burn_look()


## The ember feeds on what Ayxan forgets: it burns brighter, his clothes turn to ash.
func _refresh_burn_look() -> void:
	var n := Memory.burned_count()
	var t := float(n) / maxi(Memory.all().size(), 1)
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
