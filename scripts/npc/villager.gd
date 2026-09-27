extends CharacterBody3D
## A villager living a daily routine (data/world/villagers.json): at each hour of the
## schedule they walk (by way of the village square) to their work spot and work there
## with the matching animation — forging, chopping wood, keeping a stall, carrying
## water, sitting on a bench, talking at the fire, keeping watch with a lantern. Outside
## the schedule they walk home and go in. When Ayxan comes close they turn to him and
## greet him (voiced, subtitled); if foes come near they run home.
## The body is moved kinematically on the terrain (villages are always near the player,
## but terrain collision only exists around the camera, so no gravity is trusted).

const Human := preload("res://scripts/characters/human.gd")
const WALK_SPEED := 1.35
const RUN_SPEED := 3.6

var def: Dictionary           # this villager (name, look, voice, home, schedule, prop)
var spots: Dictionary         # the prefab's spots
var center := Vector3.ZERO    # POI centre (prefab-local → world)
var hub := Vector3.ZERO
var height_at: Callable       # (x, z) -> ground height
var clock: Node               # DayNight (hour)
var player: Node3D

var _model: Node3D
var _goal := ""               # spot id or "home"
var _path: Array[Vector3] = []
var _route_i := 0
var _inside := false
var _fleeing := false
var _speak_cd := 4.0
var _idle_cd := 30.0
var _work_cd := 0.0
var _yaw := 0.0
var _think := 0.0


func setup(villager: Dictionary, prefab_spots: Dictionary, poi_center: Vector3, hub_local: Array, ground: Callable, day_night: Node, ayxan: Node3D) -> void:
	def = villager
	spots = prefab_spots
	center = poi_center
	height_at = ground
	clock = day_night
	player = ayxan
	hub = _world(hub_local)


func _ready() -> void:
	add_to_group("villagers")
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.75
	shape.shape = cap
	shape.position.y = 0.88
	add_child(shape)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(def.get("name", ""))
	_model = Human.build(Human.spec_from_json({"look": def["look"]}, rng))
	add_child(_model)
	_model.move_anim = "Walk"
	if def.has("prop"):
		_model.attach(def["prop"], "handslot.r")
	# Start where the clock says they should be, not walking in from nowhere
	_goal = _wanted()
	if _goal == "home":
		_hide(true)
		global_position = _ground_at(_world(def["home"]))
	else:
		global_position = _ground_at(_spot_pos(_goal))
		_arrive()


func _physics_process(delta: float) -> void:
	_think -= delta
	if _think <= 0.0:
		_think = 0.5
		_decide()
	if _inside:
		return
	if not _path.is_empty():
		_walk(delta)
	else:
		_work(delta)
	_social(delta)
	_model.rotation.y = lerp_angle(_model.rotation.y, _yaw, 1.0 - exp(-8.0 * delta))


# --- Decisions -------------------------------------------------------------------------------

func _wanted() -> String:
	var h: float = clock.hour if clock != null else 12.0
	for s in def["schedule"]:
		if h >= float(s[0]) and h < float(s[1]):
			return s[2]
	return "home"


func _decide() -> void:
	var danger := _danger_near()
	if danger and not _fleeing:
		_fleeing = true
		_say("flee", 1.0)
		_go("home")
		return
	if _fleeing and not danger and _inside:
		_fleeing = false
	if _fleeing:
		return
	var want := _wanted()
	if want != _goal:
		if want == "home" and not _inside:
			_say("night", 0.5)
		_go(want)


func _go(goal: String) -> void:
	_goal = goal
	_model.cancel_action()
	var target := _world(def["home"]) if goal == "home" else _spot_pos(goal)
	if _inside:
		_hide(false)
	_path.clear()
	var here := global_position
	# By way of the square unless the target is close by
	if Vector2(here.x, here.z).distance_to(Vector2(target.x, target.z)) > 9.0:
		_path.append(hub + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)))
	_path.append(target)
	_route_i = 0


func _arrive() -> void:
	if _goal == "home":
		_hide(true)
		return
	var s: Dictionary = spots[_goal]
	if s.has("route"):
		# Walk the route back and forth
		_route_i = (_route_i + 1) % s["route"].size()
		if s.has("work") and randf() < 0.7:
			_model.play_loop(s["work"])
			_work_cd = randf_range(4.0, 7.0)
		else:
			_path.append(_world(s["route"][_route_i]))
		return
	_face(s.get("face", null))
	_start_work(s)


func _start_work(s: Dictionary) -> void:
	var clip: String = s["anim"]
	if s.has("prop") and _model.skeleton.get_node_or_null("PropHolder") == null:
		var item: Node3D = _model.attach(s["prop"], "handslot.r")
		item.get_parent().get_parent().name = "PropHolder"
	if clip == "Interact":
		_model.play_action(clip)
		_work_cd = randf_range(3.0, 6.0)
	else:
		_model.play_loop(clip)


# --- Motion ----------------------------------------------------------------------------------

func _walk(delta: float) -> void:
	var target: Vector3 = _path[0]
	var to := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	var d := to.length()
	var speed := RUN_SPEED if _fleeing else WALK_SPEED
	if d < 0.35:
		_path.pop_front()
		if _path.is_empty():
			_arrive()
		return
	var clip: String = "Jog_Fwd" if _fleeing else (spots.get(_goal, {}).get("anim", "Walk") if spots.get(_goal, {}).has("route") else "Walk")
	_model.cancel_action()
	_model.play_loop(clip)
	var step := to / d * minf(speed * delta, d)
	var p := global_position + step
	global_position = _ground_at(p)
	_yaw = atan2(to.x, to.z)


func _work(delta: float) -> void:
	if _goal == "" or _goal == "home" or not spots.has(_goal):
		return
	var s: Dictionary = spots[_goal]
	if _work_cd > 0.0:
		_work_cd -= delta
		if _work_cd <= 0.0:
			if s.has("route"):
				_path.append(_world(s["route"][_route_i]))
			elif s["anim"] == "Interact":
				_model.cancel_action()
				_model.play_action("Interact")
				_work_cd = randf_range(4.0, 8.0)


func _hide(inside: bool) -> void:
	_inside = inside
	_model.visible = not inside
	for c in get_children():
		if c is CollisionShape3D:
			c.disabled = inside


func _face(face) -> void:
	if face is Array:
		var at := _world(face)
		_yaw = atan2(at.x - global_position.x, at.z - global_position.z)
	elif face != null:
		_yaw = deg_to_rad(float(face))


# --- People ----------------------------------------------------------------------------------

func _social(delta: float) -> void:
	_speak_cd -= delta
	_idle_cd -= delta
	if player == null or not is_instance_valid(player):
		return
	var d := global_position.distance_to(player.global_position)
	if d < 3.2 and _path.is_empty():
		# Look up from the work at Ayxan
		var to := player.global_position - global_position
		_yaw = atan2(to.x, to.z)
		if _speak_cd <= 0.0:
			_say("greet", 1.0)
			_speak_cd = randf_range(40.0, 70.0)
	elif d > 3.2 and _path.is_empty() and spots.has(_goal) and not spots[_goal].has("route"):
		_face(spots[_goal].get("face", null))
	if _idle_cd <= 0.0:
		_idle_cd = randf_range(50.0, 110.0)
		if d < 14.0:
			_say("idle", 0.6)


func _say(event: String, chance: float) -> void:
	if def.has("voice"):
		Barks.say(self, def["voice"], event, chance, 1.85)


func _danger_near() -> bool:
	for f in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(f) and not f.get("dead") and f.get("aggro") and global_position.distance_to(f.global_position) < 20.0:
			return true
	return false


# --- Space -----------------------------------------------------------------------------------

func _world(local: Array) -> Vector3:
	return _ground_at(center + Vector3(float(local[0]), 0, float(local[1])))


func _spot_pos(id: String) -> Vector3:
	var s: Dictionary = spots[id]
	if s.has("route"):
		_route_i = 0
		return _world(s["route"][0])
	return _world(s["p"])


func _ground_at(p: Vector3) -> Vector3:
	if height_at.is_valid():
		p.y = height_at.call(p.x, p.z)
	return p
