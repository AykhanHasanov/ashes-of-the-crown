extends Node3D
## Kül əks-sədası: a place where the Night of Ash still smoulders. A pulsing ring
## of embers marks it; touching it (handled by Main) replays one moment of that
## night — the king's last hours.

const Effects := preload("res://scripts/world/effects.gd")

var index := 0
var place := ""
var done := false

var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _light: OmniLight3D
var _sparks: GPUParticles3D
var _beam: MeshInstance3D
var _beam_mat: StandardMaterial3D
var _t := 0.0


func _ready() -> void:
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.1
	torus.outer_radius = 1.25
	torus.rings = 48
	torus.ring_segments = 4
	_ring.mesh = torus
	_ring.scale = Vector3(1, 0.2, 1)
	_ring.position.y = 0.05
	_ring_mat = Effects.additive_material(Color(1.0, 0.5, 0.18, 0.8))
	_ring.material_override = _ring_mat
	add_child(_ring)
	_sparks = Effects.ember_column(0.8, 40)
	_sparks.position.y = 0.2
	add_child(_sparks)
	# A faint column of light so the echo can be found from anywhere in the courtyard
	_beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.05
	cyl.bottom_radius = 0.45
	cyl.height = 12.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	_beam.mesh = cyl
	_beam_mat = Effects.additive_material(Color(1.0, 0.45, 0.15, 0.22))
	_beam.material_override = _beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.position.y = 6.0
	add_child(_beam)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.5, 0.2)
	_light.light_energy = 1.2
	_light.omni_range = 5.0
	_light.position.y = 1.0
	add_child(_light)


func _process(delta: float) -> void:
	_t += delta
	if done:
		return
	var pulse := 0.5 + 0.5 * sin(_t * 2.5)
	_ring_mat.albedo_color.a = 0.45 + 0.45 * pulse
	_ring.scale = Vector3(1.0 + 0.08 * pulse, 0.2, 1.0 + 0.08 * pulse)
	_light.light_energy = 0.8 + 0.8 * pulse
	_beam_mat.albedo_color.a = 0.14 + 0.1 * pulse


## The echo is spent: it gutters out.
func extinguish() -> void:
	done = true
	_sparks.emitting = false
	var tw := create_tween().set_parallel()
	tw.tween_property(_ring_mat, "albedo_color:a", 0.0, 1.5)
	tw.tween_property(_light, "light_energy", 0.0, 1.5)
	tw.tween_property(_beam_mat, "albedo_color:a", 0.0, 1.5)
