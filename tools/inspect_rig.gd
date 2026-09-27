extends SceneTree
## Dev tool: prints skeletons, meshes and animations of the given glTF/GLB files.
func _init() -> void:
	for path in OS.get_cmdline_user_args():
		var s: Node = load(path).instantiate()
		print("=== ", path)
		_walk(s, 0)
		for sk: Skeleton3D in s.find_children("*", "Skeleton3D", true, false):
			var names := []
			for i in mini(sk.get_bone_count(), 70):
				names.append(sk.get_bone_name(i))
			print("  bones(", sk.get_bone_count(), "): ", " ".join(names))
		for ap: AnimationPlayer in s.find_children("*", "AnimationPlayer", true, false):
			var list := ap.get_animation_list()
			print("  anims(", list.size(), "): ", " ".join(list))
			if list.size() > 0:
				var a := ap.get_animation(list[0])
				print("  track0: ", a.track_get_path(0), "  len ", a.length)
		s.free()
	quit()


func _walk(n: Node, depth: int) -> void:
	if depth > 4:
		return
	var extra := ""
	if n is MeshInstance3D:
		extra = " mesh surf=%d aabb=%s" % [n.mesh.get_surface_count(), n.get_aabb().size]
	print("  ".repeat(depth + 1), n.name, " <", n.get_class(), ">", extra)
	for c in n.get_children():
		_walk(c, depth + 1)
