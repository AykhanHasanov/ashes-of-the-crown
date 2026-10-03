extends RefCounted
## The iso world's whole material set, in one place. Every built surface is the same shader
## (iso/shaders/iso_surface.gdshader) with different numbers: that is what keeps a stone
## wall, a plastered house, a flat earth roof and a carved door looking like one game. The
## palette is desaturated grey-brown on purpose — fire is the only strong colour on screen.
##
## Materials are made once and shared; ask for them by name: IsoPalette.get_mat("stone").

const SURFACE := preload("res://iso/shaders/iso_surface.gdshader")
const RIM := preload("res://iso/shaders/iso_rim.gdshader")

## name → shader parameters. Colours are linear-ish albedo, kept low and grey.
const DEFS := {
	"stone": {"base_color": Color(0.285, 0.275, 0.265), "block_height": 0.42, "block_length": 0.85,
		"color_noise": 0.13, "mortar": 0.07, "ash_amount": 0.7},
	"stone_dark": {"base_color": Color(0.19, 0.185, 0.18), "block_height": 0.5, "block_length": 1.1,
		"color_noise": 0.1, "mortar": 0.06, "ash_amount": 0.75},
	"plaster": {"base_color": Color(0.27, 0.262, 0.248), "color_noise": 0.09, "ash_amount": 0.6,
		"grime": 0.45},
	"roof": {"base_color": Color(0.17, 0.16, 0.15), "color_noise": 0.12, "ash_amount": 0.7,
		"grime": 0.0},
	"wood": {"base_color": Color(0.19, 0.145, 0.11), "plank": 0.17, "color_noise": 0.14,
		"roughness_value": 0.85, "ash_amount": 0.5, "grime": 0.2},
	"wood_carved": {"base_color": Color(0.23, 0.165, 0.115), "plank": 0.12, "color_noise": 0.1,
		"roughness_value": 0.8, "ash_amount": 0.3, "grime": 0.15},
	"rubble": {"base_color": Color(0.24, 0.235, 0.23), "color_noise": 0.2, "ash_amount": 0.85},
}

static var _cache: Dictionary = {}


static func get_mat(name: String) -> Material:
	if _cache.has(name):
		return _cache[name]
	var m: Material
	match name:
		"void":
			# a doorway or a window seen from outside: a hole, not a black paint
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.018, 0.016, 0.02)
			s.roughness = 1.0
			m = s
		"iron":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(0.16, 0.155, 0.16)
			s.metallic = 0.75          # a metal: the material rule keeps it as authored
			s.roughness = 0.5
			m = s
		"ember":
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(1.0, 0.42, 0.12)
			s.emission_enabled = true
			s.emission = Color(1.0, 0.42, 0.12)
			s.emission_energy_multiplier = 6.0
			s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m = s
		"door_light":
			# the strip of warm light under an occupied door at night
			var s := StandardMaterial3D.new()
			s.albedo_color = Color(1.0, 0.62, 0.3)
			s.emission_enabled = true
			s.emission = Color(1.0, 0.58, 0.26)
			s.emission_energy_multiplier = 4.0
			s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m = s
		"rim":
			var r := ShaderMaterial.new()
			r.shader = RIM
			m = r
		_:
			var sm := ShaderMaterial.new()
			sm.shader = SURFACE
			for k in DEFS.get(name, DEFS["stone"]):
				var v = DEFS.get(name, DEFS["stone"])[k]
				sm.set_shader_parameter(k, Vector3(v.r, v.g, v.b) if v is Color else v)
			m = sm
	_cache[name] = m
	return m
