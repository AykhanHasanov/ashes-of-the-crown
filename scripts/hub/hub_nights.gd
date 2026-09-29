extends RefCounted
## The nights of Son Ocaq: warnings and door deaths (data/hub/night_events.json). Rules only,
## on WorldState — the hub mode calls on_nightfall() when night falls and resolve_morning()
## while Aras waits at the hearth until morning; the level shows what follows.
##
## A door death happens OFF-SCREEN: the night before, the NPC is warned (their night line
## turns to a warning, their lost one's shade knocks at their door); the death itself
## resolves only while waiting until morning, on a later night, if its condition holds. In
## the morning the door is ajar, the room empty, ash on the threshold and ash footprints
## from the gate — all derived from the NPC's death_cause "door", so it persists.
## Use: const HubNights := preload("res://scripts/hub/hub_nights.gd")

const PATH := "res://data/hub/night_events.json"
const WARNED := &"door_warned_day"      # NPC flag: the day of the warning night
const CAUSE := "door"

static var _data: Dictionary = {}


static func events() -> Array:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data["events"]


## Night falls: warn those whose warning condition holds; a warning whose condition no
## longer holds lapses (the player acted in time).
static func on_nightfall() -> void:
	for e in events():
		var id := StringName(e["npc"])
		if not WorldState.is_npc_alive(id):
			continue
		if WorldState.check(e["warning_if"]):
			if not is_warned(id):
				WorldState.set_npc_flag(id, WARNED, WorldState.get_day_count())
		elif is_warned(id):
			WorldState.set_npc_flag(id, WARNED, -1)


static func is_warned(id: StringName) -> bool:
	return int(WorldState.get_npc_flag(id, WARNED, -1)) >= 0 and WorldState.is_npc_alive(id)


## Waiting at the hearth until morning, at night: the deaths of this night happen now, in
## the dark, off-screen. Only on a night after the warning night. Returns who died.
static func resolve_morning() -> Array:
	var died: Array = []
	if WorldState.get_phase() != &"night":
		return died
	for e in events():
		var id := StringName(e["npc"])
		if not is_warned(id) or WorldState.get_npc_location(id) != WorldState.SON_OCAQ:
			continue
		if int(WorldState.get_npc_flag(id, WARNED, -1)) < WorldState.get_day_count() and WorldState.check(e["death_if"]):
			WorldState.kill_npc(id, CAUSE)
			died.append(id)
	return died


## Who died at their door (the morning's aftermath): NPC ids.
static func door_dead() -> Array:
	return WorldState.npc_ids().filter(func(id): return not WorldState.is_npc_alive(id) and WorldState.get_npc_death_cause(id) == CAUSE)
