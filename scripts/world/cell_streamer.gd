extends Node3D
## Cell streaming (spec V3 §6.1). The world is cut into cell_size cells. Around Ayxan the
## 3×3 cells are FULL (meshes, colliders, lights, enemies, interactables), the 5×5 ring
## is VISUAL (meshes only), everything further shows only "far" landmark pieces.
## Mesh building runs on the WorkerThreadPool; colliders, lights and actors are added
## on the main thread within a per-frame time budget. Terrain and vegetation stream
## themselves inside Terrain3D; tree trunk colliders are added per FULL cell here.

signal actor_requested(poi: Dictionary, actor: Dictionary, key: String, pos: Vector3)
signal actors_released(poi_id: String)
signal interactable_created(node: Node3D)

enum { NONE, VISUAL, FULL }

const Builder := preload("res://scripts/world/poi_builder.gd")
const Effects := preload("res://scripts/world/effects.gd")
const Interactable := preload("res://scripts/world/interactable.gd")
const BUDGET_MS := 3.0

var builder: Builder
var cell_size := 128.0
var full_radius := 1
var visual_radius := 2
var focus: Node3D                 # usually Ayxan
var is_night := func() -> bool: return false
var high_quality := true

var pois: Array = []              # POI dicts from world_meta.json
var _prefabs := {}                # type -> prefab Dictionary
var _plans := {}                  # poi id -> {near, far}
var _state := {}                  # poi id -> NONE/VISUAL/FULL (wanted)
var _loaded := {}                 # poi id -> {visual: Node3D, physics: Node3D, extras: Array}
var _pending := {}                # poi id -> true while a worker builds it
var _main_jobs: Array = []        # Callables for the main thread
var _tree_cells := {}             # Vector2i -> Array [x, z, r]
var _tree_bodies := {}            # Vector2i -> StaticBody3D
var _cell := Vector2i(-999, -999)
var _check_t := 0.0
var stats := {"loads": 0, "last_ms": 0.0, "worker_ms": 0.0, "jobs": 0}


func setup(meta: Dictionary, terrain: Terrain3D, cfg: Dictionary) -> void:
	builder = Builder.new()
	builder.terrain = terrain
	cell_size = cfg["cell_size"]
	full_radius = cfg["full_radius"]
	visual_radius = cfg["visual_radius"]
	pois = meta["pois"]
	for p in pois:
		var prefab: Dictionary = DataDB.prefab(p["type"])
		_prefabs[p["type"]] = prefab
		_plans[p["id"]] = builder.plan(p, prefab)
		_state[p["id"]] = NONE
	var t: Array = meta["trees"]
	for i in range(0, t.size(), 3):
		var c := cell_of(Vector3(t[i], 0, t[i + 1]))
		if not _tree_cells.has(c):
			_tree_cells[c] = []
		_tree_cells[c].append([t[i], t[i + 1], t[i + 2]])
	# Landmarks first, synchronously: they must be on screen from the first frame
	for p in pois:
		var far: Array = _plans[p["id"]]["far"]
		if not far.is_empty():
			add_child(builder.build_visual(far, "Far_" + p["id"]))


func cell_of(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / cell_size), floori(pos.z / cell_size))


func poi_by_id(id: String) -> Dictionary:
	for p in pois:
		if p["id"] == id:
			return p
	return {}


func poi_pos(p: Dictionary) -> Vector3:
	return Vector3(p["pos"][0], p["pos"][1], p["pos"][2])


## Forces a refresh (after teleports).
func refresh() -> void:
	_cell = Vector2i(-999, -999)
	_check_t = 0.0


func _process(delta: float) -> void:
	_check_t -= delta
	if is_instance_valid(focus) and _check_t <= 0.0:
		_check_t = 0.4
		var c := cell_of(focus.global_position)
		if c != _cell:
			_cell = c
			_update_wanted()
	_run_jobs()


func _update_wanted() -> void:
	for p in pois:
		var c := cell_of(poi_pos(p))
		var d: int = maxi(absi(c.x - _cell.x), absi(c.y - _cell.y))
		var want := FULL if d <= full_radius else (VISUAL if d <= visual_radius else NONE)
		var id: String = p["id"]
		if want != _state[id]:
			_state[id] = want
			_transition(p, want)
	# Tree trunks in the FULL ring
	for c in _tree_cells:
		var d: int = maxi(absi(c.x - _cell.x), absi(c.y - _cell.y))
		if d <= full_radius and not _tree_bodies.has(c):
			var cell_key: Vector2i = c
			_main_jobs.append(func(): _build_trees(cell_key))
		elif d > full_radius and _tree_bodies.has(c):
			_tree_bodies[c].queue_free()
			_tree_bodies.erase(c)


func _transition(p: Dictionary, want: int) -> void:
	var id: String = p["id"]
	var rec: Dictionary = _loaded.get(id, {})
	if want == NONE:
		_unload(id)
		return
	if not rec.has("visual") and not _pending.has(id):
		_pending[id] = true
		var near: Array = _plans[id]["near"]
		WorkerThreadPool.add_task(_build_worker.bind(id, near))
	if want == FULL:
		_main_jobs.append(func(): _make_full(p))
	elif rec.has("physics"):
		_drop_full(id)


func _build_worker(id: String, pieces: Array) -> void:
	var t0 := Time.get_ticks_usec()
	var node: Node3D = builder.build_visual(pieces, "Poi_" + id)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	_on_built.call_deferred(id, node, ms)


func _on_built(id: String, node: Node3D, ms: float) -> void:
	_pending.erase(id)
	stats["worker_ms"] = ms
	stats["loads"] += 1
	if _state.get(id, NONE) == NONE:
		node.free()
		return
	add_child(node)
	var rec: Dictionary = _loaded.get(id, {})
	rec["visual"] = node
	_loaded[id] = rec


func _make_full(p: Dictionary) -> void:
	var id: String = p["id"]
	if _state.get(id, NONE) != FULL:
		return
	var rec: Dictionary = _loaded.get(id, {})
	if rec.has("physics"):
		return
	var plan: Dictionary = _plans[id]
	var body := builder.build_physics(plan["near"] + plan["far"])
	body.name = "Col_" + id
	add_child(body)
	rec["physics"] = body
	var extras: Array = []
	var prefab: Dictionary = _prefabs[p["type"]]
	var center := poi_pos(p)
	for l in prefab.get("lights", []):
		var n := _make_light(l, center)
		add_child(n)
		extras.append(n)
	for i in prefab.get("interact", []).size():
		var def: Dictionary = prefab["interact"][i]
		var it := Interactable.new()
		it.kind = def["kind"]
		it.poi = p
		it.data = def
		it.key = "%s#%d" % [id, i]
		var lp: Array = def["p"]
		var wp := center + Vector3(lp[0], 0, lp[2])
		wp.y = builder.ground(wp.x, wp.z) + float(lp[1])
		it.position = wp
		add_child(it)
		extras.append(it)
		interactable_created.emit(it)
	rec["extras"] = extras
	_loaded[id] = rec
	spawn_actors(p)


## Asks the world to spawn this POI's enemies (the world tracks kills and night rules).
func spawn_actors(p: Dictionary) -> void:
	var prefab: Dictionary = _prefabs[p["type"]]
	var center := poi_pos(p)
	var actors: Array = prefab.get("actors", [])
	for i in actors.size():
		var a: Dictionary = actors[i]
		var lp: Array = a["p"]
		var wp := center + Vector3(lp[0], 0, lp[2])
		wp.y = builder.ground(wp.x, wp.z) + 0.2
		actor_requested.emit(p, a, "%s@%d" % [p["id"], i], wp)


func is_full(id: String) -> bool:
	return _state.get(id, NONE) == FULL and _loaded.get(id, {}).has("physics")


func _drop_full(id: String) -> void:
	var rec: Dictionary = _loaded.get(id, {})
	if rec.has("physics"):
		rec["physics"].queue_free()
		rec.erase("physics")
	for n in rec.get("extras", []):
		if is_instance_valid(n):
			n.queue_free()
	rec.erase("extras")
	actors_released.emit(id)


func _unload(id: String) -> void:
	_drop_full(id)
	var rec: Dictionary = _loaded.get(id, {})
	if rec.has("visual"):
		rec["visual"].queue_free()
	_loaded.erase(id)


func _build_trees(c: Vector2i) -> void:
	if _tree_bodies.has(c):
		return
	var body := StaticBody3D.new()
	body.name = "Trees_%d_%d" % [c.x, c.y]
	body.collision_mask = 0
	for t in _tree_cells[c]:
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = t[2]
		cyl.height = 6.0
		cs.shape = cyl
		cs.position = Vector3(t[0], builder.ground(t[0], t[1]) + 3.0, t[1])
		body.add_child(cs)
	add_child(body)
	_tree_bodies[c] = body


func _run_jobs() -> void:
	var t0 := Time.get_ticks_usec()
	while not _main_jobs.is_empty() and (Time.get_ticks_usec() - t0) / 1000.0 < BUDGET_MS:
		var job: Callable = _main_jobs.pop_front()
		job.call()
	stats["jobs"] = _main_jobs.size()
	if Time.get_ticks_usec() - t0 > 50:
		stats["last_ms"] = (Time.get_ticks_usec() - t0) / 1000.0


# --- Lights and fires ----------------------------------------------------------------------

func _make_light(def: Dictionary, center: Vector3) -> Node3D:
	var lp: Array = def["p"]
	var pos := center + Vector3(lp[0], 0, lp[2])
	pos.y = builder.ground(pos.x, pos.z) + float(lp[1])
	var s: float = def.get("scale", 1.0)
	var root := Node3D.new()
	root.position = pos
	var l := OmniLight3D.new()
	l.omni_attenuation = 1.3
	match def["kind"]:
		"fire", "forge", "torch":
			l.light_color = Color(1.0, 0.55, 0.25)
			l.light_energy = 2.6 * s
			l.omni_range = 11.0 * s + 3.0
			var f := Effects.fire(s * 1.2, int(20 * s) + 8)
			root.add_child(f)
		"eternal_flame":
			l.light_color = Color(1.0, 0.5, 0.2)
			l.light_energy = 4.0 * s
			l.omni_range = 16.0 * s
			root.add_child(Effects.fire(s * 1.6, 40))
			root.add_child(Effects.ember_column(0.8 * s, 24))
		"ember":
			l.light_color = Color(1.0, 0.35, 0.12)
			l.light_energy = 1.4 * s
			l.omni_range = 6.0
			var e := Effects.ember_field(Vector3(0.6, 0.8, 0.6), 10)
			root.add_child(e)
	l.shadow_enabled = false
	root.add_child(l)
	return root


func loaded_count() -> Dictionary:
	var v := 0
	var f := 0
	for id in _state:
		if _state[id] == FULL:
			f += 1
		elif _state[id] == VISUAL:
			v += 1
	return {"full": f, "visual": v, "trees": _tree_bodies.size(), "pending": _pending.size()}
