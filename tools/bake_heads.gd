extends SceneTree
## Dev tool: cuts the head and neck out of Quaternius' Universal Base Characters
## (Superhero full bodies) so they can sit on the outfit characters, which come
## without heads. Triangles whose vertices are mostly weighted to Head/neck_01 are
## kept. Writes assets/chars/heads/<male|female>_head.res plus the skin it binds with.
## Usage: godot --headless --path . -s tools/bake_heads.gd

const OUT := "res://assets/chars/heads/"
const SRC := {"male": ["res://assets/chars/base/Superhero_Male_FullBody.gltf", "SuperHero_Male"],
	"female": ["res://assets/chars/base/Superhero_Female_FullBody.gltf", "SuperHero_Female"]}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for g in SRC:
		var s: Node = load(SRC[g][0]).instantiate()
		var sk: Skeleton3D = s.find_children("*", "Skeleton3D", true, false)[0]
		var keep_bones := [sk.find_bone("Head"), sk.find_bone("neck_01")]
		var mi: MeshInstance3D = null
		for m: MeshInstance3D in s.find_children("*", "MeshInstance3D", true, false):
			if mi == null or m.get_aabb().size.y > mi.get_aabb().size.y:
				mi = m   # the body is the tallest mesh (eyes and brows are separate)
		var arrays: Array = mi.mesh.surface_get_arrays(0)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var per := bones.size() / verts.size()
		var head_w := PackedFloat32Array()
		head_w.resize(verts.size())
		for v in verts.size():
			var w := 0.0
			for k in per:
				if bones[v * per + k] in keep_bones:
					w += weights[v * per + k]
			head_w[v] = w
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var kept := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			var a := idx[t]
			var b := idx[t + 1]
			var c := idx[t + 2]
			if head_w[a] + head_w[b] + head_w[c] >= 1.5:
				kept.append_array([a, b, c])
		arrays[Mesh.ARRAY_INDEX] = kept
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, mi.mesh.surface_get_format(0) & ~Mesh.ARRAY_FORMAT_INDEX | Mesh.ARRAY_FORMAT_INDEX)
		mesh.surface_set_material(0, mi.get_active_material(0))
		ResourceSaver.save(mesh, OUT + g + "_head.res")
		ResourceSaver.save(mi.skin, OUT + g + "_skin.res")
		print("%s head: %d of %d triangles" % [g, kept.size() / 3, idx.size() / 3])
		s.free()
	quit()
