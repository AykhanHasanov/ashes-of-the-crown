extends RefCounted
## Static helpers for placeholder 3D visuals built from primitives: materials,
## meshes and stylized humanoid figures. Replaced by real art in later milestones.


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


## Stylized armored figure facing -Z. Children "SwordPivot" (right hand) and
## "Chest" (front of the torso) are exposed for animation and attachments.
## Materials are stored as metadata "armor_mat" and "cloak_mat" so they can be tinted.
static func humanoid(cloak: Color, armor: Color, skin: Color, hair: Color) -> Node3D:
	var root := Node3D.new()
	var armor_m := mat(armor, 0.4, 0.65)
	var cloth_m := mat(cloak, 0.9)
	var skin_m := mat(skin, 0.7)
	var dark_m := mat(armor.darkened(0.65), 0.6, 0.3)
	var hair_m := mat(hair, 0.85)
	root.set_meta("armor_mat", armor_m)
	root.set_meta("cloak_mat", cloth_m)

	# Legs and boots
	root.add_child(mesh_node(capsule(0.12, 0.85), dark_m, Vector3(-0.13, 0.42, 0)))
	root.add_child(mesh_node(capsule(0.12, 0.85), dark_m, Vector3(0.13, 0.42, 0)))
	# Coat skirt
	root.add_child(mesh_node(cylinder(0.27, 0.42, 0.72), cloth_m, Vector3(0, 0.74, 0)))
	# Torso and belt
	root.add_child(mesh_node(capsule(0.27, 0.8), armor_m, Vector3(0, 1.3, 0)))
	root.add_child(mesh_node(cylinder(0.29, 0.29, 0.1), dark_m, Vector3(0, 1.02, 0)))
	# Cape
	root.add_child(mesh_node(box(Vector3(0.66, 1.2, 0.05)), cloth_m, Vector3(0, 1.0, 0.27), Vector3(-9, 0, 0)))
	# Pauldrons
	root.add_child(mesh_node(sphere(0.16), armor_m, Vector3(-0.34, 1.54, 0), Vector3.ZERO, Vector3(1, 0.75, 1)))
	root.add_child(mesh_node(sphere(0.16), armor_m, Vector3(0.34, 1.54, 0), Vector3.ZERO, Vector3(1, 0.75, 1)))
	# Left arm
	root.add_child(mesh_node(capsule(0.08, 0.64), cloth_m, Vector3(-0.38, 1.2, 0), Vector3(0, 0, -8)))
	# Neck, head, hair
	root.add_child(mesh_node(cylinder(0.07, 0.08, 0.14), skin_m, Vector3(0, 1.66, 0)))
	root.add_child(mesh_node(sphere(0.17), skin_m, Vector3(0, 1.82, 0)))
	root.add_child(mesh_node(sphere(0.18), hair_m, Vector3(0, 1.88, 0.04), Vector3.ZERO, Vector3(1.0, 0.7, 1.05)))

	# Right arm + sword on a pivot at the shoulder
	var pivot := Node3D.new()
	pivot.name = "SwordPivot"
	pivot.position = Vector3(0.38, 1.25, 0)
	pivot.rotation_degrees = Vector3(-30, 20, 0)
	root.add_child(pivot)
	pivot.add_child(mesh_node(capsule(0.08, 0.6), cloth_m, Vector3(0, -0.12, -0.12), Vector3(-60, 0, 0)))
	var steel := mat(Color(0.8, 0.8, 0.82), 0.25, 0.9)
	pivot.add_child(mesh_node(box(Vector3(0.05, 0.05, 0.24)), dark_m, Vector3(0, -0.2, -0.36)))
	pivot.add_child(mesh_node(box(Vector3(0.3, 0.04, 0.05)), armor_m, Vector3(0, -0.2, -0.49)))
	pivot.add_child(mesh_node(box(Vector3(0.07, 0.02, 1.0)), steel, Vector3(0, -0.2, -1.0)))

	var chest := Node3D.new()
	chest.name = "Chest"
	chest.position = Vector3(0, 1.38, -0.27)
	root.add_child(chest)
	return root
