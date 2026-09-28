extends Node3D
## Weather (spec V3 §6.1): clear / cloudy / rain / fog, chosen by weight from
## data/balance/world.json and blended over blend_seconds. Feeds DayNight (sun, clouds,
## fog) and runs the rain particles and rain loop around the camera. Forests add fog.

signal changed(state: String)

const NAMES := {"clear": "Açık", "cloudy": "Bulutlu", "rain": "Yağmur", "fog": "Sisli"}

var state := "clear"
var day_night            # scripts/world/day_night.gd
var camera: Camera3D
var forest_fog := 0.0    # 0..1, set by the world from the protagonist's position

var _cfg: Dictionary
var _cur := {"cloud": 0.15, "fog": 0.0, "rain": 0.0, "sun": 1.0}
var _timer := 0.0
var _rain: GPUParticles3D
var _rain_audio: AudioStreamPlayer
var _high := true


func _ready() -> void:
	_cfg = DataDB.balance("world")["weather"]
	_cur = (_cfg["states"]["clear"] as Dictionary).duplicate()
	_timer = _next_change()
	_rain = _make_rain()
	add_child(_rain)
	_rain_audio = AudioStreamPlayer.new()
	_rain_audio.stream = Audio.stream("rain_loop")
	_rain_audio.bus = "SFX"
	_rain_audio.volume_db = -60.0
	add_child(_rain_audio)


func set_state(s: String, instant := false) -> void:
	state = s
	_timer = _next_change()
	if instant:
		_cur = (_cfg["states"][s] as Dictionary).duplicate()
	changed.emit(s)


func label() -> String:
	return NAMES.get(state, state)


func _next_change() -> float:
	var r: Array = _cfg["change_minutes"]
	return randf_range(r[0], r[1]) * 60.0


func _pick() -> String:
	var total := 0.0
	for s in _cfg["states"]:
		total += float(_cfg["states"][s]["weight"])
	var roll := randf() * total
	for s in _cfg["states"]:
		roll -= float(_cfg["states"][s]["weight"])
		if roll <= 0.0:
			return s
	return "clear"


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		set_state(_pick())
	var target: Dictionary = _cfg["states"][state]
	var k := 1.0 - exp(-delta * 3.0 / float(_cfg["blend_seconds"]))
	for key in ["cloud", "fog", "rain", "sun"]:
		_cur[key] = lerpf(_cur[key], float(target[key]), k)
	if day_night:
		day_night.weather_sun = _cur["sun"]
		day_night.weather_cloud = _cur["cloud"]
		day_night.weather_dark = clampf((_cur["cloud"] - 0.5) * 2.0, 0.0, 1.0) * 0.8 + _cur["rain"] * 0.2
		day_night.weather_fog = _cur["fog"] + forest_fog * float(_cfg["forest_fog_bonus"])
	RenderingServer.global_shader_parameter_set("wind_strength", 0.4 + _cur["rain"] * 0.9 + _cur["cloud"] * 0.3)
	# Rain follows the camera
	var rain: float = _cur["rain"]
	_rain.emitting = rain > 0.05
	_rain.amount_ratio = clampf(rain, 0.0, 1.0) * (1.0 if _high else 0.5)
	if camera:
		_rain.global_position = camera.global_position + Vector3(0, 7, 0) - camera.global_basis.z * 4.0
	_rain_audio.volume_db = linear_to_db(maxf(rain, 0.0001)) - 8.0
	if rain > 0.05 and not _rain_audio.playing:
		_rain_audio.play()
	elif rain <= 0.02 and _rain_audio.playing:
		_rain_audio.stop()


func _make_rain() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 2400
	p.lifetime = 0.9
	p.visibility_aabb = AABB(Vector3(-20, -14, -20), Vector3(40, 22, 40))
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(18, 1, 18)
	pm.direction = Vector3(0.08, -1, 0.03)
	pm.spread = 2.0
	pm.initial_velocity_min = 17.0
	pm.initial_velocity_max = 21.0
	pm.gravity = Vector3(0, -4, 0)
	p.process_material = pm
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.018, 0.55)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.75, 0.8, 0.9, 0.32)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mesh.material = mat
	p.draw_pass_1 = mesh
	p.emitting = false
	return p


func apply_quality(high: bool) -> void:
	_high = high
