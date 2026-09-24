extends SceneTree
## Dev tool: loads every script under res://scripts and reports the ones that fail.
## Usage: godot --headless --path . -s tools/check_scripts.gd


func _init() -> void:
	var bad := 0
	for path in _scripts("res://scripts"):
		var s = load(path)
		if s == null or not (s is Script) or not s.can_instantiate():
			print("FAILED ", path)
			bad += 1
	print("CHECKED, failures: ", bad)
	quit()


func _scripts(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out += _scripts(dir + "/" + d)
	return out
