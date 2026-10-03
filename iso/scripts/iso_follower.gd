extends CharacterBody3D
## Rüfət, following Aras. He walks the path Aras actually took (a trail of breadcrumbs dropped
## as Aras moves), so he never cuts through a wall to keep up, and keeps a few steps behind.
##
## His walk is the Injured Walk — a subtle limp — played at its own ground speed (1.17 m/s,
## iso/tools/measure_gait.gd) so his feet stay planted. When Aras gets far ahead he hurries:
## the same limp, faster, and past that a run. He stops when Aras stops, turned towards him.
## Numbers: iso/data/iso_player.json "follower".

const Human := preload("res://scripts/characters/human.gd")
const IsoPalette := preload("res://iso/scripts/world/iso_palette.gd")
const CFG := "res://iso/data/iso_player.json"
const CRUMB := 0.5          # one breadcrumb every half metre Aras moves

var leader: Node3D
var model: Node3D
var _cfg: Dictionary
var _clip: Dictionary
var _trail: Array = []      # Vector3, oldest first
var _speed := 0.0
var _facing := Vector3(0, 0, -1)


func _ready() -> void:
	var all: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CFG))
	_cfg = all["follower"]
	_clip = all["clip_speed"]
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	shape.shape = cap
	shape.position.y = 0.88
	add_child(shape)
	collision_layer = 0          # he never blocks Aras in a doorway
	Human.tree_driven = true
	var spec := Human.spec_from_json({"look": String(_cfg["look"])}, RandomNumberGenerator.new())
	spec["idle"] = "Idle_Upright"
	spec["walk"] = "Walking_Hurt"       # the limp is his walk, wired into the tree from the start
	model = Human.build(spec)
	model.crowd_variety = false
	add_child(model)
	model.set_overlay(IsoPalette.get_mat("rim"))


func _physics_process(delta: float) -> void:
	if not is_instance_valid(leader):
		return
	var lp: Vector3 = leader.global_position
	if _trail.is_empty() or (_trail[-1] as Vector3).distance_to(lp) >= CRUMB:
		_trail.append(lp)
	# how much path lies between him and Aras
	var path_left := global_position.distance_to(_trail[0]) if not _trail.is_empty() else 0.0
	for i in range(1, _trail.size()):
		path_left += (_trail[i - 1] as Vector3).distance_to(_trail[i])
	var gap := float(_cfg["gap"])
	var walk := float(_cfg["speed"])
	var want := 0.0
	if path_left > gap:
		var behind := path_left - gap
		want = walk if behind < 2.0 else (walk * 1.25 if behind < float(_cfg["catch_up"]) else float(_cfg["run_speed"]))
	_speed = move_toward(_speed, want, 8.0 * delta)
	# walk the trail, dropping crumbs he has reached
	while not _trail.is_empty() and global_position.distance_to(_trail[0]) < 0.35 and path_left > gap:
		_trail.pop_front()
	var dir := Vector3.ZERO
	if not _trail.is_empty() and _speed > 0.05:
		dir = ((_trail[0] as Vector3) - global_position) * Vector3(1, 0, 1)
		dir = dir.normalized()
		_facing = _facing.slerp(dir, 1.0 - exp(-8.0 * delta)).normalized()
	elif _speed <= 0.05:
		var to := (lp - global_position) * Vector3(1, 0, 1)
		if to.length() > 0.5:
			_facing = _facing.slerp(to.normalized(), 1.0 - exp(-3.0 * delta)).normalized()
	velocity.x = dir.x * _speed
	velocity.z = dir.z * _speed
	velocity.y = -0.5 if is_on_floor() else velocity.y - 22.0 * delta
	move_and_slide()
	model.rotation.y = atan2(-_facing.x, -_facing.z)
	_animate()


## The limp at its own speed, hurried a little, then a run.
func _animate() -> void:
	var limp := float(_clip["walk_hurt"])
	var run_clip := float(_clip["run"])
	var walk := float(_cfg["speed"])
	if _speed < 0.05:
		model.set_gait(0.0, 1.0)
	elif _speed <= walk * 1.3:
		model.set_gait(0.5 * minf(_speed / walk, 1.0), _speed / limp)
	else:
		var run := float(_cfg["run_speed"])
		var k := clampf((_speed - walk * 1.3) / (run - walk * 1.3), 0.0, 1.0)
		model.set_gait(0.5 + 0.5 * k, lerpf(_speed / limp, _speed / run_clip, k))


func snap_behind() -> void:
	if is_instance_valid(leader):
		global_position = leader.global_position + Vector3(1.2, 0, 1.6)
		_trail.clear()
