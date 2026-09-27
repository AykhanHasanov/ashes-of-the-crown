extends Node3D
## The open-world level (V3 Faza B): Terrain3D terrain + vegetation, water, day/night,
## weather, streamed POIs and the far landmarks. Built from the generated data in
## world/terrain and world/generated/world_meta.json (see tools/gen_world.gd).
## Provides what chapter_base expects of a level: build(), player_spawn, braziers,
## apply_quality().

const TerrainSetup := preload("res://scripts/world/terrain_setup.gd")
const DayNight := preload("res://scripts/world/day_night.gd")
const Weather := preload("res://scripts/world/weather.gd")
const Water := preload("res://scripts/world/water.gd")
const Streamer := preload("res://scripts/world/cell_streamer.gd")
const Effects := preload("res://scripts/world/effects.gd")
const Birds := preload("res://scripts/world/birds.gd")
const META := "res://world/generated/world_meta.json"

var meta: Dictionary
var terrain: Terrain3D
var day_night
var weather
var water
var streamer
var player_spawn := Vector3.ZERO
var braziers: Array[Vector3] = []   # lit hearths heal like the old braziers
var size := 512.0
var forest_zones: Array = []        # [Vector2 center, radius]

var _high := true
var _birds: AudioStreamPlayer
var _crickets: AudioStreamPlayer
var _river: AudioStreamPlayer3D
var _foliage: Array = []        # [MultiMeshInstance3D, cell centre, visible range]
var _cull_from := Vector3(1e9, 0, 0)
var _cull_t := 0.0


func build() -> void:
	_high = Settings.is_high()
	meta = JSON.parse_string(FileAccess.get_file_as_string(META))
	size = meta["size"]
	day_night = DayNight.new()
	add_child(day_night)
	weather = Weather.new()
	weather.day_night = day_night
	add_child(weather)

	terrain = TerrainSetup.create(_high, DataDB.balance("world"), DataDB.world("vegetation"))
	var assets: Terrain3DAssets = terrain.assets
	add_child(terrain)
	# Terrain3D resets its asset list when it enters the tree: set assets, then load
	# the regions so the instancer finds every mesh
	terrain.assets = assets
	terrain.data_directory = TerrainSetup.DATA_DIR
	# The instancer builds its MMIs over the first frames; fix them once they exist
	get_tree().create_timer(0.3).timeout.connect(_fix_instancer)
	get_tree().create_timer(1.5).timeout.connect(_fix_instancer)
	TerrainSetup.configure_collision(terrain, int(DataDB.balance("world")["terrain"]["collision_radius"]))

	water = Water.new()
	water.terrain = terrain
	add_child(water)
	water.build(meta)

	streamer = Streamer.new()
	add_child(streamer)
	streamer.setup(meta, terrain, DataDB.balance("world")["streaming"])
	streamer.is_night = func() -> bool: return day_night.is_night()

	for b in DataDB.world("world_layout")["biomes"]:
		if b["type"] == "forest":
			forest_zones.append([Vector2(b["center"][0], b["center"][1]), float(b["radius"])])

	for p in meta["pois"]:
		if p.get("start", false):
			player_spawn = Vector3(p["pos"][0] + 3.0, p["pos"][1] + 0.5, p["pos"][2] + 3.5)
	_make_bounds()
	_make_ambience()
	_make_far_landmarks()
	_make_bridges()
	refresh_braziers()
	var birds := Birds.new()
	birds.clock = day_night
	birds.height_at = height_at
	add_child(birds)


## Terrain3D 1.0.2 was built for Godot 4.4–4.6. On 4.7 two things break for regions
## loaded from disk: the MMI nodes are not moved to their region's corner (so all
## foliage piles into region 0,0), and visibility ranges are measured from the node
## origin — the region corner — instead of the cell, so nearby grass is culled as if
## it were 250 m away. Fix both: place each MMI at its region corner, switch off the
## engine range and cull each MMI ourselves by the distance to its cell's centre.
func _fix_instancer() -> void:
	var rs := float(terrain.region_size) * terrain.vertex_spacing
	_foliage.clear()
	var ranges := {}
	var veg: Dictionary = DataDB.world("vegetation")
	for i in veg["items"].size():
		var r: Array = veg["items"][i]["range"]
		ranges[i] = float(r[1] if _high else r[0])
	for n in terrain.find_children("Region_*", "Node3D", true, false):
		var parts: PackedStringArray = n.name.split("_")
		if parts.size() != 3:
			continue
		var offset := Vector3(int(parts[1]) * rs, 0.0, int(parts[2]) * rs)
		for mmi in n.get_children():
			if not mmi is MultiMeshInstance3D:
				continue
			mmi.position = offset
			mmi.visibility_range_end = 0.0
			mmi.visibility_range_begin = 0.0
			var mesh_id := int(mmi.name.get_slice("_M", 1).get_slice("_", 0))
			var box: AABB = mmi.get_aabb()
			var center := offset + box.get_center()
			_foliage.append([mmi, center, float(ranges.get(mesh_id, 100.0)) + box.size.length() * 0.5])
	_cull_foliage(true)
	print("[world] foliage cells: ", _foliage.size())


func _cull_foliage(force := false) -> void:
	var cam := terrain.get_camera()
	if cam == null:
		return
	var p := cam.global_position
	if not force and p.distance_squared_to(_cull_from) < 4.0:
		return
	_cull_from = p
	for f in _foliage:
		var mmi: MultiMeshInstance3D = f[0]
		if is_instance_valid(mmi):
			mmi.visible = p.distance_to(f[1]) < f[2]


## Terrain3D follows the gameplay camera (clipmap centre, collision).
func attach_camera(cam: Camera3D) -> void:
	terrain.set_camera(cam)
	weather.camera = cam


func hearth_pois() -> Array:
	return meta["pois"].filter(func(p): return p["type"] == "hearth")


func refresh_braziers() -> void:
	braziers.clear()
	for p in hearth_pois():
		if WorldState.has_world_entry("hearths", p["id"]):
			braziers.append(Vector3(p["pos"][0], p["pos"][1], p["pos"][2]))


func height_at(x: float, z: float) -> float:
	var h: float = terrain.data.get_height(Vector3(x, 0, z))
	return 0.0 if is_nan(h) else h


func in_forest(pos: Vector3) -> float:
	var best := 0.0
	for f in forest_zones:
		var d: float = Vector2(pos.x, pos.z).distance_to(f[0]) / float(f[1])
		best = maxf(best, clampf((1.0 - d) * 2.5, 0.0, 1.0))
	return best


func apply_quality(high: bool) -> void:
	_high = high
	RenderingServer.global_shader_parameter_set("foliage_density", 1.0 if high else 0.6)
	day_night.apply_quality(high)
	weather.apply_quality(high)
	terrain.mesh_size = 48 if high else 32
	var veg: Dictionary = DataDB.world("vegetation")
	for i in veg["items"].size():
		var ma: Terrain3DMeshAsset = terrain.assets.get_mesh_asset(i)
		if ma:
			var r: Array = veg["items"][i]["range"]
			ma.lod0_range = r[1] if high else r[0]
	streamer.high_quality = high
	if not _foliage.is_empty():
		_fix_instancer()


func _process(delta: float) -> void:
	_cull_t -= delta
	if _cull_t <= 0.0:
		_cull_t = 0.2
		_cull_foliage()
	if not is_instance_valid(streamer.focus):
		return
	var pos: Vector3 = streamer.focus.global_position
	weather.forest_fog = in_forest(pos)
	# Ambience: birds by day, crickets by night, both hushed by rain; the river nearby
	var n: float = day_night.night_amount()
	var rain: float = weather._cur["rain"]
	_fade(_birds, (1.0 - n) * (1.0 - rain) * 0.8, delta)
	_fade(_crickets, n * (1.0 - rain * 0.7) * 0.7, delta)
	_river.global_position = _nearest_river_point(pos)


func _make_ambience() -> void:
	_birds = _loop_player("birds_loop")
	_crickets = _loop_player("crickets_loop")
	_river = AudioStreamPlayer3D.new()
	_river.stream = Audio.stream("river_loop")
	_river.bus = "SFX"
	_river.unit_size = 6.0
	_river.max_distance = 60.0
	_river.volume_db = -4.0
	add_child(_river)
	_river.play()


func _loop_player(sound: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = Audio.stream(sound)
	p.bus = "SFX"
	p.volume_db = -60.0
	add_child(p)
	p.play()
	return p


func _fade(p: AudioStreamPlayer, level: float, delta: float) -> void:
	var cur := db_to_linear(p.volume_db)
	cur = move_toward(cur, level * 0.5, delta * 0.3)
	p.volume_db = linear_to_db(maxf(cur, 0.0001))


func _nearest_river_point(pos: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var best_d := 1e9
	var pts: Array = water.river_points
	for i in range(0, pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var ab := b - a
		var t := clampf((pos - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var q := a + ab * t
		var d := q.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = q
	return best


# --- World edge ----------------------------------------------------------------------------

## Invisible walls just inside the slice so nobody walks off the terrain.
func _make_bounds() -> void:
	var body := StaticBody3D.new()
	body.name = "WorldBounds"
	var inset := 6.0
	for side in 4:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var horizontal := side < 2
		box.size = Vector3(size, 200.0, 2.0) if horizontal else Vector3(2.0, 200.0, size)
		cs.shape = box
		match side:
			0: cs.position = Vector3(size * 0.5, 60.0, inset)
			1: cs.position = Vector3(size * 0.5, 60.0, size - inset)
			2: cs.position = Vector3(inset, 60.0, size * 0.5)
			3: cs.position = Vector3(size - inset, 60.0, size * 0.5)
		body.add_child(cs)
	add_child(body)


## Landmarks outside the slice: the smoke of burning Közqala behind the western pass.
func _make_far_landmarks() -> void:
	for lm in meta.get("landmarks_far", []):
		if lm["kind"] == "smoke_column":
			var root := Node3D.new()
			root.position = Vector3(lm["pos"][0], 20.0, lm["pos"][1])
			var smoke := Effects.smoke_burst(40, 1.5, 14.0, 22.0)
			smoke.one_shot = false
			smoke.explosiveness = 0.0
			smoke.emitting = true
			smoke.visibility_aabb = AABB(Vector3(-80, -20, -80), Vector3(160, 260, 160))
			var pm: ParticleProcessMaterial = smoke.process_material
			pm.gravity = Vector3(0.6, 5.5, 0)
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			pm.emission_sphere_radius = 12.0
			root.add_child(smoke)
			var glow := OmniLight3D.new()
			glow.light_color = Color(1.0, 0.35, 0.1)
			glow.light_energy = 6.0
			glow.omni_range = 90.0
			root.add_child(glow)
			add_child(root)


## Wooden bridges where roads cross the river (from the generator).
func _make_bridges() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.42, 0.29, 0.18)
	wood.roughness = 0.9
	for br in meta["bridges"]:
		var a := Vector3(br["a"][0], br["a"][1], br["a"][2])
		var b := Vector3(br["b"][0], br["b"][1], br["b"][2])
		var dir := b - a
		dir.y = 0.0
		var length := dir.length() + 8.0
		var mid := (a + b) * 0.5
		var yaw := atan2(dir.x, dir.z)
		var root := Node3D.new()
		root.position = mid
		root.rotation.y = yaw
		add_child(root)
		var body := StaticBody3D.new()
		root.add_child(body)
		var width := 4.2
		# Deck planks, beams, railings; ramps sink into the banks at both ends
		var deck := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(width, 0.3, length)
		deck.mesh = dm
		deck.material_override = wood
		root.add_child(deck)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = dm.size
		cs.shape = sh
		body.add_child(cs)
		for side in [-1, 1]:
			var rail := MeshInstance3D.new()
			var rm := BoxMesh.new()
			rm.size = Vector3(0.18, 0.18, length - 2.0)
			rail.mesh = rm
			rail.material_override = wood
			rail.position = Vector3(side * (width * 0.5 - 0.1), 1.0, 0)
			root.add_child(rail)
			var n := int(length / 2.2)
			for i in n + 1:
				var post := MeshInstance3D.new()
				var pmesh := BoxMesh.new()
				pmesh.size = Vector3(0.22, 1.9, 0.22)
				post.mesh = pmesh
				post.material_override = wood
				post.position = Vector3(side * (width * 0.5 - 0.1), 0.1, -length * 0.5 + 1.0 + i * (length - 2.0) / n)
				root.add_child(post)
			var rcs := CollisionShape3D.new()
			var rs := BoxShape3D.new()
			rs.size = Vector3(0.25, 1.4, length - 2.0)
			rcs.shape = rs
			rcs.position = Vector3(side * (width * 0.5 - 0.1), 0.7, 0)
			body.add_child(rcs)
		for i in 3:
			var pillar := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.35
			cm.bottom_radius = 0.4
			cm.height = 4.0
			pillar.mesh = cm
			pillar.material_override = wood
			pillar.position = Vector3(0, -2.0, -length * 0.3 + i * length * 0.3)
			root.add_child(pillar)
