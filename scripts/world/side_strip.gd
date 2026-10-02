extends Node3D
## The 2.5D test strip (v4): one continuous walk, no loading, from the ash-valley edge down to
## the Son Ocaq courtyard — about 250 m, paced in six stretches that alternate quiet and
## trouble (SECTIONS below):
##   valley   quiet     wind, ash, Közkale still burning on the far ridge
##   village  tension   an abandoned hamlet: a half-laid table, a door left open, Küllü
##                      standing out in the ash who do not come
##   fight 1  trouble   two Küllüler at a brazier that stands IN the road, so a blow along
##                      the lane drives them into the fire (scripts/side_mode.gd)
##   caravan  quiet     an overturned cart, its load spilled, its fire long cold
##   fight 2  trouble   a knife bandit and a club bandit, ending in the mercy moment
##   gate     relief    the gate, and the hub's warm courtyard at the end of it
##
## The courtyard IS the hub level, placed at the end of the strip; everything in front of it
## is dressed here, and ONLY what the side camera sees: a band either side of the lane, with a
## few foreground silhouettes between the lens and the lane for depth. Everything carries a
## visibility range, because 250 m of road would otherwise all draw at once.
##
## The lane is a straight Curve3D from the valley (south) to the gate (north): the camera
## rides beside it (scripts/camera/side_camera.gd) and the protagonist walks along it.
## Numbers: data/balance/side_view.json. Test content, not canon.

const HubLevel := preload("res://scripts/hub/hub_level.gd")
const Effects := preload("res://scripts/world/effects.gd")
const Visuals := preload("res://scripts/world/visuals.gd")
const HearthFire := preload("res://scripts/world/hearth_fire.gd")
const FOLIAGE := "res://assets/foliage/%s.scn"
const PROPS := "res://assets/props_mk/%s.gltf"

const START_Z := 250.0       # the valley edge
const GATE_Z := 12.0         # where the courtyard's gate passage begins
const CAMERA_SIDE := 1.0     # the camera stands on +X
const SEE := 58.0            # nothing draws further away than this
## Foreground silhouettes sit this far out from the lane: nearer than the lens at its closest,
## or the camera would stand inside one.
const FG_X := 4.4

## The strip, in the order he walks it. `at` is where a fight waits.
const SECTIONS := [
	{"id": "valley", "from": 250.0, "to": 206.0},
	{"id": "village", "from": 206.0, "to": 160.0},
	{"id": "fight1", "from": 160.0, "to": 130.0, "at": 145.0},
	{"id": "caravan", "from": 130.0, "to": 86.0},
	{"id": "fight2", "from": 86.0, "to": 56.0, "at": 70.0},
	{"id": "gate", "from": 56.0, "to": 2.0},
]

var hub: Node3D              # HubLevel: the courtyard at the end of the strip
var day_night                # forwarded from the hub, so there is one sky
var lane := Curve3D.new()
var player_spawn := Vector3(0, 0.2, START_Z - 2.0)
var fight1_at := Vector3(0, 0, 145.0)
var fight2_at := Vector3(0, 0, 70.0)
## Fires already burning in the world. A Küllü driven into one is gone for good.
var fires: Array = []        # [{"pos": Vector3, "radius": float}]
## The same fires as plain positions: chapter_base heals at one, like any hearth.
var braziers: Array = []
## Where the passive Küllüler of the village stand, out in the ash, watching.
var village_shades: Array = []
## Every mesh the camera may have to see through (scripts/camera/side_camera.gd). The ground
## and the road are left out: fading the floor he stands on helps nobody.
var occluders: Array = []
## Stretches that want their own framing (scripts/camera/side_camera.gd zones).
var camera_zones: Array = []
var _rng := RandomNumberGenerator.new()
var _road: Node3D


func build() -> void:
	_rng.seed = 20261002
	hub = HubLevel.new()
	hub.name = "SonOcaq"
	add_child(hub)
	hub.build()
	day_night = hub.day_night
	_build_lane()
	_ground()
	_road_bed()
	_valley()
	_village()
	_fight_one()
	_caravan()
	_fight_two()
	_approach()
	_foreground()
	_mood()
	player_spawn = lane.sample_baked(0.0) + Vector3(0, 0.3, 0)
	for fire in fires:
		braziers.append(fire["pos"])
	occluders = _collect_occluders()
	# three places want their own lens, all at the same angle, so each change reads as a lens
	# change and not as a different camera
	camera_zones = [
		{"from_z": -9.0, "to_z": 10.5, "distance": 7.4, "elevation": 12.0},
		{"from_z": 138.0, "to_z": 160.0, "distance": 8.6, "elevation": 11.0},
		{"from_z": 59.0, "to_z": 81.0, "distance": 8.6, "elevation": 11.0},
	]


func apply_quality(high: bool) -> void:
	hub.apply_quality(high)


func height_at(_x: float, _z: float) -> float:
	return 0.0


## The strip's spine: dead straight from the valley to the gate. A bend turns the lens with it
## and the frame starts reading as three-quarter, which is the one thing this view must not do.
func _build_lane() -> void:
	var z := START_Z
	while z >= 2.0:
		lane.add_point(Vector3(0, 0, z))
		z -= 24.0
	lane.add_point(Vector3(0, 0, 2.0))
	lane.bake_interval = 0.25


# --- The road itself ------------------------------------------------------------------------

## Ash-grey ground under the whole strip. The hub brings its own, but 250 m of road over
## nothing reads as a road hanging in the void.
func _ground() -> void:
	var g := MeshInstance3D.new()
	g.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(320.0, START_Z + 90.0)
	plane.material = Visuals.mat(Color(0.33, 0.325, 0.335), 1.0)   # ash lies like snow
	g.mesh = plane
	g.position = Vector3(-60.0 * CAMERA_SIDE, -0.02, (START_Z + 20.0) * 0.5)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g)
	# and something to stand on: the road is drawn with flat quads, which nothing collides with
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(plane.size.x, 2.0, plane.size.y)
	cs.shape = shape
	body.add_child(cs)
	body.position = g.position + Vector3(0, -1.0, 0)
	add_child(body)


## Trodden earth under the lane the whole way, a broken wall along the far side so the
## silhouettes have a backdrop, and fence posts on the near side, low enough to see over.
func _road_bed() -> void:
	_road = Node3D.new()
	_road.name = "Road"
	add_child(_road)
	var earth := Visuals.mat(Color(0.16, 0.135, 0.115), 1.0)   # trodden dark against the ash
	var stone := Visuals.mat(Color(0.33, 0.32, 0.31), 1.0)
	var wood := Visuals.mat(Color(0.26, 0.19, 0.13), 1.0)
	var z := START_Z
	while z > GATE_Z * 0.4:
		var quad := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(4.6, 3.15)
		q.material = earth
		quad.mesh = q
		quad.position = Vector3(0, 0.02, z - 1.5)
		quad.rotation = Vector3(-PI * 0.5, 0, 0)
		_limit(quad)
		_road.add_child(quad)
		z -= 3.0
	z = GATE_Z + 3.0
	while z < START_Z - 6.0:
		if _rng.randf() >= 0.22 and not _in_section(z, "village"):
			var h := _rng.randf_range(0.8, 1.9)
			_box(_road, Vector3(_rng.randf_range(2.0, 4.0), h, 0.5),
				Vector3(-3.6 * CAMERA_SIDE + _rng.randf_range(-0.3, 0.3), h * 0.5, z), stone)
		z += _rng.randf_range(3.5, 7.0)
	z = GATE_Z + 6.0
	while z < START_Z - 10.0:
		_box(_road, Vector3(0.18, _rng.randf_range(0.9, 1.3), 0.18),
			Vector3(2.9 * CAMERA_SIDE, 0.55, z), wood)
		z += _rng.randf_range(3.0, 5.0)


# --- a. The valley edge: quiet ---------------------------------------------------------------

## Where the valley gives out: rocks, dead trees and ash drifts — and Közkale still alight on
## the far ridge, the one warm thing in the distance and the reason the land is like this.
func _valley() -> void:
	var edge := Node3D.new()
	edge.name = "Valley"
	add_child(edge)
	var kinds := ["rock", "rock_moss", "rock_small", "dead", "burnt", "stump"]
	var s: Dictionary = SECTIONS[0]
	for i in 34:
		var z := _rng.randf_range(float(s["to"]) - 10.0, float(s["from"]) + 8.0)
		# the near side has to stay INSIDE the lens (it stands 6.5-9.5 m out), or the rock is
		# not foreground, it is in the camera
		var far := _rng.randf() < 0.7
		var x := (-_rng.randf_range(6.0, 15.0) if far else _rng.randf_range(3.4, 4.6)) * CAMERA_SIDE
		_scatter(edge, FOLIAGE % kinds[_rng.randi() % kinds.size()], Vector3(x, 0, z),
			_rng.randf_range(0.8, 1.7))
	_kozkale()


## Közkale, far off on the ridge and burning: a dark keep, a glow behind its walls and a smoke
## column leaning in the wind. It stands on the far side, so it is in frame the whole walk.
func _kozkale() -> void:
	var keep := Node3D.new()
	keep.name = "Kozkale"
	keep.position = Vector3(-88.0 * CAMERA_SIDE, 0, 232.0)
	add_child(keep)
	var dark := Visuals.mat(Color(0.045, 0.042, 0.05), 1.0)
	# It stands far out on the ridge, so only what rises clear of the fog layer is ever seen:
	# the walls are a dark band and the towers are the shape you recognise it by.
	_box(keep, Vector3(64, 34, 18), Vector3(0, 17, 0), dark, false)
	for t in [[-23.0, 56.0], [3.0, 70.0], [25.0, 50.0]]:
		_box(keep, Vector3(12, float(t[1]), 12), Vector3(float(t[0]), float(t[1]) * 0.5, -2.0), dark, false)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.45, 0.15)
	# it lights itself and nothing else: a fire 90 m away that warms the whole valley would
	# undo the one rule the look runs on, which is that warmth is local
	glow.light_energy = 9.0
	glow.omni_range = 34.0
	glow.shadow_enabled = false
	glow.position = Vector3(0, 58, 2)
	keep.add_child(glow)
	# a band of fire along the top of the wall: at this distance the particles are a smudge,
	# and it is this that says "burning" rather than "a dark shape"
	var burning := StandardMaterial3D.new()
	burning.albedo_color = Color(1.0, 0.42, 0.12)
	burning.emission_enabled = true
	burning.emission = Color(1.0, 0.45, 0.14)
	burning.emission_energy_multiplier = 7.0
	burning.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_box(keep, Vector3(58, 2.2, 6), Vector3(0, 35, 0), burning, false)
	var fire := Effects.fire(16.0, 64)
	fire.position = Vector3(0, 66, 0)
	keep.add_child(fire)
	var smoke := Effects.smoke_burst(26, 2.0, 9.0, 9.0)
	smoke.position = Vector3(0, 76, 0)
	smoke.emitting = true
	keep.add_child(smoke)
	# the one thing on the horizon that must never be culled: it is why the land is like this
	for mi: MeshInstance3D in keep.find_children("*", "MeshInstance3D", true, false):
		mi.visibility_range_end = 0.0


# --- b. The abandoned village: tension -------------------------------------------------------

## Four flat-roofed houses on the far side of the road, one with its door standing open and a
## table still half laid inside it, and three Küllüler out in the ash who never come closer.
## Nothing here attacks: the stretch is only meant to be read.
func _village() -> void:
	var v := Node3D.new()
	v.name = "Village"
	add_child(v)
	var plaster := Visuals.mat(Color(0.37, 0.35, 0.32), 0.95)
	var stone := Visuals.mat(Color(0.3, 0.29, 0.28), 1.0)
	var wood := Visuals.mat(Color(0.22, 0.16, 0.11), 1.0)
	var at := [[200.0, 7.5, 3.4], [188.0, 6.0, 2.8], [174.0, 8.0, 3.8], [165.0, 5.5, 2.6]]
	for i in at.size():
		var z := float(at[i][0])
		var w := float(at[i][1])
		var h := float(at[i][2])
		var x := -7.5 * CAMERA_SIDE - _rng.randf_range(0.0, 2.0)
		_box(v, Vector3(w, h, 6.0), Vector3(x, h * 0.5, z), plaster)       # the house
		_box(v, Vector3(w + 0.7, 0.35, 6.7), Vector3(x, h + 0.17, z), stone)  # the flat roof
		_box(v, Vector3(w + 1.4, 0.5, 0.5), Vector3(x + w * 0.5 + 0.7, 0.25, z), stone)  # a terrace
		# a dark doorway facing the road
		_box(v, Vector3(0.3, 2.0, 1.1), Vector3(x + w * 0.5 - 0.1, 1.0, z + 1.2),
			Visuals.mat(Color(0.03, 0.03, 0.035), 1.0))
	# the one door left open, and the table behind it, still laid for a meal nobody ate
	var door_z := 188.0
	var door_x := -7.5 * CAMERA_SIDE + 3.0
	_box(v, Vector3(0.1, 1.95, 0.95), Vector3(door_x + 0.42, 0.98, door_z + 1.9), wood)
	_prop(v, "Table_Large", Vector3(door_x - 1.6, 0, door_z + 1.2), deg_to_rad(8.0))
	_prop(v, "Stool", Vector3(door_x - 2.6, 0, door_z + 1.9), 0.0)
	_prop(v, "Chair_1", Vector3(door_x - 0.7, 0, door_z + 0.4), deg_to_rad(150.0))
	for d in [[-2.0, 1.0], [-1.2, 1.5], [-1.6, 0.7]]:
		_prop(v, "Table_Plate", Vector3(door_x + float(d[0]), 0.78, door_z + float(d[1])), _rng.randf() * TAU)
	_prop(v, "Mug", Vector3(door_x - 1.0, 0.78, door_z + 1.7), 0.0)
	_prop(v, "CandleStick", Vector3(door_x - 1.6, 0.78, door_z + 1.2), 0.0)
	# a lamp still alight over the open door: the only warm thing in the village
	var lamp = HearthFire.new().setup(true, 0.22, false, true, false, 0.9, 5.5)
	lamp.position = Vector3(door_x + 0.3, 2.1, door_z + 1.9)
	v.add_child(lamp)
	# and the three of them, standing out in the ash where the light does not reach
	for spot in [[198.0, -15.0], [181.0, -19.0], [170.0, -13.5]]:
		village_shades.append(Vector3(float(spot[1]) * CAMERA_SIDE, 0, float(spot[0])))


# --- c. Fight one: the Küllüler and the brazier ----------------------------------------------

## A brazier burning IN the road, with the two of them on either side of it. Everything a blow
## does here runs along the lane, so "knock him into the fire" is a thing the player can see
## and then do on purpose.
func _fight_one() -> void:
	var f := Node3D.new()
	f.name = "FightOne"
	add_child(f)
	# The brazier stands in the road BEYOND them, between the two of them and the gate: he
	# comes down the road, they are between him and it, and every blow he lands throws them
	# the way he is going — which is into the fire.
	fight1_at = Vector3(0, 0, 149.0)
	var fire = HearthFire.new().setup(true, 1.05, true, true, true, 3.4, 11.0)
	fire.position = Vector3(0, 0, 144.5)
	f.add_child(fire)
	fires.append({"pos": fire.position, "radius": 1.3})
	var ring := Visuals.mat(Color(0.26, 0.25, 0.24), 1.0)
	for i in 10:
		var a := TAU * i / 10.0
		_box(f, Vector3(0.5, 0.35, 0.5), Vector3(sin(a) * 1.5, 0.17, 144.5 + cos(a) * 1.5), ring)
	_prop(f, "Crate_Wooden", Vector3(-3.2, 0, 150.0), deg_to_rad(20.0))
	_prop(f, "Barrel", Vector3(3.0, 0, 139.0), 0.0)


# --- d. The caravan wreck: quiet --------------------------------------------------------------

## What is left of a caravan that did not get through: the cart on its side, the load spilled
## across the road, the fire they lit beside it long cold. Nobody is here to explain it.
func _caravan() -> void:
	var c := Node3D.new()
	c.name = "Caravan"
	add_child(c)
	var cart := _prop(c, "Stall_Cart_Empty", Vector3(-2.7, 0.9, 106.0), deg_to_rad(12.0))
	if cart != null:
		cart.rotation = Vector3(0, deg_to_rad(12.0), deg_to_rad(104.0))   # on its side
	for s in [[-1.3, 103.5], [0.9, 108.5], [-0.4, 110.5], [2.1, 101.0]]:
		_prop(c, "Crate_Wooden", Vector3(float(s[0]), 0, float(s[1])), _rng.randf() * TAU)
	for s in [[1.6, 109.5], [-2.9, 104.5]]:
		_prop(c, "Barrel", Vector3(float(s[0]), 0, float(s[1])), _rng.randf() * TAU)
	_prop(c, "FarmCrate_Apple", Vector3(-1.9, 0, 101.5), deg_to_rad(40.0))
	_prop(c, "Bag", Vector3(0.6, 0, 100.2), deg_to_rad(70.0))
	_prop(c, "Pot_1", Vector3(2.2, 0, 99.0), 0.0)
	_prop(c, "Rope_1", Vector3(-0.8, 0, 97.6), deg_to_rad(20.0))
	# the fire they sat at, gone out: ash, a ring of stones, no light
	var cold = HearthFire.new().setup(false, 0.8, true, false, false, 0.0, 0.0)
	cold.position = Vector3(-3.1, 0, 97.0)
	c.add_child(cold)
	var kinds := ["rock", "rock_small", "dead", "burnt"]
	for i in 16:
		var z := _rng.randf_range(88.0, 128.0)
		var x := (-_rng.randf_range(6.0, 14.0) if _rng.randf() < 0.65 else _rng.randf_range(3.4, 4.6)) * CAMERA_SIDE
		_scatter(c, FOLIAGE % kinds[_rng.randi() % kinds.size()], Vector3(x, 0, z),
			_rng.randf_range(0.8, 1.6))


# --- e. Fight two: the bandits -----------------------------------------------------------------

## A camp they set across the road, with their own small fire: the second fight, and the one
## that ends in a choice rather than a kill.
func _fight_two() -> void:
	var f := Node3D.new()
	f.name = "FightTwo"
	add_child(f)
	fight2_at = Vector3(0, 0, 70.0)
	var fire = HearthFire.new().setup(true, 0.7, true, true, true, 2.6, 9.0)
	fire.position = Vector3(-3.0 * CAMERA_SIDE, 0, 74.0)
	f.add_child(fire)
	fires.append({"pos": fire.position, "radius": 1.6})
	_prop(f, "Stall_Cart_Empty", Vector3(-3.6, 0, 65.0), deg_to_rad(28.0))
	_prop(f, "Crate_Wooden", Vector3(-2.4, 0, 63.6), deg_to_rad(-15.0))
	_prop(f, "Barrel", Vector3(2.8, 0, 76.0), 0.0)
	_prop(f, "Bucket_Wooden_1", Vector3(-2.2, 0, 76.5), 0.0)


# --- f. The approach and the gate -------------------------------------------------------------

## The last stretch before the walls: the road tidies itself, a lamp or two, and the gate.
func _approach() -> void:
	var a := Node3D.new()
	a.name = "Approach"
	add_child(a)
	for z in [50.0, 32.0, 20.0]:
		var fire = HearthFire.new().setup(true, 0.55, false, true, false, 1.8, 7.5)
		fire.position = Vector3(-3.1 * CAMERA_SIDE, 1.9, z)
		a.add_child(fire)
		fires.append({"pos": fire.position, "radius": 1.2})
	_prop(a, "Barrel", Vector3(2.9, 0, 44.0), 0.0)
	_prop(a, "Crate_Wooden", Vector3(-3.0, 0, 37.0), deg_to_rad(10.0))
	for i in 12:
		var z := _rng.randf_range(16.0, 54.0)
		var x := (-_rng.randf_range(6.0, 13.0) if _rng.randf() < 0.7 else _rng.randf_range(3.4, 4.6)) * CAMERA_SIDE
		_scatter(a, FOLIAGE % ["rock", "rock_small", "stump"][_rng.randi() % 3], Vector3(x, 0, z),
			_rng.randf_range(0.7, 1.4))


# --- Depth and mood ----------------------------------------------------------------------------

## Between the lens and the lane: dark shapes he walks behind, the oldest trick in a side view.
## None of them sit over a fight — a foreground mass there hides the one thing worth watching.
func _foreground() -> void:
	var fg := Node3D.new()
	fg.name = "Foreground"
	add_child(fg)
	var dark := Visuals.mat(Color(0.05, 0.045, 0.04), 1.0)
	fg.set_meta("no_shadow", true)
	for spot in [[243.0, 1.6, 3.2], [224.0, 2.2, 2.6], [198.0, 1.4, 3.6], [178.0, 2.0, 3.0],
			[124.0, 1.7, 3.4], [103.0, 2.3, 2.4], [92.0, 1.5, 3.0], [46.0, 1.8, 3.2],
			[28.0, 1.4, 3.6]]:
		var h := float(spot[1])
		_box(fg, Vector3(float(spot[2]), h, 0.6), Vector3(FG_X * CAMERA_SIDE, h * 0.5, float(spot[0])), dark)
	for z in [236.0, 212.0, 168.0, 118.0, 96.0, 40.0]:
		_scatter(fg, FOLIAGE % "dead", Vector3((FG_X + 0.8) * CAMERA_SIDE, 0, z), 1.7)
	# real rock between the plain slabs, so the near edge is not all boxes
	for z in [247.0, 216.0, 184.0, 136.0, 112.0, 60.0, 34.0]:
		_scatter(fg, FOLIAGE % "rock", Vector3((FG_X - 0.3) * CAMERA_SIDE, -0.4, z),
			_rng.randf_range(1.9, 2.8))
	# nothing in the foreground casts: these stand between the lens and the lane, and their
	# shadows would lie right across the ground he walks on
	for mi: MeshInstance3D in fg.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Ash in the air the whole way, thick fog so the strip fades out instead of ending in a hard
## horizon, dark ridges behind it, and a low backlight from behind so a body reads as a
## silhouette with a rim.
func _mood() -> void:
	var z := 20.0
	while z < START_Z:
		var ash := Effects.ash_fall(Vector3(9, 5, 8), 70)
		ash.position = Vector3(0, 6.0, z)
		_limit(ash)
		add_child(ash)
		z += 24.0
	var env: Environment = day_night.env
	env.fog_density = 0.028
	env.fog_height = 6.0
	env.fog_height_density = 0.05
	env.fog_aerial_perspective = 0.85
	env.fog_sky_affect = 1.0   # the ground fades into the sky: no hard horizon line
	# and it fades into the colour of that sky, or the distance ends in a pale wall under a
	# dark one, which is the hard line all over again
	env.fog_light_color = Color(0.27, 0.23, 0.25)
	# Ridges close enough to still read through the fog, in two ranks: without them the fog
	# ends in a flat line and the valley has no far side.
	var ridge := Visuals.mat(Color(0.075, 0.07, 0.078), 1.0)
	var far_ridge := Visuals.mat(Color(0.05, 0.047, 0.055), 1.0)
	for i in 34:
		var rz := 4.0 + i * 8.0 + _rng.randf_range(-3.0, 3.0)
		var h := _rng.randf_range(7.0, 15.0)
		if rz > 196.0 and rz < 250.0:
			continue          # leave the horizon clear where Közkale stands
		_box(self, Vector3(_rng.randf_range(16.0, 30.0), h, 3.0),
			Vector3(-44.0 * CAMERA_SIDE - _rng.randf_range(0.0, 12.0), h * 0.35, rz), ridge, false)
		if i % 2 == 0:
			var h2 := _rng.randf_range(16.0, 28.0)
			_box(self, Vector3(_rng.randf_range(26.0, 44.0), h2, 3.0),
				Vector3(-78.0 * CAMERA_SIDE - _rng.randf_range(0.0, 20.0), h2 * 0.4, rz), far_ridge, false)
	var back := DirectionalLight3D.new()
	back.name = "Backlight"
	back.light_color = Color(0.72, 0.78, 1.0)
	back.light_energy = 1.5
	back.light_specular = 0.6
	back.shadow_enabled = false
	back.rotation_degrees = Vector3(-14.0, 90.0 * CAMERA_SIDE + 180.0, 0.0)   # from behind, low
	add_child(back)
	# A faint moon from over the lens, steep enough that every shadow falls AWAY from the
	# camera. Without one shadow in the world nothing touches the ground and every crate and
	# barrel floats; with it coming from behind the strip instead, the long shadows lay
	# themselves across the road he walks on.
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.62, 0.70, 0.95)
	moon.light_energy = 0.32
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 42.0
	moon.rotation_degrees = Vector3(-58.0, 90.0 * CAMERA_SIDE, 0.0)
	add_child(moon)


# --- Helpers ---------------------------------------------------------------------------------

func _in_section(z: float, id: String) -> bool:
	for s in SECTIONS:
		if s["id"] == id:
			return z <= float(s["from"]) and z >= float(s["to"])
	return false


## Walls, arches, roofs, carts — anything solid the lens can end up behind.
func _collect_occluders() -> Array:
	var out: Array = []
	for root in [hub, get_node_or_null("Village"), get_node_or_null("Foreground"),
			get_node_or_null("Caravan")]:
		if root == null:
			continue
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			if mi.get_aabb().size.y >= 0.6:
				out.append(mi)
	return out


## 250 m of strip cannot all draw at once; nothing is visible past the fog anyway.
func _limit(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).visibility_range_end = SEE
		(node as GeometryInstance3D).visibility_range_end_margin = 6.0
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		mi.visibility_range_end = SEE
		mi.visibility_range_end_margin = 6.0


func _box(root: Node3D, size: Vector3, pos: Vector3, mat: Material, solid := true) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	_limit(mi)
	root.add_child(mi)
	if not solid:
		return
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	root.add_child(body)


func _prop(root: Node3D, model: String, pos: Vector3, yaw: float) -> Node3D:
	var path: String = PROPS % model
	if not ResourceLoader.exists(path):
		return null
	var node: Node3D = (load(path) as PackedScene).instantiate()
	node.position = pos
	node.rotation.y = yaw
	Visuals.no_small_shadows(node)
	_limit(node)
	root.add_child(node)
	return node


func _scatter(root: Node3D, path: String, pos: Vector3, size: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var node: Node3D = (load(path) as PackedScene).instantiate()
	node.position = pos
	node.rotation.y = _rng.randf() * TAU
	node.scale = Vector3(size, size, size)
	_limit(node)
	root.add_child(node)
