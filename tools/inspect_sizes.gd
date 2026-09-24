extends SceneTree
## Dev tool: prints the size (AABB) of static glTF models in the given folders.
## Usage: godot --headless --path . -s tools/inspect_sizes.gd -- <res folder> [...]
func _init() -> void:
	for dir in OS.get_cmdline_user_args():
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".glb") and not f.ends_with(".gltf"):
				continue
			var s: Node3D = load(dir + "/" + f).instantiate()
			var box := AABB()
			var first := true
			for mi: MeshInstance3D in s.find_children("*", "MeshInstance3D", true, false):
				var xf := Transform3D()
				var n: Node = mi
				while n != null and n != s:
					xf = (n as Node3D).transform * xf
					n = n.get_parent()
				var b: AABB = xf * mi.get_aabb()
				box = b if first else box.merge(b)
				first = false
			print("%-28s size=(%.2f, %.2f, %.2f) min_y=%.2f" % [f.get_basename(), box.size.x, box.size.y, box.size.z, box.position.y])
			s.free()
	quit()
