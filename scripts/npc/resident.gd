extends CharacterBody3D
## A named NPC (NpcDefinition) standing at their WorldState location — a view only: it is
## built by NpcSpawner from WorldState and freed at any time; it never writes state.
## Stands at its spot, looks up at the protagonist when he comes close and greets him
## (voice profile, subtitled). Roles, routines and dialogue come later with the story.

const Human := preload("res://scripts/characters/human.gd")
const Names := preload("res://scripts/core/names.gd")
const TALK_RANGE := 3.2

var npc_id: StringName
var def: Resource                 # NpcDefinition
var player: Node3D
var display_name := ""

var _model: Node3D
var _home_yaw := 0.0
var _yaw := 0.0
var _speak_cd := 3.0


func setup(definition: Resource, protagonist: Node3D, yaw := 0.0) -> void:
	def = definition
	npc_id = def.id
	player = protagonist
	_home_yaw = yaw
	_yaw = yaw


func _ready() -> void:
	add_to_group("npcs")
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
	rng.seed = hash(String(npc_id))
	_model = Human.build(Human.spec_from_json({"look": def.look_id}, rng))
	add_child(_model)
	_model.rotation.y = _yaw + PI
	display_name = Names.npc(npc_id)
	EventBus.memory_burned.connect(func(_id): display_name = Names.npc(npc_id))
	EventBus.npc_changed.connect(_on_npc_changed)


func _physics_process(delta: float) -> void:
	_speak_cd -= delta
	if player != null and is_instance_valid(player):
		var to := player.global_position - global_position
		to.y = 0.0
		if to.length() < TALK_RANGE:
			_yaw = atan2(to.x, to.z)
			if _speak_cd <= 0.0 and def.voice_profile != "":
				Barks.say(self, def.voice_profile, "greet", 1.0, 1.85)
				_speak_cd = randf_range(40.0, 70.0)
		else:
			_yaw = _home_yaw
	_model.rotation.y = lerp_angle(_model.rotation.y, _yaw + PI, 1.0 - exp(-6.0 * delta))   # the model faces -Z


## A revealed name shows at once.
func _on_npc_changed(id: StringName) -> void:
	if id == npc_id:
		display_name = Names.npc(npc_id)
