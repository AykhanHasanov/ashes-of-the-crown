extends Node
## Loads the game's content from JSON under res://data (spec V3 rule 4): balance
## tables, weapons, enemies, encounters, the world layout and POI prefabs. Everything tunable
## lives in those files. World files are keyed by file name, the rest by their "id".

const DIRS := {
	"balance": "res://data/balance/",
	"weapons": "res://data/weapons/",
	"enemies": "res://data/enemies/",
	"world": "res://data/world/",
	"prefabs": "res://data/world/prefabs/",
	"encounters": "res://data/encounters/",
}

var _tables := {}   # category -> {id -> Dictionary}


func _ready() -> void:
	reload()


func reload() -> void:
	_tables.clear()
	for category in DIRS:
		var table := {}
		var dir: String = DIRS[category]
		for file in DirAccess.get_files_at(dir):
			# Exported builds list remapped files; strip Godot's suffix
			file = file.trim_suffix(".remap")
			if not file.ends_with(".json"):
				continue
			var data = JSON.parse_string(FileAccess.get_file_as_string(dir + file))
			if data is Dictionary:
				var key: String = file.get_basename() if category == "world" else data.get("id", file.get_basename())
				table[key] = data
			else:
				push_error("DataDB: cannot parse %s%s" % [dir, file])
		_tables[category] = table


## A balance table, e.g. balance("combat")["stamina"]["max"].
func balance(table: String) -> Dictionary:
	return _tables["balance"].get(table, {})


func weapon(id: String) -> Dictionary:
	return _tables["weapons"].get(id, {})


func enemy(id: String) -> Dictionary:
	return _tables["enemies"].get(id, {})


## A world file by name: world("world_layout"), world("vegetation")...
func world(file: String) -> Dictionary:
	return _tables["world"].get(file, {})


## An encounter (waves of enemies), data/encounters/<id>.json.
func encounter(id: String) -> Dictionary:
	return _tables["encounters"].get(id, {})


func prefab(id: String) -> Dictionary:
	return _tables["prefabs"].get(id, {})


func ids(category: String) -> Array:
	return _tables[category].keys()
