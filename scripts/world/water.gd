extends Node3D
## Water bodies of the open world, built from world/generated/world_meta.json: the
## river as a ribbon that follows its falling water level (UV.y downstream for the
## flow), lakes as discs. `surface_at()` answers "is there water here, and how high"
## for swimming, footsteps and the camera.

const SHADER := preload("res://shaders/water.gdshader")
const NONE := -1000.0

var river_points: Array = []   # Vector3(x, level, z), densified
var river_half := 5.5
var lakes: Array = []          # {center: Vector2, radius, level}
var terrain                    # Terrain3D, for "is the ground below the surface"
var _mats: Array[ShaderMaterial] = []


func build(meta: Dictionary) -> void:
	var rv: Dictionary = meta["river"]
	river_half = float(rv["width"]) * 0.5
	var raw: Array = []
	for p in rv["points"]:
		raw.append(Vector3(p[0], p[1], p[2]))
	river_points = _densify(raw, 4.0)
	add_child(_river_mesh())
	for lk in meta["lakes"]:
		var c := Vector2(lk["center"][0], lk["center"][1])
		lakes.append({"center": c, "radius": float(lk["radius"]) * 1.25 + float(lk["shore"]), "level": float(lk["level"])})
		add_child(_lake_mesh(c, float(lk["radius"]) * 1.18 + 4.0, float(lk["level"])))


## Water surface height at a point, or NONE when dry.
func surface_at(pos: Vector3) -> float:
	var level := NONE
	var p := Vector2(pos.x, pos.z)
	for lk in lakes:
		if p.distance_to(lk["center"]) < lk["radius"]:
			level = lk["level"]
	if level == NONE:
		var best := 1e9
		for i in river_points.size() - 1:
			var a: Vector3 = river_points[i]
			var b: Vector3 = river_points[i + 1]
			var ab := Vector2(b.x - a.x, b.z - a.z)
			var t := clampf((p - Vector2(a.x, a.z)).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
			var d := p.distance_to(Vector2(a.x, a.z) + ab * t)
			if d < best:
				best = d
				if d < river_half + 2.5:
					level = lerpf(a.y, b.y, t)
	if level != NONE and terrain != null:
		var ground: float = terrain.data.get_height(pos)
		if is_nan(ground) or ground > level - 0.05:
			return NONE
	return level


func set_clarity(c: float) -> void:
	for m in _mats:
		m.set_shader_parameter("clarity", c)


func _densify(pts: Array, step: float) -> Array:
	# Catmull-Rom through the control points
	var out: Array = []
	for i in pts.size() - 1:
		var p0: Vector3 = pts[maxi(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[mini(i + 2, pts.size() - 1)]
		var n := maxi(2, int(p1.distance_to(p2) / step))
		for s in n:
			var t := float(s) / n
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[pts.size() - 1])
	return out


func _material(flow: float, depth_scale: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("flow_speed", flow)
	m.set_shader_parameter("depth_scale", depth_scale)
	_mats.append(m)
	return m


func _river_mesh() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := river_half + 3.0   # tucked under the banks
	var along := 0.0
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_v := 0.0
	for i in river_points.size():
		var p: Vector3 = river_points[i]
		var nxt: Vector3 = river_points[mini(i + 1, river_points.size() - 1)]
		var prv: Vector3 = river_points[maxi(i - 1, 0)]
		var dir := Vector3(nxt.x - prv.x, 0, nxt.z - prv.z).normalized()
		var side := Vector3(-dir.z, 0, dir.x)
		var l := p - side * half
		var r := p + side * half
		if i > 0:
			along += river_points[i - 1].distance_to(p)
			var v := along
			for tri in [[prev_l, 0.0, prev_v], [prev_r, 1.0, prev_v], [r, 1.0, v], [prev_l, 0.0, prev_v], [r, 1.0, v], [l, 0.0, v]]:
				st.set_uv(Vector2(tri[1], tri[2]))
				st.set_normal(Vector3.UP)
				st.add_vertex(tri[0])
		prev_l = l
		prev_r = r
		prev_v = along
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _material(0.35, 2.2)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "River"
	return mi


func _lake_mesh(c: Vector2, radius: float, level: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 64
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		for v in [Vector3.ZERO, Vector3(cos(a1), 0, sin(a1)) * radius, Vector3(cos(a0), 0, sin(a0)) * radius]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v.x, v.z) * 0.05)
			st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.position = Vector3(c.x, level, c.y)
	mi.material_override = _material(0.0, 4.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Lake"
	return mi
