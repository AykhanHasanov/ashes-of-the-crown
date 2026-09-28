extends Node3D
## Son Ocaq, blockout (STORY_BIBLE §3.9): a village grown around an old Caucasus / Silk Road
## caravanserai; the last hearth burns in its courtyard. Rooms open onto a tight courtyard
## behind an arched gallery (MegaKit arches on brick piers) on all four sides — the gate is
## in the middle of the south side — so every door is seen from the hearth. Flat roofs
## everywhere; the north side has a second storey for the caravanserai silhouette (not
## enterable). One modular room (MegaKit wall modules on the courtyard face, a plaster mass
## behind) with variants. Kemal's smithy and Gülçin's bakery stand outside the gate (day
## workplaces); the outer village is dark flat-roofed houses (no interaction).
## Layout from data/hub/son_ocaq.json (HubData); only the doors are live (scripts/hub/door.gd).
## Provides what chapter_base expects of a level: build, player_spawn, braziers,
## apply_quality — and a DayNight that does not run by itself (the hub's clock is stepped).

const HubData := preload("res://scripts/hub/hub_data.gd")
const Door := preload("res://scripts/hub/door.gd")
const DayNight := preload("res://scripts/world/day_night.gd")
const Effects := preload("res://scripts/world/effects.gd")
const KIT := "res://assets/village_mk/%s.gltf"
const FAMILY := [
	["Wall_Plaster_Door_Round", "Wall_Plaster_Window_Wide_Round", "Window_Wide_Round1"],
	["Wall_Plaster_Door_Round", "Wall_Plaster_Window_Thin_Round", "Window_Thin_Round1"],
	["Wall_UnevenBrick_Door_Round", "Wall_UnevenBrick_Window_Wide_Round", "Window_Wide_Round1"],
]
const MODULE := 2.0          # MegaKit wall module width (and storey 3 m)
const ROOM_H := 3.3
const ROOM_DEPTH := 5.0
const GALLERY := 2.2         # depth of the arched gallery in front of the rooms
const NORTH_Z := -6.0        # room facades (the courtyard, gallery included, is 16 × 12 m)
const SIDE_X := 8.0
const SOUTH_Z := 6.0
const GATE_HALF := 2.0
const EYVAN_H := 7.0         # the entrance portal rises above the 3.3 m roofs

var player_spawn := Vector3(0, 0.1, 2.4)   # the open courtyard: sky, hearth and upper storey in view
var braziers: Array = []
var day_night
var hearth_pos := Vector3(0, 0, -0.8)   # a little north of centre: the gate side stays open
var hearth_radius := 1.7
var gate_pos := Vector3(0, 0, SOUTH_Z + ROOM_DEPTH - 0.4)
var doors: Dictionary = {}           # door id -> Door
var fronts: Dictionary = {}          # place id -> {door: Transform3D, window: Transform3D}
var hearth_fire: Node3D
var hearth_light: OmniLight3D
var far_light: OmniLight3D

var _plaster: StandardMaterial3D
var _brick: StandardMaterial3D
var _stone: StandardMaterial3D
var _dark: StandardMaterial3D
var _cache := {}


func build() -> void:
	day_night = DayNight.new()
	add_child(day_night)
	day_night.paused = true
	_materials()
	_ground()
	for p in HubData.places():
		_room(p, place_transform(p))
	_south_fillers()
	_corners()
	_gallery()
	_upper_storey()
	_hearth()
	_outer_village()
	var ash := Effects.ash_fall(Vector3(16, 6, 16), 60)
	ash.position = Vector3(0, 8, 0)
	add_child(ash)
	# Közkale burns on the horizon, always (STORY_BIBLE §8) — placeholder until the mood pass
	var far := Effects.fire(14.0, 40)
	far.position = Vector3(-60, 22, -260)
	add_child(far)
	far_light = OmniLight3D.new()
	far_light.light_color = Color(1.0, 0.45, 0.15)
	far_light.light_energy = 3.0
	far_light.omni_range = 120.0
	far_light.position = far.position + Vector3(0, 10, 0)
	add_child(far_light)


## The night door conversation: the courtyard almost dark (sun/moon, sky and ambient down,
## the hearth's and Közkale's light off, every other door's strip hidden); the only warm
## light is the strip under `door`. null restores the night.
func set_door_scene(door) -> void:
	var on: bool = door != null
	day_night.mood_scale = 0.05 if on else 1.0
	day_night.set_hour(day_night.hour)
	for l in [hearth_light, far_light]:
		l.visible = not on
	for d in doors.values():
		d.set_strip_hidden(on and d != door)
		d.set_key_light(on and d == door)


func apply_quality(high: bool) -> void:
	if day_night:
		day_night.apply_quality(high)


## Where a room or building stands: origin at the middle of its courtyard face, +Z facing out
## of the room (into the courtyard / the street).
static func place_transform(p: Dictionary) -> Transform3D:
	if p["kind"] == "outside":
		var at: Array = p["at"]
		return Transform3D(Basis(Vector3.UP, deg_to_rad(float(p.get("face", 0.0)))), Vector3(float(at[0]), 0, float(at[1])))
	var slot := int(p["slot"])
	match p["side"]:
		"n":
			return Transform3D(Basis.IDENTITY, Vector3(-6.0 + 4.0 * slot, 0, NORTH_Z))
		"w":
			return Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-SIDE_X, 0, -4.0 + 4.0 * slot))
		"e":
			return Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(SIDE_X, 0, -4.0 + 4.0 * slot))
		"s":
			return Transform3D(Basis(Vector3.UP, PI), Vector3(-5.0 + 10.0 * slot, 0, SOUTH_Z))
	return Transform3D.IDENTITY


## Where someone stands by day: in front of the door of `place_id`, under the gallery's edge.
func stand_point(place_id: String) -> Variant:
	if not fronts.has(place_id):
		return null
	var door: Transform3D = fronts[place_id]["door"]
	var out: float = GALLERY + 0.6 if HubData.place(place_id).get("kind", "") == "room" else 1.8
	return door.origin + door.basis.z * out + door.basis.x * 0.6


# --- The room module ---------------------------------------------------------------------------

func _room(p: Dictionary, xf: Transform3D) -> void:
	var variant: Array = FAMILY[int(p.get("variant", 0)) % FAMILY.size()]
	var root := Node3D.new()
	root.name = "Place_" + p["id"]
	root.transform = xf
	add_child(root)
	var door_left := int(p.get("variant", 0)) != 1
	var door_x := -MODULE * 0.5 if door_left else MODULE * 0.5
	var window_x := -door_x
	_put(root, variant[0], Vector3(door_x, 0, 0))
	_put(root, variant[1], Vector3(window_x, 0, 0))
	_put(root, variant[2], Vector3(window_x, 0, 0))
	# The room behind: a plaster mass under the flat roof
	_box(root, Vector3(MODULE * 2.0, ROOM_H, ROOM_DEPTH), Vector3(0, ROOM_H * 0.5, -ROOM_DEPTH * 0.5 - 0.3), _plaster)
	# What an open door or the window shows: dark inside (lit later by hub growth)
	var inside := _quad(root, Vector2(1.1, 2.3), Vector3(door_x, 1.15, -0.28), "Inside")
	var pane := _quad(root, Vector2(1.2, 1.1), Vector3(window_x, 1.7, -0.28), "Window")
	inside.set_meta("place", p["id"])
	pane.set_meta("place", p["id"])
	var d = Door.new()
	d.name = "Door_" + p["door"]
	d.setup(StringName(p["door"]), p["id"])
	d.position = Vector3(door_x, 0, 0)
	root.add_child(d)
	doors[p["door"]] = d
	fronts[p["id"]] = {"door": xf * Transform3D(Basis.IDENTITY, Vector3(door_x, 0, 0)),
		"window": xf * Transform3D(Basis.IDENTITY, Vector3(window_x, 0, 0))}
	if p["kind"] == "outside":
		# A flat roof with a parapet, and the trade in front
		_box(root, Vector3(MODULE * 2.0 + 0.4, 0.25, ROOM_DEPTH + 0.8), Vector3(0, ROOM_H + 0.12, -ROOM_DEPTH * 0.5), _brick)
		_box(root, Vector3(MODULE * 2.0 + 0.4, 0.4, 0.25), Vector3(0, ROOM_H + 0.45, 0.25), _brick)
		var prop := "res://assets/props_mk/Anvil.gltf" if p["id"] == "smithy" else "res://assets/props_mk/Stall_Empty.gltf"
		_prop(root, prop, Vector3(2.9, 0, 1.6), 0.0)


## The south side: the entrance portal (eyvan) in the middle — a tall arched frame rising
## above the roofs over a high vaulted passage — and plain wall beside the two south rooms.
func _south_fillers() -> void:
	var ph := EYVAN_H
	for s in [-1.0, 1.0]:
		# Plain wall between the south rooms and the corners
		_box(self, Vector3(1.0, ROOM_H, ROOM_DEPTH + 0.3), Vector3(s * (SIDE_X - 0.5), ROOM_H * 0.5, SOUTH_Z + ROOM_DEPTH * 0.5 + 0.15), _plaster)
		# The portal's piers (courtyard face) and the passage walls, full height
		_box(self, Vector3(1.0, ph, 1.2), Vector3(s * (GATE_HALF + 0.5), ph * 0.5, SOUTH_Z + 0.3), _stone)
		_box(self, Vector3(0.6, ph - 0.6, ROOM_DEPTH), Vector3(s * (GATE_HALF + 0.3), (ph - 0.6) * 0.5, SOUTH_Z + ROOM_DEPTH * 0.5 + 0.3), _brick)
		_box(self, Vector3(0.9, ph, 1.0), Vector3(s * (GATE_HALF + 0.45), ph * 0.5, SOUTH_Z + ROOM_DEPTH + 0.3), _stone)
	# The arch of the eyvan: a big MegaKit arch in the frame, the frame's top, the vault
	var arch := _model(KIT % "Wall_Arch")
	if arch:
		arch.scale = Vector3(GATE_HALF, (ph - 1.0) / 3.0, 1.0)
		arch.position = Vector3(0, 0, SOUTH_Z - 0.05)
		arch.rotation.y = PI
		add_child(arch)
	_box(self, Vector3(GATE_HALF * 2.0 + 2.0, 1.0, 1.2), Vector3(0, ph - 0.5, SOUTH_Z + 0.3), _stone)
	_box(self, Vector3(GATE_HALF * 2.0 + 2.4, 0.4, 1.4), Vector3(0, ph + 0.2, SOUTH_Z + 0.3), _brick)   # cornice
	_box(self, Vector3(GATE_HALF * 2.0, 0.4, ROOM_DEPTH), Vector3(0, ph - 0.6, SOUTH_Z + ROOM_DEPTH * 0.5 + 0.3), _brick)   # vault
	_box(self, Vector3(GATE_HALF * 2.0 + 1.8, 1.1, 1.0), Vector3(0, ph - 0.55, SOUTH_Z + ROOM_DEPTH + 0.3), _stone)   # outer lintel


## Solid blocks where the rows meet.
func _corners() -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var h := ROOM_H + (3.2 if sz < 0.0 else 0.0)
			_box(self, Vector3(ROOM_DEPTH + 0.3, h, ROOM_DEPTH + 0.3), Vector3(sx * (SIDE_X + ROOM_DEPTH * 0.5 + 0.15), h * 0.5,
				(NORTH_Z - ROOM_DEPTH * 0.5 - 0.15) if sz < 0.0 else (SOUTH_Z + ROOM_DEPTH * 0.5 + 0.15)), _plaster)


## The arched gallery on the north, west and east sides: brick piers, MegaKit arches between
## them and a flat roof back to the rooms. The south (gate) side is open to the sky.
func _gallery() -> void:
	var sides := [
		# [line origin, along axis, count of modules, rotation, start]
		[Vector3(0, 0, NORTH_Z + GALLERY), Vector3.RIGHT, 8, 0.0, -SIDE_X],
		[Vector3(-SIDE_X + GALLERY, 0, 0), Vector3.BACK, 6, PI * 0.5, NORTH_Z],
		[Vector3(SIDE_X - GALLERY, 0, 0), Vector3.BACK, 6, -PI * 0.5, NORTH_Z],
	]
	for side in sides:
		var line: Vector3 = side[0]
		var axis: Vector3 = side[1]
		var n: int = side[2]
		var start: float = side[4]
		for i in n + 1:
			var along := start + MODULE * i
			var pos := line + axis * along
			var is_gate: bool = absf(pos.x) < 0.1 and float(side[3]) == PI
			var at_corner := i == 0 or i == n
			if not is_gate and not at_corner and not _blocks_a_door(pos):
				_box(self, Vector3(0.34, 3.0, 0.34), pos + Vector3(0, 1.5, 0), _brick)
			var over_gate: bool = float(side[3]) == PI and absf(along + MODULE * 0.5) < GATE_HALF
			if i < n and not over_gate:
				var mid := line + axis * (along + MODULE * 0.5)
				var arch := _model(KIT % "Wall_Arch")
				if arch:
					arch.position = mid
					arch.rotation.y = side[3]
					add_child(arch)
		# The gallery roof, flush with the room roofs, and a parapet at its edge
		var length := MODULE * n
		var centre := line + axis * (start + length * 0.5)
		var inward: Vector3 = Basis(Vector3.UP, side[3]) * Vector3.BACK
		var roof_size := Vector3(length, 0.3, GALLERY + 0.3) if axis == Vector3.RIGHT else Vector3(GALLERY + 0.3, 0.3, length)
		_box(self, roof_size, centre - inward * (GALLERY * 0.5 - 0.15) + Vector3(0, 3.15, 0), _brick)
		var parapet := Vector3(length, 0.45, 0.25) if axis == Vector3.RIGHT else Vector3(0.25, 0.45, length)
		_box(self, parapet, centre + Vector3(0, 3.5, 0), _brick)
	# Corner squares of the gallery roof (north corners; the south side has no gallery)
	for sx in [-1.0, 1.0]:
		_box(self, Vector3(GALLERY, 0.3, GALLERY), Vector3(sx * (SIDE_X - GALLERY * 0.5), 3.15, NORTH_Z + GALLERY * 0.5), _brick)


## A pier here would stand in the line between the hearth and a courtyard door: leave it out
## (every door must be seen from the hearth).
func _blocks_a_door(at: Vector3) -> bool:
	var p := Vector2(at.x, at.z)
	var h := Vector2(hearth_pos.x, hearth_pos.z)
	for id in fronts:
		if HubData.place(id).get("kind", "") != "room":
			continue
		var door: Vector3 = (fronts[id]["door"] as Transform3D).origin
		var d := Vector2(door.x, door.z)
		if Geometry2D.get_closest_point_to_segment(p, h, d).distance_to(p) < 0.55:
			return true
	return false


## A second storey over the north rooms: windows onto the gallery roof, flat roof, parapet.
func _upper_storey() -> void:
	var root := Node3D.new()
	root.name = "UpperStorey"
	root.position = Vector3(0, ROOM_H, NORTH_Z)
	add_child(root)
	for i in 8:
		var x := -SIDE_X + MODULE * (i + 0.5)
		_put(root, "Wall_Plaster_Window_Thin_Round" if i % 2 == 0 else "Wall_Plaster_Straight", Vector3(x, 0, 0))
		if i % 2 == 0:
			_quad(root, Vector2(0.8, 1.2), Vector3(x, 1.6, -0.28), "UpperWindow")
	_box(root, Vector3(SIDE_X * 2.0, 3.1, ROOM_DEPTH), Vector3(0, 1.55, -ROOM_DEPTH * 0.5 - 0.3), _plaster)
	_box(root, Vector3(SIDE_X * 2.0 + 0.3, 0.45, 0.3), Vector3(0, 3.3, 0.05), _brick)


# --- Ground, hearth, village ---------------------------------------------------------------------

func _ground() -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(300, 1, 300)
	cs.shape = box
	cs.position.y = -0.5
	body.add_child(cs)
	add_child(body)
	var outside := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(300, 300)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/terrain/dirt_albedo_height.png")
	m.albedo_color = Color(0.62, 0.6, 0.58)
	m.uv1_scale = Vector3(60, 60, 1)
	plane.material = m
	outside.mesh = plane
	add_child(outside)
	var yard := MeshInstance3D.new()
	var yp := PlaneMesh.new()
	yp.size = Vector2(SIDE_X * 2.0, SOUTH_Z - NORTH_Z)
	yp.material = _stone
	yard.mesh = yp
	yard.position = Vector3(0, 0.02, 0)
	add_child(yard)


## The hearth: low and wide — one course of dressed stones around a bed of embers and logs,
## the flames rising above the rim, ash trodden into the ground around it. Placeholder
## flames until the mood pass.
func _hearth() -> void:
	var root := Node3D.new()
	root.name = "Hearth"
	root.position = hearth_pos
	add_child(root)
	var ash := MeshInstance3D.new()
	var ash_disc := CylinderMesh.new()
	ash_disc.top_radius = hearth_radius + 1.1
	ash_disc.bottom_radius = hearth_radius + 1.1
	ash_disc.height = 0.01
	var ash_mat := StandardMaterial3D.new()
	ash_mat.albedo_color = Color(0.16, 0.15, 0.14, 0.75)
	ash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ash_disc.material = ash_mat
	ash.mesh = ash_disc
	ash.position.y = 0.03
	root.add_child(ash)
	for i in 22:
		var a := TAU * i / 22.0
		var stone := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.44, 0.2, 0.34)
		bm.material = _stone
		stone.mesh = bm
		stone.position = Vector3(cos(a) * hearth_radius, 0.1, sin(a) * hearth_radius)
		stone.rotation.y = -a + PI * 0.5
		root.add_child(stone)
	var bed := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = hearth_radius - 0.15
	disc.bottom_radius = hearth_radius - 0.1
	disc.height = 0.08
	var embers := StandardMaterial3D.new()
	embers.albedo_color = Color(0.25, 0.08, 0.03)
	embers.emission_enabled = true
	embers.emission = Color(1.0, 0.32, 0.08)
	embers.emission_energy_multiplier = 1.6
	disc.material = embers
	bed.mesh = disc
	bed.position.y = 0.06
	root.add_child(bed)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.13, 0.08, 0.05)
	for i in 5:
		var log_mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.09
		cyl.bottom_radius = 0.11
		cyl.height = hearth_radius * 1.4
		cyl.material = wood
		log_mi.mesh = cyl
		log_mi.rotation = Vector3(deg_to_rad(80.0), TAU * i / 5.0, 0)
		log_mi.position = Vector3(0, 0.22, 0)
		root.add_child(log_mi)
	var glow := Effects.ember_field(Vector3(hearth_radius * 0.8, 0.3, hearth_radius * 0.8), 18)
	glow.position.y = 0.25
	root.add_child(glow)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = hearth_radius + 0.2
	shape.height = 0.3
	cs.shape = shape
	cs.position.y = 0.15
	body.add_child(cs)
	root.add_child(body)
	hearth_fire = Node3D.new()
	hearth_fire.name = "HearthFire"
	hearth_fire.position = hearth_pos
	add_child(hearth_fire)
	var fire := Effects.fire(2.4, 48)
	fire.position = Vector3(0, 0.5, 0)
	hearth_fire.add_child(fire)
	hearth_light = OmniLight3D.new()
	hearth_light.light_color = Color(1.0, 0.5, 0.2)
	hearth_light.light_energy = 3.4
	hearth_light.omni_range = 13.0
	hearth_light.position = Vector3(0, 1.8, 0)
	hearth_fire.add_child(hearth_light)
	braziers.append(hearth_pos)


## Dark flat-roofed houses round the caravanserai: background only.
func _outer_village() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1107
	for i in 16:
		var a := TAU * (float(i) + 0.5) / 16.0
		var r := rng.randf_range(24.0, 36.0)
		var pos := Vector3(sin(a) * r, 0, cos(a) * r)
		if pos.z > 10.0 and absf(pos.x) < 14.0:
			continue   # the street to the smithy and the bakery
		var size := Vector3(rng.randf_range(5.0, 9.0), rng.randf_range(2.8, 4.2), rng.randf_range(4.5, 7.5))
		var root := Node3D.new()
		root.position = pos
		root.rotation.y = atan2(-pos.x, -pos.z) + rng.randf_range(-0.25, 0.25)
		add_child(root)
		var mat := _plaster if rng.randf() < 0.5 else _brick
		_box(root, size, Vector3(0, size.y * 0.5, 0), mat)
		_box(root, Vector3(size.x + 0.2, 0.35, 0.22), Vector3(0, size.y + 0.17, size.z * 0.5), _brick)
		_quad(root, Vector2(1.0, 2.0), Vector3(rng.randf_range(-size.x * 0.3, size.x * 0.3), 1.0, size.z * 0.5 + 0.02), "OuterDoor").rotation.y = 0.0


# --- Helpers -------------------------------------------------------------------------------------

func _materials() -> void:
	_plaster = StandardMaterial3D.new()
	_plaster.albedo_texture = load("res://assets/village_mk/T_Plaster_BaseColor.png")
	_plaster.albedo_color = Color(0.8, 0.74, 0.66)
	_plaster.uv1_triplanar = true
	_plaster.uv1_scale = Vector3(0.35, 0.35, 0.35)
	_brick = StandardMaterial3D.new()
	_brick.albedo_texture = load("res://assets/village_mk/T_UnevenBrick_BaseColor.png")
	_brick.albedo_color = Color(0.9, 0.84, 0.76)
	_brick.uv1_triplanar = true
	_brick.uv1_scale = Vector3(0.5, 0.5, 0.5)
	_stone = StandardMaterial3D.new()
	_stone.albedo_texture = load("res://assets/village_mk/T_RockTrim_BaseColor.png")
	_stone.albedo_color = Color(0.72, 0.7, 0.68)
	_stone.uv1_triplanar = true
	_stone.uv1_scale = Vector3(0.4, 0.4, 0.4)
	_dark = StandardMaterial3D.new()
	_dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dark.albedo_color = Color(0.02, 0.018, 0.016)


func _put(root: Node3D, piece: String, pos: Vector3) -> void:
	var n := _model(KIT % piece)
	if n:
		n.position = pos
		root.add_child(n)


func _model(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		push_warning("HubLevel: missing " + path)
		return null
	if not _cache.has(path):
		_cache[path] = load(path)
	return (_cache[path] as PackedScene).instantiate()


func _prop(root: Node3D, path: String, pos: Vector3, yaw: float) -> void:
	var n := _model(path)
	if n:
		n.position = pos
		n.rotation.y = yaw
		root.add_child(n)


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


func _quad(root: Node3D, size: Vector2, pos: Vector3, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = _dark
	mi.position = pos
	root.add_child(mi)
	return mi
