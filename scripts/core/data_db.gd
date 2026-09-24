extends Node
## Loads the game's content from JSON under res://data (spec V3 rule 4): balance
## tables, weapons and enemies. Everything tunable lives in those files.

const DIRS := {
	"balance": "res://data/balance/",
	"weapons": "res://data/weapons/",
	"enemies": "res://data/enemies/",
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
				table[data.get("id", file.get_basename())] = data
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


func ids(category: String) -> Array:
	return _tables[category].keys()
