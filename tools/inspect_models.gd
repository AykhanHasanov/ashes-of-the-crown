extends SceneTree
## Dev tool: prints size, bones and animation lengths of the imported character models.
## Usage: godot --headless --path . -s tools/inspect_models.gd

const MODELS := [
	"res://assets/characters/adventurers/Knight.glb",
	"res://assets/characters/adventurers/Barbarian.glb",
	"res://assets/characters/adventurers/Rogue_Hooded.glb",
	"res://assets/characters/skeletons/Skeleton_Warrior.glb",
]


func _init() -> void:
	for path in MODELS:
		var scene: Node3D = load(path).instantiate()
		var aabb := AABB()
		for mi in scene.find_children("*", "MeshInstance3D", true, false):
			aabb = aabb.merge(mi.get_aabb())
		print("=== ", path.get_file(), "  aabb=", aabb)
		var skel: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
		var bones := PackedStringArray()
		for i in skel.get_bone_count():
			bones.append(skel.get_bone_name(i))
		print("bones: ", ", ".join(bones))
		var meshes := PackedStringArray()
		for mi in scene.find_children("*", "MeshInstance3D", true, false):
			meshes.append(mi.name)
		print("meshes: ", ", ".join(meshes))
		var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		for a in ["Idle", "Running_A", "1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Chop", "Dodge_Forward", "Hit_A", "Death_A", "Spellcast_Raise", "Spawn_Ground_Skeletons", "Death_C_Skeletons", "Walking_D_Skeletons"]:
			if ap.has_animation(a):
				print("  %s  %.2fs  loop=%d" % [a, ap.get_animation(a).length, ap.get_animation(a).loop_mode])
		scene.free()
	quit()
