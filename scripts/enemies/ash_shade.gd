extends CharacterBody3D
## Kül Kölgəsi — a skeleton risen from the ash of Közqala (KayKit Skeletons).
## Claws out of the ground, runs at Ayxan, telegraphs its strike with a glowing ring
## on the floor, lunges on the impact frame, then recovers. Sword hits stagger it.
## Kinds: "normal" (minion), "fast" (rogue) and "elite" (Kül Cəngavəri, a crown guard).

signal killed(shade: Node)

const CharacterModel := preload("res://scripts/characters/character_model.gd")
const Effects := preload("res://scripts/world/effects.gd")
const OVERLAY := preload("res://shaders/ash_overlay.gdshader")
const DIR := "res://assets/characters/skeletons/"
## Real seconds into the chop clip (at speed 1) where the blade lands.
const CHOP_IMPACT := 0.55

enum State { RISING, CHASE, WINDUP, LUNGE, RECOVER, DEAD }

var kind := "normal"
var display_name := "Kül Kölgəsi"
var max_health := 40.0
var health := 40.0
var damage := 12.0
var speed := 3.6
var windup_time := 0.55
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
var _shape: CollisionShape3D


func configure(k: String) -> void:
	kind = k
	match k:
		"fast":
			_model_file = "Skeleton_Rogue.glb"
			max_health = 26.0
			damage = 9.0
			speed = 5.6
			windup_time = 0.42
			size = 0.95
		"elite":
			_model_file = "Skeleton_Warrior.glb"
			_weapon_file = "Skeleton_Axe.gltf"
			display_name = "Kül Cəngavəri"
			max_health = 280.0
			damage = 24.0
			speed = 3.2
			windup_time = 0.85
			size = 1.45
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

	# Telegraph ring on the ground, grows during the windup
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 4
	_ring.mesh = torus
	_ring_mat = Effects.additive_material(Color(1.0, 0.25, 0.05, 0.0))
	_ring.material_override = _ring_mat
	_ring.position.y = 0.05
	_ring.visible = false
	add_child(_ring)

	_model.move_anim = "Walking_D_Skeletons" if kind == "elite" else "Running_A"
	_model.play_action("Spawn_Ground_Skeletons", 2.4, 0.0)
	_timer = 1.4
	_spawn_sound.call_deferred()  # after the spawner has placed us


func _spawn_sound() -> void:
	Audio.play("boss_roar" if kind == "elite" else "shade_spawn", 0.0 if kind == "elite" else -6.0, 0.12, global_position)


func _physics_process(delta: float) -> void:
	_flash = maxf(_flash - delta * 6.0, 0.0)
	_overlay.set_shader_parameter("hit_flash", _flash * 0.45)
	_knock = _knock.move_toward(Vector3.ZERO, 30.0 * delta)
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
				if dist < 1.8 + radius:
					_begin_windup()
				else:
					move = (to.normalized() + _separation() * 1.2).normalized() * speed
				_face(to, delta, 10.0)
		State.WINDUP:
			_face(to, delta, 6.0)
			var k := clampf(1.0 - _timer / windup_time, 0.0, 1.0)
			var r := lerpf(0.4, 2.0 + radius, k)
			_ring.scale = Vector3(r, 0.3, r)
			_ring_mat.albedo_color.a = 0.25 + 0.6 * k
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
		State.RECOVER:
			if _timer <= 0.0:
				_state = State.CHASE

	velocity = Vector3(move.x + _knock.x, 0.0, move.z + _knock.z)
	move_and_slide()
	if _state == State.CHASE:
		_model.set_locomotion(move.length() > 0.1, speed / 4.0)


func take_damage(amount: float, knock := Vector3.ZERO, heavy := false) -> void:
	if _state == State.DEAD:
		return
	health -= amount
	_flash = 1.0
	_knock += knock * (0.3 if kind == "elite" else 1.0)
	Fx.hit_spark(global_position + Vector3(0, 1.1 * size, 0), heavy)
	if health <= 0.0:
		_die()
		return
	var staggers := kind != "elite" or heavy
	if staggers and _state != State.RISING:
		_ring.visible = false
		_state = State.RECOVER
		_timer = 0.45 if heavy else 0.32
		_model.play_action("Hit_B" if heavy else "Hit_A", 1.8, 0.04)


func _begin_windup() -> void:
	_state = State.WINDUP
	_timer = windup_time
	_ring.visible = true
	_ring.scale = Vector3(0.4, 0.3, 0.4)
	_model.play_action("1H_Melee_Attack_Chop", CHOP_IMPACT / windup_time, 0.06)
	Audio.play("shade_windup", -10.0, 0.15, global_position)


func _die() -> void:
	_state = State.DEAD
	remove_from_group("enemies")
	_shape.set_deferred("disabled", true)
	_ring.visible = false
	_model.play_action("Death_C_Skeletons", 1.4, 0.05, true)
	Fx.death_burst(global_position, size)
	Audio.play("shade_death", -3.0, 0.12, global_position)
	killed.emit(self)
	# Crumble, then sink into the ash
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_model, "position:y", -1.6 * size, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


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
