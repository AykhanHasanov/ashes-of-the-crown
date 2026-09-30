extends Node3D
## Day/night cycle (spec V3 §6.1): 24 game hours = data/balance/world.json time.day_minutes
## real minutes. Moves one directional light between sun and moon, colours the sky
## shader, ambient light and fog, and exposes `hour`/`is_night()`. Weather multiplies
## the light through `weather_sun` and `weather_cloud`. The look (warm low sun, cool blue
## ambient, soft shadows, AgX, glow, haze and mist, and what each graphics preset turns on:
## SSAO, SSIL, SDFGI, volumetric fog) comes from data/world/lighting.json.

signal hour_changed(hour: int)

const SKY_SHADER := preload("res://shaders/sky.gdshader")
const SSAO_QUALITY := {"very_low": RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, "low": RenderingServer.ENV_SSAO_QUALITY_LOW,
	"medium": RenderingServer.ENV_SSAO_QUALITY_MEDIUM, "high": RenderingServer.ENV_SSAO_QUALITY_HIGH,
	"ultra": RenderingServer.ENV_SSAO_QUALITY_ULTRA}

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
var sky_fill: DirectionalLight3D  # SDFGI only: the cool sky light, from the sky opposite the sun
var sky_top: DirectionalLight3D   # SDFGI only: the cool sky light, from straight above
var camera_fill: OmniLight3D   # night only: a weak cool light at the camera, short range
var sky_mat: ShaderMaterial
var weather_sun := 1.0      # 0..1 from weather
var weather_cloud := 0.2
var _look: Dictionary       # data/world/lighting.json
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
	_look = DataDB.world("lighting")
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
	# A cool blue fill mixed into the sky light: shadows read blue against the warm sun
	var amb: Dictionary = _look["ambient"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = _color(amb["color"])
	env.ambient_light_sky_contribution = float(amb["sky_contribution"])
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	# AgX: filmic highlight roll-off and natural colour (no neon greens or orange skin)
	var tone: Dictionary = _look["tone"]
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = float(tone["exposure"])
	env.tonemap_white = float(tone["white"])
	var haze: Dictionary = _look["haze"]
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_sky_affect = float(haze["sky_affect"])
	env.fog_aerial_perspective = float(haze["aerial_perspective"])
	var glow: Dictionary = _look["glow"]
	env.glow_enabled = true
	env.glow_intensity = float(glow["intensity"])
	env.glow_strength = float(glow["strength"])
	env.glow_bloom = float(glow["bloom"])
	env.glow_hdr_threshold = float(glow["hdr_threshold"])
	var levels: Array = (glow["levels"] as Array).map(func(x): return int(x))
	for i in 7:
		env.set_glow_level(i, 1.0 if levels.has(i + 1) else 0.0)
	env.adjustment_enabled = true
	env.adjustment_saturation = float(tone["saturation"])
	env.adjustment_contrast = float(tone["contrast"])
	var ao: Dictionary = _look["ssao"]
	env.ssao_radius = float(ao["radius"])
	env.ssao_intensity = float(ao["intensity"])
	env.ssao_power = float(ao["power"])
	env.ssao_light_affect = float(ao["light_affect"])
	var il: Dictionary = _look["ssil"]
	env.ssil_radius = float(il["radius"])
	env.ssil_intensity = float(il["intensity"])
	var gi: Dictionary = _look["sdfgi"]
	env.sdfgi_use_occlusion = false   # occlusion blackened thick-walled buildings here
	env.sdfgi_cascades = int(gi["cascades"])
	env.sdfgi_min_cell_size = float(gi["min_cell_size"])
	env.sdfgi_energy = float(gi["energy"])
	env.sdfgi_bounce_feedback = float(gi["bounce_feedback"])
	env.sdfgi_read_sky_light = bool(gi["read_sky_light"])
	var vf: Dictionary = _look["volumetric"]
	env.volumetric_fog_density = float(vf["density"])
	env.volumetric_fog_albedo = _color(vf["albedo"])
	env.volumetric_fog_anisotropy = float(vf["anisotropy"])
	env.volumetric_fog_ambient_inject = float(vf["ambient_inject"])
	env.volumetric_fog_sky_affect = float(vf["sky_affect"])
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
	light.shadow_blur = float(_look["sun"]["shadow_blur"])   # softer shadow edges
	add_child(light)
	sky_fill = _fill_light("SkyFill")
	sky_top = _fill_light("SkyTop")
	sky_top.rotation_degrees = Vector3(-90, 0, 0)
	# At the camera, reaching only a few metres: the character and the ground before him,
	# never the far walls (a light along the whole view turned pale plaster grey-white)
	camera_fill = OmniLight3D.new()
	camera_fill.name = "CameraFill"
	camera_fill.shadow_enabled = false
	camera_fill.light_specular = 0.0
	camera_fill.light_color = _color(_look["ambient"]["camera_fill"]["color"])
	camera_fill.omni_range = float(_look["ambient"]["camera_fill"]["range"])
	camera_fill.omni_attenuation = 0.8
	add_child(camera_fill)
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
	# a lower sun than a true noon one: longer, warmer light all day
	var sun_dir := Vector3(cos(ang) * 0.85, sin(ang) * float(_look["sun"]["elevation"]), 0.35).normalized()
	var moon_dir := -sun_dir
	moon_dir.y = absf(moon_dir.y) * 0.8 + 0.2
	moon_dir = moon_dir.normalized()
	var use_moon := sun_dir.y < 0.05
	var dir := moon_dir if use_moon else sun_dir
	light.look_at_from_position(Vector3.ZERO, -dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)
	var sun: Dictionary = _look["sun"]
	light.light_color = k[3] if use_moon else (k[3] as Color).lerp(_color(sun["warm_color"]), float(sun["warmth"]) * (1.0 - n))
	# Strong warm sun over a dimmer cool fill: shadows keep their depth (the old flat look)
	light.light_energy = float(k[4]) * (1.0 if use_moon else float(sun["energy_scale"])) * lerpf(1.0, weather_sun, 0.9 if not use_moon else 0.5)
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

	# Ambient: the hour's own level, but never under the play-space floor (min_energy) — a
	# night must stay readable: the unlit side of a character and the ground, not a silhouette.
	# mood_scale still takes it down for a staged scene (the hub's door talk).
	var amb: Dictionary = _look["ambient"]
	var hour_ambient := float(k[5]) * 0.72 * float(amb["energy_scale"]) * lerpf(0.75, 1.0, weather_sun)
	env.ambient_light_energy = maxf(hour_ambient, float(amb["min_energy"])) * mood_scale
	env.ambient_light_sky_contribution = lerpf(float(amb["sky_contribution"]), float(amb["night_sky_contribution"]), n)
	env.ambient_light_color = _color(amb["color"]).lerp(_color(amb["night_color"]), n)
	# ... and what is just in front of the camera gets a little cool light at night
	# (the character is never a black cut-out)
	camera_fill.light_energy = float(amb["camera_fill"]["energy"]) * n * mood_scale
	camera_fill.visible = camera_fill.light_energy > 0.001
	var cam := get_viewport().get_camera_3d()
	if cam != null and camera_fill.visible:
		camera_fill.global_position = cam.global_position + cam.global_basis.y * 0.4
	sky_fill.light_energy = env.ambient_light_energy * float(_look["sdfgi"]["sky_fill"]) * 0.5
	sky_top.light_energy = sky_fill.light_energy
	# from the sky on the far side of the sun: it reaches the faces the sun leaves in shade
	var away := Vector3(sun_dir.x, 0.0, sun_dir.z).normalized() + Vector3(0, -0.9, 0)
	sky_fill.look_at_from_position(Vector3.ZERO, away, Vector3.UP)
	env.background_energy_multiplier = lerpf(0.15, 1.0, mood_scale)
	var fog: Color = k[6]
	env.fog_light_color = fog.lerp(grey, weather_dark * 0.6)
	env.fog_density = float(_look["haze"]["density"]) + weather_fog * 0.012 + n * 0.0015
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


## The graphics preset (Settings.quality: low / medium / high, lighting.json presets).
## `high` is kept for the shared apply_quality(high) call; the preset itself is read here.
func apply_quality(_high: bool) -> void:
	var p: Dictionary = _look["presets"][Settings.quality_id()]
	var high: bool = Settings.is_high()
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if int(p["shadow_splits"]) == 4 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	light.directional_shadow_max_distance = float(p["shadow_distance"])
	light.light_angular_distance = float(_look["sun"]["angular_distance_high"]) if high else 0.0   # contact-hardening soft shadows
	env.ssao_enabled = p["ssao"]
	if p["ssao"]:
		# the engine's defaults except quality and resolution, which the preset picks
		RenderingServer.environment_set_ssao_quality(SSAO_QUALITY.get(String(p.get("ssao_quality", "medium")), RenderingServer.ENV_SSAO_QUALITY_MEDIUM),
			bool(p.get("ssao_half", true)), 0.5, 2, 50.0, 300.0)
	env.ssil_enabled = p["ssil"]
	var gi: bool = Settings.global_illumination   # experimental, its own setting (any preset)
	env.sdfgi_enabled = gi
	env.sdfgi_read_sky_light = bool(_look["sdfgi"]["read_sky_light"])
	sky_fill.visible = gi and float(_look["sdfgi"]["sky_fill"]) > 0.0
	sky_top.visible = sky_fill.visible
	env.glow_enabled = p["glow"]
	env.volumetric_fog_enabled = p["volumetric"]
	if p["volumetric"]:
		var vf: Dictionary = _look["volumetric"]
		env.volumetric_fog_length = float(vf["length_high" if high else "length_medium"])
		env.volumetric_fog_gi_inject = 0.5 if gi else 0.0
		var size: Array = vf["size_high" if high else "size_medium"]
		RenderingServer.environment_set_volumetric_fog_volume_size(int(size[0]), int(size[1]))


func _fill_light(node_name: String) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.name = node_name
	l.shadow_enabled = false
	l.light_specular = 0.0
	l.light_color = _color(_look["ambient"]["color"])
	l.visible = false
	add_child(l)
	return l


static func _color(a: Array) -> Color:
	return Color(float(a[0]), float(a[1]), float(a[2]))
