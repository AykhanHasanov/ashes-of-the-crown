extends SceneTree
## Dev tool: prints animation clips and mesh names of the given models.
## Usage: godot --headless --path . -s tools/list_anims.gd -- res://path/a.glb [...]
func _init() -> void:
	for path in OS.get_cmdline_user_args():
		var s: Node = load(path).instantiate()
		var aps := s.find_children("*", "AnimationPlayer", true, false)
		if not aps.is_empty():
			print(path.get_file(), " clips: ", " ".join(aps[0].get_animation_list()))
		var meshes := []
		for mi in s.find_children("*", "MeshInstance3D", true, false):
			meshes.append(mi.name)
		print(path.get_file(), " meshes: ", " ".join(meshes))
		s.free()
	quit()
