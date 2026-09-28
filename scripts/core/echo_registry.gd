extends RefCounted
## Every EchoDefinition under res://data/echoes/, loaded once and looked up by id (the
## same pattern as MemoryRegistry).
## Use: const EchoRegistry := preload("res://scripts/core/echo_registry.gd")

const DIR := "res://data/echoes/"

static var _by_id: Dictionary = {}     # StringName -> EchoDefinition


static func _ensure_loaded() -> void:
	if not _by_id.is_empty():
		return
	for f in DirAccess.get_files_at(DIR):
		var file := f.trim_suffix(".remap")   # exported builds list converted resources as .remap
		if not file.ends_with(".tres"):
			continue
		var def: Resource = load(DIR + file)
		if def == null or StringName(def.get("id")) == &"":
			push_error("EchoRegistry: bad echo definition " + file)
			continue
		_by_id[def.id] = def


static func all() -> Array:
	_ensure_loaded()
	return _by_id.values()


static func has(id: StringName) -> bool:
	_ensure_loaded()
	return _by_id.has(id)


## The definition for `id`, or null (with an error) for an unknown id.
static func get_def(id: StringName) -> Resource:
	_ensure_loaded()
	if not _by_id.has(id):
		push_error("EchoRegistry: unknown echo id '%s'" % id)
		return null
	return _by_id[id]
