extends Node3D
## Deer in the valley: a couple of small herds (hinds and a stag) graze in the open
## near the protagonist, wander a few steps, lift their heads when he comes close and bolt when he
## is too near or comes running. Herds that fall far behind move on and appear
## elsewhere, never in water, on steep ground or in a settlement. Furred like the wolves.

const CharacterModel := preload("res://scripts/characters/character_model.gd")
const Fur := preload("res://scripts/characters/fur.gd")
const HERDS := 2
const A := "AnimalArmature|"
const KINDS := {
	"hind": {"path": "res://assets/quaternius/animals_pack/Deer.glb", "length": 1.75, "idle_low": "Idle_Headlow",
		"fur": {"length": 0.022, "density": 340, "shells": 6, "surfaces": ["Main", "Main_Light", "Main_Dark"]}},
	"stag": {"path": "res://assets/quaternius/animals_pack/Stag.glb", "length": 2.1, "idle_low": "Idle_Headlow",
		"fur": {"length": 0.024, "density": 320, "shells": 6, "surfaces": ["Material", "Material.003", "Material.010"]}},
}
enum S { GRAZE, WALK, ALERT, FLEE }

var height_at: Callable
var water_at: Callable        # (pos) -> surface height or -1000
var avoid: Array = []         # [Vector3, radius]: settlements
var player: Node3D

var _herds: Array = []        # {center: Vector3, animals: [..]}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var pp := player.global_position
	while _herds.size() < HERDS:
		var spot := _find_spot(pp)
		if spot == Vector3.INF:
			return
		_herds.append(_spawn_herd(spot))
	for h in _herds.duplicate():
		if Vector2(h["center"].x - pp.x, h["center"].z - pp.z).length() > 190.0:
			for a in h["animals"]:
				a["node"].queue_free()
			_herds.erase(h)
			continue
		for a in h["animals"]:
			_tick(a, h, pp, delta)


func _find_spot(pp: Vector3) -> Vector3:
	for attempt in 12:
		var ang := _rng.randf() * TAU
		var p := pp + Vector3(cos(ang), 0, sin(ang)) * _rng.randf_range(70.0, 130.0)
		if p.x < 20 or p.z < 20 or p.x > 492 or p.z > 492:
			continue
		p.y = height_at.call(p.x, p.z)
		if water_at.is_valid() and float(water_at.call(p)) > -999.0:
			continue
		var steep := absf(height_at.call(p.x + 3.0, p.z) - p.y) + absf(height_at.call(p.x, p.z + 3.0) - p.y)
		if steep > 1.8:
			continue
		var ok := true
		for av in avoid:
			if Vector2(p.x - av[0].x, p.z - av[0].z).length() < float(av[1]):
				ok = false
		if ok:
			return p
	return Vector3.INF


func _spawn_herd(center: Vector3) -> Dictionary:
	var animals := []
	var n := _rng.randi_range(2, 4)
	for i in n:
		var kind := "stag" if i == 0 and _rng.randf() < 0.6 else "hind"
		var k: Dictionary = KINDS[kind]
		var root := Node3D.new()
		add_child(root)
		var m := CharacterModel.new()
		root.add_child(m)
		m.setup(k["path"], [], 1.0, [A + "Idle", A + "Walk", A + "Gallop", A + "Eating", A + k["idle_low"]])
		m.fit_length(k["length"] * _rng.randf_range(0.92, 1.06))
		var pos := center + Vector3(_rng.randf_range(-6, 6), 0, _rng.randf_range(-6, 6))
		root.global_position = _ground(pos)
		Fur.apply(m.scene, k["fur"])
		var a := {"node": root, "model": m, "kind": k, "state": S.GRAZE, "t": _rng.randf_range(2, 8), "target": pos, "yaw": _rng.randf() * TAU}
		m.rotation.y = a["yaw"]
		_graze(a)
		animals.append(a)
	return {"center": center, "animals": animals}


func _tick(a: Dictionary, h: Dictionary, pp: Vector3, delta: float) -> void:
	var node: Node3D = a["node"]
	var m = a["model"]
	var pos := node.global_position
	var d := Vector2(pos.x - pp.x, pos.z - pp.z).length()
	var running: bool = player.has_method("is_sprinting_now") and player.is_sprinting_now()
	if a["state"] != S.FLEE and (d < 18.0 or (running and d < 32.0)):
		# Bolt: away from the protagonist, the whole herd with it
		for o in h["animals"]:
			var away: Vector3 = (o["node"].global_position - pp)
			away.y = 0
			away = away.normalized().rotated(Vector3.UP, _rng.randf_range(-0.4, 0.4))
			o["target"] = o["node"].global_position + away * _rng.randf_range(40.0, 55.0)
			o["state"] = S.FLEE
			o["model"].play_loop(A + "Gallop", 1.1)
		h["center"] = a["target"]
		return
	a["t"] -= delta
	match a["state"]:
		S.GRAZE:
			if d < 32.0:
				a["state"] = S.ALERT
				a["t"] = _rng.randf_range(3.0, 6.0)
				m.play_loop(A + "Idle")
			elif a["t"] <= 0.0:
				a["state"] = S.WALK
				a["target"] = h["center"] + Vector3(_rng.randf_range(-7, 7), 0, _rng.randf_range(-7, 7))
				m.play_loop(A + "Walk")
		S.ALERT:
			var to := pp - pos
			a["yaw"] = atan2(-to.x, -to.z)
			if d > 36.0 and a["t"] <= 0.0:
				_graze(a)
		S.WALK, S.FLEE:
			var to: Vector3 = a["target"] - pos
			to.y = 0
			var speed := 9.0 if a["state"] == S.FLEE else 1.1
			if to.length() < 0.6:
				_graze(a)
			else:
				var step := to.normalized() * minf(speed * delta, to.length())
				node.global_position = _ground(pos + step)
				a["yaw"] = atan2(-to.x, -to.z)
	m.rotation.y = lerp_angle(m.rotation.y, a["yaw"], 1.0 - exp(-5.0 * delta))


func _graze(a: Dictionary) -> void:
	a["state"] = S.GRAZE
	a["t"] = _rng.randf_range(5.0, 14.0)
	a["model"].play_loop(A + ("Eating" if _rng.randf() < 0.6 else a["kind"]["idle_low"]))


func _ground(p: Vector3) -> Vector3:
	p.y = height_at.call(p.x, p.z)
	return p
