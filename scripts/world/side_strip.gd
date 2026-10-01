extends Node3D
## The 2.5D test strip (v4): one continuous walk from the ash-valley edge, down a road, into
## the real Son Ocaq courtyard — no loading between them. The courtyard is the hub level
## itself, placed at the far end; everything in front of it is dressed here, and ONLY what the
## side camera sees: a band either side of the lane, with a few foreground silhouettes between
## the lens and the lane for depth.
##
## The lane is a Curve3D running from the valley edge (south) to the gate (north): the camera
## rides beside it (scripts/camera/side_camera.gd) and the protagonist walks along it.
## Numbers: data/balance/side_view.json. Test content, not canon.

const HubLevel := preload("res://scripts/hub/hub_level.gd")
const Effects := preload("res://scripts/world/effects.gd")
const Visuals := preload("res://scripts/world/visuals.gd")
const HearthFire := preload("res://scripts/world/hearth_fire.gd")
const FOLIAGE := "res://assets/foliage/%s.scn"
const PROPS := "res://assets/props_mk/%s.gltf"

const START_Z := 62.0        # the valley edge
const GATE_Z := 12.0         # where the courtyard's gate passage begins
const FIGHT_Z := 44.0        # the bandits wait here
const CAMERA_SIDE := 1.0     # the camera stands on +X

var hub: Node3D              # HubLevel: the courtyard at the end of the strip
var day_night                # forwarded from the hub, so there is one sky
var lane := Curve3D.new()
var player_spawn := Vector3(0, 0.2, START_Z - 2.0)
var braziers: Array = []     # the road's fires heal like the hub's
var fight_at := Vector3(0, 0, FIGHT_Z)
## The courtyard is walled: from inside the gate the camera takes a fixed frame above the
## south side, looking north across the hearth (scripts/camera/side_camera.gd zones).
var camera_zones: Array = []
var _rng := RandomNumberGenerator.new()


func build() -> void:
	_rng.seed = 20261001
	hub = HubLevel.new()
	hub.name = "SonOcaq"
	add_child(hub)
	hub.build()
	day_night = hub.day_night
	_build_lane()
	_road()
	_valley_edge()
	_foreground()
	_mood()
	player_spawn = lane.sample_baked(0.0) + Vector3(0, 0.3, 0)
	# inside the walls the lens comes in close and a little higher, over the gallery roof
	camera_zones = [{"from_z": -9.0, "to_z": 10.5, "distance": 5.2, "height": 3.4}]


func apply_quality(high: bool) -> void:
	hub.apply_quality(high)


func height_at(_x: float, _z: float) -> float:
	return 0.0


## The strip's spine: straight out of the valley, a slow bend, then true north into the gate.
func _build_lane() -> void:
	for p in [Vector3(1.8, 0, START_Z), Vector3(1.2, 0, 52.0), Vector3(-1.6, 0, 40.0),
			Vector3(-1.0, 0, 28.0), Vector3(0.0, 0, 18.0), Vector3(0.0, 0, GATE_Z), Vector3(0.0, 0, 2.0)]:
		lane.add_point(p)
	lane.bake_interval = 0.25


## The road itself: trodden earth under the lane, low walls and fences along the far side, a
## cart, barrels, and two braziers whose fire is the only strong colour out here.
func _road() -> void:
	var road := Node3D.new()
	road.name = "Road"
	add_child(road)
	var earth := Visuals.mat(Color(0.3, 0.26, 0.22), 1.0)
	var stone := Visuals.mat(Color(0.33, 0.32, 0.31), 1.0)
	var wood := Visuals.mat(Color(0.26, 0.19, 0.13), 1.0)
	# the track: quads laid along the lane
	var length := lane.get_baked_length()
	var step := 3.0
	var walked := 0.0
	while walked < length - GATE_Z * 0.3:
		var at := lane.sample_baked(walked)
		var ahead := lane.sample_baked(minf(walked + step, length))
		var dir := (ahead - at)
		dir.y = 0.0
		if dir.length() < 0.01:
			break
		var quad := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(4.6, step * 1.05)
		q.material = earth
		quad.mesh = q
		quad.position = (at + ahead) * 0.5 + Vector3(0, 0.02, 0)
		quad.rotation = Vector3(-PI * 0.5, atan2(dir.x, dir.z), 0)
		road.add_child(quad)
		walked += step
	# the far side (away from the lens): a broken wall, so the silhouettes have a backdrop
	var z := GATE_Z + 3.0
	while z < START_Z - 6.0:
		var h := _rng.randf_range(0.8, 1.9)
		var gap: bool = _rng.randf() < 0.22
		if not gap:
			var at := _lane_point(z)
			_box(road, Vector3(_rng.randf_range(2.0, 4.0), h, 0.5),
				at + Vector3(-3.6 * CAMERA_SIDE, h * 0.5, 0) + Vector3(_rng.randf_range(-0.3, 0.3), 0, 0), stone)
		z += _rng.randf_range(3.0, 6.0)
	# fence posts on the near side, low enough to see over
	z = GATE_Z + 6.0
	while z < START_Z - 10.0:
		var at := _lane_point(z)
		_box(road, Vector3(0.18, _rng.randf_range(0.9, 1.3), 0.18), at + Vector3(2.9 * CAMERA_SIDE, 0.55, 0), wood)
		z += _rng.randf_range(2.5, 4.0)
	for spot in [[48.0, -3.0], [26.0, 3.2]]:
		_prop(road, "Barrel", _lane_point(float(spot[0])) + Vector3(float(spot[1]), 0, 0), _rng.randf() * TAU)
	_prop(road, "Stall_Cart_Empty", _lane_point(44.0) + Vector3(-3.4, 0, 0), deg_to_rad(20.0))
	_prop(road, "Crate_Wooden", _lane_point(43.0) + Vector3(-2.6, 0, 0), deg_to_rad(-15.0))
	# two road fires: the eye has somewhere warm to go on the way in
	for fz in [52.0, 24.0]:
		var at := _lane_point(fz) + Vector3(-2.9 * CAMERA_SIDE, 0, 0)
		var fire = HearthFire.new().setup(true, 0.7, true, true, true, 2.6, 9.0)
		fire.position = at
		road.add_child(fire)
		braziers.append(at)


## Where the valley gives out: rocks, dead trees and ash drifts, thinning towards the road.
func _valley_edge() -> void:
	var edge := Node3D.new()
	edge.name = "ValleyEdge"
	add_child(edge)
	var kinds := ["rock", "rock_moss", "rock_small", "dead", "burnt", "stump"]
	for i in 26:
		var z := _rng.randf_range(GATE_Z + 8.0, START_Z + 8.0)
		var far := _rng.randf() < 0.65
		var x := _rng.randf_range(4.5, 11.0) * (-1.0 if far else 1.0) * CAMERA_SIDE
		var path: String = FOLIAGE % kinds[_rng.randi() % kinds.size()]
		if not ResourceLoader.exists(path):
			continue
		var node: Node3D = (load(path) as PackedScene).instantiate()
		node.position = _lane_point(z) + Vector3(x, 0, 0)
		node.rotation.y = _rng.randf() * TAU
		var s := _rng.randf_range(0.8, 1.7)
		node.scale = Vector3(s, s, s)
		edge.add_child(node)


## Between the lens and the lane: dark shapes he walks behind, the oldest trick in a side view.
func _foreground() -> void:
	var fg := Node3D.new()
	fg.name = "Foreground"
	add_child(fg)
	var dark := Visuals.mat(Color(0.05, 0.045, 0.04), 1.0)
	for spot in [[58.0, 1.6, 3.2], [37.0, 2.2, 2.6], [19.0, 1.4, 3.6]]:
		var at := _lane_point(float(spot[0])) + Vector3(5.6 * CAMERA_SIDE, 0, 0)
		_box(fg, Vector3(float(spot[2]), float(spot[1]), 0.6), at + Vector3(0, float(spot[1]) * 0.5, 0), dark)
	for z in [50.0, 30.0]:
		var path := FOLIAGE % "dead"
		if not ResourceLoader.exists(path):
			continue
		var tree: Node3D = (load(path) as PackedScene).instantiate()
		tree.position = _lane_point(z) + Vector3(6.4 * CAMERA_SIDE, 0, 0)
		tree.scale = Vector3(1.6, 1.8, 1.6)
		fg.add_child(tree)


## Ash in the air the whole way, and a low backlight from behind the strip so a character
## reads as a silhouette with a rim.
func _mood() -> void:
	for z in [54.0, 40.0, 26.0, 16.0]:
		var ash := Effects.ash_fall(Vector3(9, 5, 8), 70)
		ash.position = _lane_point(z) + Vector3(0, 6.0, 0)
		add_child(ash)
	# thick air: the strip fades out instead of ending in a hard horizon
	var env: Environment = day_night.env
	env.fog_density = 0.03
	env.fog_height = 6.0
	env.fog_height_density = 0.05
	env.fog_aerial_perspective = 0.85
	env.fog_sky_affect = 1.0   # the ground fades into the sky: no hard horizon line
	# dark ridges behind the strip, so the distance is shapes and not an empty band
	var ridge := Visuals.mat(Color(0.055, 0.05, 0.055), 1.0)
	for i in 10:
		var z := 4.0 + i * 9.0 + _rng.randf_range(-3.0, 3.0)
		var h := _rng.randf_range(9.0, 20.0)
		var w := _rng.randf_range(22.0, 40.0)
		_box(self, Vector3(w, h, 3.0), _lane_point(z) + Vector3(-78.0 * CAMERA_SIDE - _rng.randf_range(0.0, 26.0), h * 0.4, 0), ridge)
	var back := DirectionalLight3D.new()
	back.name = "Backlight"
	back.light_color = Color(0.72, 0.78, 1.0)
	back.light_energy = 1.5
	back.light_specular = 0.6
	back.shadow_enabled = false
	back.rotation_degrees = Vector3(-14.0, 90.0 * CAMERA_SIDE + 180.0, 0.0)   # from behind the strip, low
	add_child(back)


# --- Helpers ---------------------------------------------------------------------------------------

## The lane point at world z (the lane is roughly straight in z).
func _lane_point(z: float) -> Vector3:
	var best := lane.sample_baked(0.0)
	var length := lane.get_baked_length()
	var walked := 0.0
	while walked <= length:
		var p := lane.sample_baked(walked)
		if absf(p.z - z) < absf(best.z - z):
			best = p
		walked += 0.5
	return Vector3(best.x, 0.0, best.z)


func _box(root: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	root.add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	root.add_child(body)


func _prop(root: Node3D, model: String, pos: Vector3, yaw: float) -> void:
	var path: String = PROPS % model
	if not ResourceLoader.exists(path):
		return
	var node: Node3D = (load(path) as PackedScene).instantiate()
	node.position = pos
	node.rotation.y = yaw
	Visuals.no_small_shadows(node)
	root.add_child(node)
