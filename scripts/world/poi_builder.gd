extends RefCounted
## Turns a POI (world_meta.json) + its prefab (data/world/prefabs/<type>.json) into
## nodes. Work is split so the streamer can thread it:
##   plan()          main thread — resolves every piece to a world transform (terrain heights)
##   build_visual()  worker thread — instantiates meshes (no scene tree, no physics)
##   build_physics() main thread — box/cylinder colliders from the planned pieces
## Pieces marked "far" go to a separate always-loaded node: the landmarks you see
## from across the valley (castle towers, bell tower, the great plane tree).

const PREFIX := {
	"v:": "res://assets/quaternius/medieval_village_pack/",
	"c:": "res://assets/quaternius/modular_medieval_buildings_pack/",
	"d:": "res://assets/quaternius/modular_dungeon_pack/",
	"n:": "res://assets/quaternius/nature_pack/",
	"f:": "res://assets/foliage/",
	"b:": "res://assets/buildings/",   # houses built by tools/build_houses.gd: b:inn.scn
	"pm:": "res://assets/props_mk/",   # Fantasy Props MegaKit: pm:Barrel.gltf
	"vm:": "res://assets/village_mk/",  # Medieval Village MegaKit: vm:Prop_Wagon.gltf   # generated trees (tools/gen_trees.gd): f:oak.scn
	"r:": "res://assets/quaternius/rpg_items_pack/",
	"s:": "res://assets/quaternius/survival_pack/",
	"kd:": "res://assets/environment/dungeon/",
	"kh:": "res://assets/environment/halloween/",
}

var terrain: Terrain3D
var min_caster_size := 0.5   # metres (lighting.json shadows.min_caster_size; set by the streamer)
var _bounds := {}   # path -> AABB of the model at scale 1
var _mutex := Mutex.new()


static func model_path(short: String) -> String:
	for p in PREFIX:
		if short.begins_with(p):
			var rest: String = short.substr(p.length())
			return PREFIX[p] + (rest if rest.get_extension() != "" else rest + ".glb")
	return short


func ground(x: float, z: float) -> float:
	var h: float = terrain.data.get_height(Vector3(x, 0, z))
	return 0.0 if is_nan(h) else h


## Expands the prefab into a flat list of pieces with world transforms.
## Returns {"near": [...], "far": [...]} where each piece is
## {path, xform: Transform3D, collide: bool, trunk: float}.
func plan(poi: Dictionary, prefab: Dictionary) -> Dictionary:
	var center := Vector3(poi["pos"][0], poi["pos"][1], poi["pos"][2])
	var near: Array = []
	var far: Array = []
	for piece in prefab.get("pieces", []):
		for item in _expand(piece):
			var local: Vector3 = item["p"]
			var world := center + Vector3(local.x, 0.0, local.z)
			var snap: bool = piece.get("snap", true)
			world.y = (ground(world.x, world.z) if snap else center.y) + local.y
			var yaw: float = item["r"]
			var s: float = piece.get("s", 1.0)
			var entry := {
				"path": model_path(item["m"]),
				"xform": Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)).scaled(Vector3.ONE * s), world),
				"collide": piece.get("c", true),
				"trunk": float(piece.get("trunk", 0.0)),   # trunk radius in metres
			}
			(far if piece.get("far", false) else near).append(entry)
	return {"near": near, "far": far}


## "m" pieces pass through; "line", "ring" and "grid" generate several.
func _expand(piece: Dictionary) -> Array:
	var out: Array = []
	if piece.has("m"):
		var p: Array = piece["p"]
		var local := Vector3(p[0], p[1], p[2])
		var yaw: float = piece.get("r", 0.0)
		if piece.get("face", "") == "center" and Vector2(local.x, local.z).length() > 0.1:
			yaw = rad_to_deg(atan2(-local.x, -local.z))
		out.append({"m": piece["m"], "p": local, "r": yaw})
	elif piece.has("line"):
		var a := Vector2(piece["from"][0], piece["from"][1])
		var b := Vector2(piece["to"][0], piece["to"][1])
		var step: float = piece.get("step", 2.0)
		var n := maxi(1, int(round(a.distance_to(b) / step)))
		var dir := (b - a).normalized()
		var yaw := rad_to_deg(atan2(dir.x, dir.y)) + 90.0
		for i in n + 1:
			var q := a.lerp(b, float(i) / n)
			var m: String = piece["line"]
			if piece.has("gate") and i == n / 2:
				m = piece["gate"]
			out.append({"m": m, "p": Vector3(q.x, 0, q.y), "r": yaw})
	elif piece.has("ring"):
		var count: int = piece["count"]
		var r: float = piece["radius"]
		var skip: Array = piece.get("skip", [])
		for i in count:
			if i in skip:
				continue
			var ang := TAU * i / count
			var local := Vector3(cos(ang) * r, 0, sin(ang) * r)
			out.append({"m": piece["ring"], "p": local, "r": rad_to_deg(atan2(-local.x, -local.z))})
	elif piece.has("grid"):
		var a := Vector2(piece["from"][0], piece["from"][1])
		var b := Vector2(piece["to"][0], piece["to"][1])
		var step: float = piece.get("step", 4.0)
		var z := a.y
		var k := 0
		while z <= b.y + 0.01:
			var x := a.x
			while x <= b.x + 0.01:
				var jitter := Vector3(sin(k * 12.9) * step * 0.12, 0, cos(k * 7.3) * step * 0.12)
				out.append({"m": piece["grid"], "p": Vector3(x, 0, z) + jitter, "r": fmod(k * 73.0, 360.0)})
				x += step
				k += 1
			z += step
	return out


## Worker-thread safe: builds render-only nodes for a list of planned pieces.
func build_visual(pieces: Array, node_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	for p in pieces:
		var scene: PackedScene = ResourceLoader.load(p["path"])
		if scene == null:
			continue
		var inst: Node3D = scene.instantiate()
		inst.transform = p["xform"]
		root.add_child(inst)
		for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
			mi.visibility_range_end = 0.0
		# a piece under half a metre (as placed) casts no shadow
		var size: Vector3 = local_bounds(p["path"]).size * (p["xform"] as Transform3D).basis.get_scale().abs()
		if maxf(size.x, maxf(size.y, size.z)) < min_caster_size:
			for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


## Main thread: static colliders. Boxes from each model's bounds; trees get a trunk.
func build_physics(pieces: Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	for p in pieces:
		var xf: Transform3D = p["xform"]
		if p["trunk"] > 0.0:
			var cyl := CylinderShape3D.new()
			cyl.radius = p["trunk"]
			cyl.height = 8.0
			var cs := CollisionShape3D.new()
			cs.shape = cyl
			cs.position = xf.origin + Vector3(0, 4.0, 0)
			body.add_child(cs)
			continue
		if not p["collide"]:
			continue
		var box: AABB = local_bounds(p["path"])
		if box.size.length() < 0.01:
			continue
		# Shapes must not be scaled: bake the piece scale into the box size
		var shape := BoxShape3D.new()
		shape.size = box.size * xf.basis.get_scale() * 0.92
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.transform = Transform3D(xf.basis.orthonormalized(), xf * box.get_center())
		body.add_child(cs)
	return body


## Model bounds at scale 1 (cached; safe from any thread).
func local_bounds(path: String) -> AABB:
	_mutex.lock()
	var cached = _bounds.get(path)
	_mutex.unlock()
	if cached != null:
		return cached
	var box := AABB()
	var scene: PackedScene = ResourceLoader.load(path)
	if scene != null:
		var inst: Node3D = scene.instantiate()
		var first := true
		for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
			var xf := Transform3D()
			var n: Node = mi
			while n != null and n != inst:
				xf = (n as Node3D).transform * xf
				n = n.get_parent()
			var b: AABB = xf * mi.get_aabb()
			box = b if first else box.merge(b)
			first = false
		inst.free()
	_mutex.lock()
	_bounds[path] = box
	_mutex.unlock()
	return box
