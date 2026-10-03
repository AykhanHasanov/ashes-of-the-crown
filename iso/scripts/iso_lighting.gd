extends Node3D
## The iso world's light: one WorldEnvironment, one sun (the moon at night) and the sky, set
## from iso/data/iso_lighting.json for the time of day and the quality tier.
##
## Day is overcast and cold; night is near-black blue with the fires carrying the picture.
## Glow only catches what is brighter than the threshold — in practice, fire and the light
## under doors — so bloom never washes the grey world.
##
## HIGH: volumetric fog (fires glow inside it), SDFGI bounce, SSAO + SSIL, TAA, four shadow
## cascades. LOW: depth fog, no GI, two cascades, fire shadows on the hearth only. Medium is
## treated as HIGH without GI.

const CFG := "res://iso/data/iso_lighting.json"

var night := false
## The light radius around Aras: placed by the game, set here with the time of day.
var character_light: OmniLight3D
var env: Environment
var sun: DirectionalLight3D
var _cfg: Dictionary
var _sky_mat: ProceduralSkyMaterial
var _world: WorldEnvironment
var _haze: FogVolume          # ground haze, HIGH only (volumetric)
var _haze_mat: FogMaterial


func _ready() -> void:
	_cfg = JSON.parse_string(FileAccess.get_file_as_string(CFG))
	env = Environment.new()
	_sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(0, false)
	env.set_glow_level(2, true)
	env.set_glow_level(3, true)
	env.set_glow_level(4, true)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_sky_affect = 0.6
	env.fog_aerial_perspective = 0.2
	env.fog_height = 1.2              # below this the haze thickens: it lies on the ground
	env.fog_height_density = 0.12
	_world = WorldEnvironment.new()
	_world.environment = env
	add_child(_world)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.light_angular_distance = 1.2     # soft edges on HIGH
	sun.directional_shadow_blend_splits = true
	add_child(sun)
	_haze = FogVolume.new()
	_haze.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	_haze.size = Vector3(160, 4.0, 160)
	_haze.position = Vector3(0, 1.0, 30)
	_haze_mat = FogMaterial.new()
	_haze_mat.height_falloff = 0.9
	_haze_mat.edge_fade = 0.2
	_haze.material = _haze_mat
	add_child(_haze)
	Settings.changed.connect(apply_quality)
	apply_quality()
	set_night(false)


func high() -> bool:
	return Settings.quality != Settings.Quality.LOW


func set_night(on: bool) -> void:
	night = on
	var t: Dictionary = _cfg["night" if on else "day"]
	sun.light_color = _c(t["sun_color"])
	sun.light_energy = float(t["sun_energy"])
	sun.rotation_degrees = Vector3(float(t["sun_pitch"]), float(t["sun_yaw"]), 0)
	_sky_mat.sky_top_color = _c(t["sky_top"])
	_sky_mat.sky_horizon_color = _c(t["sky_horizon"])
	_sky_mat.ground_horizon_color = _c(t["sky_horizon"])
	_sky_mat.ground_bottom_color = _c(t["ground"])
	_sky_mat.sun_angle_max = 0.0
	env.ambient_light_energy = float(t["ambient_energy"])
	env.fog_light_color = _c(t["fog_color"])
	env.fog_density = float(t["fog_density_low"]) * (0.45 if env.volumetric_fog_enabled else 1.0)
	env.volumetric_fog_density = float(t["vol_density"])
	env.volumetric_fog_albedo = _c(t["vol_albedo"])
	env.tonemap_exposure = float(t["exposure"])
	_haze_mat.density = float(t["haze_density"])
	if character_light != null:
		var cl: Dictionary = _cfg["character_light"]["night" if on else "day"]
		character_light.light_energy = float(cl["energy"])
		character_light.omni_range = float(cl["range"])
		character_light.light_color = _c(cl["color"])
	_haze_mat.albedo = _c(t["vol_albedo"])


func apply_quality() -> void:
	var q: Dictionary = _cfg["high" if high() else "low"]
	var best := Settings.quality == Settings.Quality.HIGH
	# SDFGI's probes turn characters chalk-white on Intel's integrated GPUs (a driver issue
	# this project has met before, docs/PERF_PROFILE.md); there it stays off and SSIL carries
	# the bounce. Everywhere else HIGH gets it.
	var intel := RenderingServer.get_video_adapter_vendor().to_lower().contains("intel")
	env.sdfgi_enabled = bool(q["sdfgi"]) and best and not intel
	env.sdfgi_use_occlusion = true
	env.sdfgi_energy = 0.8
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.25
	env.ssao_enabled = bool(q["ssao"])
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.6
	env.ssil_enabled = bool(q["ssil"]) and best
	env.volumetric_fog_enabled = bool(q["volumetric"])
	env.volumetric_fog_anisotropy = 0.45
	env.volumetric_fog_length = 70.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_gi_inject = 0.4
	env.volumetric_fog_ambient_inject = 0.15
	env.glow_hdr_threshold = float(q["glow_threshold"])
	sun.directional_shadow_max_distance = float(q["shadow_distance"])
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if int(q["shadow_splits"]) == 4 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	var vp := get_viewport()
	if vp != null:
		vp.use_taa = bool(q["taa"])
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if bool(q["taa"]) else Viewport.SCREEN_SPACE_AA_FXAA
	set_night(night)


static func _c(a: Array) -> Color:
	return Color(float(a[0]), float(a[1]), float(a[2]))
