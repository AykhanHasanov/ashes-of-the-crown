extends Node3D
## A fire in the iso world: the hearth, a brazier, a forge, a lamp. The only warm, strong
## colour on screen, so it is built to carry the picture — a flickering light that casts
## shadows and glows inside the volumetric fog, flames and rising embers, and a melt radius
## the ground shader clears of ash (IsoWorld collects `melt_radius` from every fire).
##
## kind: "hearth" (a stone ring on the ground), "brazier" (an iron bowl on a stand),
## "forge" (a fire in a stone box), "lamp" (a small flame on a wall, no fittings).

const IsoKit := preload("res://iso/scripts/world/iso_kit.gd")
const Effects := preload("res://scripts/world/effects.gd")

var kind := "hearth"
var energy := 3.0
var reach := 9.0
var melt_radius := 2.5
var casts_shadow := true
var lit := true
## By day a fire lights its own surroundings and little else; at night it carries the picture.
var daylight := false

var _light: OmniLight3D
var _flames: GPUParticles3D
var _embers: GPUParticles3D
var _t := 0.0
var _seed := 0.0


func setup(fire_kind: String, light_energy: float, light_reach: float, melt: float, shadow := true) -> Node3D:
	kind = fire_kind
	energy = light_energy
	reach = light_reach
	melt_radius = melt
	casts_shadow = shadow
	return self


func _ready() -> void:
	_seed = randf() * 100.0
	var scale := 1.0
	match kind:
		"hearth":
			for i in 12:
				var a := TAU * i / 12.0
				var s := IsoKit.box(Vector3(0.55, 0.38, 0.42), "stone_dark", Vector3(sin(a) * 1.25, 0.19, cos(a) * 1.25), false)
				s.rotation.y = a
				add_child(s)
			for a in [0.4, 1.9, 3.3]:
				var log := IsoKit.box(Vector3(1.3, 0.16, 0.16), "wood", Vector3(0, 0.12, 0), false)
				log.rotation = Vector3(0, a, 0.12)
				add_child(log)
			scale = 1.25
		"brazier":
			add_child(IsoKit.box(Vector3(0.12, 0.9, 0.12), "iron", Vector3(0, 0.45, 0), false))
			add_child(IsoKit.box(Vector3(0.85, 0.22, 0.85), "iron", Vector3(0, 0.98, 0), false))
			add_child(IsoKit.box(Vector3(0.55, 0.06, 0.55), "iron", Vector3(0, 0.03, 0), false))
			scale = 0.7
		"forge":
			add_child(IsoKit.box(Vector3(1.4, 0.9, 1.0), "stone_dark", Vector3(0, 0.45, 0)))
			scale = 0.6
		"lamp":
			scale = 0.22
	_flames = Effects.hearth_flames(scale, int(36 * scale) + 8)
	_flames.position.y = 1.08 if kind == "brazier" else (0.92 if kind == "forge" else 0.1)
	add_child(_flames)
	_embers = Effects.ember_column(0.35 * scale + 0.1, int(18 * scale) + 4)
	_embers.position = _flames.position
	add_child(_embers)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.52, 0.22)
	_light.omni_range = reach
	_light.omni_attenuation = 1.15
	_light.shadow_enabled = casts_shadow
	_light.shadow_bias = 0.06
	_light.light_volumetric_fog_energy = 2.2     # the fog glows around a fire
	_light.light_size = 0.25                     # soft shadows on HIGH
	_light.position = _flames.position + Vector3(0, 0.6 if kind != "lamp" else 0.1, 0)
	add_child(_light)
	set_lit(lit)


func set_lit(on: bool) -> void:
	lit = on
	if _light == null:
		return
	_light.visible = on
	_flames.emitting = on
	_embers.emitting = on


## Shadows are the expensive part of a fire. LOW keeps them on the hearth only.
func set_shadow(on: bool) -> void:
	if _light != null:
		_light.shadow_enabled = on and casts_shadow


func _process(delta: float) -> void:
	if not lit or _light == null:
		return
	_t += delta
	# two slow sines and a fast one: a fire breathes, it does not strobe
	var f := 0.82 + 0.1 * sin(_t * 2.1 + _seed) + 0.06 * sin(_t * 5.3 + _seed * 1.7) + 0.04 * sin(_t * 13.0 + _seed * 0.3)
	_light.light_energy = energy * f * (0.35 if daylight else 1.0)
