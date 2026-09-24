extends CharacterBody3D
## Rüfət — Ayxan's blood brother and captain of the palace guard.
## Waits by the south-gate hearth, talks, and fights beside Ayxan during waves.
## Shades target only Ayxan, so Rüfət never dies in this chapter.

const Visuals := preload("res://scripts/world/visuals.gd")

const SPEED := 5.2
const REACH := 1.8
const DAMAGE := 12.0
const ATTACK_COOLDOWN := 1.05
const SWORD_REST := Vector3(-30, 20, 0)

var in_combat := false
var _model: Node3D
var _sword: Node3D
var _attack_cd := 0.0
var _t := 0.0
var _swing_side := 1.0


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
	_model = Visuals.humanoid(Color(0.1, 0.14, 0.27), Color(0.56, 0.58, 0.62), Color(0.72, 0.55, 0.43), Color(0.04, 0.03, 0.03))
	add_child(_model)
	_sword = _model.get_node("SwordPivot")


func face(point: Vector3) -> void:
	var d := point - global_position
	d.y = 0.0
	if d.length() > 0.01:
		_model.rotation.y = atan2(-d.x, -d.z)


func _physics_process(delta: float) -> void:
	_t += delta
	_attack_cd -= delta
	var move := Vector3.ZERO
	if in_combat:
		var e = _nearest_enemy(14.0)
		if e != null:
			var to: Vector3 = e.global_position - global_position
			to.y = 0.0
			face(e.global_position)
			if to.length() > REACH + e.radius:
				move = to.normalized() * SPEED
			elif _attack_cd <= 0.0:
				_attack_cd = ATTACK_COOLDOWN
				_swing()
				e.take_damage(DAMAGE, to.normalized() * 4.0)
	velocity = Vector3(move.x, -0.5, move.z)
	move_and_slide()
	var k := clampf(move.length() / SPEED, 0.0, 1.0)
	_model.position.y = absf(sin(_t * 9.0)) * 0.07 * k + sin(_t * 1.6) * 0.01


func _nearest_enemy(max_dist: float):
	var best = null
	var best_d := max_dist
	for e in get_tree().get_nodes_in_group("enemies"):
		var d: float = global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _swing() -> void:
	_swing_side = -_swing_side
	var dir := -_model.global_basis.z
	Fx.slash(global_position + Vector3(0, 1.0, 0), dir, _swing_side)
	_sword.rotation_degrees = Vector3(-10, 85 * _swing_side, 0)
	var tw := create_tween()
	tw.tween_property(_sword, "rotation_degrees", Vector3(-10, -85 * _swing_side, 0), 0.14)
	tw.tween_property(_sword, "rotation_degrees", SWORD_REST, 0.3)
