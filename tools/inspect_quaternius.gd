extends SceneTree
## Dev tool: animations of the Quaternius animals and the names/sizes of weapons and items.
## Usage: godot --headless --path . -s tools/inspect_quaternius.gd


func _init() -> void:
	var root := "res://assets/quaternius/"
	for file in ["Wolf.glb", "Horse.glb"]:
		var s: Node = load(root + "animals_pack/" + file).instantiate()
		var ap: AnimationPlayer = s.find_children("*", "AnimationPlayer", true, false)[0]
		var anims := PackedStringArray()
		for a in ap.get_animation_list():
			anims.append("%s(%.2f)" % [a, ap.get_animation(a).length])
		print(file, " anims: ", ", ".join(anims), "  size=", _size(s))
		s.free()
	for pack in ["medieval_weapons_pack", "rpg_items_pack"]:
		var names := PackedStringArray()
		for f in DirAccess.get_files_at(root + pack):
			if f.ends_with(".glb"):
				names.append(f.get_basename())
		print(pack, ": ", ", ".join(names))
	for f in ["Mace.glb", "Spear.glb", "Bow_Wooden.glb", "Potion1_Filled.glb"]:
		for pack in ["medieval_weapons_pack", "rpg_items_pack"]:
			var path: String = root + pack + "/" + f
			if ResourceLoader.exists(path):
				var s: Node = load(path).instantiate()
				print(f, " size=", _size(s))
				s.free()
	quit()


func _size(n: Node) -> Vector3:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		box = mi.get_aabb() if first else box.merge(mi.get_aabb())
		first = false
	return box.size
