extends Node3D
## Birds over the valley: a few flocks wheeling above the land near the camera. Each
## flock is one MultiMesh; wings flap in the vertex shader (per-bird phase and flap
## strength in INSTANCE_CUSTOM), birds bank into the turn and now and then glide.
## Flocks drift about and re-form around the camera; they roost at night.

const FLOCKS := 4
const PER_FLOCK := 12
const SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 albedo : source_color = vec4(0.07, 0.065, 0.06, 1.0);
void vertex() {
	// |x| > body width: wing. Flap = rotate the wing about the body axis.
	float wing = smoothstep(0.03, 0.35, abs(VERTEX.x));
	float flap = sin(TIME * 11.0 + INSTANCE_CUSTOM.x * 6.283) * INSTANCE_CUSTOM.y;
	VERTEX.y += flap * wing * abs(VERTEX.x) * 0.9;
}
void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 0.9;
}
"""

var clock: Node          # DayNight
var height_at: Callable
var _flocks: Array = []  # {mmi, center, radius, height, speed, glide, birds: [[angle, dr, dh, phase]]}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = SHADER
	var mesh := _bird_mesh()
	mesh.surface_set_material(0, mat)
	for f in FLOCKS:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = PER_FLOCK
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.custom_aabb = AABB(Vector3(-80, -30, -80), Vector3(160, 80, 160))
		add_child(mmi)
		var birds := []
		for b in PER_FLOCK:
			birds.append([_rng.randf() * TAU, _rng.randf_range(-4.0, 4.0), _rng.randf_range(-3.0, 3.0), _rng.randf()])
		_flocks.append({"mmi": mmi, "center": Vector3.ZERO, "radius": _rng.randf_range(14, 30), "height": _rng.randf_range(24, 48),
			"speed": _rng.randf_range(0.18, 0.3) * (1 if _rng.randf() < 0.5 else -1), "glide": 0.0, "birds": birds, "placed": false})


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var night: bool = clock != null and clock.is_night()
	for fl in _flocks:
		var mmi: MultiMeshInstance3D = fl["mmi"]
		mmi.visible = not night
		if night:
			continue
		var cp := cam.global_position
		# Keep flocks within sight: a flock that falls far behind re-forms elsewhere
		if not fl["placed"] or Vector2(fl["center"].x - cp.x, fl["center"].z - cp.z).length() > 170.0:
			var a := _rng.randf() * TAU
			fl["center"] = cp + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(40, 120)
			fl["placed"] = true
		# Drift, and switch between flapping and gliding now and then
		fl["center"] += Vector3(sin(Time.get_ticks_msec() * 0.00011 + fl["radius"]), 0, cos(Time.get_ticks_msec() * 0.00009 + fl["height"])) * delta * 2.0
		fl["glide"] = move_toward(fl["glide"], 1.0 if sin(Time.get_ticks_msec() * 0.0004 + fl["radius"]) > 0.6 else 0.0, delta * 0.6)
		var ground: float = height_at.call(fl["center"].x, fl["center"].z) if height_at.is_valid() else 0.0
		var mm := mmi.multimesh
		for i in fl["birds"].size():
			var b: Array = fl["birds"][i]
			b[0] += fl["speed"] * delta * (1.0 + b[1] * 0.02)
			var r: float = fl["radius"] + b[1]
			var ang: float = b[0]
			var pos := Vector3(fl["center"].x + cos(ang) * r, ground + fl["height"] + b[2] + sin(ang * 2.0 + b[3] * 6.0) * 1.5, fl["center"].z + sin(ang) * r)
			var dir := Vector3(-sin(ang), 0, cos(ang)) * signf(fl["speed"])
			var basis := Basis.looking_at(dir, Vector3.UP).rotated(dir, -0.35 * signf(fl["speed"]))
			mm.set_instance_transform(i, Transform3D(basis.scaled(Vector3.ONE * 0.9), pos))
			mm.set_instance_custom_data(i, Color(b[3], lerpf(0.5, 0.05, fl["glide"]), 0, 0))


## A small dark bird: slim body along -Z (the look direction), swept wings.
func _bird_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := [
		# body
		[Vector3(0, 0, -0.22), Vector3(0.035, 0, 0.05), Vector3(-0.035, 0, 0.05)],
		[Vector3(0.035, 0, 0.05), Vector3(0, 0, 0.2), Vector3(-0.035, 0, 0.05)],
		# tail
		[Vector3(0, 0, 0.14), Vector3(0.07, 0, 0.28), Vector3(-0.07, 0, 0.28)],
		# wings
		[Vector3(0.03, 0, -0.07), Vector3(0.42, 0, 0.06), Vector3(0.03, 0, 0.06)],
		[Vector3(-0.03, 0, -0.07), Vector3(-0.03, 0, 0.06), Vector3(-0.42, 0, 0.06)],
	]
	for t in tris:
		for v in t:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()
