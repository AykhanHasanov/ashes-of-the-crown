extends SceneTree
## Applies the material rule (scripts/core/material_policy.gd) to the baked foliage scenes
## (assets/foliage/*.scn, written by tools/bake_foliage.gd and tools/gen_trees.gd, which
## copy Quaternius materials) and saves them. glTF models get the rule at import instead.
## Run: godot --headless --path . -s tools/fix_materials.gd

const MaterialPolicy := preload("res://scripts/core/material_policy.gd")
const DIR := "res://assets/foliage/"


func _init() -> void:
	for f in DirAccess.get_files_at(DIR):
		if f.get_extension() != "scn":
			continue
		var path := DIR + f
		var scene: PackedScene = load(path)
		var root := scene.instantiate()
		var n := MaterialPolicy.apply(root)
		if n > 0:
			var out := PackedScene.new()
			out.pack(root)
			ResourceSaver.save(out, path)
			print("%s: %d materials fixed" % [f, n])
		root.free()
	quit()
