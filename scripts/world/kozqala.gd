extends Node3D
## Közqala — the burned throne courtyard. Built procedurally from primitives,
## shaders and particles so the whole level lives in code.
##
## Layout (north = -Z): the melted throne on a dais at the north wall, the crater
## where the crown melted in front of it, a colonnade down the middle and the
## south gate where Rüfət waits. South and east walls are kept low so they never
## hide the player from the south-east camera.

const Visuals := preload("res://scripts/world/visuals.gd")
const Effects := preload("res://scripts/world/effects.gd")
const GROUND_SHADER := preload("res://shaders/ground.gdshader")
const STONE_SHADER := preload("res://shaders/stone.gdshader")
const LAVA_SHADER := preload("res://shaders/lava.gdshader")

const HALF := 24.0

var player_spawn := Vector3(0, 0, 14)
var rufet_spot := Vector3(3.2, 0, 19.5)
var crater_pos := Vector3(0, 0, -9)
var braziers: Array[Vector3] = []
var spawn_points: Array[Vector3] = []

var env: Environment
var sun: DirectionalLight3D
var crater_light: OmniLight3D

var _rng := RandomNumberGenerator.new()
var _stone: ShaderMaterial
var _stone_dark: ShaderMaterial
var _stone_ember: ShaderMaterial
var _column_mat: ShaderMaterial
var _metal: StandardMaterial3D
var _gold: StandardMaterial3D
var _flicker: Array = []        # [OmniLight3D, base_energy, phase]
var _particles: Array = []      # [GPUParticles3D, base_amount]
var _high_only: Array[Node3D] = []
var _time := 0.0


func build() -> void:
	_rng.seed = 1337
	_make_materials()
	_make_environment()
	_make_ground()
	_make_walls()
	_make_throne()
	_make_crater()
	_make_columns()
	_make_braziers()
	_make_rubble()
	_make_skyline()
	_make_banners()
	_make_atmosphere()
	_make_spawn_points()


func apply_quality(high: bool) -> void:
	env.volumetric_fog_enabled = high
	env.ssao_enabled = high
	env.fog_density = 0.006 if high else 0.011
	crater_light.shadow_enabled = high
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if high else DirectionalLight3D.SHADOW_ORTHOGONAL
	for entry in _particles:
		var p: GPUParticles3D = entry[0]
		p.amount = maxi(4, int(entry[1] * (1.0 if high else 0.45)))
	for n in _high_only:
		n.visible = high


func _process(delta: float) -> void:
	_time += delta
	for f in _flicker:
		var light: OmniLight3D = f[0]
		var ph: float = f[2]
		light.light_energy = f[1] * (0.82 + 0.12 * sin(_time * 9.0 + ph) + 0.08 * sin(_time * 23.0 + ph * 2.3))


# --- Materials & environment -------------------------------------------------

func _make_materials() -> void:
	_stone = Visuals.shader_mat(STONE_SHADER)
	_stone_dark = Visuals.shader_mat(STONE_SHADER)
	_stone_dark.set_shader_parameter("color_a", Color(0.16, 0.14, 0.12))
	_stone_dark.set_shader_parameter("color_b", Color(0.07, 0.06, 0.055))
	_stone_ember = Visuals.shader_mat(STONE_SHADER)
	_stone_ember.set_shader_parameter("ember_amount", 4.0)
	_stone_ember.set_shader_parameter("color_a", Color(0.14, 0.11, 0.09))
	_column_mat = Visuals.shader_mat(STONE_SHADER)
	_column_mat.set_shader_parameter("bricks", false)
	_column_mat.set_shader_parameter("color_a", Color(0.34, 0.29, 0.24))
	_metal = Visuals.mat(Color(0.12, 0.1, 0.09), 0.5, 0.8)
	_gold = Visuals.mat(Color(0.62, 0.44, 0.16), 0.32, 0.95)


func _make_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.028, 0.022)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.38, 0.34)
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(1, 1.0)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(5, 0.6)
	env.fog_enabled = true
	env.fog_light_color = Color(0.26, 0.13, 0.08)
	env.fog_light_energy = 1.0
	env.fog_density = 0.011
	env.fog_height = 0.6
	env.fog_height_density = 0.12
	env.volumetric_fog_density = 0.022
	env.volumetric_fog_albedo = Color(0.62, 0.48, 0.42)
	env.volumetric_fog_emission = Color(0.05, 0.018, 0.006)
	env.volumetric_fog_anisotropy = 0.45
	env.volumetric_fog_length = 60.0
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Cold moonlight against warm fire light is the core palette of the level.
	sun = DirectionalLight3D.new()
	sun.light_color = Color(0.56, 0.64, 0.9)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55.0
	sun.rotation_degrees = Vector3(-58, 28, 0)
	add_child(sun)


# --- Geometry helpers ---------------------------------------------------------

func _block(pos: Vector3, size: Vector3, material: Material, rot_deg := Vector3.ZERO, collide := true) -> Node3D:
	var node: Node3D
	if collide:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		node = body
	else:
		node = Node3D.new()
	node.add_child(Visuals.mesh_node(Visuals.box(size), material))
	node.position = pos
	node.rotation_degrees = rot_deg
	add_child(node)
	return node


func _cylinder_body(pos: Vector3, radius: float, height: float, material: Material) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	body.add_child(shape)
	body.add_child(Visuals.mesh_node(Visuals.cylinder(radius * 0.92, radius, height), material))
	body.position = pos + Vector3(0, height * 0.5, 0)
	add_child(body)


func _track_particles(p: GPUParticles3D) -> GPUParticles3D:
	_particles.append([p, p.amount])
	return p


func _fire_light(pos: Vector3, energy: float, light_range: float, high_only := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.2)
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.4
	l.position = pos
	add_child(l)
	_flicker.append([l, energy, _rng.randf() * TAU])
	if high_only:
		_high_only.append(l)
	return l


# --- Level pieces ------------------------------------------------------------

func _make_ground() -> void:
	var ground_mat := Visuals.shader_mat(GROUND_SHADER)
	ground_mat.set_shader_parameter("crater_pos", crater_pos)
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, 160)
	var mi := Visuals.mesh_node(plane, ground_mat)
	add_child(mi)

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(160, 1, 160)
	shape.shape = box_shape
	shape.position = Vector3(0, -0.5, 0)
	body.add_child(shape)
	add_child(body)

	# Invisible bounds just outside the walls so breaches can be entered but not escaped.
	for b in [[Vector3(0, 2, -HALF - 3), Vector3(70, 4, 1)], [Vector3(0, 2, HALF + 3), Vector3(70, 4, 1)],
			[Vector3(-HALF - 3, 2, 0), Vector3(1, 4, 70)], [Vector3(HALF + 3, 2, 0), Vector3(1, 4, 70)]]:
		var wall := StaticBody3D.new()
		var ws := CollisionShape3D.new()
		var wb := BoxShape3D.new()
		wb.size = b[1]
		ws.shape = wb
		wall.add_child(ws)
		wall.position = b[0]
		add_child(wall)


func _make_walls() -> void:
	var seg := 2.0
	var count := int(HALF * 2.0 / seg)
	for side in 4:
		# 0 = north, 1 = south, 2 = west, 3 = east
		var low := side == 1 or side == 3
		for i in count:
			var t := -HALF + seg * (i + 0.5)
			var along_x := side < 2
			var pos: Vector3
			if along_x:
				pos = Vector3(t, 0, -HALF if side == 0 else HALF)
			else:
				pos = Vector3(-HALF if side == 2 else HALF, 0, t)
			if side == 1 and absf(t) < 3.5:
				continue  # south gate
			var size_xz := Vector3(seg + 0.05, 1, 1.4) if along_x else Vector3(1.4, 1, seg + 0.05)
			if _rng.randf() < 0.1:
				# Breach: a low heap of broken stone
				_block(pos + Vector3(0, 0.4, 0), Vector3(size_xz.x, 0.8, size_xz.z), _stone_dark, Vector3(0, _rng.randf_range(-8, 8), 0))
				continue
			var h := _rng.randf_range(1.2, 2.8) if low else _rng.randf_range(3.5, 8.5)
			var size := Vector3(size_xz.x, h, size_xz.z)
			_block(pos + Vector3(0, h * 0.5, 0), size, _stone if _rng.randf() < 0.7 else _stone_dark)
			if not low and _rng.randf() < 0.35:
				# Jagged broken top
				var chunk := Vector3(size.x * 0.6, _rng.randf_range(0.6, 1.4), size.z * 0.9)
				_block(pos + Vector3(_rng.randf_range(-0.3, 0.3), h + chunk.y * 0.3, 0), chunk, _stone_dark,
					Vector3(_rng.randf_range(-20, 20), 0, _rng.randf_range(-25, 25)), false)
			elif not low and _rng.randf() < 0.3:
				# Surviving crenellation
				_block(pos + Vector3(0, h + 0.4, 0), Vector3(size.x * 0.45, 0.8, size.z), _stone, Vector3.ZERO, false)

	# Gate towers flanking the south entrance (kept moderate for the camera)
	for x in [-4.6, 4.6]:
		_block(Vector3(x, 1.9, HALF), Vector3(2.4, 3.8, 2.4), _stone)
		_block(Vector3(x, 4.0, HALF), Vector3(2.8, 0.4, 2.8), _stone_dark, Vector3.ZERO, false)


func _make_throne() -> void:
	_block(Vector3(0, 0.25, -18.5), Vector3(16, 0.5, 7), _stone)
	_block(Vector3(0, 0.75, -19.6), Vector3(11, 0.5, 5), _stone)
	_block(Vector3(0, 1.25, -20.4), Vector3(7, 0.5, 3.2), _stone_dark)
	# The melted throne: seat, tall back with a sagging, tilted crest
	_block(Vector3(0, 1.9, -20.7), Vector3(2.2, 0.8, 1.6), _gold)
	_block(Vector3(0, 3.6, -21.4), Vector3(2.4, 3.8, 0.5), _gold)
	_block(Vector3(0.3, 5.7, -21.4), Vector3(1.6, 0.9, 0.45), _gold, Vector3(0, 0, -18), false)
	_block(Vector3(-1.4, 2.4, -20.7), Vector3(0.4, 1.4, 1.6), _gold)
	_block(Vector3(1.4, 2.2, -20.7), Vector3(0.4, 1.0, 1.6), _gold, Vector3(0, 0, 12))
	# Great pillars behind the throne
	for x in [-5.0, 5.0]:
		_cylinder_body(Vector3(x, 1.5, -21.5), 0.8, 9.0, _column_mat)
		_block(Vector3(x, 10.7, -21.5), Vector3(2.0, 0.5, 2.0), _stone_dark, Vector3.ZERO, false)
	# Molten gold dripping down the steps
	var drip := Visuals.glow_mat(Color(1.0, 0.55, 0.15), 2.5)
	_block(Vector3(0.2, 1.52, -19.2), Vector3(0.6, 0.05, 2.2), drip, Vector3.ZERO, false)
	_block(Vector3(0.1, 1.02, -17.6), Vector3(0.5, 0.05, 1.4), drip, Vector3.ZERO, false)


func _make_crater() -> void:
	var lava := Visuals.shader_mat(LAVA_SHADER)
	add_child(Visuals.mesh_node(Visuals.cylinder(2.6, 2.6, 0.04, 32), lava, crater_pos + Vector3(0, 0.03, 0)))
	# Obstacle so the pool cannot be walked through
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 2.7
	cyl.height = 1.2
	shape.shape = cyl
	body.add_child(shape)
	body.position = crater_pos + Vector3(0, 0.6, 0)
	add_child(body)
	# Rim of scorched rocks
	for i in 16:
		var a := TAU * i / 16.0 + _rng.randf_range(-0.1, 0.1)
		var r := _rng.randf_range(2.7, 3.3)
		var s := Vector3(_rng.randf_range(0.6, 1.3), _rng.randf_range(0.3, 0.8), _rng.randf_range(0.6, 1.1))
		_block(crater_pos + Vector3(cos(a) * r, s.y * 0.4, sin(a) * r), s, _stone_ember,
			Vector3(_rng.randf_range(-15, 15), rad_to_deg(-a), _rng.randf_range(-15, 15)), false)
	# What remains of the crown: a half-sunk golden ring
	var crown := TorusMesh.new()
	crown.inner_radius = 0.34
	crown.outer_radius = 0.48
	var crown_mat := Visuals.mat(Color(0.8, 0.55, 0.2), 0.25, 1.0)
	crown_mat.emission_enabled = true
	crown_mat.emission = Color(1.0, 0.4, 0.1)
	crown_mat.emission_energy_multiplier = 1.2
	add_child(Visuals.mesh_node(crown, crown_mat, crater_pos + Vector3(0.4, 0.12, 0.2), Vector3(68, 25, 0)))

	crater_light = _fire_light(crater_pos + Vector3(0, 1.6, 0), 5.5, 18.0)
	crater_light.light_color = Color(1.0, 0.42, 0.12)
	var column := _track_particles(Effects.ember_column(2.0, 90))
	column.position = crater_pos + Vector3(0, 0.3, 0)
	add_child(column)


func _make_columns() -> void:
	for z in [15.0, 9.0, 3.0, -3.0]:
		for x in [-7.5, 7.5]:
			var base := Vector3(x, 0, z)
			_block(base + Vector3(0, 0.2, 0), Vector3(1.6, 0.4, 1.6), _stone_dark)
			var roll := _rng.randf()
			if roll < 0.45:
				_cylinder_body(base + Vector3(0, 0.4, 0), 0.6, 7.0, _column_mat)
				_block(base + Vector3(0, 7.6, 0), Vector3(1.7, 0.45, 1.7), _stone, Vector3.ZERO, false)
			elif roll < 0.8:
				var h := _rng.randf_range(1.8, 3.6)
				_cylinder_body(base + Vector3(0, 0.4, 0), 0.6, h, _column_mat)
				_block(base + Vector3(0, h + 0.6, 0), Vector3(1.0, 0.7, 1.0), _column_mat,
					Vector3(_rng.randf_range(-25, 25), _rng.randf_range(0, 90), _rng.randf_range(-25, 25)), false)
			else:
				_cylinder_body(base + Vector3(0, 0.4, 0), 0.6, 0.9, _column_mat)
				# Fallen drum lying across the ground
				var dir := -1.0 if x > 0 else 1.0
				var fallen := Visuals.mesh_node(Visuals.cylinder(0.55, 0.6, 5.5), _column_mat,
					base + Vector3(dir * 3.2, 0.55, _rng.randf_range(-1.0, 1.0)), Vector3(0, _rng.randf_range(-30, 30), 90))
				add_child(fallen)


func _make_braziers() -> void:
	var spots := [Vector3(-4, 0, 10), Vector3(4, 0, 10), Vector3(-10, 0, -12), Vector3(10, 0, -12), Vector3(5.2, 0, 20.6)]
	var coal := Visuals.glow_mat(Color(1.0, 0.35, 0.08), 4.0)
	for p in spots:
		braziers.append(p)
		_cylinder_body(p, 0.35, 0.9, _metal)
		add_child(Visuals.mesh_node(Visuals.cylinder(0.62, 0.34, 0.35), _metal, p + Vector3(0, 1.07, 0)))
		add_child(Visuals.mesh_node(Visuals.cylinder(0.5, 0.5, 0.04), coal, p + Vector3(0, 1.22, 0)))
		var flame := _track_particles(Effects.fire(1.2, 40))
		flame.position = p + Vector3(0, 1.3, 0)
		add_child(flame)
		_fire_light(p + Vector3(0, 2.0, 0), 1.8, 9.0)


func _make_rubble() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = Visuals.box(Vector3.ONE)
	var transforms: Array[Transform3D] = []
	while transforms.size() < 110:
		var pos := Vector3(_rng.randf_range(-HALF + 1.5, HALF - 1.5), 0, _rng.randf_range(-HALF + 1.5, HALF - 1.5))
		if absf(pos.x) < 3.0 and pos.z > -14.0:
			continue  # keep the central path clear
		if pos.distance_to(crater_pos) < 4.0:
			continue
		var s := _rng.randf_range(0.2, 0.9)
		var b := Basis.from_euler(Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf() * TAU, _rng.randf_range(-0.5, 0.5)))
		b = b.scaled(Vector3(s * _rng.randf_range(0.8, 1.6), s * 0.6, s))
		transforms.append(Transform3D(b, pos + Vector3(0, s * 0.2, 0)))
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _stone_dark
	add_child(mmi)

	# Small fires still burning in the debris
	for i in 7:
		var p := Vector3(_rng.randf_range(-20, 20), 0.1, _rng.randf_range(-15, 20))
		if absf(p.x) < 4.0:
			p.x += 8.0 * signf(p.x + 0.01)
		var f := _track_particles(Effects.fire(0.6, 20))
		f.position = p
		add_child(f)
		_fire_light(p + Vector3(0, 0.8, 0), 1.2, 4.5, true)


func _make_skyline() -> void:
	var tower_mat := Visuals.mat(Color(0.05, 0.04, 0.04), 0.95)
	var window_mat := Visuals.glow_mat(Color(1.0, 0.4, 0.1), 3.0)
	for i in 16:
		var a := TAU * i / 16.0 + _rng.randf_range(-0.12, 0.12)
		var r := _rng.randf_range(36.0, 52.0)
		var w := _rng.randf_range(4.0, 8.0)
		var h := _rng.randf_range(10.0, 28.0)
		var pos := Vector3(cos(a) * r, h * 0.5, sin(a) * r)
		var tower := Visuals.mesh_node(Visuals.box(Vector3(w, h, w)), tower_mat, pos, Vector3(0, rad_to_deg(a), _rng.randf_range(-3, 3)))
		add_child(tower)
		for k in _rng.randi_range(1, 4):
			var wp := Vector3(_rng.randf_range(-w * 0.3, w * 0.3), _rng.randf_range(-h * 0.3, h * 0.35), w * 0.5 + 0.02)
			tower.add_child(Visuals.mesh_node(Visuals.box(Vector3(0.6, 1.1, 0.05)), window_mat, wp))
		if _rng.randf() < 0.45:
			var f := _track_particles(Effects.fire(3.0, 36))
			f.position = Vector3(pos.x, h + 0.5, pos.z)
			add_child(f)
	# Collapsed dome of the old palace to the north-west
	var dome := Visuals.mesh_node(Visuals.sphere(9.0), tower_mat, Vector3(-30, -2.5, -42), Vector3(0, 0, 12), Vector3(1, 0.8, 1))
	add_child(dome)


func _make_banners() -> void:
	var cloth := Visuals.mat(Color(0.42, 0.05, 0.04), 0.95)
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var trim := Visuals.mat(Color(0.7, 0.5, 0.18), 0.5, 0.6)
	for x in [-14.0, -6.0, 6.0, 14.0]:
		var h := _rng.randf_range(3.0, 4.2)
		var q := QuadMesh.new()
		q.size = Vector2(1.5, h)
		add_child(Visuals.mesh_node(q, cloth, Vector3(x, 7.6 - h * 0.5, -HALF + 0.74), Vector3(0, 0, _rng.randf_range(-3, 3))))
		add_child(Visuals.mesh_node(Visuals.box(Vector3(1.8, 0.1, 0.1)), trim, Vector3(x, 7.65, -HALF + 0.76)))
	# The great royal banner behind the throne, torn and scorched
	var big := QuadMesh.new()
	big.size = Vector2(3.4, 7.0)
	add_child(Visuals.mesh_node(big, cloth, Vector3(0, 7.2, -HALF + 0.74)))


func _make_atmosphere() -> void:
	var embers := _track_particles(Effects.ember_field(Vector3(HALF + 4, 4, HALF + 4), 420))
	embers.position = Vector3(0, 3.5, 0)
	add_child(embers)
	var ash := _track_particles(Effects.ash_fall(Vector3(HALF + 8, 6, HALF + 8), 520))
	ash.position = Vector3(0, 10, 0)
	add_child(ash)


func _make_spawn_points() -> void:
	var center := Vector3(0, 0, 3)
	for i in 20:
		var a := TAU * i / 20.0
		var r := _rng.randf_range(12.0, 19.0)
		var p := center + Vector3(cos(a) * r, 0, sin(a) * r)
		p.x = clampf(p.x, -HALF + 2.5, HALF - 2.5)
		p.z = clampf(p.z, -13.0, HALF - 3.0)
		if p.distance_to(crater_pos) < 4.5:
			continue
		var blocked := false
		for z in [15.0, 9.0, 3.0, -3.0]:
			for x in [-7.5, 7.5]:
				if p.distance_to(Vector3(x, 0, z)) < 1.8:
					blocked = true
		if not blocked:
			spawn_points.append(p)
