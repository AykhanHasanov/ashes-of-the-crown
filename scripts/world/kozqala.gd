extends Node3D
## Közqala — the burned throne courtyard.
##
## Walls, pillars, banners and debris are KayKit CC0 props (assets/environment),
## scorched by a tint plus a multiplicative soot overlay. The ground, the melted
## throne, the crater, braziers, skyline and all fire/ash effects are built in code.
##
## Layout (north = -Z): the throne dais against the two-tier north wall, the crater
## where the crown melted in front of it, a colonnade down the middle and the south
## gate where Rüfət camps. South and east sides are low parapets so the south-east
## camera never loses the protagonist behind a wall.

const Visuals := preload("res://scripts/world/visuals.gd")
const Effects := preload("res://scripts/world/effects.gd")
const GROUND_SHADER := preload("res://shaders/ground.gdshader")
const STONE_SHADER := preload("res://shaders/stone.gdshader")
const LAVA_SHADER := preload("res://shaders/lava.gdshader")
const SOOT_SHADER := preload("res://shaders/soot.gdshader")
const PROPS := "res://assets/environment/"

const HALF := 24.0
const STONE_TINT := Color(0.78, 0.7, 0.64)
const WOOD_TINT := Color(0.62, 0.52, 0.46)
const CHAR_TINT := Color(0.22, 0.18, 0.16)
const BONE_TINT := Color(0.8, 0.74, 0.68)
const CLOTH_TINT := Color(0.85, 0.62, 0.56)
const FLOOR_TINT := Color(0.36, 0.31, 0.28)

var player_spawn := Vector3(0, 0, 14)
var rufet_spot := Vector3(3.2, 0, 19.5)
var crater_pos := Vector3(0, 0, -9)
var braziers: Array[Vector3] = []
var crack_glow := 1.6
var spawn_points: Array[Vector3] = []

var env: Environment
var sun: DirectionalLight3D
var crater_light: OmniLight3D

var _rng := RandomNumberGenerator.new()
var _stone: ShaderMaterial
var _stone_dark: ShaderMaterial
var _stone_ember: ShaderMaterial
var _metal: StandardMaterial3D
var _gold: StandardMaterial3D
var _soot: ShaderMaterial
var _scenes := {}               # path -> PackedScene
var _bounds := {}               # path -> AABB in the prop's local space
var _tinted := {}               # "material id|tint" -> tinted copy
var _soot_meshes: Array[MeshInstance3D] = []
var _obstacles: Array = []      # [Vector3, radius] used to keep spawns clear
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
	_make_torches()
	_make_debris()
	_make_camp()
	_make_skyline()
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
	_metal = Visuals.mat(Color(0.12, 0.1, 0.09), 0.5, 0.8)
	_gold = Visuals.mat(Color(0.62, 0.44, 0.16), 0.32, 0.95)
	_soot = Visuals.shader_mat(SOOT_SHADER)


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
	env.volumetric_fog_density = 0.011
	env.volumetric_fog_albedo = Color(0.62, 0.48, 0.42)
	env.volumetric_fog_emission = Color(0.07, 0.03, 0.012)
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


# --- Helpers -----------------------------------------------------------------

## Places a prop from assets/environment. `collide` adds a box matching its bounds.
func _prop(file: String, pos: Vector3, rot_y := 0.0, scl := 1.0, collide := true, tint := STONE_TINT) -> Node3D:
	var path := PROPS + file
	if not _scenes.has(path):
		_scenes[path] = load(path)
	var node: Node3D = _scenes[path].instantiate()
	node.position = pos
	node.rotation_degrees.y = rot_y
	node.scale = Vector3.ONE * scl
	add_child(node)
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		_burn(mi, tint)
	if collide:
		var box := _local_bounds(path, node)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = box.size
		shape.shape = box_shape
		shape.position = box.get_center()
		body.add_child(shape)
		node.add_child(body)
		_obstacles.append([Vector3(pos.x, 0, pos.z), maxf(box.size.x, box.size.z) * scl * 0.5])
	return node


func _burn(mi: MeshInstance3D, tint: Color) -> void:
	for s in mi.mesh.get_surface_count():
		var m := mi.get_active_material(s)
		if not (m is StandardMaterial3D):
			continue
		var key := "%d|%s" % [m.get_instance_id(), tint]
		if not _tinted.has(key):
			var copy: StandardMaterial3D = m.duplicate()
			copy.albedo_color = copy.albedo_color * tint
			copy.roughness = maxf(copy.roughness, 0.85)
			_tinted[key] = copy
		mi.set_surface_override_material(s, _tinted[key])
	mi.material_overlay = _soot
	_soot_meshes.append(mi)


func _local_bounds(path: String, node: Node3D) -> AABB:
	if _bounds.has(path):
		return _bounds[path]
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D()
		var n: Node = mi
		while n != node:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b: AABB = xf * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	_bounds[path] = box
	return box


func _pick(options: Array) -> String:
	return options[_rng.randi() % options.size()]


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


func _fire(pos: Vector3, scale: float, amount: int) -> void:
	var f := _track_particles(Effects.fire(scale, amount))
	f.position = pos
	add_child(f)


# --- Level pieces ------------------------------------------------------------

func _make_ground() -> void:
	var ground_mat := Visuals.shader_mat(GROUND_SHADER)
	ground_mat.set_shader_parameter("crater_pos", crater_pos)
	ground_mat.set_shader_parameter("crack_glow", crack_glow)
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, 160)
	add_child(Visuals.mesh_node(plane, ground_mat))

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(160, 1, 160)
	shape.shape = box_shape
	shape.position = Vector3(0, -0.5, 0)
	body.add_child(shape)
	add_child(body)

	# Invisible bounds just outside the walls so the gate can be entered but not escaped.
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
	var lower := ["wall.glb", "wall_cracked.glb", "wall_archedwindow_open.glb", "wall_window_open.glb", "wall_pillar.glb"]
	var upper := ["wall_broken.glb", "wall_cracked.glb", "wall_broken.glb", ""]
	for i in 12:
		var t := -22.0 + i * 4.0
		# North: two tiers; the section behind the throne keeps its pillars
		var royal := absf(t) < 3.0
		_prop("dungeon/" + ("wall_pillar.glb" if royal else _pick(lower)), Vector3(t, 0, -HALF))
		var up := "wall_pillar.glb" if royal else _pick(upper)
		if up != "":
			_prop("dungeon/" + up, Vector3(t, 4, -HALF), 0.0, 1.0, false)
		# West: one tier with a broken second storey here and there, one scaffold
		_prop("dungeon/" + ("wall_scaffold.glb" if i == 7 else _pick(lower)), Vector3(-HALF, 0, t), 90.0)
		if _rng.randf() < 0.35:
			_prop("dungeon/wall_broken.glb", Vector3(-HALF, 4, t), 90.0, 1.0, false)
		# South and east: low parapets so the camera always sees the protagonist
		if absf(t) > 3.0:
			_prop("dungeon/barrier_column.glb", Vector3(t, 0, HALF))
		_prop("dungeon/barrier_column.glb", Vector3(HALF, 0, t), 90.0)

	# Corner towers
	for c in [Vector3(-HALF, 0, -HALF), Vector3(HALF, 0, -HALF)]:
		_prop("dungeon/pillar.glb", c, 0.0, 1.3)
		_prop("dungeon/pillar.glb", c + Vector3(0, 5.2, 0), 0.0, 1.3, false)
	for c in [Vector3(-HALF, 0, HALF), Vector3(HALF, 0, HALF)]:
		_prop("dungeon/pillar.glb", c, 0.0, 0.8)

	# South gate: a ruined arch between two decorated pillars
	_prop("halloween/arch_gate.gltf", Vector3(0, 0, HALF), 0.0, 1.0, false)
	for x in [-3.3, 3.3]:
		_prop("dungeon/pillar_decorated.glb", Vector3(x, 0, HALF), 0.0, 0.9)
	for x in [-5.5, 5.5]:
		_prop("halloween/post_skull.gltf", Vector3(x, 0, HALF + 1.6), 180.0, 1.0, false, BONE_TINT)

	# Royal banners: the triple banner behind the throne, singles along the north wall
	_prop("dungeon/banner_triple_red.glb", Vector3(0, 3.6, -HALF + 0.4), 0.0, 1.0, false, CLOTH_TINT)
	for x in [-18.0, -10.0, 10.0, 18.0]:
		var banner := "banner_red.glb" if absf(x) > 12.0 else "banner_patternA_red.glb"
		_prop("dungeon/" + banner, Vector3(x, 0.3, -HALF + 0.14), 0.0, 1.0, false, CLOTH_TINT)
	_prop("dungeon/banner_thin_red.glb", Vector3(-HALF + 0.14, 0.3, -6), 90.0, 1.0, false, CLOTH_TINT)
	_prop("dungeon/banner_shield_red.glb", Vector3(-HALF + 0.14, 0.3, 10), 90.0, 1.0, false, CLOTH_TINT)


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
	# Great decorated pillars flanking the throne
	for x in [-5.0, 5.0]:
		_prop("dungeon/pillar_decorated.glb", Vector3(x, 1.5, -21.5))
		_prop("dungeon/pillar_decorated.glb", Vector3(x, 5.5, -21.5), 0.0, 1.0, false)
	# Molten gold dripping down the steps
	var drip := Visuals.glow_mat(Color(1.0, 0.55, 0.15), 2.5)
	_block(Vector3(0.2, 1.52, -19.2), Vector3(0.6, 0.05, 2.2), drip, Vector3.ZERO, false)
	_block(Vector3(0.1, 1.02, -17.6), Vector3(0.5, 0.05, 1.4), drip, Vector3.ZERO, false)
	# The spilled royal treasury and melted candles
	_prop("dungeon/coin_stack_small.glb", Vector3(1.9, 1.5, -20.2), 20.0, 1.0, false)
	_prop("dungeon/coin_stack_medium.glb", Vector3(-2.4, 1.0, -19.1), -35.0, 1.0, false)
	_prop("dungeon/coin_stack_large.glb", Vector3(3.8, 0.5, -17.6), 60.0, 1.0, false)
	_prop("dungeon/coin_stack_small.glb", Vector3(-4.2, 0.5, -16.8), 5.0, 1.0, false)
	_prop("dungeon/trunk_large_A.glb", Vector3(-6.2, 0.5, -17.2), 25.0, 1.0, true, WOOD_TINT)
	for x in [-2.9, 2.9]:
		_prop("dungeon/candle_triple.glb", Vector3(x, 1.5, -20.9), _rng.randf_range(0, 360), 1.0, false)
	for x in [-1.3, 1.5]:
		_prop("dungeon/candle_melted.glb", Vector3(x, 1.5, -19.6), 0.0, 1.0, false)


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
	_obstacles.append([crater_pos, 3.3])
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
	# Swords of the fallen guard stuck in the ash around it
	for deg in [205.0, 320.0, 35.0, 110.0]:
		var a := deg_to_rad(deg)
		_prop("dungeon/sword_shield_broken.glb", crater_pos + Vector3(cos(a), 0, sin(a)) * 4.6, _rng.randf_range(0, 360), 1.0, false)

	crater_light = _fire_light(crater_pos + Vector3(0, 1.6, 0), 5.5, 18.0)
	crater_light.light_color = Color(1.0, 0.42, 0.12)
	var column := _track_particles(Effects.ember_column(2.0, 90))
	column.position = crater_pos + Vector3(0, 0.3, 0)
	add_child(column)


func _make_columns() -> void:
	for z in [15.0, 9.0, 3.0, -3.0]:
		for x in [-7.5, 7.5]:
			var base := Vector3(x, 0, z)
			var outward := -1.0 if x < 0 else 1.0
			var roll := _rng.randf()
			if roll < 0.4:
				# Still standing, two storeys high
				_prop("dungeon/pillar.glb", base)
				_prop("dungeon/pillar.glb", base + Vector3(0, 4, 0), 0.0, 1.0, false)
			elif roll < 0.75:
				# Snapped: one storey, the rest lies shattered beside it
				_prop("dungeon/pillar.glb", base, _rng.randf_range(-6, 6))
				_prop("dungeon/floor_tile_large_rocks.glb", base + Vector3(outward * 2.4, 0, _rng.randf_range(-1, 1)), _rng.randf_range(0, 360), 0.7, false, FLOOR_TINT)
			else:
				# A stump and a heap of rubble where the column came down
				_prop("dungeon/column.glb", base, 0.0, 1.5)
				_prop("dungeon/rubble_large.glb", base + Vector3(outward * 3.8, 0, _rng.randf_range(-1, 1)), 90.0 + _rng.randf_range(-20, 20), 0.5)


func _make_braziers() -> void:
	var spots := [Vector3(-4, 0, 10), Vector3(4, 0, 10), Vector3(-10, 0, -12), Vector3(10, 0, -12), Vector3(5.2, 0, 20.6)]
	var coal := Visuals.glow_mat(Color(1.0, 0.35, 0.08), 4.0)
	for p in spots:
		braziers.append(p)
		_cylinder_body(p, 0.35, 0.9, _metal)
		_obstacles.append([p, 1.0])
		add_child(Visuals.mesh_node(Visuals.cylinder(0.62, 0.34, 0.35), _metal, p + Vector3(0, 1.07, 0)))
		add_child(Visuals.mesh_node(Visuals.cylinder(0.5, 0.5, 0.04), coal, p + Vector3(0, 1.22, 0)))
		_fire(p + Vector3(0, 1.3, 0), 1.2, 40)
		_fire_light(p + Vector3(0, 2.0, 0), 1.8, 9.0)
		var crackle := AudioStreamPlayer3D.new()
		crackle.stream = Audio.stream("loop_fire")
		crackle.bus = "SFX"
		crackle.volume_db = -8.0
		crackle.unit_size = 2.5
		crackle.max_distance = 14.0
		crackle.autoplay = true
		crackle.position = p + Vector3(0, 1.2, 0)
		add_child(crackle)


func _make_torches() -> void:
	# [position on the wall face, rotation, has its own light]
	var torches := [
		[Vector3(-8, 2.2, -HALF + 0.5), 0.0, true], [Vector3(8, 2.2, -HALF + 0.5), 0.0, true],
		[Vector3(-14, 2.2, -HALF + 0.5), 0.0, false], [Vector3(14, 2.2, -HALF + 0.5), 0.0, false],
		[Vector3(-HALF + 0.5, 2.2, -12), 90.0, false], [Vector3(-HALF + 0.5, 2.2, 2), 90.0, true],
		[Vector3(-HALF + 0.5, 2.2, 14), 90.0, false],
	]
	for t in torches:
		var pos: Vector3 = t[0]
		var rot: float = t[1]
		_prop("dungeon/torch_mounted.glb", pos, rot, 1.0, false, WOOD_TINT)
		var out := Vector3(0, 0, 0.42) if rot == 0.0 else Vector3(0.42, 0, 0)
		_fire(pos + out + Vector3(0, 0.72, 0), 0.45, 18)
		if t[2]:
			_fire_light(pos + out * 3.0 + Vector3(0, 0.8, 0), 1.3, 7.0)


func _make_debris() -> void:
	# Broken flagstones laid over the courtyard floor
	for i in 12:
		var p := Vector3(_rng.randf_range(-21, 21), 0.0, _rng.randf_range(-14, 21))
		var file := _pick(["floor_tile_small_broken_A.glb", "floor_tile_small_broken_B.glb", "floor_tile_large_rocks.glb"])
		_prop("dungeon/" + file, p, _rng.randi_range(0, 3) * 90.0, 1.0, false, FLOOR_TINT)
	# Bones of those who did not escape the fire
	for i in 16:
		var p := Vector3(_rng.randf_range(-20, 20), 0.12, _rng.randf_range(-14, 21))
		if p.distance_to(crater_pos) < 3.5:
			continue
		var file := _pick(["bone_A.gltf", "bone_B.gltf", "bone_C.gltf", "skull.gltf", "ribcage.gltf", "bone_A.gltf"])
		_prop("halloween/" + file, p, _rng.randf_range(0, 360), 0.8, false, BONE_TINT)
	# Burned trees in the corners
	var trees := [["tree_dead_large.gltf", Vector3(-19.5, 0, -18.5)], ["tree_dead_medium.gltf", Vector3(19.5, 0, -17.5)],
		["tree_dead_large.gltf", Vector3(19, 0, 19)], ["tree_dead_medium.gltf", Vector3(-20, 0, 19.5)],
		["tree_dead_small.gltf", Vector3(-15, 0, -20)], ["tree_dead_small.gltf", Vector3(16, 0, 7)]]
	for t in trees:
		_prop("halloween/" + t[0], t[1], _rng.randf_range(0, 360), 1.2, true, CHAR_TINT)
	# Tables and barrels dragged out of the burning halls
	_prop("dungeon/table_long_broken.glb", Vector3(-17, 0, 6), 70.0, 1.0, true, WOOD_TINT)
	_prop("dungeon/barrel_small.glb", Vector3(-20, 0, -2), 0.0, 1.0, true, WOOD_TINT)
	_prop("dungeon/barrel_small.glb", Vector3(-19.1, 0, -3.3), 40.0, 1.0, true, WOOD_TINT)
	_prop("dungeon/box_stacked.glb", Vector3(-20, 0, 14.5), 15.0, 1.0, true, WOOD_TINT)
	_prop("dungeon/crates_stacked.glb", Vector3(19.5, 0, -6), -20.0, 1.0, true, WOOD_TINT)
	_prop("dungeon/barrel_large.glb", Vector3(20, 0, -10), 0.0, 1.0, true, WOOD_TINT)
	_prop("dungeon/rubble_half.glb", Vector3(17.5, 0, 12), 0.0)
	_prop("dungeon/rubble_half.glb", Vector3(-21.5, 0, -9), 90.0)
	# Small fires still burning in the debris
	for i in 7:
		var p := Vector3(_rng.randf_range(-20, 20), 0.1, _rng.randf_range(-15, 20))
		if absf(p.x) < 4.0:
			p.x += 8.0 * signf(p.x + 0.01)
		_fire(p, 0.6, 20)
		_fire_light(p + Vector3(0, 0.8, 0), 0.6, 4.0, true)


## Rüfət's camp by the south gate: supplies saved from the fire.
func _make_camp() -> void:
	_prop("dungeon/crates_stacked.glb", Vector3(8.8, 0, 21.3), 10.0, 1.0, true, WOOD_TINT)
	_prop("dungeon/barrel_large.glb", Vector3(7.0, 0, 22.4), 0.0, 1.0, true, WOOD_TINT)
	_prop("dungeon/barrel_small.glb", Vector3(7.6, 0, 19.6), 30.0, 1.0, true, WOOD_TINT)
	_prop("dungeon/keg.glb", Vector3(-7.6, 0, 21.8), 90.0, 1.0, true, WOOD_TINT)
	_prop("dungeon/box_large.glb", Vector3(-5.8, 0, 22.3), 15.0, 1.0, true, WOOD_TINT)
	_prop("dungeon/table_medium_broken.glb", Vector3(-9.8, 0, 19.2), 35.0, 1.0, true, WOOD_TINT)


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
			_fire(Vector3(pos.x, h + 0.5, pos.z), 3.0, 36)
	# Collapsed dome of the old palace to the north-west
	add_child(Visuals.mesh_node(Visuals.sphere(9.0), tower_mat, Vector3(-30, -2.5, -42), Vector3(0, 0, 12), Vector3(1, 0.8, 1)))


func _make_atmosphere() -> void:
	var embers := _track_particles(Effects.ember_field(Vector3(HALF + 4, 4, HALF + 4), 420))
	embers.position = Vector3(0, 3.5, 0)
	add_child(embers)
	var ash := _track_particles(Effects.ash_fall(Vector3(HALF + 8, 6, HALF + 8), 520))
	ash.position = Vector3(0, 10, 0)
	add_child(ash)


func _make_spawn_points() -> void:
	var center := Vector3(0, 0, 3)
	for i in 24:
		var a := TAU * i / 24.0
		var r := _rng.randf_range(11.0, 18.0)
		var p := center + Vector3(cos(a) * r, 0, sin(a) * r)
		p.x = clampf(p.x, -HALF + 3.0, HALF - 3.0)
		p.z = clampf(p.z, -13.0, HALF - 3.5)
		var blocked := false
		for o in _obstacles:
			if p.distance_to(o[0]) < o[1] + 0.9:
				blocked = true
				break
		if not blocked:
			spawn_points.append(p)
