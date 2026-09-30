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
const Visuals := preload("res://scripts/world/visuals.gd")
const HearthFire := preload("res://scripts/world/hearth_fire.gd")
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
const FOOTSTEP := 0.55

var player_spawn := Vector3(0, 0.1, 2.4)   # the open courtyard: sky, hearth and upper storey in view
var braziers: Array = []
var day_night
var hearth_pos := Vector3(0, 0, -0.8)   # a little north of centre: the gate side stays open
var hearth_radius := 1.7
var gate_pos := Vector3(0, 0, SOUTH_Z + ROOM_DEPTH - 0.4)
var doors: Dictionary = {}           # door id -> Door
var growth: Dictionary = {}          # place id -> {window, snow}: hub growth visuals
var fronts: Dictionary = {}          # place id -> {door: Transform3D, window: Transform3D}
var hearth_fire: Node3D
var hearth_light: OmniLight3D
var far_light: OmniLight3D

var _plaster: StandardMaterial3D
var _brick: StandardMaterial3D
var _stone: StandardMaterial3D
var _dark: StandardMaterial3D
var _ash: StandardMaterial3D
var _step_mat: StandardMaterial3D
var _snow: StandardMaterial3D
var _cleared: StandardMaterial3D
var _scorch: StandardMaterial3D
var ash_cover: MeshInstance3D
var _window_lit: StandardMaterial3D
var lament: AudioStreamPlayer3D
var _door_scene := false
var moon_rim: DirectionalLight3D   # the door scene's faint cool light: the door's silhouette reads
var _cache := {}
var room_spots: Dictionary = {}      # Aras's room: spot -> global Transform3D (see _interior)
var room_bounds := AABB()            # Aras's room, inside
var room_xf := Transform3D.IDENTITY   # Aras's room: its front's middle, +Z out of the room
var room_lamp: OmniLight3D
var _floor: StandardMaterial3D
var _rug: StandardMaterial3D


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
	refresh_aftermath()
	EventBus.npc_died.connect(func(_id, _c): refresh_aftermath())
	EventBus.state_replaced.connect(refresh_aftermath)
	moon_rim = DirectionalLight3D.new()
	moon_rim.name = "MoonRim"
	moon_rim.light_color = Color(0.55, 0.66, 0.95)
	moon_rim.light_energy = 0.22
	moon_rim.visible = false
	add_child(moon_rim)
	lament = AudioStreamPlayer3D.new()
	lament.name = "Lament"
	lament.stream = load("res://assets/audio/lament_loop.wav")
	lament.bus = "SFX"
	lament.unit_size = 7.0
	lament.max_distance = 60.0
	lament.finished.connect(_on_lament_finished)
	add_child(lament)
	refresh_growth()
	EventBus.npc_changed.connect(func(_id): refresh_growth())
	EventBus.npc_moved.connect(func(_id, _a, _b): refresh_growth())
	EventBus.npc_died.connect(func(_id, _c): refresh_growth())
	EventBus.state_replaced.connect(refresh_growth)
	EventBus.time_of_day_changed.connect(func(_p): refresh_growth())
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
	_door_scene = on
	refresh_growth()   # lit windows go dark for the scene
	moon_rim.visible = on
	if on:
		# grazing across the door's face from above and aside: its silhouette reads, cool
		var d: Transform3D = door.global_transform
		var dir: Vector3 = (-d.basis.z * 0.55 + d.basis.x * 0.7 + Vector3.DOWN * 0.55).normalized()
		moon_rim.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP), Vector3.ZERO)


## After a door death: ash on the threshold and a trail of ash footprints from the gate to
## that door. Derived from WorldState (death_cause "door"), so it is there after any load.
func refresh_aftermath() -> void:
	if not is_inside_tree():
		return
	for n in get_children():
		if n.is_in_group("hub_aftermath"):
			remove_child(n)   # at once: the new one takes its name
			n.queue_free()
	for d in doors.values():
		if not HubData.is_door_death_place(d.place_id):
			continue
		var root := Node3D.new()
		root.name = "Aftermath_" + String(d.door_id)
		root.add_to_group("hub_aftermath")
		add_child(root)
		var xf: Transform3D = d.global_transform
		var pile := MeshInstance3D.new()
		var blot := QuadMesh.new()
		blot.size = Vector2(2.1, 2.1)
		blot.material = _scorch
		pile.name = "Scorch"
		pile.mesh = blot
		pile.rotation = Vector3(-PI * 0.5, 0, xf.basis.get_euler().y)
		pile.position = xf.origin + xf.basis.z * 0.55 + Vector3(0, 0.028, 0)
		root.add_child(pile)
		var from := Vector3(0, 0, SOUTH_Z - 0.6)
		var to: Vector3 = xf.origin + xf.basis.z * 0.7
		var dir := (to - from)
		dir.y = 0.0
		var n := int(dir.length() / FOOTSTEP)
		var side := Vector3(-dir.z, 0, dir.x).normalized()
		for i in n:
			var step := MeshInstance3D.new()
			step.name = "Footprint%d" % i
			step.set_meta("footprint", true)
			var q := QuadMesh.new()
			q.size = Vector2(0.16, 0.36)
			q.material = _step_mat
			step.mesh = q
			var at := from + dir * (float(i) / n) + side * (0.11 if i % 2 == 0 else -0.11)
			step.position = Vector3(at.x, 0.03, at.z)
			step.rotation = Vector3(-PI * 0.5, 0, -atan2(dir.x, dir.z))
			root.add_child(step)


## A bare footprint in ash, drawn once: a sole, a heel and five toes (white, alpha).
static func footprint_texture() -> ImageTexture:
	var w := 32
	var h := 72
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var blobs := [[Vector2(16, 44), Vector2(9, 16)], [Vector2(16, 62), Vector2(7, 8)], [Vector2(21, 22), Vector2(5, 5)],
		[Vector2(14, 18), Vector2(3.5, 3.5)], [Vector2(9, 20), Vector2(3, 3)], [Vector2(26, 26), Vector2(3, 3)], [Vector2(5, 25), Vector2(2.5, 2.5)]]
	for y in h:
		for x in w:
			var a := 0.0
			for b in blobs:
				var c: Vector2 = b[0]
				var r: Vector2 = b[1]
				var d := Vector2((x - c.x) / r.x, (y - c.y) / r.y).length()
				a = maxf(a, clampf((1.0 - d) * 3.0, 0.0, 1.0))
			if a > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, a * 0.9))
	return ImageTexture.create_from_image(img)


func footprints(door_id: String) -> Array:
	var root := get_node_or_null("Aftermath_" + door_id)
	return [] if root == null else root.get_children().filter(func(n): return n.has_meta("footprint"))


func footprint_count(door_id: String) -> int:
	return footprints(door_id).size()


## Hub growth from WorldState (placeholder visuals, data-driven): each room dark / lit (its
## window glows) / melted (the ash-snow at its door gone); the hearth's flame grows with the
## resolved core grief arcs (data/hub/son_ocaq.json hearth.stages).
func refresh_growth() -> void:
	if not is_inside_tree():
		return
	for id in growth:
		var st := HubData.room_state(id)
		growth[id]["window"].material_override = _window_lit if st != "dark" and not _door_scene else _dark
		growth[id]["cleared"].visible = st == "melted"
	hearth_fire.scale = Vector3.ONE * HubData.hearth_scale()


func room_state_shown(place_id: String) -> String:
	if growth[place_id]["window"].material_override == _dark:
		return "dark"
	return "melted" if growth[place_id]["cleared"].visible else "lit"


## The lament on the morning after a door death: sung at that door (placeholder audio), so
## the sound leads to it. No UI.
func set_lament(door) -> void:
	lament.set_meta("on", door != null)
	if door == null:
		lament.stop()
		return
	lament.global_position = door.global_position + door.global_basis.z * 1.2 + Vector3(0, 1.4, 0)
	if not lament.playing:
		lament.play()


func _on_lament_finished() -> void:
	if lament.get_meta("on", false):
		lament.play()   # a loop while the mourning lasts


## Ash-snow lying unevenly: a noise alpha (heavier in drifts, thin between).
static func _noise_cover() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.frequency = 0.03
	var tex := NoiseTexture2D.new()
	tex.noise = n
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.15))
	g.set_color(1, Color(1, 1, 1, 0.6))
	tex.color_ramp = g
	return tex


## A burn mark: an irregular blot — ragged edge, darker tongues licking outward — not a disc.
static func scorch_texture() -> ImageTexture:
	var size := 96
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var n := FastNoiseLite.new()
	n.seed = 71
	n.frequency = 0.09
	var c := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var p := Vector2(x, y) - c
			var ang := atan2(p.y, p.x)
			# the edge wanders with the angle, plus a few long tongues
			var edge := 0.62 + 0.22 * n.get_noise_2d(cos(ang) * 40.0, sin(ang) * 40.0) + 0.12 * maxf(sin(ang * 5.0 + 1.3), 0.0)
			var r := p.length() / (size * 0.5)
			var a := clampf((edge - r) * 5.0, 0.0, 1.0) * (0.75 + 0.25 * n.get_noise_2d(x * 2.0, y * 2.0))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


## A soft round patch (alpha).
static func _soft_patch() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.9))
	g.set_color(1, Color(1, 1, 1, 0.0))
	g.add_point(0.6, Color(1, 1, 1, 0.7))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	return tex


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

## Aras's room (STORY_SLICE §2): a plain hollow room behind his door — two beds (his and
## Rüfət's), a lamp, a rug, a chest. Placeholder blockout until the mood pass. Its spots
## (room_spots, global): bed_protagonist, bed_rufet, inside_door, lamp.
func _interior(root: Node3D, door_x: float) -> void:
	var w := MODULE * 2.0
	var back := -ROOM_DEPTH - 0.3
	var inner := Node3D.new()
	inner.name = "Interior"
	root.add_child(inner)
	_box(inner, Vector3(w + 0.4, 0.1, ROOM_DEPTH + 0.3), Vector3(0, -0.02, back * 0.5), _floor)            # floor
	_box(inner, Vector3(0.2, ROOM_H, ROOM_DEPTH + 0.3), Vector3(-w * 0.5 - 0.1, ROOM_H * 0.5, back * 0.5), _plaster)
	_box(inner, Vector3(0.2, ROOM_H, ROOM_DEPTH + 0.3), Vector3(w * 0.5 + 0.1, ROOM_H * 0.5, back * 0.5), _plaster)
	_box(inner, Vector3(w + 0.4, ROOM_H, 0.2), Vector3(0, ROOM_H * 0.5, back - 0.1), _plaster)            # back wall
	_box(inner, Vector3(w + 0.4, 0.2, ROOM_DEPTH + 0.3), Vector3(0, ROOM_H + 0.1, back * 0.5), _plaster)  # ceiling
	# Two beds along the back wall, heads to the wall; the rug between; the lamp in the corner
	var bed_side := -door_x   # the far side from the door stays free to walk in
	_prop(inner, "res://assets/props_mk/Bed_Twin1.gltf", Vector3(-bed_side * 0.15, 0, back + 1.25), 0.0)
	_prop(inner, "res://assets/props_mk/Bed_Twin2.gltf", Vector3(bed_side * 1.45, 0, back + 1.25), 0.0)
	var rug := MeshInstance3D.new()
	rug.name = "Rug"
	var rq := QuadMesh.new()
	rq.size = Vector2(1.6, 2.2)
	rq.material = _rug
	rug.mesh = rq
	rug.rotation.x = -PI * 0.5
	rug.position = Vector3(0, 0.012, back + 3.1)
	inner.add_child(rug)
	_prop(inner, "res://assets/props_mk/Chest_Wood.gltf", Vector3(-bed_side * 1.5, 0, back + 0.55), 0.0)
	var lamp_at := Vector3(-bed_side * 1.6, 0, back + 1.5)
	_prop(inner, "res://assets/props_mk/CandleStick_Stand.gltf", lamp_at, 0.0)
	room_lamp = OmniLight3D.new()
	room_lamp.name = "RoomLamp"
	room_lamp.light_color = Color(1.0, 0.62, 0.3)
	room_lamp.light_energy = 1.4
	room_lamp.omni_range = 5.5
	room_lamp.shadow_enabled = false   # on only while he is in the room (hub_mode._tick)
	room_lamp.position = lamp_at + Vector3(0, 1.5, 0.3)
	inner.add_child(room_lamp)
	var xf: Transform3D = root.transform
	room_xf = xf
	var face_in := Basis(Vector3.UP, PI)   # the model faces -Z: turned to the room's front
	room_spots = {
		"bed_protagonist": xf * Transform3D(face_in, Vector3(-bed_side * 0.15, 0.0, back + 1.4)),
		# Rüfət sits awake on his bed's edge, feet on the floor, facing the room and the door
		"bed_rufet": xf * Transform3D(Basis(Vector3.UP, bed_side * PI * 0.5), Vector3(bed_side * 0.93, 0.08, back + 1.7)),
		"inside_door": xf * Transform3D(Basis.IDENTITY, Vector3(door_x, 0.0, -1.3)),
		"lamp": xf * Transform3D(Basis.IDENTITY, lamp_at),
	}
	room_bounds = AABB(xf * Vector3(-w * 0.5, 0, back), Vector3.ZERO).expand(xf * Vector3(w * 0.5, ROOM_H, -0.2))


## Inside Aras's room (the protagonist's position `at`).
func in_room(at: Vector3) -> bool:
	return room_bounds.has_volume() and room_bounds.grow(0.05).has_point(at + Vector3(0, 0.5, 0))


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
	var pane := _quad(root, Vector2(1.2, 1.1), Vector3(window_x, 1.7, -0.28), "Window")
	pane.set_meta("place", p["id"])
	if HubData.residents_of(p["id"]).has(HubData.PROTAGONIST):
		_interior(root, door_x)   # Aras's own room: he can walk in
	else:
		# The room behind: a plaster mass under the flat roof
		_box(root, Vector3(MODULE * 2.0, ROOM_H, ROOM_DEPTH), Vector3(0, ROOM_H * 0.5, -ROOM_DEPTH * 0.5 - 0.3), _plaster)
		# What an open door shows: dark inside
		var inside := _quad(root, Vector2(1.1, 2.3), Vector3(door_x, 1.15, -0.28), "Inside")
		inside.set_meta("place", p["id"])
	# Resolved grief: the ash-snow at this door cleared, warm-toned stones showing
	var cleared := MeshInstance3D.new()
	cleared.name = "ClearedStones"
	var cq := QuadMesh.new()
	cq.size = Vector2(3.0, 1.9)
	cq.material = _cleared
	cleared.mesh = cq
	cleared.rotation.x = -PI * 0.5
	cleared.position = Vector3(0, 0.026, 1.15)
	cleared.visible = false
	root.add_child(cleared)
	growth[p["id"]] = {"window": pane, "cleared": cleared}
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
	# The ambient ash-snow over the courtyard (under every mark and glow)
	ash_cover = MeshInstance3D.new()
	ash_cover.name = "AshCover"
	var ap := PlaneMesh.new()
	ap.size = Vector2(SIDE_X * 2.0, SOUTH_Z - NORTH_Z)
	ap.material = _snow
	ash_cover.mesh = ap
	ash_cover.position = Vector3(0, 0.021, 0)
	add_child(ash_cover)
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
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = hearth_radius + 0.2
	shape.height = 0.3
	cs.shape = shape
	cs.position.y = 0.15
	body.add_child(cs)
	root.add_child(body)
	# The fire itself (embers, logs, flames, sparks, the flickering light): a lit HearthFire
	# inside the dressed stones; it grows with the hub (refresh_growth scales hearth_fire)
	hearth_fire = Node3D.new()
	hearth_fire.name = "HearthFire"
	hearth_fire.position = hearth_pos
	add_child(hearth_fire)
	var fire = HearthFire.new().setup(true, hearth_radius - 0.2, false, true, true, 4.2, 15.0)
	fire.name = "Fire"
	hearth_fire.add_child(fire)
	hearth_light = fire.light
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
	_floor = StandardMaterial3D.new()
	_floor.albedo_texture = load("res://assets/village_mk/T_WoodTrim_BaseColor.png")
	_floor.albedo_color = Color(0.55, 0.42, 0.32)
	_floor.uv1_triplanar = true
	_floor.uv1_scale = Vector3(0.6, 0.6, 0.6)
	_rug = StandardMaterial3D.new()
	_rug.albedo_color = Color(0.46, 0.12, 0.08)   # a plain red kilim (placeholder)
	_rug.roughness = 1.0
	_ash = StandardMaterial3D.new()
	_ash.albedo_color = Color(0.82, 0.8, 0.77)   # ash is pale: it must read on the dark stone
	_ash.roughness = 1.0
	_step_mat = StandardMaterial3D.new()
	_step_mat.albedo_texture = footprint_texture()
	_step_mat.albedo_color = Color(0.98, 0.97, 0.95)   # fresh pale ash: brighter than the lying cover
	_step_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_step_mat.roughness = 1.0
	# Three ground states that must never look alike (STORY_BIBLE §8: ash snow):
	#   ambient ash-snow — light grey, everywhere;   cleared (resolved grief) — warm stones;
	#   a door death — a dark scorched mark (the footprints to it stay pale ash)
	_snow = StandardMaterial3D.new()
	_snow.albedo_texture = _noise_cover()
	_snow.albedo_color = Color(0.84, 0.83, 0.81)
	_snow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_snow.roughness = 1.0
	_snow.uv1_scale = Vector3(3, 3, 1)
	_cleared = StandardMaterial3D.new()
	_cleared.albedo_texture = load("res://assets/village_mk/T_RockTrim_BaseColor.png")
	_cleared.albedo_color = Color(0.95, 0.66, 0.42)
	_cleared.uv1_scale = Vector3(2, 1.3, 1)
	_cleared.roughness = 0.85
	_scorch = StandardMaterial3D.new()
	_scorch.albedo_texture = scorch_texture()
	_scorch.albedo_color = Color(0.07, 0.05, 0.04)
	_scorch.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_scorch.roughness = 1.0
	_window_lit = StandardMaterial3D.new()
	_window_lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_window_lit.albedo_color = Color(0.95, 0.6, 0.28)
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
		Visuals.no_small_shadows(n, Vector3.ONE, float(DataDB.world("lighting")["shadows"]["min_caster_size"]))
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
