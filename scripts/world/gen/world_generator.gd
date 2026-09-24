extends RefCounted
## Builds an open-world slice from data/world/world_layout.json (spec V3 §6.1):
## noise layers + ridge splines + hills → height map, carves the river bed and
## lakes, flattens POIs, routes roads with A*, places minor POIs by
## data/world/poi_rules.json, paints the Terrain3D control/colour maps, scatters
## vegetation by biome and draws the parchment map. Run by tools/gen_world.gd;
## the result is saved as Terrain3D regions + world/generated/world_meta.json.

enum Biome { PLAIN, MEADOW, FOREST, FARMLAND, RIVERSIDE, MOUNTAIN }
const BIOME_NAMES := ["plain", "meadow", "forest", "farmland", "riverside", "mountain"]
# Terrain texture slots, in data/balance/world.json → terrain.textures order
enum Tex { GRASS, MEADOW, DIRT, ROCK, MUD, FOREST, SAND }
const NO_WATER := -1000.0

var layout: Dictionary
var rules: Dictionary
var veg: Dictionary
var size := 512
var rng := RandomNumberGenerator.new()

var heights := PackedFloat32Array()
var water := PackedFloat32Array()        # water surface height per pixel, or NO_WATER
var biome := PackedByteArray()
var road := PackedFloat32Array()         # 0..1 road strength
var clear := PackedFloat32Array()        # 0..1 inside a POI footprint
var river_dist := PackedFloat32Array()
var river_level := PackedFloat32Array()

var pois: Array = []                     # {id, type, name, pos: Vector3, flatten, landmark, ...}
var road_paths: Array = []               # Array of PackedVector3Array
var bridges: Array = []                  # {a: Vector3, b: Vector3}
var river_points: Array = []             # [Vector3(x, level, z)]
var trees: Array = []                    # [x, z, radius]
var instances: Array = []                # per vegetation item: Array[Transform3D]
var log_lines: Array = []

var _large := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _warp := FastNoiseLite.new()
var _slope := PackedFloat32Array()


func _init(layout_data: Dictionary, rules_data: Dictionary, veg_data: Dictionary) -> void:
	layout = layout_data
	rules = rules_data
	veg = veg_data
	size = int(layout["size"])
	rng.seed = int(layout["seed"])
	var n: int = size * size
	for arr in [heights, road, clear, river_level]:
		arr.resize(n)
		arr.fill(0.0)
	water.resize(n)
	water.fill(NO_WATER)
	river_dist.resize(n)
	river_dist.fill(1e9)
	biome.resize(n)
	biome.fill(Biome.PLAIN)
	_setup_noise()


func generate() -> void:
	var t0 := Time.get_ticks_msec()
	_base()
	_border()
	_ridges()
	_hills()
	_river_field()
	_carve_river()
	_lakes()
	_biomes()
	_resolve_major_pois()
	_flatten_pois(pois)
	_compute_slope()
	_roads()
	_minor_pois()
	_compute_slope()
	_place_echo_at_bridge()
	instances = _vegetation()
	_log("generated in %d ms: %d POIs, %d roads, %d bridges, %d trees" % [
		Time.get_ticks_msec() - t0, pois.size(), road_paths.size(), bridges.size(), trees.size()])


# --- Helpers -------------------------------------------------------------------------------

func _setup_noise() -> void:
	var nl: Dictionary = layout["noise"]
	_large.seed = rng.randi()
	_large.frequency = nl["large"]["frequency"]
	_large.fractal_octaves = int(nl["large"]["octaves"])
	_large.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail.seed = rng.randi()
	_detail.frequency = nl["detail"]["frequency"]
	_detail.fractal_octaves = int(nl["detail"]["octaves"])
	_warp.seed = rng.randi()
	_warp.frequency = 0.02


func _log(line: String) -> void:
	log_lines.append(line)
	print("[worldgen] ", line)


func idx(x: int, z: int) -> int:
	return z * size + x


func height_at(x: float, z: float) -> float:
	var xi := clampi(int(x), 0, size - 2)
	var zi := clampi(int(z), 0, size - 2)
	var fx := clampf(x - xi, 0.0, 1.0)
	var fz := clampf(z - zi, 0.0, 1.0)
	var a := lerpf(heights[idx(xi, zi)], heights[idx(xi + 1, zi)], fx)
	var b := lerpf(heights[idx(xi, zi + 1)], heights[idx(xi + 1, zi + 1)], fx)
	return lerpf(a, b, fz)


func _at(arr, x: float, z: float):
	return arr[idx(clampi(int(x), 0, size - 1), clampi(int(z), 0, size - 1))]


func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


static func seg_dist(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	## Returns (distance, t along the segment).
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return Vector2(p.distance_to(a + ab * t), t)


func _smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# --- Shape ---------------------------------------------------------------------------------

func _base() -> void:
	var base: float = layout["base_height"]
	var nl: Dictionary = layout["noise"]
	var amp_l: float = nl["large"]["amplitude"]
	var amp_d: float = nl["detail"]["amplitude"]
	for z in size:
		# The valley falls gently from north to south with the river
		var tilt := lerpf(4.5, -2.5, float(z) / size)
		for x in size:
			heights[idx(x, z)] = base + tilt + _large.get_noise_2d(x, z) * amp_l + _detail.get_noise_2d(x, z) * amp_d


func _border() -> void:
	var b: Dictionary = layout["border"]
	var w: float = b["width"]
	var hgt: float = b["height"]
	var nz: float = b["noise"]
	for z in size:
		for x in size:
			var d := float(mini(mini(x, z), mini(size - 1 - x, size - 1 - z)))
			d += _warp.get_noise_2d(x * 0.7, z * 0.7) * 18.0
			if d < w:
				var t := 1.0 - maxf(d, 0.0) / w
				var add := hgt * pow(_smooth(t), 1.4) + absf(_large.get_noise_2d(x * 2.3, z * 2.3)) * nz * t
				# Passes where roads and the river leave the valley
				for g in b.get("gaps", []):
					var gd := Vector2(x, z).distance_to(_v2(g["at"])) / float(g["radius"])
					if gd < 1.6:
						add *= 1.0 - float(g["depth"]) * (1.0 - _smooth((gd - 0.6) / 1.0))
				heights[idx(x, z)] += add


func _ridges() -> void:
	var buf := PackedFloat32Array()
	buf.resize(size * size)
	for r in layout["ridges"]:
		var pts: Array = r["points"]
		var w: float = r["width"]
		var hgt: float = r["height"]
		buf.fill(0.0)
		var lo := Vector2(1e9, 1e9)
		var hi := Vector2(-1e9, -1e9)
		for p in pts:
			lo = lo.min(_v2(p))
			hi = hi.max(_v2(p))
		var x0 := clampi(int(lo.x - w), 0, size - 1)
		var x1 := clampi(int(hi.x + w), 0, size - 1)
		var z0 := clampi(int(lo.y - w), 0, size - 1)
		var z1 := clampi(int(hi.y + w), 0, size - 1)
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				var p := Vector2(x, z)
				var best := 1e9
				for i in pts.size() - 1:
					best = minf(best, seg_dist(p, _v2(pts[i]), _v2(pts[i + 1])).x)
				var ww := w * (1.0 + _warp.get_noise_2d(x, z) * 0.35)
				if best < ww:
					var t := 1.0 - best / ww
					var crest := 0.8 + 0.35 * _large.get_noise_2d(x * 1.7 + 300.0, z * 1.7)
					buf[idx(x, z)] = hgt * crest * _smooth(t)
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				heights[idx(x, z)] += buf[idx(x, z)]


func _hills() -> void:
	for hdef in layout["hills"]:
		var c := _v2(hdef["center"])
		var r: float = hdef["radius"]
		var hgt: float = hdef["height"]
		for z in range(maxi(0, int(c.y - r)), mini(size, int(c.y + r) + 1)):
			for x in range(maxi(0, int(c.x - r)), mini(size, int(c.x + r) + 1)):
				var d := Vector2(x, z).distance_to(c) / r
				if d < 1.0:
					heights[idx(x, z)] += hgt * (0.5 + 0.5 * cos(d * PI))


# --- Water ---------------------------------------------------------------------------------

func _river_field() -> void:
	var rv: Dictionary = layout["river"]
	var pts: Array = rv["points"]
	var total := 0.0
	var lengths := [0.0]
	for i in pts.size() - 1:
		total += _v2(pts[i]).distance_to(_v2(pts[i + 1]))
		lengths.append(total)
	var l0: float = rv["level_start"]
	var l1: float = rv["level_end"]
	for i in pts.size():
		river_points.append(Vector3(pts[i][0], lerpf(l0, l1, lengths[i] / total), pts[i][1]))
	var reach: float = float(rv["width"]) * 0.5 + float(rv["bank"]) + 40.0
	for i in pts.size() - 1:
		var a := _v2(pts[i])
		var b := _v2(pts[i + 1])
		var lo := a.min(b) - Vector2(reach, reach)
		var hi := a.max(b) + Vector2(reach, reach)
		for z in range(maxi(0, int(lo.y)), mini(size, int(hi.y) + 1)):
			for x in range(maxi(0, int(lo.x)), mini(size, int(hi.x) + 1)):
				var dt := seg_dist(Vector2(x, z), a, b)
				# Meander the banks a little
				var d := dt.x + _warp.get_noise_2d(x * 1.3, z * 1.3) * 2.2
				var k := idx(x, z)
				if d < river_dist[k]:
					river_dist[k] = d
					var along: float = lerpf(lengths[i], lengths[i + 1], dt.y)
					river_level[k] = lerpf(l0, l1, along / total)


func _carve_river() -> void:
	var rv: Dictionary = layout["river"]
	var hw: float = float(rv["width"]) * 0.5
	var bank: float = rv["bank"]
	var depth: float = rv["depth"]
	for k in size * size:
		var d: float = river_dist[k]
		if d > hw + bank:
			continue
		var lvl: float = river_level[k]
		if d < hw:
			var u := d / hw
			heights[k] = minf(heights[k], lvl - depth * (1.0 - u * u) - 0.15)
			water[k] = lvl
		else:
			var t := _smooth((d - hw) / bank)
			heights[k] = lerpf(lvl + 0.25, heights[k], t)
			if d < hw + 1.5:
				water[k] = lvl


func _lakes() -> void:
	for lk in layout["lakes"]:
		var c := _v2(lk["center"])
		var r: float = lk["radius"]
		var lvl: float = lk["level"]
		var depth: float = lk["depth"]
		var shore: float = lk["shore"]
		var reach := r * 1.3 + shore
		for z in range(maxi(0, int(c.y - reach)), mini(size, int(c.y + reach) + 1)):
			for x in range(maxi(0, int(c.x - reach)), mini(size, int(c.x + reach) + 1)):
				var k := idx(x, z)
				var p := Vector2(x, z)
				var ang := (p - c).angle()
				var rr := r * (1.0 + 0.16 * _warp.get_noise_2d(cos(ang) * 60.0, sin(ang) * 60.0))
				var d := p.distance_to(c)
				if d < rr:
					var u := d / rr
					heights[k] = minf(heights[k], lvl - depth * pow(1.0 - u * u, 0.7) - 0.2)
					water[k] = lvl
				elif d < rr + shore:
					var t := _smooth((d - rr) / shore)
					heights[k] = lerpf(lvl + 0.2, heights[k], t)
					if d < rr + 1.2:
						water[k] = lvl
		if lk.has("island"):
			var isl: Dictionary = lk["island"]
			var ic := _v2(isl["center"])
			var ir: float = isl["radius"]
			for z in range(int(ic.y - ir * 2), int(ic.y + ir * 2) + 1):
				for x in range(int(ic.x - ir * 2), int(ic.x + ir * 2) + 1):
					var d := Vector2(x, z).distance_to(ic) / (ir * 2.0)
					if d < 1.0:
						var k := idx(x, z)
						heights[k] = maxf(heights[k], lvl + float(isl["height"]) * (1.0 - d * d) * 1.6 - 0.9)


func water_at(x: float, z: float) -> float:
	return _at(water, x, z)


# --- Biomes --------------------------------------------------------------------------------

func _biomes() -> void:
	var weights := {}
	for b in layout["biomes"]:
		if b.has("center"):
			weights[b] = true
	var river_w := 0.0
	for b in layout["biomes"]:
		if b.get("follow", "") == "river":
			river_w = b["width"]
	var base: float = layout["base_height"]
	for z in size:
		for x in size:
			var k := idx(x, z)
			var best := 0.0
			var kind := Biome.PLAIN
			var wobble := _warp.get_noise_2d(x * 0.8 + 50.0, z * 0.8) * 0.25
			for b in weights:
				var t: float = 1.0 - Vector2(x, z).distance_to(_v2(b["center"])) / float(b["radius"]) + wobble
				if t > best:
					best = t
					kind = BIOME_NAMES.find(b["type"])
			if river_dist[k] < river_w * (0.8 + wobble) and kind != Biome.FOREST:
				kind = Biome.RIVERSIDE
			if heights[k] > base + 26.0:
				kind = Biome.MOUNTAIN
			biome[k] = kind


func biome_at(x: float, z: float) -> int:
	return _at(biome, x, z)


# --- POIs ----------------------------------------------------------------------------------

func _resolve_major_pois() -> void:
	for p in layout["pois"]:
		var poi: Dictionary = p.duplicate(true)
		var xz := _v2(p["pos"])
		poi["pos"] = Vector3(xz.x, 0.0, xz.y)
		poi["major"] = true
		poi["flatten"] = float(p.get("flatten", 0.0))
		pois.append(poi)
	for poi in pois:
		poi["pos"].y = _poi_height(poi)


## Mostly the centre's height (a hilltop stays a hilltop instead of a crater),
## softened by the surroundings.
func _poi_height(p: Dictionary) -> float:
	var c: Vector3 = p["pos"]
	if float(p["flatten"]) <= 0.0:
		return height_at(c.x, c.z)
	return lerpf(_average_height(c, maxf(p["flatten"] * 0.5, 2.0)), height_at(c.x, c.z), 0.7)


func _average_height(c: Vector3, r: float) -> float:
	var sum := 0.0
	var n := 0
	for a in 12:
		for s in [0.3, 0.7, 1.0]:
			var ang := TAU * a / 12.0
			sum += height_at(c.x + cos(ang) * r * s, c.z + sin(ang) * r * s)
			n += 1
	return sum / n


func _flatten_pois(list: Array) -> void:
	for poi in list:
		var r: float = poi["flatten"]
		if r <= 0.0:
			continue
		var c: Vector3 = poi["pos"]
		var outer := r * 2.2
		for z in range(maxi(0, int(c.z - outer)), mini(size, int(c.z + outer) + 1)):
			for x in range(maxi(0, int(c.x - outer)), mini(size, int(c.x + outer) + 1)):
				var d := Vector2(x, z).distance_to(Vector2(c.x, c.z))
				if d > outer:
					continue
				var k := idx(x, z)
				var t := 1.0 if d < r else 1.0 - _smooth((d - r) / (outer - r))
				heights[k] = lerpf(heights[k], c.y, t)
				clear[k] = maxf(clear[k], t)


func _compute_slope() -> void:
	_slope.resize(size * size)
	for z in size:
		for x in size:
			var hx := heights[idx(mini(x + 1, size - 1), z)] - heights[idx(maxi(x - 1, 0), z)]
			var hz := heights[idx(x, mini(z + 1, size - 1))] - heights[idx(x, maxi(z - 1, 0))]
			_slope[idx(x, z)] = Vector2(hx, hz).length() * 0.5   # rise per metre


func slope_deg(x: float, z: float) -> float:
	return rad_to_deg(atan(_at(_slope, x, z)))


func poi(id: String) -> Dictionary:
	for p in pois:
		if p["id"] == id:
			return p
	return {}


## Fills gaps: wherever the nearest POI is further than rules.gap, a minor POI goes
## at the most remote valid spot (spec §6.3 density rule).
func _minor_pois() -> void:
	var gap: float = rules["gap"]
	var margin: float = rules["edge_margin"]
	var types: Array = rules["types"]
	var count := 0
	for _i in 30:
		var best_p := Vector3.ZERO
		var best_d := 0.0
		var best_biome := 0
		for z in range(int(margin), size - int(margin), 8):
			for x in range(int(margin), size - int(margin), 8):
				if not _minor_spot_ok(x, z):
					continue
				var d := _nearest_poi_dist(Vector3(x, 0, z))
				if d > best_d:
					best_d = d
					best_p = Vector3(x, 0, z)
					best_biome = biome_at(x, z)
		if best_d < gap:
			break
		var allowed := types.filter(func(t): return BIOME_NAMES[best_biome] in t["biomes"])
		if allowed.is_empty():
			allowed = types
		var pick: Dictionary = _weighted(allowed)
		count += 1
		var p := {
			"id": "%s_%d" % [pick["type"], count], "type": pick["type"], "name": pick["name"],
			"pos": Vector3(best_p.x, 0.0, best_p.z), "flatten": float(pick["flatten"]), "major": false,
		}
		p["pos"].y = _poi_height(p)
		pois.append(p)
		_flatten_pois([p])
	_log("minor POIs placed: %d" % count)
	# Density rule (spec §6.3): from any walkable spot the nearest POI within 150–200 m
	var worst := 0.0
	for z in range(int(margin), size - int(margin), 8):
		for x in range(int(margin), size - int(margin), 8):
			if biome_at(x, z) == Biome.MOUNTAIN or water_at(x, z) > NO_WATER:
				continue
			worst = maxf(worst, _nearest_poi_dist(Vector3(x, 0, z)))
	_log("POI coverage: farthest walkable spot is %.0f m from a POI (rule: ≤ 150–200 m)" % worst)


func _minor_spot_ok(x: int, z: int) -> bool:
	if slope_deg(x, z) > float(rules["max_slope_deg"]):
		return false
	var wc: float = rules["water_clearance"]
	for o in [Vector2(wc, 0), Vector2(-wc, 0), Vector2(0, wc), Vector2(0, -wc), Vector2.ZERO]:
		if water_at(x + o.x, z + o.y) > NO_WATER:
			return false
	if _at(road, x, z) > 0.0 or _at(clear, x, z) > 0.0:
		return false
	return true


func _nearest_poi_dist(p: Vector3) -> float:
	var best := 1e9
	for q in pois:
		var d := Vector2(p.x, p.z).distance_to(Vector2(q["pos"].x, q["pos"].z))
		best = minf(best, d)
	return best


func _weighted(list: Array) -> Dictionary:
	var total := 0.0
	for t in list:
		total += float(t["weight"])
	var r := rng.randf() * total
	for t in list:
		r -= float(t["weight"])
		if r <= 0.0:
			return t
	return list[list.size() - 1]


# --- Roads ---------------------------------------------------------------------------------

const ROAD_CELL := 4

func _roads() -> void:
	var cells := size / ROAD_CELL
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, cells, cells)
	grid.cell_size = Vector2(ROAD_CELL, ROAD_CELL)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	grid.update()
	var river_hw: float = float(layout["river"]["width"]) * 0.5
	for cz in cells:
		for cx in cells:
			var x := cx * ROAD_CELL + ROAD_CELL / 2
			var z := cz * ROAD_CELL + ROAD_CELL / 2
			var k := idx(x, z)
			var w := 1.0 + pow(_slope[k] * 6.0, 2.0) * 3.0
			if water[k] > NO_WATER:
				if river_dist[k] < river_hw + 2.0:
					w += 28.0  # crossing is allowed (bridge) but costly
				else:
					grid.set_point_solid(Vector2i(cx, cz), true)
			if heights[k] > float(layout["base_height"]) + 20.0:
				w += 6.0
			grid.set_point_weight_scale(Vector2i(cx, cz), w)
	for rdef in layout["roads"]:
		var a: Vector3 = _road_end(rdef, "from")
		var b: Vector3 = _road_end(rdef, "to")
		var from := Vector2i(clampi(int(a.x) / ROAD_CELL, 0, cells - 1), clampi(int(a.z) / ROAD_CELL, 0, cells - 1))
		var to := Vector2i(clampi(int(b.x) / ROAD_CELL, 0, cells - 1), clampi(int(b.z) / ROAD_CELL, 0, cells - 1))
		var ids := grid.get_id_path(from, to)
		if ids.is_empty():
			_log("road %s → %s: no path" % [rdef["from"], rdef["to"]])
			continue
		var pts: Array = []
		for c in ids:
			pts.append(Vector2(c.x * ROAD_CELL + ROAD_CELL * 0.5, c.y * ROAD_CELL + ROAD_CELL * 0.5))
		pts[0] = Vector2(a.x, a.z)
		pts[pts.size() - 1] = Vector2(b.x, b.z)
		pts = _chaikin(_chaikin(pts))
		_stamp_road(pts)


func _road_end(rdef: Dictionary, key: String) -> Vector3:
	var id: String = rdef[key]
	if id.begins_with("edge"):
		var e: Array = rdef["edge"]
		return Vector3(e[0], 0, e[1])
	return poi(id)["pos"]


func _chaikin(pts: Array) -> Array:
	if pts.size() < 3:
		return pts
	var out: Array = [pts[0]]
	for i in pts.size() - 1:
		out.append(pts[i].lerp(pts[i + 1], 0.25))
		out.append(pts[i].lerp(pts[i + 1], 0.75))
	out.append(pts[pts.size() - 1])
	return out


func _stamp_road(pts: Array) -> void:
	# Heights along the road, smoothed so it doesn't follow every bump
	var hs: Array = []
	for p in pts:
		hs.append(height_at(p.x, p.y))
	for _pass in 4:
		var sm := hs.duplicate()
		for i in range(1, hs.size() - 1):
			sm[i] = (hs[i - 1] + hs[i] * 2.0 + hs[i + 1]) * 0.25
		hs = sm
	var line := PackedVector3Array()
	var bridge_start := -1
	for i in pts.size():
		var p: Vector2 = pts[i]
		var wet: bool = water_at(p.x, p.y) > NO_WATER
		var y: float = hs[i]
		if wet:
			y = maxf(y, water_at(p.x, p.y) + 1.1)
			if bridge_start < 0:
				bridge_start = maxi(i - 1, 0)
		elif bridge_start >= 0:
			var a2: Vector2 = pts[bridge_start]
			var lvl: float = water_at((a2.x + p.x) * 0.5, (a2.y + p.y) * 0.5)
			var deck := maxf(lvl, float(layout["river"]["level_end"])) + 1.2
			bridges.append({"a": Vector3(a2.x, deck, a2.y), "b": Vector3(p.x, deck, p.y)})
			bridge_start = -1
		line.append(Vector3(p.x, y, p.y))
	road_paths.append(line)
	var half := 2.4
	var edge := 3.8
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var lo := a.min(b) - Vector2(edge, edge)
		var hi := a.max(b) + Vector2(edge, edge)
		for z in range(maxi(0, int(lo.y)), mini(size, int(hi.y) + 2)):
			for x in range(maxi(0, int(lo.x)), mini(size, int(hi.x) + 2)):
				var k := idx(x, z)
				if water[k] > NO_WATER:
					continue
				var dt := seg_dist(Vector2(x, z), a, b)
				if dt.x > edge:
					continue
				var s := 1.0 - _smooth((dt.x - half) / (edge - half))
				var target: float = lerpf(hs[i], hs[i + 1], dt.y) - 0.05
				heights[k] = lerpf(heights[k], target, s * 0.85)
				road[k] = maxf(road[k], s)


func _place_echo_at_bridge() -> void:
	for p in pois:
		if p.get("at_bridge", false):
			if bridges.is_empty():
				p["pos"] = poi("hearth_west")["pos"] + Vector3(6, 0, 4)
			else:
				var br: Dictionary = bridges[0]
				var dir: Vector3 = (br["b"] - br["a"]).normalized()
				var side := Vector3(-dir.z, 0, dir.x)
				var spot: Vector3 = br["a"] - dir * 5.0 + side * 3.5
				spot.y = height_at(spot.x, spot.z)
				p["pos"] = spot


# --- Terrain maps --------------------------------------------------------------------------

## Control map (texture ids + blend) packed the way Terrain3D stores it.
func control_image() -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RF)
	var tex_noise := FastNoiseLite.new()
	tex_noise.seed = 99
	tex_noise.frequency = 0.035
	for z in size:
		for x in size:
			var k := idx(x, z)
			var base := Tex.GRASS
			var over := Tex.GRASS
			var blend := 0.0
			var n := tex_noise.get_noise_2d(x, z)
			match biome[k]:
				Biome.MEADOW:
					base = Tex.GRASS
					over = Tex.MEADOW
					blend = _smooth(n * 1.4 + 0.55)
				Biome.FOREST:
					base = Tex.FOREST
					over = Tex.GRASS
					blend = clampf(n * 0.8 + 0.1, 0.0, 0.6)
				Biome.FARMLAND:
					base = Tex.MEADOW
					over = Tex.DIRT
					blend = clampf(n + 0.25, 0.0, 0.4)
				Biome.PLAIN:
					base = Tex.GRASS
					over = Tex.MEADOW
					blend = _smooth(n + 0.3) * 0.7
				Biome.RIVERSIDE:
					base = Tex.GRASS
					over = Tex.MUD
					blend = clampf(1.0 - river_dist[k] / 16.0, 0.0, 1.0) * 0.8
				Biome.MOUNTAIN:
					base = Tex.GRASS
					over = Tex.ROCK
					blend = 0.45
			# Steep ground is rock
			var sl: float = rad_to_deg(atan(_slope[k]))
			if sl > 26.0:
				over = Tex.ROCK
				blend = maxf(blend, _smooth((sl - 26.0) / 14.0))
			# Beds and shores
			if water[k] > NO_WATER and heights[k] < water[k] - 0.1:
				base = Tex.MUD
				over = Tex.SAND if _near_lake(x, z) else Tex.MUD
				blend = 0.5
			elif _near_lake(x, z) and heights[k] < _lake_level(x, z) + 1.4:
				over = Tex.SAND
				blend = 1.0
			# Roads and settlements
			if road[k] > 0.05:
				over = Tex.DIRT
				blend = maxf(blend if over == Tex.DIRT else 0.0, road[k])
			elif clear[k] > 0.2 and biome[k] != Biome.FOREST:
				over = Tex.DIRT
				blend = maxf(blend * 0.3, clear[k] * 0.45 * (0.6 + 0.4 * n))
			var ctrl: int = Terrain3DUtil.enc_base(base) | Terrain3DUtil.enc_overlay(over) | Terrain3DUtil.enc_blend(int(clampf(blend, 0.0, 1.0) * 255.0))
			img.set_pixel(x, z, Color(Terrain3DUtil.as_float(ctrl), 0.0, 0.0, 1.0))
	return img


func _near_lake(x: float, z: float) -> bool:
	for lk in layout["lakes"]:
		if Vector2(x, z).distance_to(_v2(lk["center"])) < float(lk["radius"]) * 1.25 + float(lk["shore"]):
			return true
	return false


func _lake_level(x: float, z: float) -> float:
	for lk in layout["lakes"]:
		if Vector2(x, z).distance_to(_v2(lk["center"])) < float(lk["radius"]) * 1.3 + float(lk["shore"]):
			return lk["level"]
	return NO_WATER


func height_image() -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RF)
	for z in size:
		for x in size:
			img.set_pixel(x, z, Color(heights[idx(x, z)], 0.0, 0.0, 1.0))
	return img


## Colour map: soft tint variation that breaks texture tiling (alpha = roughness 0.5).
func color_image() -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var n := FastNoiseLite.new()
	n.seed = 5
	n.frequency = 0.012
	for z in size:
		for x in size:
			var k := idx(x, z)
			var v := n.get_noise_2d(x, z)
			var c := Color(1.0 + v * 0.1, 1.0 + v * 0.06, 1.0 - v * 0.05)
			if biome[k] == Biome.FOREST:
				c = c * Color(0.82, 0.86, 0.8)
			elif biome[k] == Biome.MEADOW:
				c = c * Color(1.04, 1.0, 0.88)
			img.set_pixel(x, z, Color(minf(c.r, 1.0), minf(c.g, 1.0), minf(c.b, 1.0), 0.5))
	return img


# --- Vegetation ----------------------------------------------------------------------------

func _vegetation() -> Array:
	var out: Array = []
	var clump := FastNoiseLite.new()
	clump.seed = 77
	clump.frequency = 0.025
	var cl: Dictionary = veg["clear"]
	for item in veg["items"]:
		var list: Array[Transform3D] = []
		var sp: float = item["spacing"]
		var chances: Dictionary = item["chance"]
		var sc: Array = item["scale"]
		var max_slope: float = item["max_slope"]
		var is_tree: bool = item.has("collide")
		var steps := int(size / sp)
		for gz in steps:
			for gx in steps:
				var x := (gx + rng.randf()) * sp
				var z := (gz + rng.randf()) * sp
				if x < 1.0 or z < 1.0 or x > size - 2 or z > size - 2:
					continue
				var bname: String = BIOME_NAMES[biome_at(x, z)]
				var chance: float = chances.get(bname, 0.0)
				if chance <= 0.0:
					continue
				chance *= clampf(0.8 + clump.get_noise_2d(x, z) * 1.1, 0.1, 1.6)
				if rng.randf() > chance:
					continue
				if slope_deg(x, z) > max_slope:
					continue
				var wet := false
				for o in [Vector2.ZERO, Vector2(cl["water"], 0), Vector2(-cl["water"], 0), Vector2(0, cl["water"]), Vector2(0, -cl["water"])]:
					if water_at(x + o.x, z + o.y) > NO_WATER:
						wet = true
				if wet:
					continue
				var rd: float = _at(road, x, z)
				if rd > (0.02 if is_tree else 0.35):
					continue
				if is_tree and _road_near(x, z, float(cl["road"])):
					continue
				var cv: float = _at(clear, x, z)
				if cv > (0.0 if is_tree else 0.6):
					continue
				if is_tree and _near_poi(x, z, float(cl["poi_extra"])):
					continue
				var s := rng.randf_range(sc[0], sc[1])
				var y := height_at(x, z) - 0.06 * s
				var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.1), s))
				list.append(Transform3D(basis, Vector3(x, y, z)))
				if is_tree:
					trees.append([snappedf(x, 0.01), snappedf(z, 0.01), snappedf(float(item["collide"]) * s / sc[0], 0.01)])
		out.append(list)
		_log("vegetation %s: %d" % [item["id"], list.size()])
	return out


func _road_near(x: float, z: float, r: float) -> bool:
	for o in [Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		if _at(road, x + o.x, z + o.y) > 0.05:
			return true
	return false


func _near_poi(x: float, z: float, extra: float) -> bool:
	for p in pois:
		var r: float = maxf(float(p["flatten"]), 4.0) + extra
		if Vector2(x, z).distance_to(Vector2(p["pos"].x, p["pos"].z)) < r:
			return true
	return false


# --- Parchment map -------------------------------------------------------------------------

func map_image() -> Image:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	var paper := Color(0.86, 0.79, 0.64)
	var light := Vector3(-1.0, 1.6, -1.0).normalized()
	var n := FastNoiseLite.new()
	n.seed = 3
	n.frequency = 0.06
	for z in size:
		for x in size:
			var k := idx(x, z)
			var hx := heights[idx(mini(x + 1, size - 1), z)] - heights[idx(maxi(x - 1, 0), z)]
			var hz := heights[idx(x, mini(z + 1, size - 1))] - heights[idx(x, maxi(z - 1, 0))]
			var normal := Vector3(-hx, 2.0, -hz).normalized()
			var shade := clampf(normal.dot(light) * 1.25, 0.35, 1.2)
			var c := paper
			match biome[k]:
				Biome.FOREST:
					c = c.lerp(Color(0.42, 0.5, 0.32), 0.55)
				Biome.MEADOW, Biome.PLAIN:
					c = c.lerp(Color(0.66, 0.68, 0.45), 0.35)
				Biome.FARMLAND:
					c = c.lerp(Color(0.8, 0.7, 0.42), 0.4)
				Biome.RIVERSIDE:
					c = c.lerp(Color(0.6, 0.66, 0.46), 0.35)
				Biome.MOUNTAIN:
					c = c.lerp(Color(0.62, 0.58, 0.52), 0.5)
			c = c * shade
			# Contour every 6 m
			var h: float = heights[k]
			if fposmod(h, 6.0) < 0.35 and _slope[k] > 0.08:
				c = c.darkened(0.12)
			if road[k] > 0.4:
				c = c.lerp(Color(0.55, 0.38, 0.22), 0.7)
			if water[k] > NO_WATER and heights[k] < water[k]:
				var depth := clampf((water[k] - heights[k]) / 4.0, 0.0, 1.0)
				c = Color(0.52, 0.66, 0.7).lerp(Color(0.3, 0.44, 0.55), depth)
			c = c * (0.96 + n.get_noise_2d(x, z) * 0.05)
			img.set_pixel(x, z, c)
	for br in bridges:
		var a: Vector3 = br["a"]
		var b: Vector3 = br["b"]
		for i in 20:
			var p := a.lerp(b, i / 19.0)
			for o in [-1, 0, 1]:
				img.set_pixel(clampi(int(p.x) + o, 0, size - 1), clampi(int(p.z), 0, size - 1), Color(0.4, 0.26, 0.14))
	return img


# --- Meta for the runtime ------------------------------------------------------------------

func meta() -> Dictionary:
	var poi_list: Array = []
	for p in pois:
		var d: Dictionary = p.duplicate()
		d["pos"] = [snappedf(p["pos"].x, 0.01), snappedf(p["pos"].y, 0.01), snappedf(p["pos"].z, 0.01)]
		d.erase("at_bridge")
		poi_list.append(d)
	var roads_out: Array = []
	for line in road_paths:
		var pts: Array = []
		for v in line:
			pts.append([snappedf(v.x, 0.1), snappedf(v.y, 0.01), snappedf(v.z, 0.1)])
		roads_out.append(pts)
	var br_out: Array = []
	for br in bridges:
		br_out.append({"a": [br["a"].x, br["a"].y, br["a"].z], "b": [br["b"].x, br["b"].y, br["b"].z]})
	var river_out: Array = []
	for v in river_points:
		river_out.append([v.x, v.y, v.z])
	var tree_out: Array = []
	for t in trees:
		tree_out.append_array(t)
	return {
		"id": layout["id"],
		"name": layout["name"],
		"size": size,
		"pois": poi_list,
		"roads": roads_out,
		"bridges": br_out,
		"river": {"points": river_out, "width": layout["river"]["width"], "bank": layout["river"]["bank"], "name": layout["river"]["name"]},
		"lakes": layout["lakes"],
		"landmarks_far": layout.get("landmarks_far", []),
		"trees": tree_out,
		"log": log_lines,
	}
