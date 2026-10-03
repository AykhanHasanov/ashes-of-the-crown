extends CanvasLayer
## Közkale burning, as the iso camera can show it. A lens that looks down at 40° never sees
## the horizon — at the top of the frame the ground is barely fifty metres away — so the castle
## cannot be a model in the distance. It is what you would see of a great fire just beyond the
## top-left edge of the picture: its light bleeding in from that corner, and dark smoke drifting
## across it. It is drawn on the screen, under the HUD, so Közkale is always in the same
## direction wherever Aras walks — which is the point: it is always there.
##
## `reveal` (0 … 1) brightens it while the camera pulls out outside the gate.

var reveal := 0.0
var night := false
var _glow: TextureRect
var _smoke: GPUParticles2D
var _t := 0.0


func _ready() -> void:
	layer = 1
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.5, 0.2, 1.0))
	g.set_color(1, Color(1.0, 0.4, 0.15, 0.0))
	g.add_point(0.3, Color(1.0, 0.45, 0.17, 0.45))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0.7, 0.7)     # fully gone before the rect's edges: no box
	tex.width = 256
	tex.height = 256
	_glow = TextureRect.new()
	_glow.texture = tex
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	add_child(_glow)
	_smoke = _make_smoke()
	add_child(_smoke)


func _process(delta: float) -> void:
	_t += delta
	var size := get_viewport().get_visible_rect().size
	_glow.size = Vector2(size.x * 0.34, size.y * 0.42)
	_glow.position = Vector2.ZERO
	_smoke.position = Vector2(-size.x * 0.02, size.y * 0.05)
	var pulse := 0.85 + 0.1 * sin(_t * 0.8) + 0.05 * sin(_t * 2.1)
	var base := 0.26 if night else 0.14
	_glow.modulate = Color(1, 1, 1, clampf((base + 0.35 * reveal) * pulse, 0.0, 1.0))


## Dark smoke rolling in from beyond the corner and leaning across it with the wind.
func _make_smoke() -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.amount = 22
	p.lifetime = 11.0
	p.preprocess = 11.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 40.0
	pm.direction = Vector3(1.0, 0.35, 0)
	pm.spread = 14.0
	pm.initial_velocity_min = 22.0
	pm.initial_velocity_max = 38.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 2.2
	pm.scale_max = 3.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 1.7))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var g := Gradient.new()
	g.set_color(0, Color(0.05, 0.045, 0.045, 0.0))
	g.set_color(1, Color(0.06, 0.055, 0.055, 0.0))
	g.add_point(0.2, Color(0.05, 0.045, 0.045, 0.16))
	g.add_point(0.65, Color(0.06, 0.055, 0.055, 0.1))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var sg := Gradient.new()
	sg.set_color(0, Color(1, 1, 1, 1))
	sg.set_color(1, Color(1, 1, 1, 0))
	var st := GradientTexture2D.new()
	st.gradient = sg
	st.fill = GradientTexture2D.FILL_RADIAL
	st.fill_from = Vector2(0.5, 0.5)
	st.fill_to = Vector2(1.0, 0.5)
	st.width = 64
	st.height = 64
	p.texture = st
	return p
