extends Node3D
## PLACEHOLDER level for the test echo: a small training yard remembered in washed-out,
## warm light — a wooden dummy, a weapon stand, barrels and a fence, trees beyond, and
## invisible walls so the scene stays small. Existing assets only. Provides what
## chapter_base expects of a level (build, player_spawn, braziers, apply_quality).

const Effects := preload("res://scripts/world/effects.gd")
const HALF := 11.0

var player_spawn := Vector3(0, 0, 7)
var braziers: Array = []


func build() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.55, 0.46)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.66, 0.55)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.62, 0.5)
	env.fog_density = 0.035
	env.glow_enabled = true
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.45   # a memory, not the present
	env.adjustment_brightness = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -60, 0)
	sun.light_color = Color(1.0, 0.86, 0.66)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)
	# Ground
	var ground := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	cs.shape = box
	cs.position.y = -0.5
	ground.add_child(cs)
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/terrain/dirt_albedo_height.png")
	mat.uv1_scale = Vector3(14, 14, 1)
	plane.material = mat
	mi.mesh = plane
	ground.add_child(mi)
	add_child(ground)
	# Invisible walls: the memory ends at the fence
	for side in 4:
		var wall := StaticBody3D.new()
		var ws := CollisionShape3D.new()
		var wb := BoxShape3D.new()
		wb.size = Vector3(HALF * 2.0 + 2.0, 4.0, 1.0) if side < 2 else Vector3(1.0, 4.0, HALF * 2.0 + 2.0)
		ws.shape = wb
		wall.add_child(ws)
		wall.position = [Vector3(0, 2, -HALF), Vector3(0, 2, HALF), Vector3(-HALF, 2, 0), Vector3(HALF, 2, 0)][side]
		add_child(wall)
	# Fence along the edge, props in the yard, trees beyond
	for i in 11:
		var x := -HALF + 1.0 + i * 2.05
		_prop("res://assets/village_mk/Prop_WoodenFence_Single.gltf", Vector3(x, 0, -HALF), 0.0)
		_prop("res://assets/village_mk/Prop_WoodenFence_Single.gltf", Vector3(-HALF, 0, x), 90.0)
		_prop("res://assets/village_mk/Prop_WoodenFence_Single.gltf", Vector3(HALF, 0, x), 90.0)
	_prop("res://assets/props_mk/Dummy.gltf", Vector3(0, 0, -3), 180.0)
	_prop("res://assets/props_mk/WeaponStand.gltf", Vector3(-6, 0, -8), 30.0)
	_prop("res://assets/props_mk/Barrel.gltf", Vector3(7, 0, -8), 0.0)
	_prop("res://assets/props_mk/Barrel.gltf", Vector3(7.8, 0, -7.2), 40.0)
	_prop("res://assets/props_mk/Crate_Wooden.gltf", Vector3(-7.5, 0, 3), 15.0)
	_prop("res://assets/props_mk/Bench.gltf", Vector3(6, 0, 4), -90.0)
	for p in [Vector3(-15, 0, -14), Vector3(-4, 0, -17), Vector3(9, 0, -16), Vector3(16, 0, -6), Vector3(-17, 0, 2), Vector3(15, 0, 9)]:
		_prop("res://assets/foliage/%s.scn" % ("oak" if int(p.x) % 2 == 0 else "beech"), p, p.z * 20.0)
	var ash := Effects.ember_field(Vector3(12, 3, 12), 30)
	ash.position = Vector3(0, 2.5, 0)
	add_child(ash)


func apply_quality(_high: bool) -> void:
	pass


func _prop(path: String, pos: Vector3, yaw_deg: float) -> void:
	var n: Node3D = load(path).instantiate()
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	add_child(n)
