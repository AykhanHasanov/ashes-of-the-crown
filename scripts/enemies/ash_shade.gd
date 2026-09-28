extends CharacterBody3D
## Kül Kölgəsi — a skeleton risen from the ash (KayKit Skeletons).
## Claws out of the ground, runs at the protagonist, telegraphs its strike with a ring on the
## floor that grows for Balance.WINDUP seconds, lunges, then recovers. Sword hits
## stagger it — except during the last Balance.UNSTOPPABLE seconds of the windup,
## when the ring turns white-hot and only a dodge helps.
## Kinds: "normal" (minion), "fast" (rogue) and "elite" (Kül Cəngavəri), whose extra
## move is Kül Burulğanı: a 360° sweep used when the protagonist gets behind it or piles on hits.

signal killed(shade: Node)

const Balance := preload("res://scripts/systems/balance.gd")
const CharacterModel := preload("res://scripts/characters/character_model.gd")
const Effects := preload("res://scripts/world/effects.gd")
const OVERLAY := preload("res://shaders/ash_overlay.gdshader")
const HP_BAR := preload("res://shaders/hp_bar.gdshader")
const DIR := "res://assets/characters/skeletons/"
## Real seconds into the chop clip (at speed 1) where the blade lands.
const CHOP_IMPACT := 0.55
const WAIT_RING := 3.4

enum State { RISING, CHASE, WINDUP, LUNGE, RECOVER, WHIRL_WINDUP, DEAD }

var kind := "normal"
var display_name := "Kül Gölgesi"
var max_health := 40.0
var health := 40.0
var damage := 12.0
var speed := 3.6
var radius := 0.45
var size := 1.0
var target  # the player node; untyped so its script members resolve at runtime

var _model_file := "Skeleton_Minion.glb"
var _weapon_file := "Skeleton_Blade.gltf"
var _state := State.RISING
var _timer := 0.0
var _lunge_dir := Vector3.FORWARD
var _lunge_hit := false
var _knock := Vector3.ZERO
var _flash := 0.0
var _model
var _overlay: ShaderMaterial
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _whirl_ring: MeshInstance3D
var _whirl_mat: StandardMaterial3D
var _shape: CollisionShape3D
var _bar: MeshInstance3D
var _bar_mat: ShaderMaterial
var _bar_lag := 1.0
var _bar_hold := 0.0
var _orbit := 1.0
var _whirl_cd := 0.0
var _recent_hits: Array[int] = []


func configure(k: String) -> void:
	kind = k
	var stats: Dictionary = Balance.ENEMIES[k]
	max_health = stats["health"]
	damage = stats["damage"]
	speed = stats["speed"]
	size = stats["size"]
	match k:
		"fast":
			_model_file = "Skeleton_Rogue.glb"
		"elite":
			_model_file = "Skeleton_Warrior.glb"
			_weapon_file = "Skeleton_Axe.gltf"
			display_name = "Kül Şövalyesi"
			radius = 0.75
	health = max_health


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 5
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = radius
	cap.height = maxf(1.8 * size, radius * 2.0 + 0.1)
	_shape.shape = cap
	_shape.position.y = cap.height * 0.5
	add_child(_shape)

	_model = CharacterModel.new()
	add_child(_model)
	_model.setup(DIR + _model_file, [], 0.82 * size)
	_model.tint(Color(0.55, 0.48, 0.45))
	_model.attach(DIR + _weapon_file, "handslot.r")
	_overlay = ShaderMaterial.new()
	_overlay.shader = OVERLAY
	_overlay.set_shader_parameter("intensity", 0.9 if kind == "elite" else 0.6)
	_overlay.set_shader_parameter("flash_color", Color(1.0, 0.7, 0.45))
	_model.set_overlay(_overlay)
	var eye_glow := StandardMaterial3D.new()
	eye_glow.albedo_color = Color(1.0, 0.45, 0.1)
	eye_glow.emission_enabled = true
	eye_glow.emission = Color(1.0, 0.45, 0.1)
	eye_glow.emission_energy_multiplier = 8.0
	for mi in _model.scene.find_children("*Eyes*", "MeshInstance3D", true, false):
		mi.material_override = eye_glow
		mi.material_overlay = null
	var trail := Effects.ash_trail(size, 16 if kind == "elite" else 8)
	trail.position.y = 0.9 * size
	add_child(trail)

	# Strike telegraph: a ring on the ground that grows during the windup
	_ring = _make_ring(0.85)
	_ring_mat = _ring.material_override
	if kind == "elite":
		# Kül Burulğanı telegraph: a full-radius ring that fills in
		_whirl_ring = _make_ring(0.93)
		_whirl_mat = _whirl_ring.material_override

	# Health bar above the head (the elite uses the HUD boss bar instead)
	_bar = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.1, 0.13)
	_bar.mesh = quad
	_bar_mat = ShaderMaterial.new()
	_bar_mat.shader = HP_BAR
	_bar.material_override = _bar_mat
	_bar.position.y = 2.25 * size
	_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar.visible = false
	add_child(_bar)
	_orbit = 1.0 if randf() < 0.5 else -1.0

	_model.move_anim = "Walking_D_Skeletons" if kind == "elite" else "Running_A"
	_model.play_action("Spawn_Ground_Skeletons", 2.4, 0.0)
	_timer = 1.4
	_spawn_sound.call_deferred()  # after the spawner has placed us


func _make_ring(inner: float) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = 1.0
	torus.rings = 40
	torus.ring_segments = 4
	ring.mesh = torus
	ring.material_override = Effects.additive_material(Color(1.0, 0.25, 0.05, 0.0))
	ring.position.y = 0.05
	ring.visible = false
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	return ring


func _spawn_sound() -> void:
	Audio.play("boss_roar" if kind == "elite" else "shade_spawn", 0.0 if kind == "elite" else -6.0, 0.12, global_position)


func _physics_process(delta: float) -> void:
	_flash = maxf(_flash - delta * 6.0, 0.0)
	_overlay.set_shader_parameter("hit_flash", _flash * 0.45)
	_knock = _knock.move_toward(Vector3.ZERO, 30.0 * delta)
	_whirl_cd -= delta
	_update_bar(delta)
	if _state == State.DEAD:
		velocity = Vector3(_knock.x, 0.0, _knock.z)
		move_and_slide()
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
				_model.cancel_action()
		State.CHASE:
			if has_target:
				if kind == "elite" and _whirl_cd <= 0.0 and _wants_whirl(to, dist):
					_begin_whirl()
				else:
					var slot_free := _attackers() < Balance.MAX_ATTACKERS
					if dist < 1.8 + radius and slot_free:
						_begin_windup()
					elif not slot_free and dist < WAIT_RING + 1.0:
						# Circle the protagonist, keeping the wait distance, until a slot opens
						var radial := -to.normalized() * clampf(WAIT_RING - dist, -1.0, 1.0)
						var tangent := Vector3(-to.z, 0.0, to.x).normalized() * _orbit * 0.6
						move = (radial + tangent + _separation()).limit_length(1.0) * speed * 0.6
					else:
						move = (to.normalized() + _separation() * 1.2).normalized() * speed
				_face(to, delta, 10.0)
		State.WINDUP:
			_face(to, delta, 6.0)
			_update_telegraph(_ring, _ring_mat, lerpf(0.4, 2.0 + radius, _windup_progress()))
			if _timer <= 0.0:
				_state = State.LUNGE
				_timer = 0.14
				_lunge_dir = to.normalized() if dist > 0.01 else -_model.global_basis.z
				_lunge_hit = false
				_ring.visible = false
		State.LUNGE:
			move = _lunge_dir * 9.0
			if has_target and not _lunge_hit and dist < 1.5 + radius:
				_lunge_hit = true
				target.take_damage(damage, _lunge_dir * 8.0)
			if _timer <= 0.0:
				_state = State.RECOVER
				_timer = 0.55
		State.WHIRL_WINDUP:
			var k := clampf(1.0 - _timer / Balance.WHIRL_TELEGRAPH, 0.0, 1.0)
			_whirl_ring.visible = true
			_whirl_ring.scale = Vector3(Balance.WHIRL_RADIUS, 0.3, Balance.WHIRL_RADIUS)
			_whirl_mat.albedo_color = Color(1.0, 0.25, 0.05).lerp(Color(1.0, 0.95, 0.8), k * k)
			_whirl_mat.albedo_color.a = 0.25 + 0.7 * k
			if _timer <= 0.0:
				_whirl_strike(has_target, dist)
		State.RECOVER:
			if _timer <= 0.0:
				_state = State.CHASE

	velocity = Vector3(move.x + _knock.x, 0.0, move.z + _knock.z)
	move_and_slide()
	if _state == State.CHASE:
		_model.set_locomotion(move.length() > 0.1, speed / 4.0)


## Seconds until this shade's blow lands on the protagonist (INF when not attacking). Used for perfect dodges.
func time_to_strike() -> float:
	match _state:
		State.WINDUP:
			return maxf(_timer, 0.0)
		State.LUNGE:
			return 0.0 if not _lunge_hit else INF
		State.WHIRL_WINDUP:
			return maxf(_timer, 0.0)
	return INF


func is_attacking() -> bool:
	return _state in [State.WINDUP, State.LUNGE, State.WHIRL_WINDUP]


func take_damage(amount: float, knock := Vector3.ZERO, heavy := false) -> void:
	if _state == State.DEAD:
		return
	health -= amount
	_flash = 1.0
	_knock += knock * (0.3 if kind == "elite" else 1.0)
	_recent_hits.append(Time.get_ticks_msec())
	Fx.hit_spark(global_position + Vector3(0, 1.1 * size, 0), heavy)
	if Settings.damage_numbers:
		Fx.damage_number(global_position + Vector3(0, 2.0 * size, 0), amount, "heavy" if heavy else "normal")
	_bar.visible = kind != "elite"
	_bar_hold = 0.45
	if health <= 0.0:
		_die()
		return
	if _unstoppable():
		return
	var staggers := kind != "elite" or heavy
	if staggers and _state != State.RISING:
		_ring.visible = false
		_state = State.RECOVER
		_timer = 0.45 if heavy else 0.32
		_model.play_action("Hit_B" if heavy else "Hit_A", 1.8, 0.04)


## The last moments of a windup (and the whole whirl) cannot be interrupted.
func _unstoppable() -> bool:
	if _state == State.WINDUP and _timer <= Balance.UNSTOPPABLE:
		return true
	return _state in [State.WHIRL_WINDUP, State.LUNGE]


func _windup_progress() -> float:
	return clampf(1.0 - _timer / Balance.WINDUP, 0.0, 1.0)


## Grows the ring; in the unstoppable phase its edge burns white.
func _update_telegraph(ring: MeshInstance3D, mat: StandardMaterial3D, r: float) -> void:
	ring.scale = Vector3(r, 0.3, r)
	if _timer <= Balance.UNSTOPPABLE:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.04)
		mat.albedo_color = Color(1.0, 0.9, 0.75).lerp(Color(1.0, 1.0, 1.0), pulse)
		mat.albedo_color.a = 1.0
	else:
		mat.albedo_color = Color(1.0, 0.25, 0.05, 0.25 + 0.6 * _windup_progress())


func _begin_windup() -> void:
	_state = State.WINDUP
	_timer = Balance.WINDUP
	_ring.visible = true
	_ring.scale = Vector3(0.4, 0.3, 0.4)
	_model.play_action("1H_Melee_Attack_Chop", CHOP_IMPACT / Balance.WINDUP, 0.06)
	Audio.play("shade_windup", -10.0, 0.15, global_position)


# --- Kül Burulğanı (elite) ------------------------------------------------------------------

func _wants_whirl(to: Vector3, dist: float) -> bool:
	if dist > Balance.WHIRL_RADIUS + 0.5:
		return false
	var facing: Vector3 = -_model.global_basis.z
	var behind := facing.dot(to.normalized()) < -0.3
	var now := Time.get_ticks_msec()
	_recent_hits = _recent_hits.filter(func(t): return now - t < Balance.WHIRL_HITS_WINDOW * 1000.0)
	return behind or _recent_hits.size() >= Balance.WHIRL_HITS_TRIGGER


func _begin_whirl() -> void:
	_state = State.WHIRL_WINDUP
	_timer = Balance.WHIRL_TELEGRAPH
	_recent_hits.clear()
	_model.play_action("2H_Melee_Attack_Spin", 1.8 / Balance.WHIRL_TELEGRAPH, 0.08)
	Audio.play("boss_roar", -6.0, 0.1, global_position)


func _whirl_strike(has_target: bool, dist: float) -> void:
	_whirl_ring.visible = false
	_whirl_cd = Balance.WHIRL_COOLDOWN
	_state = State.RECOVER
	_timer = 0.8
	Fx.fire_nova(global_position, Balance.WHIRL_RADIUS)
	Fx.shake(0.5)
	Audio.play("hit_heavy", -2.0, 0.1, global_position)
	if has_target and dist <= Balance.WHIRL_RADIUS + 0.4:
		var away: Vector3 = (target.global_position - global_position).normalized()
		target.take_damage(Balance.WHIRL_DAMAGE, away * 10.0)


# --- Death and helpers ----------------------------------------------------------------------

func _die() -> void:
	_state = State.DEAD
	remove_from_group("enemies")
	_shape.set_deferred("disabled", true)
	_ring.visible = false
	if _whirl_ring:
		_whirl_ring.visible = false
	create_tween().tween_method(func(v: float): _bar_mat.set_shader_parameter("alpha", v), 1.0, 0.0, 0.4)
	_model.play_action("Death_C_Skeletons", 1.4, 0.05, true)
	Fx.death_burst(global_position, size)
	Audio.play("shade_death", -3.0, 0.12, global_position)
	if is_instance_valid(target) and target.has_method("on_enemy_killed"):
		target.on_enemy_killed()
	killed.emit(self)
	# Crumble, then sink into the ash
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_model, "position:y", -1.6 * size, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _attackers() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and e.is_attacking():
			n += 1
	return n


## The bar shows current health instantly; the pale "lost" segment drains after a beat.
func _update_bar(delta: float) -> void:
	if not _bar.visible:
		return
	var ratio := clampf(health / max_health, 0.0, 1.0)
	_bar_hold -= delta
	if _bar_hold <= 0.0:
		_bar_lag = move_toward(_bar_lag, ratio, delta * 1.5)
	_bar_mat.set_shader_parameter("ratio", ratio)
	_bar_mat.set_shader_parameter("lag", maxf(_bar_lag, ratio))


func _face(dir: Vector3, delta: float, rate: float) -> void:
	if dir.length() > 0.01:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-rate * delta))


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
