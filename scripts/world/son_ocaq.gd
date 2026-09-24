extends "res://scripts/world/kozqala.gd"
## Son Ocaq — the ruined caravanserai where the survivors gathered. An arcaded
## yard (two storeys of arches to the north and west, low parapets to the south
## and east for the camera) around one great fire: the last hearth. Each survivor
## has a small station of their own belongings around the yard.
##
## Reuses Közqala's prop, material, lighting and effect helpers.

const YARD := 17.0

var hearth := Vector3.ZERO
var gate_inside := Vector3(0, 0, YARD - 1.5)
var gate_outside := Vector3(0, 0, YARD + 7.0)
var hide_spots: Array[Vector3] = [
	Vector3(-14.5, 0, -14.5), Vector3(14.5, 0, -14.5), Vector3(-14.5, 0, -6.0),
	Vector3(-14.5, 0, 9.0), Vector3(14.5, 0, -6.0), Vector3(-10.0, 0, -14.5),
	Vector3(10.0, 0, -14.5), Vector3(14.0, 0, 12.0),
]


func build() -> void:
	_rng.seed = 4242
	crater_pos = Vector3(0, 0, -400)  # no lava heat in the ground shader here
	crack_glow = 0.45  # the fire never reached this yard
	player_spawn = Vector3(0, 0, YARD - 2.5)
	_make_materials()
	_make_environment()
	env.ambient_light_energy = 0.8
	env.fog_light_color = Color(0.2, 0.1, 0.07)
	_make_ground()
	_make_yard()
	_make_hearth()
	_make_stations()
	_make_skyline()
	_make_atmosphere()
	_make_attack_points()


func _make_yard() -> void:
	var lower := ["wall_arched.glb", "wall_arched.glb", "wall_archedwindow_open.glb", "wall_pillar.glb"]
	var upper := ["wall_archedwindow_open.glb", "wall_window_open.glb", "wall_broken.glb", ""]
	var count := int(YARD * 2.0 / 4.0)
	for i in count + 1:
		var t := -YARD + 2.0 + i * 4.0
		if t > YARD:
			break
		_prop("dungeon/" + _pick(lower), Vector3(t, 0, -YARD))
		var up := _pick(upper)
		if up != "":
			_prop("dungeon/" + up, Vector3(t, 4, -YARD), 0.0, 1.0, false)
		_prop("dungeon/" + _pick(lower), Vector3(-YARD, 0, t), 90.0)
		if _rng.randf() < 0.5:
			_prop("dungeon/" + _pick(["wall_archedwindow_open.glb", "wall_broken.glb"]), Vector3(-YARD, 4, t), 90.0, 1.0, false)
		if absf(t) > 3.0:
			_prop("dungeon/barrier_column.glb", Vector3(t, 0, YARD))
		_prop("dungeon/barrier_column.glb", Vector3(YARD, 0, t), 90.0)
	for c in [Vector3(-YARD, 0, -YARD), Vector3(YARD, 0, -YARD)]:
		_prop("dungeon/pillar.glb", c, 0.0, 1.3)
		_prop("dungeon/pillar.glb", c + Vector3(0, 5.2, 0), 0.0, 1.3, false)
	for c in [Vector3(-YARD, 0, YARD), Vector3(YARD, 0, YARD)]:
		_prop("dungeon/pillar.glb", c, 0.0, 0.8)
	# Gate
	_prop("halloween/arch_gate.gltf", Vector3(0, 0, YARD), 0.0, 1.0, false)
	for x in [-3.3, 3.3]:
		_prop("dungeon/pillar_decorated.glb", Vector3(x, 0, YARD), 0.0, 0.9)
	# Torches along the arcades
	for x in [-10.0, 10.0]:
		_prop("dungeon/torch_mounted.glb", Vector3(x, 2.2, -YARD + 0.5), 0.0, 1.0, false, WOOD_TINT)
		_fire(Vector3(x, 2.92, -YARD + 0.92), 0.45, 18)
		_fire_light(Vector3(x, 3.0, -YARD + 1.8), 1.2, 7.0)
	_prop("dungeon/torch_mounted.glb", Vector3(-YARD + 0.5, 2.2, 0), 90.0, 1.0, false, WOOD_TINT)
	_fire(Vector3(-YARD + 0.92, 2.92, 0), 0.45, 18)
	_fire_light(Vector3(-YARD + 1.8, 3.0, 0), 1.2, 7.0)
	# Broken flagstones and a dead tree in the yard
	for i in 10:
		var p := Vector3(_rng.randf_range(-14, 14), 0.0, _rng.randf_range(-14, 14))
		if p.length() < 4.5:
			continue
		_prop("dungeon/" + _pick(["floor_tile_small_broken_A.glb", "floor_tile_small_broken_B.glb"]), p, _rng.randi_range(0, 3) * 90.0, 1.0, false, FLOOR_TINT)
	_prop("halloween/tree_dead_medium.gltf", Vector3(14.0, 0, 14.0), 40.0, 1.2, true, CHAR_TINT)
	_prop("halloween/tree_dead_small.gltf", Vector3(-14.5, 0, 14.0), 0.0, 1.2, true, CHAR_TINT)


## The last hearth: a great fire in a ring of stones. It also heals Ayxan.
func _make_hearth() -> void:
	braziers.append(hearth)
	for i in 12:
		var a := TAU * i / 12.0
		var s := Vector3(_rng.randf_range(0.5, 0.8), _rng.randf_range(0.35, 0.55), _rng.randf_range(0.5, 0.8))
		_block(hearth + Vector3(cos(a) * 1.25, s.y * 0.5, sin(a) * 1.25), s, _stone_dark, Vector3(0, rad_to_deg(-a), 0), false)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.4
	cyl.height = 1.0
	shape.shape = cyl
	body.add_child(shape)
	body.position = hearth + Vector3(0, 0.5, 0)
	add_child(body)
	_obstacles.append([hearth, 2.0])
	var coal := Visuals.glow_mat(Color(1.0, 0.35, 0.08), 4.0)
	add_child(Visuals.mesh_node(Visuals.cylinder(1.0, 1.1, 0.12), coal, hearth + Vector3(0, 0.06, 0)))
	_fire(hearth + Vector3(0, 0.2, 0), 2.6, 70)
	var column := _track_particles(Effects.ember_column(0.9, 60))
	column.position = hearth + Vector3(0, 1.0, 0)
	add_child(column)
	crater_light = _fire_light(hearth + Vector3(0, 2.2, 0), 4.5, 16.0)
	crater_light.light_color = Color(1.0, 0.5, 0.2)
	var crackle := AudioStreamPlayer3D.new()
	crackle.stream = Audio.stream("loop_fire")
	crackle.bus = "SFX"
	crackle.volume_db = -3.0
	crackle.unit_size = 4.0
	crackle.max_distance = 22.0
	crackle.autoplay = true
	crackle.position = hearth + Vector3(0, 1.0, 0)
	add_child(crackle)


## Each survivor's corner of the yard, matching their station in survivors.gd.
func _make_stations() -> void:
	# Sabir: a reading table with candles
	_prop("dungeon/table_medium_broken.glb", Vector3(-9.0, 0, -12.8), 10.0, 1.0, true, WOOD_TINT)
	_prop("dungeon/candle_triple.glb", Vector3(-8.6, 0.95, -12.8), 0.0, 1.0, false)
	_prop("dungeon/trunk_large_A.glb", Vector3(-11.8, 0, -13.2), 20.0, 1.0, true, WOOD_TINT)
	# Elvin: under the royal banner he has claimed
	_prop("dungeon/banner_triple_red.glb", Vector3(-2.5, 0.3, -YARD + 0.14), 0.0, 1.0, false, CLOTH_TINT)
	_prop("dungeon/coin_stack_medium.glb", Vector3(-4.2, 0, -14.0), 30.0, 1.0, false)
	# Əhliman: a shrine of candles by the north-east arcade
	for off in [Vector3(-0.8, 0, -1.6), Vector3(0.7, 0, -1.8), Vector3(0, 0, -2.4), Vector3(1.6, 0, -1.2)]:
		_prop("dungeon/" + _pick(["candle_triple.glb", "candle_melted.glb"]), Vector3(8.5, 0, -11.5) + off, _rng.randf_range(0, 360), 1.0, false)
	_prop("dungeon/banner_thin_red.glb", Vector3(8.5, 0.3, -YARD + 0.14), 0.0, 1.0, false, CLOTH_TINT)
	# Anar: what he saved of his caravan
	_prop("dungeon/crates_stacked.glb", Vector3(14.2, 0, 6.0), -15.0, 1.0, true, WOOD_TINT)
	_prop("dungeon/barrel_large.glb", Vector3(14.5, 0, 1.5), 0.0, 1.0, true, WOOD_TINT)
	_prop("dungeon/box_large.glb", Vector3(13.8, 0, -1.2), 25.0, 1.0, true, WOOD_TINT)
	_prop("dungeon/coin_stack_small.glb", Vector3(12.8, 0, 5.2), 0.0, 1.0, false)
	# İbrahim: a makeshift laboratory
	_prop("dungeon/table_long_broken.glb", Vector3(-14.2, 0, 3.0), 0.0, 1.0, true, WOOD_TINT)
	_prop("dungeon/keg.glb", Vector3(-14.6, 0, -0.8), 90.0, 1.0, true, WOOD_TINT)
	_prop("dungeon/barrel_small.glb", Vector3(-13.8, 0, 6.2), 0.0, 1.0, true, WOOD_TINT)
	# Şahbaz: wounded soldiers' corner by the gate
	_prop("dungeon/sword_shield_broken.glb", Vector3(-8.0, 0, 12.5), 30.0, 1.0, false)
	_prop("dungeon/box_stacked.glb", Vector3(-10.5, 0, 13.5), 10.0, 1.0, true, WOOD_TINT)
	# Rüfət: the gate post
	_prop("dungeon/barrel_small.glb", Vector3(5.5, 0, 14.5), 0.0, 1.0, true, WOOD_TINT)
	# Bones of the caravan's dead
	for i in 6:
		var p := Vector3(_rng.randf_range(-14, 14), 0.12, _rng.randf_range(-14, 14))
		if p.length() > 5.0:
			_prop("halloween/" + _pick(["bone_A.gltf", "bone_B.gltf", "skull.gltf"]), p, _rng.randf_range(0, 360), 0.8, false, BONE_TINT)


## Where shades pour in during the night attack: through the gate and over the parapets.
func _make_attack_points() -> void:
	for x in [-2.0, 0.0, 2.0]:
		spawn_points.append(Vector3(x, 0, YARD - 2.0))
	for z in [-8.0, 0.0, 8.0]:
		spawn_points.append(Vector3(YARD - 2.0, 0, z))
	spawn_points.append(Vector3(-5.0, 0, YARD - 2.0))
