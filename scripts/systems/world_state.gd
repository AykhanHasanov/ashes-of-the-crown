extends Node
## WorldState (autoload): the single source of truth for everything that persists.
## Nodes and scenes hold no saved state: they read from here and change it only through
## the typed accessors below. Every change emits its EventBus signal (see event_bus.gd).
## Exceptions: meta bookkeeping (playtime, save stamp) emits nothing.
##
## Sections (to_dict / from_dict; SaveManager writes them as JSON):
##   meta       save_version, playtime (s), last_saved_timestamp (unix)
##   player     stats {health, max_health, flasks, max_flasks, fire, weapon, level},
##              current_region, position [x, y, z],
##              memories {memory_id: "kept" | "burned"} — absent means UNKNOWN (not found yet),
##              burn_context {memory_id: "echo" | "combat"} — where each burned memory burned
##   inventory  item_id -> count
##   flags      story flags, key -> bool / int / float / String
##   story      chapter, checkpoint, echoes_seen — story progress lives here and nowhere
##              else (one fact, one owner: never mirror these in flags)
##   npcs       npc_id -> {alive, location_id, rescued, relationship, death_cause, flags}
##              for every NpcDefinition (data/npcs); location_id is a POI id, "party"
##              (with the protagonist), "son_ocaq" (the hub) or "" (not in the world)
##   world      time_of_day (hour), day_count, hub_stage, and open-world progress:
##              hearths / chests / echoes / discovered / killed (id lists), fog, last_hearth

const MemoryRegistry := preload("res://scripts/core/memory_registry.gd")
const NpcRegistry := preload("res://scripts/core/npc_registry.gd")

const SAVE_VERSION := 3

## A memory is not found yet (UNKNOWN), remembered (KEPT) or given to the fire (BURNED).
enum MemoryState { UNKNOWN, KEPT, BURNED }
const STATE_NAMES := {MemoryState.KEPT: "kept", MemoryState.BURNED: "burned"}
const WORLD_LISTS := ["hearths", "chests", "echoes", "discovered", "killed"]
const INT_STATS := ["flasks", "max_flasks", "level"]
const FLOAT_STATS := ["health", "max_health", "fire"]
const STRING_STATS := ["weapon"]
const BURN_CONTEXTS := ["echo", "combat"]
## Special NPC locations: with the protagonist, and the hub (rescued people go there).
const PARTY := "party"
const SON_OCAQ := "son_ocaq"

## True once a game is running (new game or load); playtime counts only then.
var session_active := false

# Built at declaration, not in _ready: a main scene's _enter_tree runs before any
# autoload's _ready, and must already find a valid state.
var _state: Dictionary = default_state()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _process(delta: float) -> void:
	if session_active:
		_state["meta"]["playtime"] = float(_state["meta"]["playtime"]) + delta


## A brand-new state (also used by SaveManager to build migrated saves).
static func default_state() -> Dictionary:
	return {
		"meta": {"save_version": SAVE_VERSION, "playtime": 0.0, "last_saved_timestamp": 0},
		"player": {"stats": {"level": 1}, "current_region": "", "position": [0.0, 0.0, 0.0], "memories": {}, "burn_context": {}},
		"inventory": {},
		"flags": {},
		"story": {"chapter": 1, "checkpoint": "", "echoes_seen": []},
		"npcs": default_npcs(),
		"world": {"time_of_day": 8.5, "day_count": 1, "hub_stage": 0,
			"hearths": [], "chests": [], "echoes": [], "discovered": [], "killed": [], "fog": "", "last_hearth": ""},
	}


## Every NPC of the registry as a new game has them.
static func default_npcs() -> Dictionary:
	var out := {}
	for def in NpcRegistry.all():
		out[String(def.id)] = new_npc_record(def)
	return out


static func new_npc_record(def: Resource) -> Dictionary:
	return {"alive": true, "location_id": def.home_location_id, "rescued": false, "relationship": 0,
		"death_cause": "", "flags": {}}


# --- Session -----------------------------------------------------------------------------------

func new_game() -> void:
	_state = default_state()
	session_active = true
	EventBus.state_replaced.emit()


func to_dict() -> Dictionary:
	return _state.duplicate(true)


## Replaces the whole state. Missing keys get defaults and every value is coerced to its
## type (JSON turns ints into floats), so a save → load round trip is exact.
## Returns false (and keeps the current state) if `data` is not a usable state.
func from_dict(data: Variant) -> bool:
	var clean := normalize(data)
	if clean.is_empty():
		return false
	_state = clean
	session_active = true
	EventBus.state_replaced.emit()
	return true


static func normalize(data: Variant) -> Dictionary:
	if not (data is Dictionary):
		return {}
	var d: Dictionary = data
	for section in ["meta", "player", "story", "world"]:
		if not (d.get(section) is Dictionary):
			return {}
	var out := default_state()
	var meta: Dictionary = d["meta"]
	out["meta"]["save_version"] = int(meta.get("save_version", SAVE_VERSION))
	out["meta"]["playtime"] = float(meta.get("playtime", 0.0))
	out["meta"]["last_saved_timestamp"] = int(meta.get("last_saved_timestamp", 0))

	var p: Dictionary = d["player"]
	var stats: Dictionary = {}
	var src_stats: Dictionary = p.get("stats", {}) if p.get("stats") is Dictionary else {}
	for k in src_stats:
		stats[String(k)] = _coerce_stat(String(k), src_stats[k])
	if not stats.has("level"):
		stats["level"] = 1
	out["player"]["stats"] = stats
	out["player"]["current_region"] = String(p.get("current_region", ""))
	var pos: Array = p.get("position", [0, 0, 0]) if p.get("position") is Array else [0, 0, 0]
	out["player"]["position"] = [float(pos[0]) if pos.size() > 0 else 0.0, float(pos[1]) if pos.size() > 1 else 0.0, float(pos[2]) if pos.size() > 2 else 0.0]
	var mems: Dictionary = {}
	var src_mems: Dictionary = p.get("memories", {}) if p.get("memories") is Dictionary else {}
	for id in src_mems:
		var sid := String(id)
		var st := String(src_mems[id])
		if not MemoryRegistry.has(StringName(sid)):
			push_warning("WorldState: dropped unknown memory id '%s' from the save" % sid)
			continue
		if not st in ["kept", "burned"]:
			push_warning("WorldState: dropped memory '%s' with unknown state '%s'" % [sid, st])
			continue
		mems[sid] = st
	out["player"]["memories"] = mems
	var ctx: Dictionary = {}
	var src_ctx: Dictionary = p.get("burn_context", {}) if p.get("burn_context") is Dictionary else {}
	for id in mems:
		if mems[id] != "burned":
			continue
		var c := String(src_ctx.get(id, "combat"))
		ctx[id] = c if c in BURN_CONTEXTS else "combat"
	out["player"]["burn_context"] = ctx

	var inv: Dictionary = d.get("inventory", {}) if d.get("inventory") is Dictionary else {}
	for k in inv:
		out["inventory"][String(k)] = int(inv[k])

	var flags: Dictionary = d.get("flags", {}) if d.get("flags") is Dictionary else {}
	for k in flags:
		out["flags"][String(k)] = _coerce_flag(flags[k])

	var s: Dictionary = d["story"]
	out["story"]["chapter"] = int(s.get("chapter", 1))
	out["story"]["checkpoint"] = String(s.get("checkpoint", ""))
	var echoes: Array = []
	for i in s.get("echoes_seen", []):
		echoes.append(int(i))
	out["story"]["echoes_seen"] = echoes

	var npcs: Dictionary = d.get("npcs", {}) if d.get("npcs") is Dictionary else {}
	for k in npcs:
		if not out["npcs"].has(String(k)):
			push_warning("WorldState: dropped unknown NPC id '%s' from the save" % k)
			continue
		if not (npcs[k] is Dictionary):
			continue
		var src: Dictionary = npcs[k]
		var rec: Dictionary = out["npcs"][String(k)]
		rec["alive"] = bool(src.get("alive", true))
		rec["location_id"] = String(src.get("location_id", rec["location_id"]))
		rec["rescued"] = bool(src.get("rescued", false))
		rec["relationship"] = int(src.get("relationship", 0))
		rec["death_cause"] = String(src.get("death_cause", ""))
		rec["flags"] = _coerce_tree(src["flags"]) if src.get("flags") is Dictionary else {}

	var w: Dictionary = d["world"]
	for k in w:
		out["world"][String(k)] = w[k]   # unknown keys survive (forward compatible)
	out["world"]["time_of_day"] = float(w.get("time_of_day", 8.5))
	out["world"]["day_count"] = int(w.get("day_count", 1))
	out["world"]["hub_stage"] = int(w.get("hub_stage", 0))
	for list in WORLD_LISTS:
		var ids: Array = []
		for id in w.get(list, []):
			ids.append(String(id))
		out["world"][list] = ids
	out["world"]["fog"] = String(w.get("fog", ""))
	out["world"]["last_hearth"] = String(w.get("last_hearth", ""))
	return out


## Equality that never errors on mismatched types.
static func _same(a: Variant, b: Variant) -> bool:
	return typeof(a) == typeof(b) and a == b


static func _coerce_stat(key: String, v: Variant) -> Variant:
	if key in INT_STATS:
		return int(v)
	if key in FLOAT_STATS:
		return float(v)
	if key in STRING_STATS:
		return String(v)
	return v


## Free-form data (NPC records): the flag rule applied all the way down.
static func _coerce_tree(v: Variant) -> Variant:
	if v is Dictionary:
		var d := {}
		for k in v:
			d[String(k)] = _coerce_tree(v[k])
		return d
	if v is Array:
		return (v as Array).map(func(x): return _coerce_tree(x))
	return _coerce_flag(v)


## JSON has one number type: a whole float comes back as int (flags are small ints or bools).
static func _coerce_flag(v: Variant) -> Variant:
	if v is float and is_equal_approx(v, roundf(v)):
		return int(v)
	if v is StringName:
		return String(v)
	return v


func mark_saved(timestamp: int) -> void:
	_state["meta"]["last_saved_timestamp"] = timestamp
	_state["meta"]["save_version"] = SAVE_VERSION


func playtime() -> float:
	return float(_state["meta"]["playtime"])


func last_saved() -> int:
	return int(_state["meta"]["last_saved_timestamp"])


# --- Flags ---------------------------------------------------------------------------------------

func set_flag(key: StringName, value: Variant = true) -> void:
	var k := String(key)
	var old: Variant = _state["flags"].get(k)
	var v: Variant = _coerce_flag(value)
	if _state["flags"].has(k) and _same(old, v):
		return
	_state["flags"][k] = v
	EventBus.flag_changed.emit(key, old, v)


func get_flag(key: StringName, default: Variant = null) -> Variant:
	return _state["flags"].get(String(key), default)


func has_flag(key: StringName) -> bool:
	return _state["flags"].has(String(key))


func clear_flag(key: StringName) -> void:
	var k := String(key)
	if not _state["flags"].has(k):
		return
	var old: Variant = _state["flags"][k]
	_state["flags"].erase(k)
	EventBus.flag_changed.emit(key, old, null)


# --- Memories (Yaddaş Yanğını) -------------------------------------------------------------------

func get_memory_state(id: StringName) -> MemoryState:
	match _state["player"]["memories"].get(String(id), ""):
		"kept":
			return MemoryState.KEPT
		"burned":
			return MemoryState.BURNED
	return MemoryState.UNKNOWN


## Remembers a memory (an echo's KEEP choice). Only a memory not yet decided can be kept.
## False if the id is unknown or the memory is already kept or burned.
func keep_memory(id: StringName) -> bool:
	if not MemoryRegistry.has(id) or get_memory_state(id) != MemoryState.UNKNOWN:
		return false
	_state["player"]["memories"][String(id)] = "kept"
	EventBus.memory_kept.emit(id)
	return true


## Burns a memory for good. `context` records where: "echo" (an echo's BURN choice) or
## "combat" (the fire wheel, Kül Şahı's offer). False if the id is unknown or it is
## already burned.
func burn_memory(id: StringName, context: StringName = &"combat") -> bool:
	if not MemoryRegistry.has(id) or has_burned(id):
		return false
	assert(String(context) in BURN_CONTEXTS, "unknown burn context")
	_state["player"]["memories"][String(id)] = "burned"
	_state["player"]["burn_context"][String(id)] = String(context) if String(context) in BURN_CONTEXTS else "combat"
	EventBus.memory_burned.emit(id)
	return true


## Where a burned memory burned: &"echo" or &"combat"; &"" if it is not burned.
func get_burn_context(id: StringName) -> StringName:
	return StringName(_state["player"]["burn_context"].get(String(id), ""))


func has_burned(id: StringName) -> bool:
	return get_memory_state(id) == MemoryState.BURNED


## Burned memory ids, in the order they burned.
func burned_memories() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in _state["player"]["memories"]:
		if _state["player"]["memories"][id] == "burned":
			out.append(StringName(id))
	return out



# --- Player --------------------------------------------------------------------------------------

## Merges `stats` (known keys are coerced to their types) and emits player_stats_changed.
func set_player_stats(stats: Dictionary) -> void:
	for k in stats:
		_state["player"]["stats"][String(k)] = _coerce_stat(String(k), stats[k])
	EventBus.player_stats_changed.emit()


func get_player_stat(key: StringName, default: Variant = null) -> Variant:
	return _state["player"]["stats"].get(String(key), default)


func player_stats() -> Dictionary:
	return (_state["player"]["stats"] as Dictionary).duplicate()


func set_player_position(p: Vector3) -> void:
	_state["player"]["position"] = [p.x, p.y, p.z]
	EventBus.player_stats_changed.emit()


func get_player_position() -> Vector3:
	var a: Array = _state["player"]["position"]
	return Vector3(a[0], a[1], a[2])


func set_region(region: StringName) -> void:
	if get_region() == region:
		return
	_state["player"]["current_region"] = String(region)
	EventBus.region_changed.emit(region)


func get_region() -> StringName:
	return StringName(_state["player"]["current_region"])


# --- Inventory -----------------------------------------------------------------------------------

func add_item(id: StringName, count := 1) -> void:
	if count <= 0:
		return
	var k := String(id)
	_state["inventory"][k] = int(_state["inventory"].get(k, 0)) + count
	EventBus.inventory_changed.emit(id, int(_state["inventory"][k]))


## False (and nothing changes) if there are fewer than `count`.
func remove_item(id: StringName, count := 1) -> bool:
	var k := String(id)
	var have := int(_state["inventory"].get(k, 0))
	if count <= 0 or have < count:
		return false
	if have == count:
		_state["inventory"].erase(k)
	else:
		_state["inventory"][k] = have - count
	EventBus.inventory_changed.emit(id, have - count)
	return true


func item_count(id: StringName) -> int:
	return int(_state["inventory"].get(String(id), 0))


func items() -> Dictionary:
	return (_state["inventory"] as Dictionary).duplicate()


# --- Story ---------------------------------------------------------------------------------------

func get_chapter() -> int:
	return int(_state["story"]["chapter"])


func set_chapter(n: int) -> void:
	if get_chapter() == n:
		return
	_state["story"]["chapter"] = n
	EventBus.story_changed.emit(&"chapter")


func get_checkpoint() -> String:
	return String(_state["story"]["checkpoint"])


func set_checkpoint(id: String) -> void:
	if get_checkpoint() == id:
		return
	_state["story"]["checkpoint"] = id
	EventBus.story_changed.emit(&"checkpoint")


func echoes_seen() -> Array[int]:
	var out: Array[int] = []
	for i in _state["story"]["echoes_seen"]:
		out.append(int(i))
	return out


## Records an ember echo as seen. False if it already was.
func mark_echo_seen(index: int) -> bool:
	if index in _state["story"]["echoes_seen"]:
		return false
	_state["story"]["echoes_seen"].append(index)
	EventBus.story_changed.emit(&"echoes_seen")
	return true


## Debug demos jump into the middle of the story with some echoes already seen.
func set_echoes_seen(list: Array) -> void:
	var out: Array = []
	for i in list:
		out.append(int(i))
	_state["story"]["echoes_seen"] = out
	EventBus.story_changed.emit(&"echoes_seen")


# --- NPCs ---------------------------------------------------------------------------------------
# One record per NpcDefinition. A dead NPC stays dead: nothing brings them back, and the
# spawner never builds a body for them again.

func has_npc(id: StringName) -> bool:
	return _state["npcs"].has(String(id))


## A copy of the NPC's record ({} for an unknown id).
func get_npc(id: StringName) -> Dictionary:
	return (_state["npcs"].get(String(id), {}) as Dictionary).duplicate(true)


func npc_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in _state["npcs"]:
		out.append(StringName(k))
	return out


func is_npc_alive(id: StringName) -> bool:
	return has_npc(id) and bool(_state["npcs"][String(id)]["alive"])


func get_npc_location(id: StringName) -> String:
	return String(_state["npcs"].get(String(id), {}).get("location_id", ""))


func is_npc_rescued(id: StringName) -> bool:
	return has_npc(id) and bool(_state["npcs"][String(id)]["rescued"])


func get_npc_relationship(id: StringName) -> int:
	return int(_state["npcs"].get(String(id), {}).get("relationship", 0))


func get_npc_death_cause(id: StringName) -> String:
	return String(_state["npcs"].get(String(id), {}).get("death_cause", ""))


## Moves a living NPC to `location_id` (a POI id, PARTY, SON_OCAQ or ""). Emits npc_moved.
func move_npc(id: StringName, location_id: String) -> bool:
	if not is_npc_alive(id):
		return false
	var rec: Dictionary = _state["npcs"][String(id)]
	var old := String(rec["location_id"])
	if old == location_id:
		return false
	rec["location_id"] = location_id
	EventBus.npc_moved.emit(id, old, location_id)
	return true


## Rescued: the NPC goes to the hub (SON_OCAQ). Emits npc_rescued, then npc_moved.
func rescue_npc(id: StringName) -> bool:
	if not is_npc_alive(id) or is_npc_rescued(id):
		return false
	_state["npcs"][String(id)]["rescued"] = true
	EventBus.npc_rescued.emit(id)
	move_npc(id, SON_OCAQ)
	return true


## Permanent death. Only the story calls this (companions are downed, never killed, in
## ordinary combat). Emits npc_died.
func kill_npc(id: StringName, cause := "") -> bool:
	if not is_npc_alive(id):
		return false
	var rec: Dictionary = _state["npcs"][String(id)]
	rec["alive"] = false
	rec["death_cause"] = cause
	EventBus.npc_died.emit(id, cause)
	return true


## Adds `delta` to the relationship. Emits npc_relationship_changed(id, old, new).
func change_npc_relationship(id: StringName, delta: int) -> void:
	if not has_npc(id) or delta == 0:
		return
	var rec: Dictionary = _state["npcs"][String(id)]
	var old := int(rec["relationship"])
	rec["relationship"] = old + delta
	EventBus.npc_relationship_changed.emit(id, old, old + delta)


func set_npc_flag(id: StringName, key: StringName, value: Variant = true) -> void:
	if not has_npc(id):
		return
	var flags: Dictionary = _state["npcs"][String(id)]["flags"]
	if flags.has(String(key)) and _same(flags[String(key)], value):
		return
	flags[String(key)] = _coerce_flag(value)
	EventBus.npc_changed.emit(id)


func get_npc_flag(id: StringName, key: StringName, default: Variant = null) -> Variant:
	return _state["npcs"].get(String(id), {}).get("flags", {}).get(String(key), default)


# --- World ---------------------------------------------------------------------------------------

static func phase_of(hour: float) -> StringName:
	if hour >= 5.0 and hour < 8.0:
		return &"dawn"
	if hour >= 8.0 and hour < 18.0:
		return &"day"
	if hour >= 18.0 and hour < 21.0:
		return &"dusk"
	return &"night"


## Records the clock. Counts a new day when it wraps past midnight and emits
## time_of_day_changed only when the phase (dawn/day/dusk/night) changes.
func set_time_of_day(hour: float) -> void:
	var old := get_time_of_day()
	if is_equal_approx(old, hour):
		return
	_state["world"]["time_of_day"] = hour
	if hour < old - 12.0:
		_state["world"]["day_count"] = get_day_count() + 1
	if phase_of(old) != phase_of(hour):
		EventBus.time_of_day_changed.emit(phase_of(hour))


func get_time_of_day() -> float:
	return float(_state["world"]["time_of_day"])


func get_day_count() -> int:
	return int(_state["world"]["day_count"])


func set_hub_stage(stage: int) -> void:
	if get_hub_stage() == stage:
		return
	_state["world"]["hub_stage"] = stage
	EventBus.world_changed.emit(&"hub_stage")


func get_hub_stage() -> int:
	return int(_state["world"]["hub_stage"])


## Open-world id lists: hearths, chests, echoes, discovered, killed.
func has_world_entry(list: StringName, id: String) -> bool:
	return id in _state["world"].get(String(list), [])


## Adds `id` to a world list. False if it was already there.
func add_world_entry(list: StringName, id: String) -> bool:
	var k := String(list)
	if not _state["world"].has(k):
		_state["world"][k] = []
	if id in _state["world"][k]:
		return false
	_state["world"][k].append(id)
	EventBus.world_changed.emit(list)
	return true


func clear_world_list(list: StringName) -> void:
	_state["world"][String(list)] = []
	EventBus.world_changed.emit(list)


func world_list(list: StringName) -> Array[String]:
	var out: Array[String] = []
	for id in _state["world"].get(String(list), []):
		out.append(String(id))
	return out


## Single world values that have no dedicated accessor (fog, last_hearth).
func set_world_value(key: StringName, value: Variant) -> void:
	if _state["world"].has(String(key)) and _same(_state["world"][String(key)], value):
		return
	_state["world"][String(key)] = value
	EventBus.world_changed.emit(key)


func get_world_value(key: StringName, default: Variant = null) -> Variant:
	return _state["world"].get(String(key), default)


# --- Dialogue conditions -------------------------------------------------------------------------

## Condition strings used by dialogue branches: "memory:<id>" (burned), "kept:<id>",
## "flag:<name>", "alive:<npc>", "dead:<npc>", "rescued:<npc>".
func check(cond: String) -> bool:
	var arg := cond.get_slice(":", 1)
	match cond.get_slice(":", 0):
		"memory":
			return has_burned(StringName(arg))
		"kept":
			return get_memory_state(StringName(arg)) == MemoryState.KEPT
		"flag":
			return has_flag(StringName(arg))
		"alive":
			return is_npc_alive(StringName(arg))
		"dead":
			return has_npc(StringName(arg)) and not is_npc_alive(StringName(arg))
		"rescued":
			return is_npc_rescued(StringName(arg))
	return false


## Side effects attached to dialogue nodes and choices ("do": [...]): "flag:<name>".
func apply(action: String) -> void:
	if action.get_slice(":", 0) == "flag":
		set_flag(StringName(action.get_slice(":", 1)))
