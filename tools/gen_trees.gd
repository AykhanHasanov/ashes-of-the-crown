extends SceneTree
## Dev tool: grows the world's trees procedurally (data/world/trees.json) — the way
## SpeedTree-style game trees are built: a tapered, bark-textured trunk and branch
## tubes, and photographed leaf-cluster cards (tools/make_foliage_cards.py) hung on
## the outer branches. Card normals point out of the crown so the canopy shades as
## one soft volume; inner cards are darkened through vertex colour (occlusion).
## Hand-made LODs: farther levels use fewer, larger cards (extra vertices that only
## the LOD index arrays reference), so the silhouette holds while the cost drops.
## Output: assets/foliage/<id>.scn (instanced by Terrain3D through vegetation.json).
## Usage: godot --headless --path . -s tools/gen_trees.gd [-- id]

const MaterialPolicy := preload("res://scripts/core/material_policy.gd")
const OUT := "res://assets/foliage/"
const CARDS := "res://assets/foliage/cards/%s.png"
const BARK := "res://assets/foliage/bark/%s_%s.jpg"
const LEAF_SHADER := preload("res://shaders/tree_leaves.gdshader")
const BARK_SHADER := preload("res://shaders/tree_bark.gdshader")
## Screen-error keys for the LOD index arrays (≈ metres of error at the selection
## distance); with Godot's 1 px threshold these switch at roughly 45 m and 100 m.
const LOD_KEYS := [0.055, 0.12]

var rng := RandomNumberGenerator.new()
var cfg: Dictionary
# Bark
var b_verts := PackedVector3Array()
var b_norms := PackedVector3Array()
var b_uvs := PackedVector2Array()
var b_cols := PackedColorArray()
var bark_by_lod := [PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
# Leaf cards: each card is 4 vertices; lod tells which level(s) draw it
var l_verts := PackedVector3Array()
var l_norms := PackedVector3Array()
var l_uvs := PackedVector2Array()
var l_cols := PackedColorArray()
var cards_by_lod := [PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
var crown_center := Vector3.ZERO
var crown_radii := Vector3.ONE


func _init() -> void:
	if not _ensure_imports():
		quit()
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/trees.json"))
	var only := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		only = args[0]
	for id in data["trees"]:
		if only != "" and id != only:
			continue
		cfg = data["trees"][id]
		_reset()
		rng.seed = int(cfg.get("seed", 1))
		match cfg["kind"]:
			"broadleaf":
				_broadleaf(true)
			"dead":
				_broadleaf(false)
			"conifer":
				_conifer()
		_save(id, _build_mesh())
	quit()


func _reset() -> void:
	for a in [b_verts, b_norms, b_uvs, b_cols, l_verts, l_norms, l_uvs, l_cols]:
		a.clear()
	bark_by_lod = [PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
	cards_by_lod = [PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]


# --- Broadleaf and dead trees ------------------------------------------------------------------

func _broadleaf(leaves: bool) -> void:
	var h: float = cfg["height"]
	var r0: float = cfg["trunk_radius"]
	var crown_h: float = cfg["crown_height"]
	var crown_r: float = cfg["crown_radius"]
	crown_center = Vector3(0, h - crown_h * 0.5, 0)
	crown_radii = Vector3(crown_r, crown_h * 0.5, crown_r)
	# Trunk: gently bent, flared at the roots, continuing up into the crown
	var bend: float = cfg.get("bend", 0.3)
	var a1 := rng.randf() * TAU
	var trunk: Array[Vector3] = []
	var radii: Array[float] = []
	var top := h * 0.86
	for i in 15:
		var t := i / 14.0
		var off := Vector3(cos(a1), 0, sin(a1)) * bend * (sin(t * 2.6) * 0.8 + t * 0.4) + Vector3(sin(a1 * 3.0 + t * 5.0), 0, cos(a1 * 2.0 + t * 4.0)) * 0.06 * t
		trunk.append(Vector3(off.x, t * top, off.z))
		var flare := 1.0 + 0.55 * exp(-t * top / 0.5)
		radii.append(maxf(r0 * (1.0 - 0.8 * t) * flare, 0.03))
	crown_center.x = trunk[10].x
	crown_center.z = trunk[10].z
	var lite: bool = cfg.get("lite", false)   # bushes: the leaves hide the wood, keep it cheap
	if lite:
		_tube(_every_other(trunk), _every_other(radii), 5, 1.0, r0, [0, 1, 2])
	else:
		_tube(trunk, radii, 12, 2.0, r0, [0, 1])
		_tube(_every_other(trunk), _every_other(radii), 6, 2.0, r0, [2])
	# Primary branches, spread round the trunk by the golden angle
	var n: int = cfg["branches"]
	var start: float = cfg["crown_start"]
	var tips: Array = []   # [points, radii] of every branch that carries leaves
	for i in n:
		var t := lerpf(start, 0.84, float(i) / maxf(n - 1, 1)) + rng.randf_range(-0.04, 0.04)
		var base := _along(trunk, t)
		var az := i * 2.39996 + rng.randf_range(-0.3, 0.3)
		var elev := deg_to_rad(lerpf(22.0, 58.0, t) + rng.randf_range(-8, 8))
		var dir := Vector3(cos(az) * cos(elev), sin(elev), sin(az) * cos(elev))
		var length := _to_crown_edge(base, dir) * rng.randf_range(0.82, 0.98)
		var br := _branch(base, dir, length, _radius_at(radii, t) * 0.55, 0.06, 7)
		if lite:
			_tube(br[0], br[1], 3, 1.0, 0.12, [0, 1])
		else:
			_tube(br[0], br[1], 7, 1.0, 0.12, [0])
			_tube(br[0], br[1], 4, 1.0, 0.12, [1, 2])
		tips.append(br)
		# Secondary shoots
		for k in 3:
			var ts := rng.randf_range(0.3, 0.8)
			var sb := _along(br[0], ts)
			var side := dir.cross(Vector3.UP).normalized() * (1.0 if k % 2 == 0 else -1.0)
			var sdir := (dir * 0.6 + side * 0.7 + Vector3.UP * rng.randf_range(0.1, 0.5)).normalized()
			var sl := length * rng.randf_range(0.32, 0.5) * (1.0 - ts * 0.4)
			var sbr := _branch(sb, sdir, sl, _radius_at(br[1], ts) * 0.55, 0.12, 4)
			if not lite:
				_tube(sbr[0], sbr[1], 5, 1.0, 0.07, [0] if leaves else [0, 1])
			tips.append(sbr)
			if not leaves:
				# Dead trees: one more level of bare twigs for a gnarled silhouette
				for m in 2:
					var tt := rng.randf_range(0.4, 0.9)
					var tb := _along(sbr[0], tt)
					var tdir := (sdir + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(0.0, 0.6), rng.randf_range(-0.8, 0.8))).normalized()
					var tw := _branch(tb, tdir, sl * 0.45, _radius_at(sbr[1], tt) * 0.6, 0.15, 3)
					_tube(tw[0], tw[1], 4, 1.0, 0.04, [0])
	if not leaves:
		return
	# Leaf cards fill the crown's outer shell evenly (the branches underneath carry them;
	# sampling the envelope instead of branch tips avoids clumps and holes)
	var count: int = cfg["cards"]
	var cs: Array = cfg["card_size"]
	var floor_y := h * start + minf(1.2, h * 0.08)
	# Lobes make the crown lumpy and uneven, as real crowns are (no lollipops)
	var lobes: Array[Vector3] = []
	for k in 6:
		var l := _rand_dir()
		l.y = absf(l.y) * 0.8 - 0.1
		lobes.append(l.normalized())
	for c in count:
		var u := _rand_dir()
		var lobe := 0.0
		for l in lobes:
			lobe = maxf(lobe, u.dot(l))
		var shape := 0.7 + 0.4 * pow(maxf(lobe, 0.0), 1.5)
		var p := crown_center + u * crown_radii * shape * sqrt(rng.randf_range(0.3, 1.0))
		p.y = maxf(p.y, floor_y + rng.randf() * 0.8)
		var out := (p - crown_center).normalized()
		var axis := (out * 0.75 + Vector3.UP * 0.35 + _rand_dir() * 0.3).normalized()
		_card(p - axis * 0.4, axis, rng.randf_range(cs[0], cs[1]))
	# A few cards crowning the leader
	for c in 6:
		_card(trunk[14] + _rand_dir() * 0.6, (Vector3.UP + _rand_dir() * 0.5).normalized(), rng.randf_range(cs[0], cs[1]))


## Grows a branch from `base` along `dir`, bending up a little toward the light.
func _branch(base: Vector3, dir: Vector3, length: float, r_base: float, curl: float, steps: int) -> Array:
	var pts: Array[Vector3] = [base]
	var rad: Array[float] = [r_base]
	var d := dir
	var p := base
	for s in steps:
		d = (d + Vector3.UP * curl + _rand_dir() * 0.12).normalized()
		p += d * (length / steps)
		pts.append(p)
		rad.append(maxf(r_base * (1.0 - float(s + 1) / steps) * 0.9, 0.012))
	return [pts, rad]


## Distance from `from` to the crown ellipsoid along `dir`.
func _to_crown_edge(from: Vector3, dir: Vector3) -> float:
	var o := (from - crown_center) / crown_radii
	var d := dir / crown_radii
	var a := d.dot(d)
	var b := 2.0 * o.dot(d)
	var c := o.dot(o) - 1.0
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return crown_radii.x * 0.5
	return maxf((-b + sqrt(disc)) / (2.0 * a), 0.8)


# --- Conifers ------------------------------------------------------------------------------------

func _conifer() -> void:
	var h: float = cfg["height"]
	var r0: float = cfg["trunk_radius"]
	var crown_r: float = cfg["crown_radius"]
	var y0: float = h * float(cfg["crown_start"])
	crown_center = Vector3(0, (y0 + h) * 0.45, 0)
	crown_radii = Vector3(crown_r, (h - y0) * 0.5, crown_r)
	var trunk: Array[Vector3] = []
	var radii: Array[float] = []
	for i in 13:
		var t := i / 12.0
		trunk.append(Vector3(sin(t * 3.0) * 0.05, t * h * 0.99, cos(t * 2.0) * 0.04))
		radii.append(maxf(r0 * pow(1.0 - t, 0.9) * (1.0 + 0.5 * exp(-t * h / 0.5)), 0.015))
	_tube(trunk, radii, 10, 2.0, r0, [0, 1])
	_tube(_every_other(trunk), _every_other(radii), 5, 2.0, r0, [2])
	var gap: float = cfg["whorl_gap"]
	var per: int = cfg["per_whorl"]
	var y := y0
	var whorl := 0
	while y < h * 0.95:
		var u := (y - y0) / (h - y0)
		for b in per:
			var az := (b + whorl * 0.5) * TAU / per + rng.randf_range(-0.25, 0.25)
			var length := crown_r * pow(1.0 - u, 0.95) * rng.randf_range(0.85, 1.1) + 0.3
			var pitch := deg_to_rad(lerpf(-24.0, 12.0, u) + rng.randf_range(-6, 6))
			var dir := Vector3(cos(az) * cos(pitch), sin(pitch), sin(az) * cos(pitch))
			var base := _along(trunk, y / (h * 0.99))
			if length > 1.4:
				var br := _branch(base, dir, length * 0.8, 0.05, -0.02, 3)
				_tube(br[0], br[1], 4, 1.0, 0.05, [0])
			var parts := int(ceil(length / 1.5))
			var seg := length / parts
			for k in parts:
				var p := base + dir * (seg * k)
				var droop := Vector3(0, -0.06 * k * k, 0)
				var roll := rng.randf_range(-0.7, 0.7)
				_branch_card(p + droop, dir, seg * 1.25, roll, 0, u)
				_branch_card(p + droop, dir, seg * 1.1, roll + PI * 0.5, 1, u)   # crossed card: fuller at LOD0 only
			# Distant levels: one long card for the whole branch
			_branch_card(base, dir, length * 1.1, rng.randf_range(-0.4, 0.4), 2, u)
		y += gap * rng.randf_range(0.85, 1.15)
		whorl += 1
	# The leader
	for k in 3:
		var dir := (Vector3.UP * 2.0 + _rand_dir()).normalized()
		_branch_card(trunk[11], dir, 1.3, TAU * k / 3.0, 0, 1.0)
		_branch_card(trunk[11], dir, 1.3, TAU * k / 3.0, 2, 1.0)


## A fir branch card: texture +U runs along the branch, the branch at V = 0.5.
## level 0 = drawn at LOD0 and LOD1, 1 = LOD0 only, 2 = LOD2 only.
func _branch_card(base: Vector3, dir: Vector3, length: float, roll: float, level: int, u: float) -> void:
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized().rotated(dir, roll)
	var w := length * 0.8
	var corners := [base - side * w * 0.5, base + dir * length - side * w * 0.5, base + dir * length + side * w * 0.5, base + side * w * 0.5]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var cn := dir.cross(side).normalized()
	if cn.y < 0.0:
		cn = -cn
	var ao := clampf(0.45 + 0.4 * u + 0.25 * rng.randf(), 0.0, 1.0)
	var rnd := rng.randf()
	var start := l_verts.size()
	for i in 4:
		var v: Vector3 = corners[i]
		var radial := Vector3(v.x, 0, v.z).normalized()
		l_verts.append(v)
		l_norms.append((radial * 0.55 + Vector3.UP * 0.6 + cn * 0.25).normalized())
		l_uvs.append(uvs[i])
		var tipw := 1.0 if i == 1 or i == 2 else 0.25
		l_cols.append(Color(ao, rnd, tipw))
	_register_card(start, [0, 1] if level == 0 else ([0] if level == 1 else [2]))


# --- Cards and tubes -----------------------------------------------------------------------------

## A leaf-cluster card standing on `p`, growing along `axis`. It is drawn at LOD0; the
## same spot gets a larger copy for LOD1 (60 % of cards) and LOD2 (25 %).
func _card(p: Vector3, axis: Vector3, size: float) -> void:
	var side := axis.cross(_rand_dir())
	if side.length() < 0.01:
		side = axis.cross(Vector3.FORWARD)
	side = side.normalized()
	var roll := rng.randf()
	var ao := _crown_ao(p)
	var rnd := rng.randf()
	_card_quad(p, axis, side, size, ao, rnd, [0])
	if roll < 0.6:
		_card_quad(p, axis, side, size * 1.3, ao, rnd, [1])
	if roll < 0.25:
		_card_quad(p, axis, side, size * 1.75, ao, rnd, [2])


func _card_quad(p: Vector3, axis: Vector3, side: Vector3, size: float, ao: float, rnd: float, levels: Array) -> void:
	var base := p - axis * size * 0.12
	var corners := [base - side * size * 0.5, base + axis * size - side * size * 0.5, base + axis * size + side * size * 0.5, base + side * size * 0.5]
	var uvs := [Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]
	var cn := axis.cross(side).normalized()
	if cn.dot(p - crown_center) < 0.0:
		cn = -cn
	var start := l_verts.size()
	for i in 4:
		var v: Vector3 = corners[i]
		var sph := ((v - crown_center) / crown_radii).normalized()
		l_verts.append(v)
		l_norms.append((sph * 0.8 + cn * 0.2).normalized())
		l_uvs.append(uvs[i])
		l_cols.append(Color(ao, rnd, 1.0 if i == 1 or i == 2 else 0.0))
	_register_card(start, levels)


func _register_card(start: int, levels: Array) -> void:
	for lv in levels:
		cards_by_lod[lv].append_array([start, start + 1, start + 2, start, start + 2, start + 3])


## Occlusion inside the crown: centre and underside dark, the sunny outer shell bright.
func _crown_ao(p: Vector3) -> float:
	var d := ((p - crown_center) / crown_radii).length()
	var below := clampf((p.y - (crown_center.y - crown_radii.y)) / (crown_radii.y * 2.0), 0.0, 1.0)
	return clampf(smoothstep(0.25, 1.0, d) * 0.7 + below * 0.3 + 0.1, 0.0, 1.0)


## A tapered tube through `pts` (parallel-transport frames, UV seam closed).
func _tube(pts: Array, radii: Array, segs: int, u_repeat: float, ref_radius: float, levels: Array) -> void:
	var start := b_verts.size()
	var normal := Vector3.RIGHT
	var along := 0.0
	var tile := TAU * maxf(ref_radius, 0.05) / u_repeat   # square bark texels
	for i in pts.size():
		var p: Vector3 = pts[i]
		var t: Vector3 = ((pts[mini(i + 1, pts.size() - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		if i == 0:
			normal = t.cross(Vector3.FORWARD if absf(t.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		else:
			normal = (normal - t * normal.dot(t)).normalized()
			along += (p - (pts[i - 1] as Vector3)).length()
		var binormal := t.cross(normal)
		var ao := clampf(0.6 + p.y * 0.2, 0.0, 1.0) * (1.0 - 0.25 * clampf(1.0 - ((p - crown_center) / crown_radii).length(), 0.0, 1.0))
		for k in segs + 1:
			var ang := TAU * k / segs
			var o: Vector3 = (normal * cos(ang) + binormal * sin(ang))
			b_verts.append(p + o * float(radii[i]))
			b_norms.append(o)
			b_uvs.append(Vector2(float(k) / segs * u_repeat, along / tile))
			b_cols.append(Color(ao, 0, 0))
	for i in pts.size() - 1:
		for k in segs:
			var a := start + i * (segs + 1) + k
			var b := a + segs + 1
			for lv in levels:
				bark_by_lod[lv].append_array([a, a + 1, b, a + 1, b + 1, b])   # clockwise = front face in Godot


func _every_other(a: Array) -> Array:
	var out := []
	for i in a.size():
		if i % 2 == 0 or i == a.size() - 1:
			out.append(a[i])
	return out


func _along(pts: Array, t: float) -> Vector3:
	var f := clampf(t, 0.0, 1.0) * (pts.size() - 1)
	var i := mini(int(f), pts.size() - 2)
	return (pts[i] as Vector3).lerp(pts[i + 1], f - i)


func _radius_at(radii: Array, t: float) -> float:
	var f := clampf(t, 0.0, 1.0) * (radii.size() - 1)
	var i := mini(int(f), radii.size() - 2)
	return lerpf(radii[i], radii[i + 1], f - i)


func _rand_dir() -> Vector3:
	return Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()


# --- Mesh and materials --------------------------------------------------------------------------

func _build_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var h: float = cfg["height"]
	# Bark
	# Tangents come from every tube (all LODs) so no vertex is left without one
	var all_idx := PackedInt32Array()
	for lv in 3:
		all_idx.append_array(bark_by_lod[lv])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in b_verts.size():
		st.set_normal(b_norms[i])
		st.set_uv(b_uvs[i])
		st.set_color(b_cols[i])
		st.add_vertex(b_verts[i])
	for i in all_idx:
		st.add_index(i)
	st.generate_tangents()
	var barr := st.commit_to_arrays()
	barr[Mesh.ARRAY_INDEX] = bark_by_lod[0]
	var blods := {}
	for k in 2:
		blods[LOD_KEYS[k]] = bark_by_lod[k + 1]
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, barr, [], blods)
	var bark := ShaderMaterial.new()
	bark.shader = BARK_SHADER
	bark.set_shader_parameter("bark_albedo", load(BARK % [cfg["bark"], "Color"]))
	bark.set_shader_parameter("bark_normal", load(BARK % [cfg["bark"], "NormalGL"]))
	bark.set_shader_parameter("bark_rough", load(BARK % [cfg["bark"], "Roughness"]))
	var bt: Array = cfg.get("bark_tint", [1, 1, 1])
	bark.set_shader_parameter("tint", Color(bt[0], bt[1], bt[2]))
	bark.set_shader_parameter("char_amount", float(cfg.get("char", 0.0)))
	bark.set_shader_parameter("tree_height", h)
	mesh.surface_set_material(0, bark)
	# Leaves with their hand-made LODs
	if l_verts.size() > 0:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = l_verts
		arrays[Mesh.ARRAY_NORMAL] = l_norms
		arrays[Mesh.ARRAY_TEX_UV] = l_uvs
		arrays[Mesh.ARRAY_COLOR] = l_cols
		arrays[Mesh.ARRAY_INDEX] = cards_by_lod[0]
		var lods := {}
		for k in 2:
			if cards_by_lod[k + 1].size() > 0:
				lods[LOD_KEYS[k]] = cards_by_lod[k + 1]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], lods)
		var leaf := ShaderMaterial.new()
		leaf.shader = LEAF_SHADER
		leaf.set_shader_parameter("leaf_tex", load(CARDS % cfg["card"]))
		var lt: Array = cfg.get("leaf_tint", [1, 1, 1])
		leaf.set_shader_parameter("tint", Color(lt[0], lt[1], lt[2]))
		leaf.set_shader_parameter("tree_height", h)
		mesh.surface_set_material(1, leaf)
	return mesh


func _save(id: String, mesh: ArrayMesh) -> void:
	var root := MeshInstance3D.new()
	root.name = id
	root.mesh = mesh
	MaterialPolicy.apply(root)   # the project's material rule: non-metals are matte
	var scene := PackedScene.new()
	scene.pack(root)
	var path: String = OUT + id + ".scn"
	var err := ResourceSaver.save(scene, path)
	var leaf_tris := [0, 0, 0]
	for k in 3:
		leaf_tris[k] = cards_by_lod[k].size() / 3
	print("%-10s %4.1f m  LOD0 %5d tris  LOD1 %5d  LOD2 %5d  (bark %d/%d/%d)  → %s (err %d)" % [
		id, mesh.get_aabb().size.y, (bark_by_lod[0].size() + cards_by_lod[0].size()) / 3, (bark_by_lod[1].size() + cards_by_lod[1].size()) / 3,
		(bark_by_lod[2].size() + cards_by_lod[2].size()) / 3, bark_by_lod[0].size() / 3, bark_by_lod[1].size() / 3, bark_by_lod[2].size() / 3, path, err])
	root.free()


## Cards and bark must import as mipmapped VRAM textures (normal map flagged), or the
## canopy shimmers at a distance. Writes the .import files before first use.
func _ensure_imports() -> bool:
	var dirs := {"res://assets/foliage/cards/": ".png", "res://assets/foliage/bark/": ".jpg"}
	var missing := false
	for dir in dirs:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(dirs[dir]):
				continue
			var imp: String = dir + f + ".import"
			if FileAccess.file_exists(imp):
				continue
			var fa := FileAccess.open(imp, FileAccess.WRITE)
			fa.store_string('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=2\nmipmaps/generate=true\ncompress/normal_map=%d\nprocess/fix_alpha_border=true\n' % (1 if "Normal" in f else 0))
			fa.close()
			missing = true
	if missing:
		print("wrote .import files: run `godot --headless --path . --import` then this tool again")
	return not missing
