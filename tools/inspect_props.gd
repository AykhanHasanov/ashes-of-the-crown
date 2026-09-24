extends SceneTree
## Dev tool: prints the bounding box of every environment model so levels can be laid out in code.
## Usage: godot --headless --path . -s tools/inspect_props.gd


func _init() -> void:
	for dir in ["res://assets/environment/dungeon/", "res://assets/environment/halloween/"]:
		for file in DirAccess.get_files_at(dir):
			if not (file.ends_with(".glb") or file.ends_with(".gltf")):
				continue
			var node: Node3D = load(dir + file).instantiate()
			var box := AABB()
			var first := true
			for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
				var b: AABB = mi.transform * mi.get_aabb()
				box = b if first else box.merge(b)
				first = false
			print("%-30s pos=(%.2f, %.2f, %.2f) size=(%.2f, %.2f, %.2f)" % [file, box.position.x, box.position.y, box.position.z, box.size.x, box.size.y, box.size.z])
			node.free()
	quit()
