extends Node3D
## Test yard for the combat and enemy-AI tests (scenes/tests/combat_test.tscn): a flat
## floor inside a 19 m ring of walls, four pillars and a low barrier, laid out like the
## old arena the checks were written against (the protagonist starts at (0, 0, 8); the barrier at
## (0, 0, 1) stays below eye height so sight lines pass over it). Plain primitives only,
## so it builds instantly and runs headless. Provides what chapter_base expects of a level.

const RING := 19.0

var player_spawn := Vector3(0, 0, 8)
var braziers: Array = []            # no hearth healing in the tests
var spawn_points: Array[Vector3] = []


func build() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3, 0.32, 0.36)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.62)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	add_child(sun)
	_box(Vector3(0, -0.5, 0), Vector3(80, 1, 80), Color(0.35, 0.33, 0.3))   # floor
	var pieces := 30
	for i in pieces:
		var a := TAU * i / pieces
		var wall := _box(Vector3(cos(a), 0, sin(a)) * RING + Vector3(0, 1.5, 0), Vector3(4.2, 3.0, 0.8), Color(0.4, 0.38, 0.36))
		wall.rotation.y = -a + PI * 0.5
	for p in [Vector3(-7, 0, -2), Vector3(7, 0, -3), Vector3(-9, 0, 7), Vector3(10, 0, 8)]:
		_box(p + Vector3(0, 1.5, 0), Vector3(1.0, 3.0, 1.0), Color(0.45, 0.43, 0.4))
	_box(Vector3(0, 0.5, 1), Vector3(1.2, 1.0, 1.2), Color(0.45, 0.43, 0.4))   # low barrier
	for i in 12:
		var a := TAU * i / 12.0
		spawn_points.append(Vector3(cos(a), 0, sin(a)) * (RING - 4.0))


func apply_quality(_high: bool) -> void:
	pass


func _box(pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	mi.mesh = mesh
	body.add_child(mi)
	add_child(body)
	return body
