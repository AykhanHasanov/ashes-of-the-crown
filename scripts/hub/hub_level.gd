extends Node3D
## Son Ocaq, blockout (STORY_BIBLE §3.9): a village grown around an old caravanserai; the
## last hearth burns in its courtyard. Rooms open onto the courtyard on the north, west
## and east sides (the gate is south), so every door is seen from the hearth. One
## modular room (MegaKit wall modules on the courtyard face, a plaster mass behind, a
## flat roof) with variants; Kemal's smithy and Gülçin's bakery use the same module just
## outside the gate; the outer village is dark background houses (no interaction).
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
const MODULE := 2.0          # MegaKit wall module width
const ROOM_H := 3.4
const ROOM_DEPTH := 5.0
const NORTH_Z := -9.0        # courtyard faces
const SIDE_X := 11.0
const SOUTH_Z := 9.0

var player_spawn := Vector3(0, 0.1, 5.0)
var braziers: Array = []
var day_night
var hearth_pos := Vector3.ZERO
var gate_pos := Vector3(0, 0, SOUTH_Z - 0.4)
var doors: Dictionary = {}           # door id -> Door
var fronts: Dictionary = {}          # place id -> {door: Transform3D, window: Transform3D}
var hearth_fire: Node3D

var _plaster: StandardMaterial3D
var _brick: StandardMaterial3D
var _dark: StandardMaterial3D
var _cache := {}


func build() -> void:
	day_night = DayNight.new()
	add_child(day_night)
	day_night.paused = true
	_materials()
	_ground()
	for p in HubData.places():
		var xf := place_transform(p)
		_room(p, xf)
	_walls()
	_hearth()
	_outer_village()
	var ash := Effects.ash_fall(Vector3(24, 6, 24), 60)
	ash.position = Vector3(0, 8, 0)
	add_child(ash)
	# Közkale burns on the horizon, always (STORY_BIBLE §8)
	var far := Effects.fire(14.0, 40)
	far.position = Vector3(-60, 22, -260)
	add_child(far)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.45, 0.15)
	glow.light_energy = 3.0
	glow.omni_range = 120.0
	glow.position = far.position + Vector3(0, 10, 0)
	add_child(glow)


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
			return Transform3D(Basis.IDENTITY, Vector3(-8.0 + 4.0 * slot, 0, NORTH_Z))
		"w":
			return Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-SIDE_X, 0, -5.0 + 4.0 * slot))
		"e":
			return Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(SIDE_X, 0, -5.0 + 4.0 * slot))
	return Transform3D.IDENTITY


## Where a resident stands by day: in front of their door.
func stand_point(place_id: String) -> Variant:
	if not fronts.has(place_id):
		return null
	var door: Transform3D = fronts[place_id]["door"]
	return door.origin + door.basis.z * 1.8 + door.basis.x * 0.9


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
	# The room behind: a plaster mass, flat roof and a parapet (caravanserai roofs are flat)
	_box(root, Vector3(MODULE * 2.0, ROOM_H, ROOM_DEPTH), Vector3(0, ROOM_H * 0.5, -ROOM_DEPTH * 0.5 - 0.3), _plaster)
	_box(root, Vector3(MODULE * 2.0 + 0.1, 0.35, 0.3), Vector3(0, ROOM_H + 0.17, 0.05), _brick)
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
		_box(root, Vector3(MODULE * 2.0, 0.2, ROOM_DEPTH + 0.6), Vector3(0, ROOM_H + 0.1, -ROOM_DEPTH * 0.5), _brick)
		var prop := "res://assets/props_mk/Anvil.gltf" if p["id"] == "smithy" else "res://assets/props_mk/Stall_Empty.gltf"
		_prop(root, prop, Vector3(2.8, 0, 1.6), 0.0)


# --- Walls, ground, hearth, village ------------------------------------------------------------

func _walls() -> void:
	var h := ROOM_H + 0.6
	# Corners between the rows and the south wall with the gate (4 m opening)
	for s in [-1.0, 1.0]:
		_solid(Vector3(1.0 + ROOM_DEPTH, h, 2.2), Vector3(s * (SIDE_X - 0.5 + ROOM_DEPTH * 0.5), h * 0.5, NORTH_Z - ROOM_DEPTH * 0.5 + 0.8))
		_solid(Vector3(1.0 + ROOM_DEPTH, h, SOUTH_Z - 5.0), Vector3(s * (SIDE_X + ROOM_DEPTH * 0.5 - 0.5), h * 0.5, (SOUTH_Z + 5.0) * 0.5 + 1.0))
		_solid(Vector3(SIDE_X - 2.0 + ROOM_DEPTH, h, 1.2), Vector3(s * (2.0 + (SIDE_X - 2.0 + ROOM_DEPTH) * 0.5), h * 0.5, SOUTH_Z + 0.6))
		_solid(Vector3(0.9, h + 1.2, 1.6), Vector3(s * 2.45, (h + 1.2) * 0.5, SOUTH_Z + 0.6))
	_box(self, Vector3(5.8, 0.9, 1.6), Vector3(0, h + 0.75, SOUTH_Z + 0.6), _brick)   # lintel


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
	yp.material = _brick.duplicate()
	(yp.material as StandardMaterial3D).uv1_scale = Vector3(6, 5, 1)
	yard.mesh = yp
	yard.position = Vector3(0, 0.02, 0)
	add_child(yard)


func _hearth() -> void:
	var fire_base := _model("res://assets/quaternius/medieval_village_pack/Bonfire.glb")
	if fire_base:
		fire_base.scale = Vector3.ONE * 4.5
		add_child(fire_base)
	for i in 10:
		var a := TAU * i / 10.0
		var rock := _model("res://assets/foliage/rock_small.scn")
		if rock:
			rock.position = Vector3(cos(a), 0, sin(a)) * 2.3
			rock.rotation.y = a * 3.0
			rock.scale = Vector3.ONE * 0.62
			add_child(rock)
	hearth_fire = Node3D.new()
	hearth_fire.name = "HearthFire"
	add_child(hearth_fire)
	var fire := Effects.fire(1.8, 40)
	fire.position = Vector3(0, 0.3, 0)
	hearth_fire.add_child(fire)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.2)
	light.light_energy = 3.4
	light.omni_range = 16.0
	light.position = Vector3(0, 1.4, 0)
	hearth_fire.add_child(light)
	braziers.append(hearth_pos)


func _outer_village() -> void:
	var houses := ["house_a", "house_b", "house_small", "house_long", "barn", "house_a", "house_small", "house_b", "hall", "house_long"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1107
	for i in houses.size():
		var a := -PI * 0.1 + TAU * (float(i) + 0.5) / houses.size()
		var r := rng.randf_range(34.0, 46.0)
		var pos := Vector3(sin(a) * r, 0, cos(a) * r)
		if pos.z > 12.0 and absf(pos.x) < 20.0:
			pos.z += 14.0   # keep the smithy and bakery street clear
		var house := _model("res://assets/buildings/%s.scn" % houses[i])
		if house:
			house.position = pos
			house.rotation.y = atan2(-pos.x, -pos.z) + rng.randf_range(-0.3, 0.3)
			add_child(house)


# --- Helpers -------------------------------------------------------------------------------------

func _materials() -> void:
	_plaster = StandardMaterial3D.new()
	_plaster.albedo_texture = load("res://assets/village_mk/T_Plaster_BaseColor.png")
	_plaster.albedo_color = Color(0.82, 0.78, 0.72)
	_plaster.uv1_triplanar = true
	_plaster.uv1_scale = Vector3(0.35, 0.35, 0.35)
	_brick = StandardMaterial3D.new()
	_brick.albedo_texture = load("res://assets/village_mk/T_UnevenBrick_BaseColor.png")
	_brick.uv1_triplanar = true
	_brick.uv1_scale = Vector3(0.4, 0.4, 0.4)
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


func _solid(size: Vector3, pos: Vector3) -> void:
	_box(self, size, pos, _brick)


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
