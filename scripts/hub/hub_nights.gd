extends RefCounted
## The nights of Son Ocaq: warnings and door deaths (data/hub/night_events.json). Rules only,
## on WorldState — the hub mode calls on_nightfall() when night falls and resolve_morning()
## while Aras waits at the hearth until morning; the level shows what follows.
##
## Nights are counted in the hub only (per NPC, the nights they spent here: NPC flag
## "hub_nights"). From the event's warning_night on, while warning_if holds, the NPC is
## WARNED: their night line turns to a warning, their lost one's shade knocks at their door.
## FAIRNESS RULE (STORY_SLICE §S10): permanent loss never comes before the player actually
## received the warning. The countdown starts only once it was HEARD — the warning line shown
## at their door (DoorTalk) or a story line ("warning_heard:<npc>", e.g. Domrul's line 3).
## Unheard, the warning simply repeats on the next hub night. The death resolves only while
## waiting until morning, on a hub night AFTER the one it was heard for, if death_if holds;
## cancel_if (e.g. their grief resolved) ends the warning for good. The death is OFF-SCREEN:
## in the morning the door is ajar, the room empty, ash on the threshold and ash footprints
## from the gate — all derived from the NPC's death_cause "door", so it persists.
## Use: const HubNights := preload("res://scripts/hub/hub_nights.gd")

const PATH := "res://data/hub/night_events.json"
const NIGHTS := &"hub_nights"           # NPC flag: hub nights they spent in Son Ocaq
const NIGHT_DAY := &"hub_night_day"     # NPC flag: the day whose night was counted last
const WARNED := &"door_warned_night"    # NPC flag: the hub night the warning began (-1: none)
const HEARD := &"warning_heard_night"   # NPC flag: the hub night whose warning was heard (-1)
const CAUSE := "door"
const MOURNED := &"door_death_morning"  # NPC flag: the day whose morning found the door ajar

static var _data: Dictionary = {}


static func events() -> Array:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _data["events"]


static func event_of(id: StringName) -> Dictionary:
	for e in events():
		if StringName(e["npc"]) == id:
			return e
	return {}


static func hub_nights(id: StringName) -> int:
	return int(WorldState.get_npc_flag(id, NIGHTS, 0))


## Night falls in the hub: count the night for everyone living here (once per day), then warn
## those whose night has come; a cancelled or lapsed warning ends.
static func on_nightfall() -> void:
	var day := WorldState.get_day_count()
	for id in WorldState.npc_ids():
		if WorldState.is_npc_alive(id) and WorldState.get_npc_location(id) == WorldState.SON_OCAQ \
				and int(WorldState.get_npc_flag(id, NIGHT_DAY, -1)) != day:
			WorldState.set_npc_flag(id, NIGHT_DAY, day)
			WorldState.set_npc_flag(id, NIGHTS, hub_nights(id) + 1)
	for e in events():
		var id := StringName(e["npc"])
		if not WorldState.is_npc_alive(id) or WorldState.get_npc_location(id) != WorldState.SON_OCAQ:
			continue
		if _cancelled(e) or not WorldState.check(String(e.get("warning_if", ""))):
			_clear(id)
		elif not is_warned(id) and hub_nights(id) >= int(e.get("warning_night", 1)):
			WorldState.set_npc_flag(id, WARNED, hub_nights(id))


static func _cancelled(e: Dictionary) -> bool:
	return String(e.get("cancel_if", "")) != "" and WorldState.check(String(e["cancel_if"]))


static func _clear(id: StringName) -> void:
	WorldState.set_npc_flag(id, WARNED, -1)
	WorldState.set_npc_flag(id, HEARD, -1)


static func is_warned(id: StringName) -> bool:
	if int(WorldState.get_npc_flag(id, WARNED, -1)) < 0 or not WorldState.is_npc_alive(id):
		return false
	return not _cancelled(event_of(id))


## The player received the warning (the line at the door, or a story line about it).
## Counts for the current hub night; the first time only. Returns true if it was new.
static func mark_heard(id: StringName) -> bool:
	if not is_warned(id) or was_heard(id):
		return false
	WorldState.set_npc_flag(id, HEARD, hub_nights(id))
	return true


static func was_heard(id: StringName) -> bool:
	return int(WorldState.get_npc_flag(id, HEARD, -1)) >= 0


## Waiting at the hearth until morning, at night: the deaths of this night happen now, in
## the dark, off-screen. Only on a hub night after the one the warning was heard for.
## Returns who died.
static func resolve_morning() -> Array:
	var died: Array = []
	if WorldState.get_phase() != &"night":
		return died
	for e in events():
		var id := StringName(e["npc"])
		if not is_warned(id) or not was_heard(id) or WorldState.get_npc_location(id) != WorldState.SON_OCAQ:
			continue
		if int(WorldState.get_npc_flag(id, HEARD, -1)) < hub_nights(id) and WorldState.check(String(e.get("death_if", ""))):
			WorldState.set_npc_flag(id, MOURNED, WorldState.get_day_count() + 1)   # the morning to come
			WorldState.kill_npc(id, CAUSE)
			died.append(id)
	return died


## The morning after a door death (that whole day, until night): the NPC whose door stands
## ajar and is mourned — Peri Nene sings there. &"" otherwise.
static func mourned() -> StringName:
	if WorldState.get_phase() == &"night":
		return &""
	for id in door_dead():
		if int(WorldState.get_npc_flag(id, MOURNED, -1)) == WorldState.get_day_count():
			return id
	return &""


## Who died at their door (the morning's aftermath): NPC ids.
static func door_dead() -> Array:
	return WorldState.npc_ids().filter(func(id): return not WorldState.is_npc_alive(id) and WorldState.get_npc_death_cause(id) == CAUSE)
