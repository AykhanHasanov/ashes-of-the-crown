extends RefCounted
## Every MemoryDefinition under res://data/memories/, loaded once and looked up by id.
## Use: const MemoryRegistry := preload("res://scripts/core/memory_registry.gd")
##      MemoryRegistry.get_def(&"rufet_face"), MemoryRegistry.all()

const DIR := "res://data/memories/"

static var _by_id: Dictionary = {}     # StringName -> MemoryDefinition
static var _ordered: Array = []


static func _ensure_loaded() -> void:
	if not _ordered.is_empty():
		return
	for f in DirAccess.get_files_at(DIR):
		# Exported builds list converted resources as "<name>.tres.remap"
		var file := f.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var def: Resource = load(DIR + file)
		if def == null or StringName(def.get("id")) == &"":
			push_error("MemoryRegistry: bad memory definition " + file)
			continue
		_by_id[def.id] = def
		_ordered.append(def)
	_ordered.sort_custom(func(a, b): return a.order < b.order)


## All memories in display order.
static func all() -> Array:
	_ensure_loaded()
	return _ordered.duplicate()


static func has(id: StringName) -> bool:
	_ensure_loaded()
	return _by_id.has(id)


## The definition for `id`, or null (with an error) for an unknown id.
static func get_def(id: StringName) -> Resource:
	_ensure_loaded()
	if not _by_id.has(id):
		push_error("MemoryRegistry: unknown memory id '%s'" % id)
		return null
	return _by_id[id]


static func count() -> int:
	_ensure_loaded()
	return _ordered.size()
