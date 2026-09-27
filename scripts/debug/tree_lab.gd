extends Node3D
## Tree lab: the generated trees (tools/gen_trees.gd) in a row under a sky, for checking
## shapes, cards, lighting and LODs.
## Run: godot --path . res://scenes/tree_lab.tscn -- --capture=captures/trees.png --frame=60
## TREE_LAB_DIST=<metres> moves the camera back (LOD check); TREE_LAB_IDS=oak,fir,...

var _frame := 0


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.46, 0.68)
	sm.sky_horizon_color = Color(0.72, 0.76, 0.8)
	sm.ground_horizon_color = Color(0.5, 0.5, 0.48)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -140, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.3, 0.33, 0.2)
	ground.material_override = gm
	add_child(ground)
	var ids := ["oak", "beech", "maple", "fir", "fir_young", "dead", "burnt"]
	if OS.get_environment("TREE_LAB_IDS") != "":
		ids = Array(OS.get_environment("TREE_LAB_IDS").split(","))
	for i in ids.size():
		var path: String = ids[i] if "/" in ids[i] else "res://assets/foliage/%s.scn" % ids[i]
		var t: Node3D = load(path).instantiate()
		t.position = Vector3((i - (ids.size() - 1) * 0.5) * float(OS.get_environment("TREE_LAB_GAP") if OS.get_environment("TREE_LAB_GAP") != "" else "11"), 0, 0)
		t.rotation.y = float(OS.get_environment("TREE_LAB_ROT")) if OS.get_environment("TREE_LAB_ROT") != "" else 0.0
		add_child(t)
	var cam := Camera3D.new()
	var dist := float(OS.get_environment("TREE_LAB_DIST")) if OS.get_environment("TREE_LAB_DIST") != "" else 45.0
	cam.position = Vector3(0, 4.0, dist)
	cam.fov = 60
	add_child(cam)
	cam.look_at(Vector3(0, 7.0, 0))


func _process(_delta: float) -> void:
	_frame += 1
	if Settings.capture_path != "" and _frame == Settings.capture_frame:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(Settings.capture_path)
		print("CAPTURE saved=", Settings.capture_path)
		get_tree().quit()
