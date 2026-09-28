extends Node3D
## Day/night cycle (spec V3 §6.1): 24 game hours = data/balance/world.json time.day_minutes
## real minutes. Moves one directional light between sun and moon, colours the sky
## shader, ambient light and fog, and exposes `hour`/`is_night()`. Weather multiplies
## the light through `weather_sun` and `weather_cloud`.

signal hour_changed(hour: int)

const SKY_SHADER := preload("res://shaders/sky.gdshader")

# hour → [sky top, horizon, sun colour, sun energy, ambient energy, fog colour]
const KEYS := [
	[0.0,  Color(0.02, 0.03, 0.07), Color(0.06, 0.07, 0.12), Color(0.55, 0.6, 0.85), 0.16, 0.22, Color(0.05, 0.06, 0.1)],
	[4.5,  Color(0.03, 0.04, 0.09), Color(0.1, 0.09, 0.14),  Color(0.55, 0.6, 0.85), 0.14, 0.22, Color(0.08, 0.08, 0.12)],
	[5.8,  Color(0.2, 0.25, 0.42),  Color(0.95, 0.52, 0.32), Color(1.0, 0.55, 0.3),  0.45, 0.4,  Color(0.6, 0.42, 0.34)],
	[7.5,  Color(0.3, 0.48, 0.75),  Color(0.9, 0.78, 0.66),  Color(1.0, 0.85, 0.66), 1.0,  0.75, Color(0.72, 0.7, 0.68)],
	[12.0, Color(0.26, 0.47, 0.8),  Color(0.78, 0.84, 0.9),  Color(1.0, 0.96, 0.88), 1.35, 1.0,  Color(0.72, 0.78, 0.84)],
	[16.5, Color(0.28, 0.46, 0.76), Color(0.86, 0.8, 0.72),  Color(1.0, 0.88, 0.7),  1.15, 0.85, Color(0.75, 0.72, 0.68)],
	[18.8, Color(0.24, 0.26, 0.45), Color(1.0, 0.45, 0.22),  Color(1.0, 0.5, 0.25),  0.55, 0.45, Color(0.62, 0.38, 0.28)],
	[20.2, Color(0.05, 0.06, 0.14), Color(0.22, 0.12, 0.16), Color(0.55, 0.6, 0.85), 0.16, 0.25, Color(0.1, 0.08, 0.12)],
	[24.0, Color(0.02, 0.03, 0.07), Color(0.06, 0.07, 0.12), Color(0.55, 0.6, 0.85), 0.16, 0.22, Color(0.05, 0.06, 0.1)],
]

var hour := 8.5
var paused := false
var env: Environment
var light: DirectionalLight3D
var sky_mat: ShaderMaterial
var weather_sun := 1.0      # 0..1 from weather
var weather_cloud := 0.2
var weather_dark := 0.0
var weather_fog := 0.0      # extra fog density
## Scales sun/moon, sky and ambient light: < 1 darkens the scene (the night door conversation,
## where the only warm light is the strip under the door).
var mood_scale := 1.0

var _cfg: Dictionary
var _last_hour := -1
var _t := 0.0


func _ready() -> void:
	_cfg = DataDB.balance("world")["time"]
	hour = _cfg["start_hour"]
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# AgX: filmic highlight roll-off and natural colour (no neon greens or orange skin)
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_sky_affect = 0.35
	env.fog_aerial_perspective = 0.5
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.95
	env.adjustment_contrast = 1.08
	# Valley mist: fog that pools below the hills (cheap height fog, thick at dawn and dusk)
	env.fog_height = 16.0
	env.fog_height_density = 0.02
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	light = DirectionalLight3D.new()
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 110.0
	light.directional_shadow_blend_splits = true
	light.shadow_bias = 0.04
	add_child(light)
	_apply()


func set_hour(h: float) -> void:
	hour = fposmod(h, 24.0)
	_apply()


func is_night() -> bool:
	return hour < float(_cfg["dawn"]) or hour > float(_cfg["dusk"])


## 0 at noon … 1 at midnight, smooth.
func night_amount() -> float:
	var sun_h := sin((hour - 6.0) / 24.0 * TAU)
	return clampf(1.0 - (sun_h + 0.15) / 0.35, 0.0, 1.0)


func clock_text() -> String:
	return "%02d:%02d" % [int(hour), int(fmod(hour, 1.0) * 60.0)]


func _process(delta: float) -> void:
	_t += delta
	if not paused:
		hour = fposmod(hour + delta * 24.0 / (float(_cfg["day_minutes"]) * 60.0), 24.0)
	_apply()
	if int(hour) != _last_hour:
		_last_hour = int(hour)
		hour_changed.emit(_last_hour)


func _apply() -> void:
	var k := _sample(hour)
	var n := night_amount()
	# Sun travels east → south → west; the moon opposite
	var ang := (hour - 6.0) / 24.0 * TAU
	var sun_dir := Vector3(cos(ang) * 0.85, sin(ang), 0.35).normalized()
	var moon_dir := -sun_dir
	moon_dir.y = absf(moon_dir.y) * 0.8 + 0.2
	moon_dir = moon_dir.normalized()
	var use_moon := sun_dir.y < 0.05
	var dir := moon_dir if use_moon else sun_dir
	light.look_at_from_position(Vector3.ZERO, -dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)
	light.light_color = k[3]
	# Strong sun over a dimmer sky fill: shadows keep their depth (the old flat look)
	light.light_energy = float(k[4]) * (1.0 if use_moon else 1.55) * lerpf(1.0, weather_sun, 0.9 if not use_moon else 0.5)
	light.shadow_opacity = lerpf(1.0, 0.35, 1.0 - weather_sun) * (0.6 if use_moon else 1.0)
	light.light_energy *= mood_scale

	var top: Color = k[1]
	var horizon: Color = k[2]
	var grey := Color(0.42, 0.44, 0.47) * (1.0 - n * 0.85)
	top = top.lerp(grey, weather_dark * 0.75)
	horizon = horizon.lerp(grey * 1.1, weather_dark * 0.7)
	sky_mat.set_shader_parameter("sun_dir", sun_dir)
	sky_mat.set_shader_parameter("moon_dir", moon_dir)
	sky_mat.set_shader_parameter("top_color", top)
	sky_mat.set_shader_parameter("horizon_color", horizon)
	sky_mat.set_shader_parameter("ground_color", horizon.darkened(0.55))
	sky_mat.set_shader_parameter("sun_color", k[3])
	sky_mat.set_shader_parameter("night", n)
	sky_mat.set_shader_parameter("cloud_cover", weather_cloud)
	sky_mat.set_shader_parameter("cloud_darkness", weather_dark)
	sky_mat.set_shader_parameter("ember_pulse", 0.8 + 0.2 * sin(_t * 1.3) + 0.08 * sin(_t * 5.1))

	env.ambient_light_energy = float(k[5]) * 0.72 * lerpf(0.75, 1.0, weather_sun) * mood_scale
	env.background_energy_multiplier = lerpf(0.15, 1.0, mood_scale)
	var fog: Color = k[6]
	env.fog_light_color = fog.lerp(grey, weather_dark * 0.6)
	env.fog_density = 0.0016 + weather_fog * 0.012 + n * 0.0015
	# Mist: heavy around sunrise (5-8), lighter at dusk, a trace at noon
	var dawn := clampf(1.0 - absf(hour - 6.5) / 2.0, 0.0, 1.0)
	var dusk := clampf(1.0 - absf(hour - 19.5) / 2.0, 0.0, 1.0)
	# Lamps in the houses: lit from dusk till the small hours, most of them out by 2 am
	var lamps := clampf((n - 0.15) * 2.5, 0.0, 1.0)
	if hour > 1.5 and hour < 6.0:
		lamps *= 0.25
	RenderingServer.global_shader_parameter_set("window_light", lamps)
	env.fog_height_density = 0.005 + dawn * 0.035 + dusk * 0.012 + n * 0.012 + weather_fog * 0.03


## Interpolates the KEYS table at hour h.
func _sample(h: float) -> Array:
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if h >= a[0] and h <= b[0]:
			var t: float = (h - a[0]) / maxf(b[0] - a[0], 0.001)
			t = t * t * (3.0 - 2.0 * t)
			return [h, a[1].lerp(b[1], t), a[2].lerp(b[2], t), a[3].lerp(b[3], t),
				lerpf(a[4], b[4], t), lerpf(a[5], b[5], t), a[6].lerp(b[6], t)]
	return KEYS[0]


func apply_quality(high: bool) -> void:
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if high else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	light.directional_shadow_max_distance = 140.0 if high else 70.0
	env.ssao_enabled = high
	env.sdfgi_enabled = false
	env.volumetric_fog_enabled = false
