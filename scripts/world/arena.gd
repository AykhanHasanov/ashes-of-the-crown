extends "res://scripts/world/kozqala.gd"
## Test arena for the V3 combat core (phase A): a ring of ruined walls around a
## scorched floor, a hearth to rest at (refills flasks and heals), torches, a few
## pillars and low walls to fight around. Reuses Közqala's prop and effect helpers.

const RING := 19.0

var hearth := Vector3(0, 0, -11.0)


func build() -> void:
	_rng.seed = 777
	crater_pos = Vector3(0, 0, -400)
	crack_glow = 0.9
	player_spawn = Vector3(0, 0, 8)
	_make_materials()
	_make_environment()
	_make_ground()
	_make_ring()
	_make_hearth_spot()
	_make_cover()
	_make_skyline()
	_make_atmosphere()
	for i in 12:
		var a := TAU * i / 12.0
		spawn_points.append(Vector3(cos(a), 0, sin(a)) * (RING - 4.0))


func _make_ring() -> void:
	var pieces := 30  # 4 m walls around a 19 m ring leave no gaps
	for i in pieces:
		var a := TAU * i / pieces
		var p := Vector3(cos(a), 0, sin(a)) * RING
		var rot := rad_to_deg(-a) + 90.0
		# Keep the camera side (south) low so it never hides the fight
		var south := p.z > RING * 0.35
		if south:
			_prop("dungeon/barrier_column.glb", p, rot)
		else:
			_prop("dungeon/" + _pick(["wall.glb", "wall_cracked.glb", "wall_arched.glb", "wall_broken.glb"]), p, rot)
			if _rng.randf() < 0.4:
				_prop("dungeon/wall_broken.glb", p + Vector3(0, 4, 0), rot, 1.0, false)
	for i in 6:
		var a := TAU * i / 6.0 + 0.26
		var p := Vector3(cos(a), 0, sin(a)) * (RING - 1.2)
		_fire(p + Vector3(0, 0.1, 0), 0.8, 24)
		_fire_light(p + Vector3(0, 1.2, 0), 1.3, 7.0)


func _make_hearth_spot() -> void:
	braziers.append(hearth)
	var coal := Visuals.glow_mat(Color(1.0, 0.35, 0.08), 4.0)
	_cylinder_body(hearth, 0.5, 0.9, _metal)
	add_child(Visuals.mesh_node(Visuals.cylinder(0.8, 0.5, 0.35), _metal, hearth + Vector3(0, 1.07, 0)))
	add_child(Visuals.mesh_node(Visuals.cylinder(0.65, 0.65, 0.04), coal, hearth + Vector3(0, 1.22, 0)))
	_fire(hearth + Vector3(0, 1.3, 0), 1.5, 44)
	crater_light = _fire_light(hearth + Vector3(0, 2.2, 0), 2.8, 12.0)


## Pillars and low walls to use as cover and to test the camera against.
func _make_cover() -> void:
	for p in [Vector3(-7, 0, -2), Vector3(7, 0, -3), Vector3(-9, 0, 7), Vector3(10, 0, 8)]:
		_prop("dungeon/pillar.glb", p, _rng.randf_range(0, 90))
	_prop("dungeon/barrier_column.glb", Vector3(0, 0, 1), 0.0)
	_prop("dungeon/rubble_half.glb", Vector3(-13, 0, -8), 30.0)
	_prop("dungeon/crates_stacked.glb", Vector3(13, 0, -7), -20.0, 1.0, true, WOOD_TINT)
	for i in 10:
		var p := Vector3(_rng.randf_range(-15, 15), 0.12, _rng.randf_range(-15, 15))
		if p.distance_to(player_spawn) < 5.0:
			p.x += 8.0 * signf(p.x + 0.01)  # keep the spawn view clear
		_prop("halloween/" + _pick(["bone_A.gltf", "bone_B.gltf", "skull.gltf"]), p, _rng.randf_range(0, 360), 0.8, false, BONE_TINT)
