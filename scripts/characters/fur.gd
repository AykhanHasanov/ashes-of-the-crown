extends RefCounted
## Gives the low-poly Quaternius animals real fur: their furred surfaces are rebuilt with
## smoothed normals (the facets go) and the rest-pose position stored in UV/UV2 (the
## fur pattern then rides on the body), and drawn with shaders/fur_shell.gdshader —
## a solid skin plus `shells` layers of strands. Eyes, nose and hooves stay as they are.
## cfg: {"length": m, "density": strands/m, "shells": n, "surfaces": [material names],
##       "tint": [r,g,b] (multiplies the base colour), "rosettes": 0..1, "droop": m}

const SHADER := preload("res://shaders/fur_shell.gdshader")


## `root` must already be in the tree and scaled (world size is used for metres → mesh units).
static func apply(root: Node3D, cfg: Dictionary) -> void:
	var furred: Array = cfg.get("surfaces", ["Main", "Main_Light", "Main_Dark", "Grey"])
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var to_mesh := 1.0 / maxf(mi.global_transform.basis.get_scale().x, 0.00001)
		var src: Mesh = mi.mesh
		var out := ArrayMesh.new()
		var mats: Array = []
		for s in src.get_surface_count():
			var mat := mi.get_active_material(s)
			var arrays: Array = src.surface_get_arrays(s)
			var name: String = mat.resource_name if mat != null else ""
			if name in furred:
				_smooth_and_mark(arrays)
				out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				mats.append(_fur_material(mat, cfg, to_mesh))
			else:
				out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				mats.append(mat)
		mi.mesh = out
		for s in mats.size():
			mi.set_surface_override_material(s, mats[s])


## Averages the normals of every vertex that shares a position, and stores the rest
## position: UV = (x, z), UV2.x = y.
static func _smooth_and_mark(arrays: Array) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var sums := {}
	for i in verts.size():
		var key := verts[i].snapped(Vector3.ONE * 0.0001)
		sums[key] = sums.get(key, Vector3.ZERO) + normals[i]
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	uv.resize(verts.size())
	uv2.resize(verts.size())
	for i in verts.size():
		var n: Vector3 = sums[verts[i].snapped(Vector3.ONE * 0.0001)]
		normals[i] = n.normalized() if n.length() > 0.0001 else normals[i]
		uv[i] = Vector2(verts[i].x, verts[i].z)
		uv2[i] = Vector2(verts[i].y, 0.0)
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_TANGENT] = null


static func _fur_material(orig: Material, cfg: Dictionary, to_mesh: float) -> ShaderMaterial:
	var color := Color(0.5, 0.5, 0.5)
	if orig is StandardMaterial3D:
		color = orig.albedo_color
	if cfg.has("tint"):
		var t: Array = cfg["tint"]
		color = Color(color.r * t[0], color.g * t[1], color.b * t[2])
	var shells: int = cfg.get("shells", 10)
	var first: ShaderMaterial = null
	var prev: ShaderMaterial = null
	for k in shells + 1:
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("albedo", color)
		m.set_shader_parameter("shell", float(k) / shells)
		m.set_shader_parameter("fur_length", float(cfg.get("length", 0.035)) * to_mesh)
		m.set_shader_parameter("density", float(cfg.get("density", 260.0)) / to_mesh)
		m.set_shader_parameter("droop", float(cfg.get("droop", 0.012)) * to_mesh)
		m.set_shader_parameter("rosettes", float(cfg.get("rosettes", 0.0)))
		m.set_shader_parameter("spot_scale", float(cfg.get("spot_scale", 9.0)) / to_mesh)
		m.render_priority = k
		if prev == null:
			first = m
		else:
			prev.next_pass = m
		prev = m
	return first
