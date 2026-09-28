extends Node
## Builds the bodies of named NPCs from WorldState — never from hand-placed nodes. An NPC
## has a body when they are alive and their location is somewhere loaded:
##   "party"      companions (NpcDefinition.companion) fight beside the protagonist (Ally);
##   a POI id     they stand there (Resident) while that place is loaded;
##   anything else (e.g. "son_ocaq", the hub that is not built yet, or "") — no body.
## A dead NPC never gets a body again. Bodies are views: freed and rebuilt at any time.
##
## The mode sets `player`, `place` (location id -> Vector3 centre, or null when that place
## is not loaded) and optionally `height_at`, and calls refresh() when places load or
## unload. WorldState changes (npc_moved, npc_died, load) refresh on their own.

const NpcRegistry := preload("res://scripts/core/npc_registry.gd")
const Ally := preload("res://scripts/npc/ally.gd")
const Resident := preload("res://scripts/npc/resident.gd")

var player: Node3D
var place := Callable()           # (location_id: String) -> Variant (Vector3 or null)
var height_at := Callable()       # (x, z) -> float, optional
var bodies: Dictionary = {}       # npc id -> Node3D

var _queued := false


func _ready() -> void:
	EventBus.npc_moved.connect(func(_id, _from, _to): queue_refresh())
	EventBus.npc_died.connect(func(_id, _cause): queue_refresh())
	EventBus.state_replaced.connect(queue_refresh)


func queue_refresh() -> void:
	if not _queued:
		_queued = true
		refresh.call_deferred()


## Spawns what WorldState says should be here, frees what should not.
func refresh() -> void:
	_queued = false
	var at_place: Dictionary = {}          # location -> [ids], for spreading people out
	for def in NpcRegistry.all():
		if def.npc_kind == "voice_only":
			continue
		var id: StringName = def.id
		var loc := WorldState.get_npc_location(id)
		var want := ""                     # "ally" | "resident" | ""
		var pos: Variant = null
		if WorldState.is_npc_alive(id):
			if loc == WorldState.PARTY and def.companion and player != null:
				want = "ally"
			elif loc != "" and loc != WorldState.PARTY and place.is_valid():
				pos = place.call(loc)
				if pos != null:
					want = "resident"
					at_place[loc] = at_place.get(loc, []) + [id]
		var body = bodies.get(id)
		if body != null and not is_instance_valid(body):
			bodies.erase(id)
			body = null
		var kind := "" if body == null else ("ally" if body is Ally else "resident")
		if kind == want and (want != "resident" or body.get_meta("location", "") == loc):
			continue
		if body != null:
			body.queue_free()
			bodies.erase(id)
		if want == "ally":
			_spawn_ally(def)
		elif want == "resident":
			var i: int = at_place[loc].size() - 1
			_spawn_resident(def, loc, pos, i)


func _spawn_ally(def: Resource) -> void:
	var a = Ally.new()
	a.setup(def, player)
	a.height_at = height_at
	add_child(a)
	var back: Vector3 = player.facing() if player.has_method("facing") else Vector3.FORWARD
	a.global_position = player.global_position - back * 2.0 + Vector3(0.8, 0.3, 0)
	bodies[def.id] = a


func _spawn_resident(def: Resource, loc: String, center: Vector3, i: int) -> void:
	var r = Resident.new()
	var a := i * 2.4
	var p := center + Vector3(cos(a), 0, sin(a)) * (3.0 + i * 0.6)
	if height_at.is_valid():
		p.y = height_at.call(p.x, p.z)
	r.setup(def, player, atan2(center.x - p.x, center.z - p.z))
	r.set_meta("location", loc)
	add_child(r)
	r.global_position = p
	bodies[def.id] = r


func body(id: StringName) -> Node3D:
	var b = bodies.get(id)
	return b if b != null and is_instance_valid(b) and not b.is_queued_for_deletion() else null
