extends Node3D
## Area effects: explosions and ground slams (instant), and burning ground left by
## "Alevli" enemies (lingering). Only combatants hostile to the source are hurt.

const Effects := preload("res://scripts/world/effects.gd")
const Hit := preload("res://scripts/combat/hit.gd")

var source: Node3D
var radius := 1.4
var dps := 6.0
var life := 3.0
var _tick := 0.0


## Instant blast: damage falls off towards the edge; returns how many were hit.
static func blast(pos: Vector3, rad: float, damage: float, kind: String, stance: float, burn: float, src: Node3D, tree: SceneTree) -> int:
	var n := 0
	for c in tree.get_nodes_in_group("combatants"):
		if c == src or c.dead:
			continue
		if is_instance_valid(src) and src.has_method("is_hostile") and not src.is_hostile(c):
			continue
		var d: float = Vector2(c.global_position.x - pos.x, c.global_position.z - pos.z).length()
		if d > rad + c.radius or absf(c.global_position.y - pos.y) > 3.0:
			continue
		var fall := clampf(1.0 - d / (rad + c.radius) * 0.5, 0.5, 1.0)
		var push := Vector3(c.global_position.x - pos.x, 0, c.global_position.z - pos.z).normalized() * 9.0
		var hit = Hit.new().setup(src if is_instance_valid(src) else null, damage * fall, kind, stance, push)
		hit.parryable = false
		hit.heavy = true
		hit.burn = burn
		c.receive_hit(hit)
		n += 1
	Fx.fire_nova(pos, rad)
	Fx.shake(0.6)
	Audio.play("execute", -2.0, 0.1, pos)
	return n


## A patch of burning ground.
static func fire_patch(parent: Node, pos: Vector3, src: Node3D, rad: float, dps_value: float, seconds: float) -> Node3D:
	var a = load("res://scripts/combat/aoe.gd").new()
	a.source = src
	a.radius = rad
	a.dps = dps_value
	a.life = seconds
	parent.add_child(a)
	a.global_position = pos
	var f := Effects.fire(0.5, 10)
	a.add_child(f)
	return a


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.25
	for p in get_tree().get_nodes_in_group("player_side"):
		if p.dead or not p is Node3D:
			continue
		if p.global_position.distance_to(global_position) < radius + 0.4:
			p.apply_status("burn", 1.5)
