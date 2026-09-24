extends CharacterBody3D
## Rüfət — Ayxan's blood brother and captain of the palace guard (KayKit Knight
## with helmet, sword and round shield). Waits by the south-gate hearth, talks, and
## fights beside Ayxan during the waves. Shades target only Ayxan in this chapter.

const CharacterModel := preload("res://scripts/characters/character_model.gd")
const MODEL_PATH := "res://assets/characters/adventurers/Knight.glb"
const HIDDEN := ["1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield", "Spike_Shield", "2H_Sword"]

const SPEED := 5.4
const REACH := 1.9
const DAMAGE := 12.0
const ATTACK_COOLDOWN := 1.1
const IMPACT := 0.32

var in_combat := false
var _model
var _attack_cd := 0.0
var _swing_t := -1.0
var _swing_target


func _ready() -> void:
	add_to_group("npcs")
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
	_model.tint(Color(0.85, 0.85, 0.9))
	var cape: MeshInstance3D = _model.mesh("Knight_Cape")
	if cape:
		var blue := StandardMaterial3D.new()
		blue.albedo_color = Color(0.1, 0.15, 0.3)
		blue.roughness = 0.85
		cape.material_override = blue


func face(point: Vector3) -> void:
	var d := point - global_position
	d.y = 0.0
	if d.length() > 0.01:
		_model.rotation.y = atan2(-d.x, -d.z)


func _physics_process(delta: float) -> void:
	_attack_cd -= delta
	var move := Vector3.ZERO
	if _swing_t >= 0.0:
		var before := _swing_t
		_swing_t += delta
		if before < IMPACT and _swing_t >= IMPACT:
			_land_swing()
		if _swing_t > 0.6:
			_swing_t = -1.0
	elif in_combat:
		var e = _nearest_enemy(14.0)
		if e != null:
			var to: Vector3 = e.global_position - global_position
			to.y = 0.0
			face(e.global_position)
			if to.length() > REACH + e.radius:
				move = to.normalized() * SPEED
			elif _attack_cd <= 0.0:
				_attack_cd = ATTACK_COOLDOWN
				_swing_t = 0.0
				_swing_target = e
				_model.play_action("1H_Melee_Attack_Chop", 1.6, 0.06)
				Audio.play("swing", -12.0, 0.1, global_position, 3)
	velocity = Vector3(move.x, -0.5, move.z)
	move_and_slide()
	_model.set_locomotion(move.length() > 0.1)


func _land_swing() -> void:
	var e = _swing_target
	if not is_instance_valid(e) or not e.is_in_group("enemies"):
		return
	var to: Vector3 = e.global_position - global_position
	to.y = 0.0
	if to.length() > REACH + e.radius + 0.6:
		return
	e.take_damage(DAMAGE, to.normalized() * 4.0)
	Audio.play("hit", -8.0, 0.1, e.global_position, 3)


func _nearest_enemy(max_dist: float):
	var best = null
	var best_d := max_dist
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best
