extends SceneTree
## Dev tool: prints size, meshes and a few animation lengths of the character models.
## Usage: godot --headless --path . -s tools/inspect_models.gd

const MODELS := [
	"res://assets/characters/adventurers/Mage.glb",
	"res://assets/characters/adventurers/Rogue.glb",
]


func _init() -> void:
	for path in MODELS:
		var scene: Node3D = load(path).instantiate()
		var meshes := PackedStringArray()
		for mi in scene.find_children("*", "MeshInstance3D", true, false):
			meshes.append(mi.name)
		print("=== ", path.get_file(), "\nmeshes: ", ", ".join(meshes))
		var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		for a in ["Sit_Floor_Idle", "Sit_Chair_Idle", "Cheer", "Spellcasting", "Interact", "Death_A"]:
			print("  %s: %s" % [a, ap.has_animation(a)])
		scene.free()
	quit()
