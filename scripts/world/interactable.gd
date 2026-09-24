extends Node3D
## Something Ayxan can use with [E] in the open world: a hearth (light it, rest, fast
## travel), a chest (nar toxumu = +1 flask, or ember), an echo stone (lore). Its
## saved state lives in GameState.world, keyed by `key` / the POI id.

const Effects := preload("res://scripts/world/effects.gd")
const CHEST_CLOSED := "res://assets/quaternius/rpg_items_pack/Chest_Closed.glb"
const CHEST_OPEN := "res://assets/quaternius/rpg_items_pack/Chest_Open.glb"

var kind := ""            # hearth | chest | echo
var poi: Dictionary
var data: Dictionary
var key := ""
var use_range := 2.6

var _model: Node3D
var _fire: Node3D
var _light: OmniLight3D
var _pillar: Node3D
var _t := 0.0


func _ready() -> void:
	add_to_group("interactables")
	match kind:
		"hearth":
			use_range = 3.4
			_light = OmniLight3D.new()
			_light.position = Vector3(0, 1.2, 0)
			_light.light_color = Color(1.0, 0.5, 0.2)
			_light.omni_range = 14.0
			_light.shadow_enabled = false
			add_child(_light)
			refresh()
		"chest":
			_set_chest(is_used())
		"echo":
			use_range = 2.4


func hearth_id() -> String:
	return poi["id"]


func is_used() -> bool:
	match kind:
		"hearth":
			return GameState.world_has("hearths", hearth_id())
		"chest":
			return GameState.world_has("chests", key)
		"echo":
			return GameState.world_has("echoes", key)
	return false


func prompt() -> String:
	match kind:
		"hearth":
			return "[E]  Ocağa otur" if is_used() else "[E]  Ocağı yandır — %s" % poi["name"]
		"chest":
			return "" if is_used() else "[E]  Sandığı aç"
		"echo":
			return "[E]  Daşa toxun" if not is_used() else "[E]  Yenidən oxu"
	return ""


## Visual state of a hearth: embers when cold, fire + ember pillar when lit.
func refresh() -> void:
	if kind != "hearth":
		return
	var lit := is_used()
	if _fire:
		_fire.queue_free()
		_fire = null
	if _pillar:
		_pillar.queue_free()
		_pillar = null
	if lit:
		_fire = Effects.fire(1.6, 36)
		_fire.position = Vector3(0, 0.3, 0)
		add_child(_fire)
		# A column of embers into the sky: seen from across the valley
		_pillar = Effects.ember_column(0.9, 40)
		_pillar.position = Vector3(0, 1.0, 0)
		_pillar.scale = Vector3(1, 6, 1)
		add_child(_pillar)
		_light.light_energy = 3.2
	else:
		_fire = Effects.ember_field(Vector3(0.8, 0.3, 0.8), 8)
		_fire.position = Vector3(0, 0.3, 0)
		add_child(_fire)
		_light.light_energy = 0.6


func _set_chest(open: bool) -> void:
	if _model:
		_model.queue_free()
	var scene: PackedScene = load(CHEST_OPEN if open else CHEST_CLOSED)
	_model = scene.instantiate()
	_model.scale = Vector3.ONE * 1.3
	_model.rotation.y = deg_to_rad(float(data.get("r", 0.0)))
	add_child(_model)
	if not open:
		var glow := Effects.ember_field(Vector3(0.5, 0.3, 0.5), 6)
		glow.position = Vector3(0, 0.8, 0)
		_model.add_child(glow)


func open_chest() -> void:
	_set_chest(true)


func _process(delta: float) -> void:
	_t += delta
	if _light and kind == "hearth":
		var base := 3.2 if is_used() else 0.6
		_light.light_energy = base * (0.85 + 0.1 * sin(_t * 8.0) + 0.05 * sin(_t * 19.0))
