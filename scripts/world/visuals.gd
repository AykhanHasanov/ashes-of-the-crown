extends RefCounted
## Static helpers for building level geometry in code: materials and primitive meshes.

const SMALL_CASTER := 0.5   # metres; the default of lighting.json shadows.min_caster_size


## Small things cast no shadow: every mesh under `model` whose largest side (at `scale`) is
## under `limit` metres gets shadow casting off. Returns how many were switched off. Safe on
## a worker thread (it touches only the given nodes).
static func no_small_shadows(model: Node, scale := Vector3.ONE, limit := SMALL_CASTER) -> int:
	var n := 0
	var meshes: Array = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		meshes.append(model)
	for mi in meshes:
		var size: Vector3 = (mi as MeshInstance3D).get_aabb().size * scale.abs()
		if maxf(size.x, maxf(size.y, size.z)) < limit:
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n += 1
	return n


static func mat(color: Color, roughness := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


static func glow_mat(color: Color, energy := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


static func shader_mat(shader: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	return m


static func mesh_node(mesh: Mesh, material: Material, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	return mi


static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = height
	c.radial_segments = 12
	c.rings = 4
	return c


static func cylinder(top: float, bottom: float, height: float, segments := 14) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = segments
	c.rings = 1
	return c


static func sphere(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 14
	s.rings = 7
	return s

