extends Node3D
## Character lab: realistic characters with the merged animation library, lit like the
## game. Used to check models, retargeted animations and materials.
## Run: godot --path . res://scenes/char_lab.tscn -- --capture=captures/lab.png --frame=90
## Optional: --demo=<anim1,anim2,...> and CHAR_LAB_TIME=<seconds into the clip>

const LIB := "res://assets/anims/ual_library.res"
const Human := preload("res://scripts/characters/human.gd")
const MODELS := ["res://assets/chars/outfits/Male_Ranger.gltf", "res://assets/chars/outfits/Male_Peasant.gltf",
	"res://assets/chars/outfits/Female_Ranger.gltf", "res://assets/chars/outfits/Female_Peasant.gltf"]

var _frame := 0
var _cam: Camera3D


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.35, 0.38, 0.42)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.62)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.3, 0.28, 0.25)
	floor_mi.material_override = fm
	add_child(floor_mi)
	var lib: AnimationLibrary = load(LIB)
	var anims: PackedStringArray = ["Idle", "Jog_Fwd", "Sword_Regular_A", "Death01"]
	if Settings.demo != "":
		anims = Settings.demo.split(",")
	var specs := [
		{"outfit": "Male_Ranger", "hood": true, "hair": "Hair_SimpleParted", "beard": true, "cloth_hue": [0.18, 0.55, 0.985, 1.05, 0.62]},
		{"outfit": "Male_Peasant", "hair": "Hair_Buzzed", "beard": true, "tint": Color(0.8, 0.7, 0.6)},
		{"outfit": "Female_Ranger", "hood": true},
		{"outfit": "Female_Peasant", "hair": "Hair_Long"},
	]
	# CHAR_LAB_LOOKS=ash,bandit,... builds looks from data/looks.json; CHAR_LAB_OVERLAY=0.6 adds the ember overlay
	var rng := RandomNumberGenerator.new()
	var looks := OS.get_environment("CHAR_LAB_LOOKS")
	if looks != "":
		specs.clear()
		for l in looks.split(","):
			specs.append(Human.spec_from_json({"look": l}, rng))
	for i in 4:
		var c: Node3D = Human.build(specs[i])
		if OS.get_environment("CHAR_LAB_OVERLAY") != "":
			var ov := ShaderMaterial.new()
			ov.shader = preload("res://shaders/ash_overlay.gdshader")
			ov.set_shader_parameter("intensity", float(OS.get_environment("CHAR_LAB_OVERLAY")))
			c.set_overlay(ov)
		c.position = Vector3(-3.0 + i * 2.0, 0, 0)
		c.rotation.y = PI   # face the camera
		add_child(c)
		if OS.get_environment("CHAR_LAB_WEAPON") != "":
			c.attach("res://assets/props_mk/Sword_Bronze.gltf", "handslot.r")
			c.attach("res://assets/props_mk/Shield_Wooden.gltf", "handslot.l", Vector3.ZERO, true)
		var a := anims[i % anims.size()]
		c.play_loop(a)
		c.anim.seek(float(OS.get_environment("CHAR_LAB_TIME")) if OS.get_environment("CHAR_LAB_TIME") != "" else 0.4, true)
		var l := Label3D.new()
		l.text = a
		l.position = Vector3(0, 2.1, 0)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 48
		c.add_child(l)
	_cam = Camera3D.new()
	_cam.position = Vector3(0, 1.4, 6.5)
	_cam.fov = 50
	add_child(_cam)
	_cam.look_at(Vector3(0, 0.95, 0))
	if OS.get_environment("CHAR_LAB_SIDE") != "":
		_cam.position = Vector3(-4.2, 1.3, 4.5)
		_cam.look_at(Vector3(-1.5, 1.0, 0))
	if OS.get_environment("CHAR_LAB_CLOSE") != "":
		_cam.position = Vector3(-3.0 + 2.0 * int(OS.get_environment("CHAR_LAB_CLOSE")), 1.6, 1.2)
		_cam.fov = 35
		_cam.look_at(Vector3(_cam.position.x, 1.55, 0))


func _process(_delta: float) -> void:
	_frame += 1
	if Settings.capture_path != "" and _frame == Settings.capture_frame:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(Settings.capture_path)
		print("CAPTURE saved=", Settings.capture_path)
		get_tree().quit()
