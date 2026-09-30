extends Node3D
## Something the protagonist can use with [E] in the open world: a hearth (light it, rest, fast
## travel), a chest (nar toxumu = +1 flask, or ember), an echo stone (lore), or a memory
## ember that opens an echo (data {"echo": id}; gone once its memory is kept or burned). Its
## saved state lives in WorldState's world section, keyed by `key` / the POI id.

const Effects := preload("res://scripts/world/effects.gd")
const HearthFire := preload("res://scripts/world/hearth_fire.gd")
const CHEST_CLOSED := "res://assets/quaternius/rpg_items_pack/Chest_Closed.glb"
const CHEST_OPEN := "res://assets/quaternius/rpg_items_pack/Chest_Open.glb"

const EchoRegistry := preload("res://scripts/core/echo_registry.gd")

var kind := ""            # hearth | chest | echo | memory_echo | hub_gate | trail
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
		"memory_echo":
			use_range = 2.2
			_build_memory_ember()
		"hub_gate", "trail":
			use_range = 2.6
			_build_gate_sign()


## A small glowing ember hovering over the ground: the placeholder look of a lost memory.
func _build_memory_ember() -> void:
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	core.mesh = sphere
	core.material_override = Effects.additive_material(Color(1.0, 0.55, 0.2, 1.0))
	core.position.y = 1.1
	add_child(core)
	var embers := Effects.ember_field(Vector3(0.3, 0.6, 0.3), 12)
	embers.position.y = 1.0
	add_child(embers)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.5, 0.2)
	_light.light_energy = 1.6
	_light.omni_range = 4.0
	_light.position.y = 1.1
	add_child(_light)
	visible = not is_used()


## The road to Son Ocaq: a post with a lantern (placeholder sign).
func _build_gate_sign() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.24, 0.16, 0.1)
	wood.roughness = 0.9
	for part in [[Vector3(0.16, 2.5, 0.16), Vector3(0, 1.25, 0)], [Vector3(0.9, 0.12, 0.12), Vector3(0.35, 2.25, 0)]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part[0]
		bm.material = wood
		mi.mesh = bm
		mi.position = part[1]
		add_child(mi)
	if ResourceLoader.exists("res://assets/props_mk/Lantern_Wall.gltf"):
		var lantern: Node3D = load("res://assets/props_mk/Lantern_Wall.gltf").instantiate()
		lantern.position = Vector3(0.7, 1.75, 0)
		add_child(lantern)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.6, 0.3)
	_light.light_energy = 1.4
	_light.omni_range = 6.0
	_light.position = Vector3(0.3, 2.0, 0)
	add_child(_light)


func hearth_id() -> String:
	return poi["id"]


func is_used() -> bool:
	match kind:
		"hearth":
			return WorldState.has_world_entry("hearths", hearth_id())
		"chest":
			return WorldState.has_world_entry("chests", key)
		"echo":
			return WorldState.has_world_entry("echoes", key)
		"memory_echo":
			var def: Resource = EchoRegistry.get_def(StringName(data.get("echo", ""))) if EchoRegistry.has(StringName(data.get("echo", ""))) else null
			return def == null or WorldState.get_memory_state(def.memory_id) != WorldState.MemoryState.UNKNOWN
	return false


func prompt() -> String:
	match kind:
		"hearth":
			return "[E]  Ocağın başına otur" if is_used() else "[E]  Ocağı yak — %s" % poi["name"]
		"chest":
			return "" if is_used() else "[E]  Sandığı aç"
		"echo":
			return "[E]  Taşa dokun" if not is_used() else "[E]  Yeniden oku"
		"memory_echo":
			return "" if is_used() else tr("ECHO_PROMPT_EMBER")
		"hub_gate":
			return tr("WORLD_PROMPT_HUB_GATE")
		"trail":
			return tr("WORLD_PROMPT_TRAIL_" + String(data.get("to", "")).to_upper())
	return ""


## Visual state of a hearth (scripts/world/hearth_fire.gd): cold ash and smoke until lit;
## flames, sparks and the ember pillar once lit.
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
		# flames and sparks (the prefab has the stones and logs; this node keeps its own light)
		_fire = HearthFire.new().setup(true, 1.1, false, false, false)
		add_child(_fire)
		# A column of embers into the sky: seen from across the valley
		_pillar = Effects.ember_column(0.9, 40)
		_pillar.position = Vector3(0, 1.0, 0)
		_pillar.scale = Vector3(1, 6, 1)
		add_child(_pillar)
		_light.light_energy = 3.2
	else:
		# not lit yet: cold ash and a thin thread of smoke
		_fire = HearthFire.new().setup(false, 1.1, false, true, false)
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
