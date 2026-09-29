extends RefCounted
## Son Ocaq's layout and rules as data (res://data/hub/son_ocaq.json): the caravanserai
## rooms and the buildings outside, who lives where, which doors belong to whom, the hub
## services and the hearth's growth. Everything here is DERIVED from WorldState: a door
## is open by day when someone of its room is home, closed at night, unless the story
## overrides it (WorldState.set_door_override). Nothing is stored here.
## Use: const HubData := preload("res://scripts/hub/hub_data.gd")

const PATH := "res://data/hub/son_ocaq.json"
const PROTAGONIST := "protagonist"      # Aras's resident id in the room lists

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data


## Every room and outside building: {id, door, residents, workers, kind: "room" | "outside", ...}.
## residents sleep there; workers (outside workplaces) stand there by day.
static func places() -> Array:
	var out: Array = []
	for r in data()["rooms"]:
		var d: Dictionary = r.duplicate()
		d["kind"] = "room"
		if not d.has("workers"):
			d["workers"] = []
		out.append(d)
	for o in data()["outside"]:
		var d: Dictionary = o.duplicate()
		d["kind"] = "outside"
		if not d.has("workers"):
			d["workers"] = []
		out.append(d)
	return out


static func place(id: String) -> Dictionary:
	for p in places():
		if p["id"] == id:
			return p
	return {}


static func place_of_door(door_id: String) -> Dictionary:
	for p in places():
		if p["door"] == door_id:
			return p
	return {}


## The room an NPC lives in: the first room_rule whose condition holds, else the place
## that lists them. "" if they have none.
static func room_of(npc_id: String) -> String:
	for rule in data().get("room_rules", []):
		if rule["npc"] == npc_id and WorldState.check(rule["condition"]):
			return rule["room"]
	for p in places():
		if (p["residents"] as Array).has(npc_id):
			return p["id"]
	return ""


## Where an NPC is by day: their workplace if they have one, else their room.
static func day_place_of(npc_id: String) -> String:
	for p in places():
		if (p["workers"] as Array).has(npc_id):
			return p["id"]
	return room_of(npc_id)


## Who lives in `place_id` now (room rules applied).
static func residents_of(place_id: String) -> Array:
	var out: Array = []
	var seen := {}
	for p in places():
		for id in p["residents"]:
			seen[id] = true
	for rule in data().get("room_rules", []):
		seen[rule["npc"]] = true
	for id in seen:
		if room_of(id) == place_id:
			out.append(id)
	return out


## Whether a resident is home in Son Ocaq: alive and located there. Aras's own room
## always counts as lived in.
static func is_home(resident_id: String) -> bool:
	if resident_id == PROTAGONIST:
		return true
	var id := StringName(resident_id)
	return WorldState.is_npc_alive(id) and WorldState.get_npc_location(id) == WorldState.SON_OCAQ


## Someone of this place died opening its door to a shade (death_cause "door").
static func is_door_death_place(place_id: String) -> bool:
	for r in residents_of(place_id):
		var id := StringName(r)
		if r != PROTAGONIST and not WorldState.is_npc_alive(id) and WorldState.get_npc_death_cause(id) == "door":
			return true
	return false


## Someone lives in this place and is home.
static func is_lived_in(place_id: String) -> bool:
	return residents_of(place_id).any(func(r): return is_home(r))


## A door's state: the story's override if any; else closed at night; else open when
## someone of its place is home (or, for a workplace, someone who works there).
static func door_open(door_id: String) -> bool:
	var o := WorldState.get_door_override(StringName(door_id))
	if o != "":
		return o == "open"
	if WorldState.get_phase() == &"night":
		return false
	var p := place_of_door(door_id)
	if p.is_empty():
		return false
	return is_lived_in(p["id"]) or (p["workers"] as Array).any(func(w): return is_home(w))


## A hub service ("ash_upgrades", "shop", "training") is open when its NPC lives here.
## Placeholder hook: the services themselves come later.
static func service_available(service: String) -> bool:
	var services: Dictionary = data().get("services", {})
	for npc in services:
		if services[npc] == service:
			return is_home(npc)
	return false


static func services_available() -> Array:
	var services: Dictionary = data().get("services", {})
	return services.values().filter(func(s): return service_available(s))


## The courtyard hearth's flame scale for the resolved core grief arcs.
static func hearth_scale() -> float:
	var stages: Array = data()["hearth"]["stages"]
	return float(stages[clampi(WorldState.core_grief_resolved_count(), 0, stages.size() - 1)])
