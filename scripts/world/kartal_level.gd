extends Node3D
## Kartal Yamacı (STORY_SLICE §S8): Eşref's stone hut on a windy mountain slope, with a
## COLD stone hearth outside and the red headscarf (the sirin_yazmasi pickup) on its stones.
## A separate small scene reached by a trail from the valley (scenes/kartal_yamaci.tscn,
## scripts/kartal_mode.gd); integrated into the terrain later (BACKLOG). PLACEHOLDER
## blockout: a heightfield slope, stone boxes, foliage from assets/foliage.
## Layout: the trail comes up from the south (+Z, the sign at trail_pos); the slope rises to
## the north; the hut stands on a levelled terrace, its door facing the hearth and the trail.

const DayNight := preload("res://scripts/world/day_night.gd")
const Effects := preload("res://scripts/world/effects.gd")
const ItemPickup := preload("res://scripts/world/item_pickup.gd")

const SIZE := 96                 # the slope's grid: SIZE × SIZE metres, 1 m cells
const RISE := 0.3                # metres of height per metre north
const TERRACE := Vector3(0, 0, -10)
const TERRACE_R := 10.0
const YAZMA_KEY := "kartal_yamaci/yazma"
const GRASS := Color(0.62, 0.62, 0.6)   # cold, ash-dusted grass
const PATH := Color(0.5, 0.4, 0.32)     # bare trodden earth

var player_spawn := Vector3.ZERO
var braziers: Array = []         # a cold hearth: nothing to heal at here
var day_night
var trail_pos := Vector3.ZERO    # the sign where the trail leads back down to the valley
var hut_door := Vector3.ZERO     # in front of the hut's door (Eşref stands here)
var hut_inside := Vector3.ZERO
var hearth_pos := Vector3.ZERO
var yazma: Node3D                # ItemPickup
var arena_center := Vector3.ZERO # where the shades circle the hut
var _noise := FastNoiseLite.new()
var _stone: StandardMaterial3D
var _cache := {}


func build() -> void:
	_noise.seed = 7
	_noise.frequency = 0.035
	day_night = DayNight.new()
	add_child(day_night)
	day_night.paused = true
	_materials()
	_ground()
	_hut()
	_hearth()
	_trail()
	_dress()
	var ash := Effects.ash_fall(Vector3(30, 8, 30), 160)   # wind-driven ash over the slope
	ash.position = TERRACE + Vector3(0, height_at(TERRACE.x, TERRACE.z) + 8.0, 6)
	add_child(ash)


func apply_quality(high: bool) -> void:
	if day_night:
		day_night.apply_quality(high)


## Ground height: the slope rising north, a shallow trough the trail follows, a little
## noise, and the hut's terrace levelled flat.
func height_at(x: float, z: float) -> float:
	var h := (30.0 - z) * RISE + 0.012 * x * x + _noise.get_noise_2d(x, z) * 1.6
	var d := Vector2(x - TERRACE.x, z - TERRACE.z).length()
	var flat := (30.0 - TERRACE.z) * RISE + 0.3
	var t := smoothstep(TERRACE_R, TERRACE_R * 0.6, d)
	return lerpf(h, flat, t)


func _at(x: float, z: float) -> Vector3:
	return Vector3(x, height_at(x, z), z)


func _materials() -> void:
	_stone = StandardMaterial3D.new()
	_stone.albedo_texture = load("res://assets/village_mk/T_RockTrim_BaseColor.png")
	_stone.albedo_color = Color(0.62, 0.6, 0.58)
	_stone.uv1_triplanar = true
	_stone.uv1_scale = Vector3(0.45, 0.45, 0.45)


func _ground() -> void:
	var n := SIZE + 1
	var half := SIZE * 0.5
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for zi in n:
		for xi in n:
			var x := float(xi) - half
			var z := float(zi) - half
			var h := height_at(x, z)
			heights[zi * n + xi] = h
			st.set_uv(Vector2(x, z) * 0.12)
			st.set_color(GRASS.lerp(PATH, path_amount(x, z)))   # the worn trail, painted into the ground
			st.add_vertex(Vector3(x, h, z))
	for zi in SIZE:
		for xi in SIZE:
			var i := zi * n + xi
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + n)
			st.add_index(i + 1)
			st.add_index(i + n + 1)
			st.add_index(i + n)
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/terrain/grass_albedo_height.png")
	mat.vertex_color_use_as_albedo = true   # GRASS / PATH tints
	mat.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.name = "Slope"
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	shape.map_data = heights
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


## The stone hut: rough walls, a doorway facing south, a flat earth roof on timber.
func _hut() -> void:
	var base := _at(TERRACE.x, TERRACE.z)
	var root := Node3D.new()
	root.name = "Hut"
	root.position = base
	add_child(root)
	var w := 6.0
	var d := 4.6
	var h := 2.6
	var door_x := -1.0
	var door_w := 1.1
	var t := 0.45
	_box(root, Vector3(w, h, t), Vector3(0, h * 0.5, -d * 0.5), _stone)                     # back
	_box(root, Vector3(t, h, d), Vector3(-w * 0.5, h * 0.5, 0), _stone)                     # sides
	_box(root, Vector3(t, h, d), Vector3(w * 0.5, h * 0.5, 0), _stone)
	var left := door_x - door_w * 0.5 + w * 0.5
	var right := w * 0.5 - (door_x + door_w * 0.5)
	_box(root, Vector3(left, h, t), Vector3(-w * 0.5 + left * 0.5, h * 0.5, d * 0.5), _stone)   # front, left of the door
	_box(root, Vector3(right, h, t), Vector3(w * 0.5 - right * 0.5, h * 0.5, d * 0.5), _stone)  # front, right
	_box(root, Vector3(door_w, h - 2.0, t), Vector3(door_x, 2.0 + (h - 2.0) * 0.5, d * 0.5), _stone)  # lintel
	var roof := StandardMaterial3D.new()
	roof.albedo_color = Color(0.3, 0.26, 0.22)
	roof.roughness = 1.0
	_box(root, Vector3(w + 0.6, 0.35, d + 0.6), Vector3(0, h + 0.17, 0), roof)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.025, 0.02)
	_box(root, Vector3(w - 0.9, 0.05, d - 0.9), Vector3(0, 0.02, 0), dark)   # a dark earth floor inside
	hut_door = base + Vector3(door_x + 0.2, 0, d * 0.5 + 1.2)
	hut_inside = base + Vector3(door_x, 0, 0.3)
	arena_center = base + Vector3(1.0, 0, d * 0.5 + 5.0)


## The cold hearth in front of the hut: a ring of stones round old ash — never lit since
## Şirin died — and her red headscarf lying on its stones (taken once: the pickup).
func _hearth() -> void:
	hearth_pos = _at(TERRACE.x + 3.4, TERRACE.z + 5.0)
	var root := Node3D.new()
	root.name = "ColdHearth"
	root.position = hearth_pos
	add_child(root)
	for i in 9:
		var a := TAU * i / 9.0
		var s := 0.28 + 0.06 * sin(i * 2.3)
		_box(root, Vector3(s * 1.4, s, s), Vector3(cos(a) * 0.75, s * 0.5, sin(a) * 0.75), _stone)
	var ash := MeshInstance3D.new()
	ash.name = "OldAsh"
	var q := QuadMesh.new()
	q.size = Vector2(1.3, 1.3)
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(0.22, 0.21, 0.2)
	am.roughness = 1.0
	q.material = am
	ash.mesh = q
	ash.rotation.x = -PI * 0.5
	ash.position.y = 0.03
	root.add_child(ash)
	var log_mat := StandardMaterial3D.new()
	log_mat.albedo_color = Color(0.08, 0.06, 0.05)
	for i in 2:
		var lg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.07
		cyl.bottom_radius = 0.08
		cyl.height = 0.8
		cyl.material = log_mat
		lg.mesh = cyl
		lg.rotation = Vector3(PI * 0.5, 0.6 + i * 1.2, 0)
		lg.position = Vector3(0, 0.1, 0)
		root.add_child(lg)
	yazma = ItemPickup.new()
	yazma.name = "Yazma"
	yazma.setup(YAZMA_KEY, "sirin_yazmasi")
	yazma.position = Vector3(0.72, 0.3, 0.1)   # lying on the stones, not in the ash
	root.add_child(yazma)


## The trail's top end: a post and a board (placeholder sign), where he arrives.
func _trail() -> void:
	trail_pos = _at(1.5, 34.0)
	player_spawn = _at(0.0, 31.0) + Vector3(0, 0.2, 0)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.26, 0.18)
	var root := Node3D.new()
	root.name = "TrailSign"
	root.position = trail_pos
	add_child(root)
	_box(root, Vector3(0.14, 1.7, 0.14), Vector3(0, 0.85, 0), wood)
	_box(root, Vector3(0.9, 0.3, 0.06), Vector3(0.3, 1.45, 0), wood)


## How much of the worn trail is at (x, z): up the trough from the sign to the terrace,
## and the trodden ground before the hut's door. 0..1.
func path_amount(x: float, z: float) -> float:
	var a := 0.0
	if z > TERRACE.z + 3.0 and z < 36.0:
		a = 1.0 - smoothstep(0.7, 1.6, absf(x - trail_x(z)))
	var yard := Vector2(x - TERRACE.x, z - (TERRACE.z + 4.5)).length()
	return maxf(a, (1.0 - smoothstep(2.0, 4.5, yard)) * 0.8)


func trail_x(z: float) -> float:
	return sin(z * 0.12) * 1.2


## Wind-bent pines, dead trees and rocks on the slope (placeholder dressing).
func _dress() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var kinds := ["res://assets/foliage/pine.scn", "res://assets/foliage/fir.scn", "res://assets/foliage/dead.scn",
		"res://assets/foliage/rock.scn", "res://assets/foliage/rock_moss.scn", "res://assets/foliage/rock_small.scn"]
	var placed := 0
	var tries := 0
	while placed < 70 and tries < 600:
		tries += 1
		var x := rng.randf_range(-44.0, 44.0)
		var z := rng.randf_range(-44.0, 44.0)
		if absf(x - trail_x(z)) < 4.0 and z > TERRACE.z:
			continue   # keep the trail clear
		if Vector2(x - TERRACE.x, z - TERRACE.z).length() < TERRACE_R + 2.0:
			continue   # and the terrace
		var path: String = kinds[rng.randi() % kinds.size()]
		var n := _model(path)
		if n == null:
			continue
		n.position = _at(x, z)
		n.rotation.y = rng.randf() * TAU
		var s := rng.randf_range(0.8, 1.3)
		n.scale = Vector3(s, s, s)
		add_child(n)
		placed += 1


func _model(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	if not _cache.has(path):
		_cache[path] = load(path)
	return (_cache[path] as PackedScene).instantiate()


func _box(root: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	root.add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	root.add_child(body)
