extends Node3D
## An arrow, a burning bolt or an ash orb. Flies with gravity, ray-tests its path
## every physics frame and delivers a Hit to the first hostile combatant it meets.
## Dodged (invulnerable) targets let it fly on; walls and ground stop it. A parry
## knocks it aside.

const Effects := preload("res://scripts/world/effects.gd")
const Hit := preload("res://scripts/combat/hit.gd")

var shooter: Node3D
var player_side := false          # the shooter's side, kept even after the shooter dies
var hit_info: Dictionary = {}     # damage, damage_type, stance, burn, parryable
var velocity := Vector3.ZERO
var gravity := 0.0
var life := 4.0
var _exclude: Array[RID] = []


static func launch(parent: Node, from: Vector3, to: Vector3, owner_node: Node3D, info: Dictionary, spec: Dictionary) -> Node3D:
	var p = load("res://scripts/combat/projectile.gd").new()
	p.shooter = owner_node
	p.player_side = owner_node.is_in_group("player_side")
	p.hit_info = info
	p.gravity = float(spec.get("gravity", 0.0))
	var speed: float = spec.get("speed", 20.0)
	var dir := (to - from).normalized()
	# Aim a little higher to make up for the drop over the distance
	var t := from.distance_to(to) / speed
	var v := dir * speed + Vector3(0, 0.5 * p.gravity * t, 0)
	p.velocity = v
	parent.add_child(p)
	p.global_position = from
	p._build(spec)
	return p


func _build(spec: Dictionary) -> void:
	if owner_rid_ok():
		_exclude.append(shooter.get_rid())
	if spec.get("orb", false):
		var mi := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.18
		sphere.height = 0.36
		mi.mesh = sphere
		mi.material_override = Effects.additive_material(Color(1.0, 0.45, 0.12, 1.0))
		add_child(mi)
	elif spec.has("model") and ResourceLoader.exists(spec["model"]):
		var arrow: Node3D = load(spec["model"]).instantiate()
		add_child(arrow)
		_fit(arrow, 0.9)
	if spec.get("fire", false):
		var trail := Effects.ember_trail()
		add_child(trail)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.5, 0.2)
		l.light_energy = 1.5
		l.omni_range = 4.0
		add_child(l)


func owner_rid_ok() -> bool:
	return is_instance_valid(shooter) and shooter is CollisionObject3D


func _fit(item: Node3D, length: float) -> void:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in item.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D()
		var n: Node = mi
		while n != null and n != item:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b: AABB = xf * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if longest > 0.0001:
		item.scale = Vector3.ONE * (length / longest)
	# Point the long axis along -Z (the flight direction after look_at)
	if box.size.y >= box.size.x and box.size.y >= box.size.z:
		item.rotation.x = -PI * 0.5
	elif box.size.x >= box.size.z:
		item.rotation.y = PI * 0.5


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	velocity.y -= gravity * delta
	var from := global_position
	var to := from + velocity * delta
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2 | 4, _exclude)
	var res := space.intersect_ray(q)
	if res.is_empty():
		global_position = to
		if velocity.length() > 0.1:
			look_at(to + velocity, Vector3.UP)
		return
	var c = res["collider"]
	if c is CharacterBody3D and c.has_method("receive_hit"):
		if c.is_in_group("player_side") == player_side:
			_exclude.append(c.get_rid())   # friendly: fly past
			global_position = to
			return
		var hit = Hit.new().setup(shooter if is_instance_valid(shooter) else null, float(hit_info.get("damage", 10.0)),
			hit_info.get("damage_type", "pierce"), float(hit_info.get("stance", 8.0)), velocity.normalized() * 3.0)
		hit.burn = float(hit_info.get("burn", 0.0))
		hit.parryable = hit_info.get("parryable", true)
		var result: String = c.receive_hit(hit)
		if result == "ignored":
			_exclude.append(c.get_rid())   # dodged through it
			global_position = to
			return
		Fx.hit_spark(res["position"], result == "parried")
	else:
		Fx.hit_spark(res["position"], false)
		if hit_info.get("burn", 0.0) > 0.0:
			Fx.ash_puff(res["position"])
	queue_free()
