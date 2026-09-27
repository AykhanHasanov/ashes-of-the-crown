extends RefCounted
## Static builders for particle systems and effect meshes: fire, embers, falling ash,
## bursts, smoke and the sword-slash arc. Everything is generated in code.

static var _soft_tex: Texture2D


static func soft_texture() -> Texture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 64
		t.height = 64
		_soft_tex = t
	return _soft_tex


static func particle_material(additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft_texture()
	return m


static func additive_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = color
	return m


static func ramp(stops: Array) -> GradientTexture1D:
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for s in stops:
		offsets.append(s[0])
		colors.append(s[1])
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = colors
	var t := GradientTexture1D.new()
	t.gradient = g
	t.use_hdr = true
	return t


static func curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	for p in points:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t


static func make_particles(amount: int, lifetime: float, pm: ParticleProcessMaterial, size: float, mat: Material, bounds: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(amount, 1)
	p.lifetime = lifetime
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = mat
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-bounds, -bounds * 0.5, -bounds), Vector3(bounds * 2.0, bounds * 2.0, bounds * 2.0))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Flames for braziers, burning debris and tower tops.
static func fire(scale := 1.0, amount := 32) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.18 * scale
	pm.direction = Vector3.UP
	pm.spread = 14.0
	pm.initial_velocity_min = 0.8 * scale
	pm.initial_velocity_max = 1.7 * scale
	pm.gravity = Vector3(0, 1.4 * scale, 0)
	pm.damping_min = 0.4
	pm.damping_max = 0.9
	pm.scale_min = 0.6
	pm.scale_max = 1.1
	pm.scale_curve = curve([Vector2(0, 0.6), Vector2(0.25, 1.0), Vector2(1, 0.0)])
	pm.color_ramp = ramp([
		[0.0, Color(2.6, 1.4, 0.45, 0.9)],
		[0.35, Color(1.8, 0.55, 0.1, 0.75)],
		[0.75, Color(0.6, 0.1, 0.02, 0.35)],
		[1.0, Color(0.1, 0.02, 0.0, 0.0)],
	])
	return make_particles(amount, 0.75, pm, 0.6 * scale, particle_material(true), 3.0 * scale)


## Slow glowing embers drifting over the whole courtyard.
static func ember_field(extents: Vector3, amount: int) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.direction = Vector3.UP
	pm.spread = 40.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0.35, 0.25, 0.15)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 6.0
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.15
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	pm.color_ramp = ramp([
		[0.0, Color(4.0, 1.2, 0.2, 0.0)],
		[0.15, Color(5.0, 1.6, 0.3, 1.0)],
		[0.8, Color(3.0, 0.6, 0.1, 0.8)],
		[1.0, Color(1.0, 0.2, 0.0, 0.0)],
	])
	var p := make_particles(amount, 7.0, pm, 0.09, particle_material(true), maxf(extents.x, extents.z) + 4.0)
	p.preprocess = 7.0
	return p


## Grey ash flakes falling from a burned sky.
static func ash_fall(extents: Vector3, amount: int) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.direction = Vector3.DOWN
	pm.spread = 25.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0.15, -0.35, 0.1)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.8
	pm.turbulence_influence_min = 0.03
	pm.turbulence_influence_max = 0.1
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	pm.color_ramp = ramp([
		[0.0, Color(0.55, 0.52, 0.5, 0.0)],
		[0.1, Color(0.6, 0.57, 0.55, 0.85)],
		[0.9, Color(0.45, 0.43, 0.42, 0.7)],
		[1.0, Color(0.4, 0.4, 0.4, 0.0)],
	])
	var p := make_particles(amount, 12.0, pm, 0.08, particle_material(false), maxf(extents.x, extents.z) + 4.0)
	p.preprocess = 12.0
	return p


## Column of sparks rising from the crater where the crown melted.
static func ember_column(radius: float, amount: int) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radius
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.5
	pm.gravity = Vector3(0.2, 0.6, 0.0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.5
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.2
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	pm.color_ramp = ramp([
		[0.0, Color(6.0, 2.5, 0.6, 1.0)],
		[0.6, Color(3.0, 0.7, 0.1, 0.8)],
		[1.0, Color(0.6, 0.1, 0.0, 0.0)],
	])
	var p := make_particles(amount, 3.5, pm, 0.12, particle_material(true), 10.0)
	p.preprocess = 3.5
	return p


## Dark ash streaming off a shade's body.
static func ash_trail(size: float, amount := 14) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.35 * size
	pm.direction = Vector3.UP
	pm.spread = 30.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3(0, 0.5, 0)
	pm.scale_curve = curve([Vector2(0, 0.4), Vector2(0.3, 1.0), Vector2(1, 0.2)])
	pm.color_ramp = ramp([
		[0.0, Color(0.05, 0.04, 0.04, 0.0)],
		[0.2, Color(0.06, 0.05, 0.05, 0.75)],
		[1.0, Color(0.1, 0.09, 0.09, 0.0)],
	])
	var p := make_particles(amount, 1.4, pm, 0.45 * size, particle_material(false), 3.0)
	return p


## Small sparks leaking from Ayxan's chest ember.
static func ember_trail() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.06
	pm.direction = Vector3.UP
	pm.spread = 35.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0, 0.8, 0)
	pm.color_ramp = ramp([
		[0.0, Color(6.0, 2.5, 0.6, 1.0)],
		[1.0, Color(1.0, 0.2, 0.0, 0.0)],
	])
	return make_particles(10, 0.9, pm, 0.06, particle_material(true), 2.0)


## One-shot radial burst (fire nova, sparks). `flat` keeps it in the ground plane.
static func burst(amount: int, speed: float, lifetime: float, size: float, flat: bool, hot: Color) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.3
	pm.direction = Vector3(1, 0, 0) if flat else Vector3.UP
	pm.spread = 180.0
	pm.flatness = 0.85 if flat else 0.0
	pm.initial_velocity_min = speed * 0.6
	pm.initial_velocity_max = speed
	pm.damping_min = speed * 0.8
	pm.damping_max = speed * 1.2
	pm.gravity = Vector3(0, 1.0 if flat else -6.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	pm.scale_curve = curve([Vector2(0, 1.0), Vector2(1, 0.0)])
	pm.color_ramp = ramp([
		[0.0, hot],
		[0.5, Color(hot.r * 0.5, hot.g * 0.25, hot.b * 0.1, 0.8)],
		[1.0, Color(0.3, 0.05, 0.0, 0.0)],
	])
	var p := make_particles(amount, lifetime, pm, size, particle_material(true), speed + 2.0)
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = false
	return p


## One-shot puff of dark ash (dash, shade death).
static func smoke_burst(amount: int, speed: float, lifetime: float, size: float) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.4
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = speed * 0.4
	pm.initial_velocity_max = speed
	pm.damping_min = speed
	pm.damping_max = speed * 1.5
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_curve = curve([Vector2(0, 0.5), Vector2(0.3, 1.0), Vector2(1, 0.6)])
	pm.color_ramp = ramp([
		[0.0, Color(0.08, 0.07, 0.07, 0.9)],
		[1.0, Color(0.2, 0.19, 0.18, 0.0)],
	])
	var p := make_particles(amount, lifetime, pm, size, particle_material(false), speed + 2.0)
	p.one_shot = true
	p.explosiveness = 0.9
	p.emitting = false
	return p


## Hearth smoke from a chimney: a thin, slow plume that widens and drifts downwind.
static func chimney_smoke() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.15
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0.35, 0.25, 0.12)   # rises, then leans with the valley wind
	pm.damping_min = 0.1
	pm.damping_max = 0.2
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.scale_curve = curve([Vector2(0, 0.25), Vector2(0.4, 0.75), Vector2(1, 1.3)])
	pm.color_ramp = ramp([
		[0.0, Color(0.42, 0.4, 0.38, 0.0)],
		[0.12, Color(0.45, 0.43, 0.41, 0.6)],
		[1.0, Color(0.6, 0.6, 0.6, 0.0)],
	])
	var p := make_particles(22, 7.0, pm, 1.6, particle_material(false), 12.0)
	p.one_shot = false
	p.explosiveness = 0.0
	p.randomness = 0.4
	p.emitting = true
	p.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 14, 12))
	return p


## Flat crescent used for sword slashes. Alpha fades toward both ends and the inner edge.
static func arc_mesh(inner: float, outer: float, angle_deg: float, segments := 18) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := deg_to_rad(angle_deg) * 0.5
	for i in segments:
		var t0 := float(i) / segments
		var t1 := float(i + 1) / segments
		var a0 := -half + 2.0 * half * t0
		var a1 := -half + 2.0 * half * t1
		var f0 := sin(t0 * PI)
		var f1 := sin(t1 * PI)
		var in0 := Vector3(sin(a0) * inner, 0, -cos(a0) * inner)
		var out0 := Vector3(sin(a0) * outer, 0, -cos(a0) * outer)
		var in1 := Vector3(sin(a1) * inner, 0, -cos(a1) * inner)
		var out1 := Vector3(sin(a1) * outer, 0, -cos(a1) * outer)
		st.set_color(Color(1, 1, 1, 0)); st.add_vertex(in0)
		st.set_color(Color(1, 1, 1, f0)); st.add_vertex(out0)
		st.set_color(Color(1, 1, 1, 0)); st.add_vertex(in1)
		st.set_color(Color(1, 1, 1, 0)); st.add_vertex(in1)
		st.set_color(Color(1, 1, 1, f0)); st.add_vertex(out0)
		st.set_color(Color(1, 1, 1, f1)); st.add_vertex(out1)
	return st.commit()
