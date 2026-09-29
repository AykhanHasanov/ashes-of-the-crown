extends Node3D
## A shade in Son Ocaq's courtyard at night (placeholder Küllü). A view only, never a
## combatant: no body, no damage, not in the enemies or combatants groups.
##   ROAMER  walks from door to door and knocks. When Aras comes within break_range it
##           breaks into ash and re-forms elsewhere, out of his way, a while later.
##   LOST    a resident's own lost one (NpcDefinition.lost_one_*), knocking at that
##           resident's door on a warning night; breaks and re-forms at the same door.
##   NARIN   the small shade at Aras's door. It does not break; by morning it is gone.
## Numbers: data/hub/son_ocaq.json night_shades.

enum Kind { ROAMER, LOST, NARIN }
enum S { WALK, KNOCK, GONE }

const Human := preload("res://scripts/characters/human.gd")
const HubData := preload("res://scripts/hub/hub_data.gd")
const Effects := preload("res://scripts/world/effects.gd")

signal knocked(door_id: StringName)

var kind := Kind.ROAMER
var identity := ""                 # look id (lost_esref, npc_narin, ash...)
var home_door: Node3D              # LOST / NARIN: the door they stand at
var level                          # HubLevel (doors, stand points)
var player: Node3D
var cfg: Dictionary
var state := S.WALK
var knocks := 0
var reform_in := 0.0

var _model: Node3D
var _target_door: Node3D
var _goal := Vector3.ZERO
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(k: int, look_id: String, lvl, protagonist: Node3D, settings: Dictionary, door: Node3D = null) -> void:
	kind = k
	identity = look_id
	level = lvl
	player = protagonist
	cfg = settings
	home_door = door


func _ready() -> void:
	add_to_group("hub_shades")
	_rng.randomize()
	var spec := Human.spec_from_json({"look": identity}, _rng)
	_model = Human.build(spec)
	add_child(_model)
	_model.move_anim = "Walk"
	_model.tint(Color(0.34, 0.32, 0.31))
	if kind == Kind.NARIN:
		_model.scale = Vector3.ONE * float(cfg.get("narin_scale", 0.6))
	var trail := Effects.ash_trail(0.5, 10)
	trail.position.y = 1.0
	add_child(trail)
	_pick_next()


## Is this shade walking the yard now (not broken into ash)?
func is_present() -> bool:
	return state != S.GONE


func _process(delta: float) -> void:
	_t -= delta
	match state:
		S.GONE:
			reform_in -= delta
			if reform_in <= 0.0:
				_reform()
			return
		S.WALK:
			var to := _goal - global_position
			to.y = 0.0
			if to.length() < 0.3:
				_start_knock()
			else:
				var step: float = minf(float(cfg["speed"]) * delta, to.length())
				global_position += to.normalized() * step
				_model.rotation.y = atan2(-to.x, -to.z)
				_model.set_locomotion(true, 0.6)
		S.KNOCK:
			if _t <= 0.0:
				_pick_next()
	if kind != Kind.NARIN and player != null and is_instance_valid(player) \
			and global_position.distance_to(player.global_position) < float(cfg["break_range"]):
		break_apart()


## Aras came too close: it breaks into ash (not the small one at his door).
func break_apart() -> void:
	if kind == Kind.NARIN or state == S.GONE:
		return
	state = S.GONE
	var burst := Effects.smoke_burst(18, 1.2, 1.4, 0.5)
	burst.position = global_position + Vector3(0, 1.0, 0)
	get_parent().add_child(burst)
	burst.emitting = true
	get_tree().create_timer(3.0, false).timeout.connect(burst.queue_free)
	_model.visible = false
	var r: Array = cfg["reform_seconds"]
	reform_in = _rng.randf_range(float(r[0]), float(r[1]))


func _reform() -> void:
	state = S.WALK
	_model.visible = true
	if kind == Kind.ROAMER:
		# somewhere out of his way
		var best := global_position
		for i in 8:
			var d: Node3D = level.doors.values().pick_random()
			var p: Vector3 = d.global_position + d.global_basis.z * 1.2
			if player == null or p.distance_to(player.global_position) > float(cfg["break_range"]) * 2.5:
				best = p
				break
		global_position = best
	_pick_next()


func _pick_next() -> void:
	state = S.WALK
	if kind != Kind.ROAMER and home_door != null:
		_target_door = home_door
	else:
		var doors: Array = level.doors.values().filter(func(d): return HubData.place(d.place_id).get("kind", "") == "room")
		_target_door = doors.pick_random()
	_goal = _target_door.global_position + _target_door.global_basis.z * 0.9
	_goal.y = 0.0


func _start_knock() -> void:
	state = S.KNOCK
	_model.set_locomotion(false)
	var to: Vector3 = _target_door.global_position - global_position
	_model.rotation.y = atan2(-to.x, -to.z)
	_model.play_action("Interact", 1.0, 0.1)
	knocks += 1
	Audio.play("door_knock", -8.0, 0.05, _target_door.global_position + Vector3(0, 1.1, 0))
	knocked.emit(_target_door.door_id)
	var w: Array = cfg["knock_wait"]
	_t = _rng.randf_range(float(w[0]), float(w[1]))
