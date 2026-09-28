extends RefCounted
## Every NpcDefinition under res://data/npcs/, loaded once and looked up by id (the same
## pattern as MemoryRegistry and EchoRegistry).
## Use: const NpcRegistry := preload("res://scripts/core/npc_registry.gd")

const DIR := "res://data/npcs/"

static var _by_id: Dictionary = {}     # StringName -> NpcDefinition
static var _order: Array = []          # ids sorted, for stable iteration


static func _ensure_loaded() -> void:
	if not _by_id.is_empty():
		return
	for f in DirAccess.get_files_at(DIR):
		var file := f.trim_suffix(".remap")   # exported builds list converted resources as .remap
		if not file.ends_with(".tres"):
			continue
		var def: Resource = load(DIR + file)
		if def == null or StringName(def.get("id")) == &"":
			push_error("NpcRegistry: bad NPC definition " + file)
			continue
		_by_id[def.id] = def
	_order = _by_id.keys()
	_order.sort_custom(func(a, b): return String(a) < String(b))


## All definitions, sorted by id.
static func all() -> Array:
	_ensure_loaded()
	return _order.map(func(id): return _by_id[id])


static func has(id: StringName) -> bool:
	_ensure_loaded()
	return _by_id.has(id)


## The definition for `id`, or null (with an error) for an unknown id.
static func get_def(id: StringName) -> Resource:
	_ensure_loaded()
	if not _by_id.has(id):
		push_error("NpcRegistry: unknown NPC id '%s'" % id)
		return null
	return _by_id[id]
