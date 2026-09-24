extends SceneTree
## Dev tool: bakes each vegetation model (data/world/vegetation.json) into a plain
## Y-up, metre-scale mesh scene at assets/foliage/<id>.scn. Quaternius glTFs keep their
## geometry at 1/100 scale under a ×100, Z-up node; Terrain3D's instancer uses the raw
## mesh without node transforms, so it would draw 5 mm grass. Run before gen_world.
## Usage: godot --headless --path . -s tools/bake_foliage.gd

const OUT := "res://assets/foliage/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var veg = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/vegetation.json"))
	for item in veg["items"]:
		if item.has("procedural"):
			_save(item["id"], _tuft(item["procedural"]))
			continue
		var src: Node3D = load(item["model"]).instantiate()
		var mi: MeshInstance3D = src.find_children("*", "MeshInstance3D", true, false)[0]
		var xf := Transform3D()
		var n: Node = mi
		while n != null and n != src:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var baked := ArrayMesh.new()
		var normal_basis := xf.basis.inverse().transposed()
		for s in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in verts.size():
				verts[i] = xf * verts[i]
			arrays[Mesh.ARRAY_VERTEX] = verts
			if arrays[Mesh.ARRAY_NORMAL] != null:
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for i in normals.size():
					normals[i] = (normal_basis * normals[i]).normalized()
				arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_TANGENT] = null
			baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var mat := mi.get_active_material(s)
			if mat != null:
				baked.surface_set_material(s, mat)
		_save(item["id"], baked)
		src.free()
	quit()


func _save(id: String, mesh: ArrayMesh) -> void:
	var root := MeshInstance3D.new()
	root.name = id
	root.mesh = mesh
	var scene := PackedScene.new()
	scene.pack(root)
	var path: String = OUT + id + ".scn"
	ResourceSaver.save(scene, path)
	var tris := 0
	for s in mesh.get_surface_count():
		tris += mesh.surface_get_array_len(s) / 3 if mesh.surface_get_array_index_len(s) <= 0 else mesh.surface_get_array_index_len(s) / 3
	print("baked %-12s height %.2f m, %d triangles → %s" % [id, mesh.get_aabb().size.y, tris, path])
	root.free()


## A low-poly grass tuft: tapered blades leaning outwards, 3 triangles each.
## Normals point mostly up so the tuft shades softly like the ground under it.
func _tuft(cfg: Dictionary) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blades: int = cfg["blades"]
	var hr: Array = cfg["height"]
	var w: float = cfg["width"]
	var spread: float = cfg["spread"]
	for b in blades:
		var ang := TAU * b / blades + rng.randf_range(-0.4, 0.4)
		var root := Vector3(cos(ang), 0, sin(ang)) * rng.randf_range(0.0, spread)
		var h := rng.randf_range(hr[0], hr[1])
		var lean := Vector3(cos(ang), 0, sin(ang)) * h * rng.randf_range(0.15, 0.4)
		var face := ang + PI * 0.5 + rng.randf_range(-0.5, 0.5)
		var side := Vector3(cos(face), 0, sin(face)) * w * 0.5
		var bl := root - side
		var br := root + side
		var mid := root + lean * 0.45 + Vector3(0, h * 0.55, 0)
		var ml := mid - side * 0.7
		var mr := mid + side * 0.7
		var tip := root + lean + Vector3(0, h, 0)
		var n := (Vector3.UP * 2.0 + Vector3(cos(ang), 0, sin(ang))).normalized()
		for v in [bl, br, mr, bl, mr, ml, ml, mr, tip]:
			st.set_normal(n)
			st.set_uv(Vector2(0.5, v.y / h))
			st.add_vertex(v)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.44, 0.6, 0.2)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	return st.commit()
