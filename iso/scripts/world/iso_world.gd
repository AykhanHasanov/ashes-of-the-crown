extends Node3D
## The iso map: one continuous place, no loading, dressed only where the camera looks.
## Walking order (and screen order: the road climbs from the bottom right of the screen):
##   the valley road     rocks, dead trees, a waystone, Közkale's glow on the far side
##   the village edge    four abandoned houses, two of them roofless, a cart on its side
##   outside the gate    the smithy and the bakery, each with its fire
##   the eyvan gate      a tall pointed portal in the caravanserai's south wall
##   the courtyard       Son Ocak: a hearth in the middle, an arched gallery on all four sides,
##                       eight carved doors on the north and west rows — every one in sight of
##                       the hearth and of the camera
##
## Layout, top view (x east, z south). The camera stands to the south-east looking north-west,
## so the north and west rows face it and the south and east walls are the ones that fade.
##   caravanserai   x -15 … 15, z -15 … 15, gate in the south wall at x 0
##   court          x -7.6 … 7.6, z -7.6 … 7.6, hearth at the centre
##   road           from (26, 74) down to the gate
##
## Every built thing is IsoKit geometry wearing an IsoPalette material, every fire an IsoFire.
## Facts other systems read: player_spawn, fires (for the ground melt), doors (id → node),
## occluders (what the camera may fade), calm_zone (where the default gait is a walk).

const IsoKit := preload("res://iso/scripts/world/iso_kit.gd")
const IsoPalette := preload("res://iso/scripts/world/iso_palette.gd")
const IsoFire := preload("res://iso/scripts/world/iso_fire.gd")
const GROUND := preload("res://iso/shaders/iso_ground.gdshader")
const FOLIAGE := "res://assets/foliage/%s.scn"

const ROAD := [Vector2(27, 78), Vector2(22, 66), Vector2(15, 55), Vector2(8, 44), Vector2(3, 32),
	Vector2(0.5, 22), Vector2(0, 15), Vector2(0, 4)]
const HALF := 15.0            # the caravanserai's half width
const COURT := 7.6            # the open court's half width
const ROOM := 10.5            # where the room fronts stand
const ROOF_H := 3.9
const WALL_H := 5.2
## The doors of Son Ocak that the camera can see, and who is behind them on the slice's first
## night (STORY_SLICE S4). Eşref is still on Kartal Yamacı, so his room is dark.
const DOORS := [
	{"id": "door_ibrahim", "row": "north", "at": -6.0, "night": true},
	{"id": "door_ehliman", "row": "north", "at": -2.0, "night": true},
	{"id": "door_peri_nene", "row": "north", "at": 2.0, "night": true},
	{"id": "door_esref", "row": "north", "at": 6.0, "night": false},
	{"id": "door_sona", "row": "west", "at": -6.0, "night": true},
	{"id": "door_protagonist", "row": "west", "at": -2.0, "night": true},
	{"id": "door_domrul", "row": "west", "at": 2.0, "night": true},
	{"id": "door_nermin", "row": "west", "at": 6.0, "night": true},
]

var player_spawn := Vector3(25.5, 0.1, 74.0)
var fires: Array = []         # IsoFire nodes
var doors: Dictionary = {}    # id → {"node": Node3D, "strip": Node3D, "night": bool}
var occluders: Array = []     # MeshInstance3D the camera may fade
## What comes off when Aras is inside the walls: every roof, and the south and east sides
## (the ones between the lens and the court). Diablo's rule — inside, you see inside.
var cutaway: Array = []
var cut_roofs: Array = []
var calm_zone := AABB(Vector3(-HALF, -1, -HALF), Vector3(HALF * 2, 6, HALF * 2))
var hearth: Node3D
var ground_mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()
var _arch: Node3D             # everything the camera may need to see through


func build() -> void:
	_rng.seed = 7331
	_arch = Node3D.new()
	_arch.name = "Architecture"
	add_child(_arch)
	_ground()
	_valley()
	_village()
	_outside_gate()
	_caravanserai()
	_upload_ground()
	# only what wears the iso surface can dither itself away (the `fade` instance uniform)
	var surface := IsoPalette.SURFACE
	var all: Array = _arch.find_children("*", "MeshInstance3D", true, false)
	all.append_array(get_node("Valley").find_children("*", "MeshInstance3D", true, false))
	for mi: MeshInstance3D in all:
		var m := mi.material_override as ShaderMaterial
		if m != null and m.shader == surface:
			occluders.append(mi)


## Adds a piece and marks everything in it as part of the cutaway.
func _cut(parent: Node3D, piece: Node3D) -> void:
	parent.add_child(piece)
	for mi: MeshInstance3D in piece.find_children("*", "MeshInstance3D", true, false):
		cutaway.append(mi)


# --- Ground ------------------------------------------------------------------------------------

func _ground() -> void:
	var g := MeshInstance3D.new()
	g.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	plane.subdivide_width = 0
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = GROUND
	# the whole inside is flagged: the court and the gallery floors under the arcades
	ground_mat.set_shader_parameter("paved_rect", Vector4(-HALF + 0.9, -HALF + 0.9, HALF - 0.9, HALF - 0.9))
	plane.material = ground_mat
	g.mesh = plane
	g.position = Vector3(0, 0, 30)
	add_child(g)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(200, 2, 200)
	cs.shape = sh
	body.add_child(cs)
	body.position = Vector3(0, -1, 30)
	add_child(body)


## Fires and the road go to the ground shader once everything is built.
func _upload_ground() -> void:
	var pts: Array = []
	for p in ROAD:
		pts.append(Vector4(p.x, 0, p.y, 0))
	ground_mat.set_shader_parameter("road", pts)
	ground_mat.set_shader_parameter("road_count", pts.size())
	refresh_fires()


## Which fires are burning decides where the ash has melted. Call when one is lit or put out.
func refresh_fires() -> void:
	var f: Array = []
	for fire in fires:
		if fire.lit and f.size() < 12:
			var p: Vector3 = fire.global_position if fire.is_inside_tree() else fire.position
			f.append(Vector4(p.x, p.y, p.z, fire.melt_radius))
	ground_mat.set_shader_parameter("fires", f)
	ground_mat.set_shader_parameter("fire_count", f.size())


# --- The valley road ---------------------------------------------------------------------------

func _valley() -> void:
	var v := Node3D.new()
	v.name = "Valley"
	add_child(v)
	for i in 30:
		var t := _rng.randf()
		var p := _road_point(t * 0.55)
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var off := Vector3(side * _rng.randf_range(4.5, 14.0), 0, _rng.randf_range(-3.0, 3.0))
		if _rng.randf() < 0.62:
			var r := IsoKit.rock(Vector3(_rng.randf_range(0.8, 2.6), _rng.randf_range(0.5, 1.4), _rng.randf_range(0.8, 2.2)),
				_rng.randi(), "rubble" if _rng.randf() < 0.6 else "stone_dark")
			r.position = p + off
			v.add_child(r)
		else:
			var kind: String = ["dead", "burnt", "stump", "dead"][_rng.randi() % 4]
			_foliage(v, kind, p + off, _rng.randf_range(0.75, 1.15))
	# a waystone at the side of the road, half buried
	var stone := IsoKit.box(Vector3(0.6, 1.9, 0.45), "stone", Vector3(19.0, 0.8, 63.0))
	stone.rotation_degrees = Vector3(0, 30, 7)
	v.add_child(stone)


func _road_point(t: float) -> Vector3:
	var f := clampf(t, 0.0, 0.999) * (ROAD.size() - 1)
	var i := int(f)
	var a: Vector2 = ROAD[i]
	var b: Vector2 = ROAD[i + 1]
	var p := a.lerp(b, f - i)
	return Vector3(p.x, 0, p.y)


## A plant or a rock from the shared nature set, re-dressed in the palette so it reads as
## part of this world rather than of the kit it came from.
func _foliage(root: Node3D, kind: String, at: Vector3, size: float) -> void:
	var path := FOLIAGE % kind
	if not ResourceLoader.exists(path):
		return
	var node: Node3D = (load(path) as PackedScene).instantiate()
	node.position = at
	node.rotation.y = _rng.randf() * TAU
	node.scale = Vector3.ONE * size
	var mat := "rubble" if kind.begins_with("rock") else "wood"
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = IsoPalette.get_mat(mat)
	root.add_child(node)


# --- The village edge ----------------------------------------------------------------------------

func _village() -> void:
	var v := Node3D.new()
	v.name = "Village"
	_arch.add_child(v)
	# [x, z, width, depth, height, yaw, ruined]
	for h in [[22.0, 54.0, 6.0, 5.0, 3.2, 90.0, false], [24.0, 46.0, 5.0, 4.5, 3.0, 90.0, true],
			[4.0, 54.0, 6.5, 5.0, 3.4, -90.0, true], [0.0, 44.0, 5.5, 5.0, 3.1, -90.0, false]]:
		var house := IsoKit.house(float(h[2]), float(h[3]), float(h[4]), 0.5, 2, bool(h[6]))
		house.position = Vector3(float(h[0]), 0, float(h[1]))
		house.rotation_degrees.y = float(h[5])
		v.add_child(house)
	# a cart on its side in the ditch, its load long gone
	var cart := Node3D.new()
	cart.position = Vector3(13.5, 0, 40.0)
	cart.rotation_degrees = Vector3(0, 25, 0)
	v.add_child(cart)
	var bed := IsoKit.box(Vector3(1.6, 0.12, 2.8), "wood", Vector3(0, 0.75, 0))
	bed.rotation_degrees = Vector3(0, 0, 72)
	cart.add_child(bed)
	var wheel := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.55
	cyl.height = 0.12
	wheel.mesh = cyl
	wheel.material_override = IsoPalette.get_mat("wood")
	wheel.position = Vector3(0.9, 0.06, 1.6)
	cart.add_child(wheel)
	for i in 3:
		cart.add_child(IsoKit.box(Vector3(0.5, 0.4, 0.5), "wood", Vector3(-1.2 + i * 0.7, 0.2, -1.4 + i * 0.4), false))
	_foliage(v, "dead", Vector3(8.0, 0, 50.0), 1.8)
	_foliage(v, "burnt", Vector3(18.0, 0, 41.0), 1.6)


# --- Outside the gate: the smithy and the bakery ------------------------------------------------

func _outside_gate() -> void:
	var o := Node3D.new()
	o.name = "OutsideGate"
	_arch.add_child(o)
	# the smithy, east of the road: open to the road under one wide pointed arch
	var smithy := Node3D.new()
	smithy.position = Vector3(10.5, 0, 22.0)
	o.add_child(smithy)
	var front := IsoKit.arch_wall(6.0, 3.6, 0.5, [{"x": 1.0, "w": 4.0, "spring": 1.4}], "stone")
	front.position = Vector3(-3.0, 0, 2.25)
	front.rotation_degrees.y = 0
	smithy.add_child(front)
	smithy.add_child(IsoKit.box(Vector3(6.0, 3.6, 0.5), "stone", Vector3(0, 1.8, -2.25)))
	smithy.add_child(IsoKit.box(Vector3(0.5, 3.6, 4.0), "stone", Vector3(2.75, 1.8, 0)))
	smithy.add_child(IsoKit.box(Vector3(0.5, 3.6, 4.0), "stone", Vector3(-2.75, 1.8, 0)))
	smithy.add_child(IsoKit.box(Vector3(6.4, 0.32, 5.0), "roof", Vector3(0, 3.76, 0)))
	var forge := IsoFire.new().setup("forge", 2.6, 7.0, 2.2, false)
	forge.position = Vector3(-1.3, 0, -1.2)
	smithy.add_child(forge)
	fires.append(forge)
	smithy.add_child(IsoKit.box(Vector3(0.5, 0.5, 0.5), "wood", Vector3(0.9, 0.25, 0.6), false))
	smithy.add_child(IsoKit.box(Vector3(0.75, 0.22, 0.3), "iron", Vector3(0.9, 0.61, 0.6), false))
	# the bakery, west of the road: a closed house with its tandir glowing by the door
	var bakery := IsoKit.house(6.0, 5.0, 3.3, 0.35, 1)
	bakery.position = Vector3(-10.5, 0, 22.0)
	bakery.rotation_degrees.y = 90.0
	o.add_child(bakery)
	var tandir := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 0.75
	dome.height = 1.1
	dome.is_hemisphere = true
	tandir.mesh = dome
	tandir.material_override = IsoPalette.get_mat("plaster")
	tandir.position = Vector3(-6.6, 0, 24.5)
	o.add_child(tandir)
	var oven := IsoFire.new().setup("lamp", 1.8, 5.0, 1.6, false)
	oven.position = Vector3(-6.0, 0.25, 24.5)
	o.add_child(oven)
	fires.append(oven)


# --- Son Ocak: the caravanserai ---------------------------------------------------------------

func _caravanserai() -> void:
	var c := Node3D.new()
	c.name = "SonOcak"
	_arch.add_child(c)
	var t := 1.0
	# outer walls; the south one carries the eyvan
	c.add_child(IsoKit.box(Vector3(HALF * 2, WALL_H, t), "stone", Vector3(0, WALL_H * 0.5, -HALF + t * 0.5)))
	c.add_child(IsoKit.box(Vector3(t, WALL_H, HALF * 2), "stone", Vector3(-HALF + t * 0.5, WALL_H * 0.5, 0)))
	_cut(c, IsoKit.box(Vector3(t, WALL_H, HALF * 2), "stone", Vector3(HALF - t * 0.5, WALL_H * 0.5, 0)))
	var gate_w := 3.6
	var south := IsoKit.arch_wall(HALF * 2, WALL_H, t, [{"x": HALF - gate_w * 0.5, "w": gate_w, "spring": 2.4}], "stone")
	south.position = Vector3(-HALF, 0, HALF - t * 0.5)
	_cut(c, south)
	_eyvan(c, gate_w)
	# the galleries: an arcade on every side of the court, under one flat roof with the rooms
	_arcade(c, "north")
	_arcade(c, "south")
	_arcade(c, "west")
	_arcade(c, "east")
	for r in [[0.0, -(HALF + COURT) * 0.5, HALF * 2, HALF - COURT], [0.0, (HALF + COURT) * 0.5, HALF * 2, HALF - COURT],
			[-(HALF + COURT) * 0.5, 0.0, HALF - COURT, COURT * 2], [(HALF + COURT) * 0.5, 0.0, HALF - COURT, COURT * 2]]:
		var slab := IsoKit.box(Vector3(float(r[2]), 0.35, float(r[3])), "roof", Vector3(float(r[0]), ROOF_H + 0.17, float(r[1])))
		c.add_child(slab)
		for mi: MeshInstance3D in slab.find_children("*", "MeshInstance3D", true, false):
			cut_roofs.append(mi)
	# the room fronts and their doors
	_door_row(c, "north")
	_door_row(c, "west")
	# the hearth, the heart of it
	hearth = IsoFire.new().setup("hearth", 9.0, 17.0, 3.4, true)
	hearth.position = Vector3(0, 0, 0)
	c.add_child(hearth)
	fires.append(hearth)
	# a few things people left in the gallery
	c.add_child(IsoKit.box(Vector3(1.8, 0.45, 0.5), "wood", Vector3(-9.0, 0.23, -4.0), false))   # a bench
	c.add_child(IsoKit.box(Vector3(0.6, 0.8, 0.6), "wood", Vector3(9.0, 0.4, -5.5), false))     # a crate
	c.add_child(IsoKit.box(Vector3(0.6, 0.8, 0.6), "wood", Vector3(9.4, 0.4, -4.8), false))
	for i in 4:
		var lamp := IsoFire.new().setup("lamp", 0.9, 4.0, 0.0, false)
		lamp.position = [Vector3(-COURT - 0.5, 2.6, -4.0), Vector3(-COURT - 0.5, 2.6, 4.0),
			Vector3(-4.0, 2.6, -COURT - 0.5), Vector3(4.0, 2.6, -COURT - 0.5)][i]
		c.add_child(lamp)
		fires.append(lamp)


## The eyvan: a tall pointed portal projecting from the south wall, deeper than the wall,
## with a recessed frame — the one monumental thing in the place.
func _eyvan(c: Node3D, gate_w: float) -> void:
	var w := gate_w + 2.6
	var h := 7.0
	var front := IsoKit.arch_wall(w, h, 1.6, [{"x": 1.3, "w": gate_w, "spring": 3.2}], "stone")
	front.position = Vector3(-w * 0.5, 0, HALF + 0.3)
	_cut(c, front)
	# a band of darker stone framing the arch, and a parapet on top
	_cut(c, IsoKit.box(Vector3(w + 0.3, 0.45, 1.9), "stone_dark", Vector3(0, h + 0.22, HALF + 0.3), false))
	for side in [-1.0, 1.0]:
		_cut(c, IsoKit.box(Vector3(0.35, h, 0.4), "stone_dark", Vector3(side * (w * 0.5 + 0.05), h * 0.5, HALF + 1.15), false))
	# the passage ceiling, so the gate is a short dark tunnel and not a hole
	_cut(c, IsoKit.box(Vector3(gate_w + 0.2, 0.4, 2.6), "stone_dark", Vector3(0, IsoKit.opening_height(gate_w, 3.2) + 0.2, HALF - 0.4), false))


## One side's arcade: a wall of pointed arches along the edge of the court.
func _arcade(c: Node3D, side: String) -> void:
	var length := COURT * 2.0
	var bay := 2.53
	var n := int(length / bay)
	var openings: Array = []
	for i in n:
		if side == "south" and i == n / 2:
			continue    # the gate passage comes through here; it gets its own wide arch below
		openings.append({"x": i * bay + 0.35, "w": bay - 0.7, "spring": 1.65})
	if side == "south":
		openings.append({"x": (n / 2) * bay + 0.15, "w": bay - 0.3, "spring": 1.55})
	var wall := IsoKit.arch_wall(length, ROOF_H, 0.55, openings, "stone")
	match side:
		"north":
			wall.position = Vector3(-COURT, 0, -COURT)
		"south":
			wall.position = Vector3(-COURT, 0, COURT)
		"west":
			wall.position = Vector3(-COURT, 0, COURT)
			wall.rotation_degrees.y = 90.0
		"east":
			wall.position = Vector3(COURT, 0, COURT)
			wall.rotation_degrees.y = 90.0
	if side == "south" or side == "east":
		_cut(c, wall)
	else:
		c.add_child(wall)


## A row of rooms seen from the court: plain wall between carved doors, lintels over them,
## and for each door the strip of light that shows under it at night.
func _door_row(c: Node3D, row: String) -> void:
	var span := ROOM
	var door_w := 1.6       # the stone frame; the leaf itself is 1.1
	var frame_h := 3.0
	var at_list: Array = []
	for d in DOORS:
		if d["row"] == row:
			at_list.append(float(d["at"]))
	at_list.sort()
	var edges: Array = [-span]
	for a in at_list:
		edges.append(a - door_w * 0.5)
		edges.append(a + door_w * 0.5)
	edges.append(span)
	var t := 0.5
	for i in range(0, edges.size(), 2):
		var a: float = edges[i]
		var b: float = edges[i + 1]
		if b - a > 0.05:
			c.add_child(_row_box(row, (a + b) * 0.5, b - a, ROOF_H, ROOF_H * 0.5, t))
	for a in at_list:
		c.add_child(_row_box(row, a, door_w, ROOF_H - frame_h, frame_h + (ROOF_H - frame_h) * 0.5, t))
	for d in DOORS:
		if d["row"] != row:
			continue
		var door := IsoKit.carved_door()
		var a := float(d["at"])
		if row == "north":
			door.position = Vector3(a, 0, -ROOM + t * 0.5)
		else:
			door.position = Vector3(-ROOM + t * 0.5, 0, a)
			door.rotation_degrees.y = 90.0
		door.name = String(d["id"])
		c.add_child(door)
		doors[String(d["id"])] = {"node": door, "strip": _door_strip(door), "night": bool(d["night"])}


func _row_box(row: String, at: float, length: float, height: float, y: float, t: float) -> Node3D:
	if row == "north":
		return IsoKit.box(Vector3(length, height, t), "plaster", Vector3(at, y, -ROOM))
	return IsoKit.box(Vector3(t, height, length), "plaster", Vector3(-ROOM, y, at))


## The warm line under a closed, occupied door at night, and the small pool of light it puts
## on the flagstones in front of it. Off by day.
func _door_strip(door: Node3D) -> Node3D:
	var s := Node3D.new()
	s.name = "Strip"
	door.add_child(s)
	var line := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, 0.03, 0.04)
	line.mesh = bm
	line.material_override = IsoPalette.get_mat("door_light")
	line.position = Vector3(0, 0.015, 0.09)
	s.add_child(line)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.58, 0.28)
	light.light_energy = 1.1
	light.omni_range = 2.4
	light.omni_attenuation = 2.0
	light.light_volumetric_fog_energy = 1.4
	light.shadow_enabled = false
	light.position = Vector3(0, 0.12, 0.45)
	s.add_child(light)
	s.visible = false
	return s


## Night lights the strips of the rooms somebody is in; day puts them all out.
func set_night(on: bool) -> void:
	for id in doors:
		var d: Dictionary = doors[id]
		(d["strip"] as Node3D).visible = on and bool(d["night"])
