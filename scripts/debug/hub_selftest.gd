extends Node
## Headless checks for Son Ocaq (the hub): its data, who lives where, derived door states,
## stepped time phases, grief arcs and the hearth, hub services, lost ones, night events
## and the v6 save migration. Later stages add the scene, door mode, shades and growth.
## Run: godot --headless --path . res://scenes/tests/hub_test.tscn   (exit code = failures)

const HubData := preload("res://scripts/hub/hub_data.gd")
const Door := preload("res://scripts/hub/door.gd")
const NpcRegistry := preload("res://scripts/core/npc_registry.gd")

## STORY_BIBLE Act I: these live in Son Ocaq from the start; the others are brought in.
const START_IN_HUB := [&"domrul", &"ehliman", &"gulcin", &"kemal", &"peri_nene", &"sona"]
const RESCUED_LATER := [&"elvin", &"esref", &"ibrahim", &"nermin", &"sabir", &"sahbaz", &"samir"]
const CORE := [&"ehliman", &"elvin", &"esref", &"ibrahim", &"nermin", &"sabir", &"sahbaz", &"sona"]

var _fails := 0
var _doors := {}
var _door_events: Array = []
var _phases: Array = []


func _ready() -> void:
	EventBus.door_changed.connect(func(id, open): _door_events.append([id, open]))
	EventBus.time_of_day_changed.connect(func(p): _phases.append(p))
	_run.call_deferred()


func _run() -> void:
	_data()
	await _doors_and_time()
	_grief_and_services()
	_lost_ones()
	_migration()
	print("HUB TESTS DONE, failures: ", _fails)
	get_tree().quit(_fails)


# --- Data -----------------------------------------------------------------------------------------

func _data() -> void:
	var places := HubData.places()
	var doors: Array = places.map(func(p): return p["door"])
	var unique := {}
	for d in doors:
		unique[d] = true
	_check("every place has its own stable door id", unique.size() == doors.size() and places.size() >= 13)
	var residents: Array = []
	for p in places:
		residents.append_array(p["residents"])
	_check("every resident is Aras or a known NPC", residents.all(func(r): return r == HubData.PROTAGONIST or NpcRegistry.has(StringName(r))))
	var at_start: Array = NpcRegistry.all().filter(func(d): return d.home_location_id == "son_ocaq").map(func(d): return d.id)
	_check("a new game starts these in Son Ocaq: Sona, Ehliman, Peri Nene, Kemal, Gülçin, Domrul", at_start == START_IN_HUB, str(at_start))
	_check("the others have a room but are brought in later", RESCUED_LATER.all(func(id): return NpcRegistry.get_def(id).home_location_id == "" and HubData.room_of(String(id)) != ""))
	_check("Rüfət lives in Aras's room; Samir with Nermin; Sona in her own room", HubData.room_of("rufet") == "room_protagonist"
		and HubData.room_of("samir") == "room_nermin" and HubData.room_of("sona") == "room_sona")
	_check("Kemal's smithy and Gülçin's bakery stand outside the caravanserai", HubData.place(HubData.room_of("kemal"))["kind"] == "outside"
		and HubData.place(HubData.room_of("gulcin"))["kind"] == "outside")


# --- Doors and stepped time ------------------------------------------------------------------------

func _doors_and_time() -> void:
	WorldState.new_game()
	WorldState.set_time_of_day(10.0)
	for p in HubData.places():
		var d = Door.new()
		d.setup(StringName(p["door"]), p["id"])
		add_child(d)
		_doors[p["door"]] = d
	await get_tree().process_frame
	_check("by day, the doors of people at home are open", _open("door_sona") and _open("door_ehliman") and _open("door_kemal"))
	_check("Aras's own door is open by day", _open("door_protagonist"))
	_check("rooms of people not yet brought in stay closed", not _open("door_sabir") and not _open("door_esref"))
	var open_before: int = _doors.values().filter(func(d): return d.is_open).size()
	_door_events.clear()
	_phases.clear()
	await get_tree().create_timer(0.5).timeout
	_check("the hub clock does not run by itself", is_equal_approx(WorldState.get_time_of_day(), 10.0))
	WorldState.set_time_of_day(21.0)   # "wait until night" at the hearth
	await get_tree().process_frame
	_check("waiting until night: the phase event fires", _phases == [&"night"] and WorldState.check("time:night"))
	_check("at night every door closes", _doors.values().all(func(d): return not d.is_open))
	_check("... and each announces it (door_changed)", open_before == 7 and _door_events.size() == open_before and _door_events.all(func(e): return e[1] == false), str(_door_events))
	WorldState.set_time_of_day(7.0)   # "wait until morning"
	await get_tree().process_frame
	_check("morning: the phase event fires and doors open again", _phases.back() == &"dawn" and _open("door_sona") and WorldState.check("time:dawn"))
	WorldState.rescue_npc(&"sabir")
	await get_tree().process_frame
	_check("a rescued NPC moves in: his door opens by day", _open("door_sabir"))
	WorldState.kill_npc(&"ehliman", "test")
	await get_tree().process_frame
	_check("a dead NPC's door stays closed", not _open("door_ehliman"))
	WorldState.set_door_override(&"door_ehliman", "open")
	await get_tree().process_frame
	_check("the story can override a door", _open("door_ehliman") and WorldState.get_door_override(&"door_ehliman") == "open")
	WorldState.set_door_override(&"door_ehliman", "")
	await get_tree().process_frame
	_check("... and clear the override", not _open("door_ehliman"))
	WorldState.set_flag(&"sona_moved_in")
	await get_tree().process_frame
	_check("room rule: Sona can move into Aras's room (story flag hook)", HubData.room_of("sona") == "room_protagonist"
		and HubData.residents_of("room_protagonist").has("sona") and not _open("door_sona"))
	WorldState.clear_flag(&"sona_moved_in")
	var closed_before := not _open("door_sabir")
	WorldState.set_time_of_day(22.0)
	await get_tree().process_frame
	_check("an open door blocks the way only when closed", not closed_before and _doors["door_sabir"]._blocker.disabled == false)


func _open(door_id: String) -> bool:
	return _doors[door_id].is_open


# --- Grief, hearth, services -----------------------------------------------------------------------

func _grief_and_services() -> void:
	WorldState.new_game()
	var base := HubData.hearth_scale()
	_check("core grief arcs are the eight core residents", NpcRegistry.all().filter(func(d): return d.tags.has("core_grief")).map(func(d): return d.id) == CORE)
	WorldState.resolve_grief(&"sona")
	WorldState.resolve_grief(&"esref")
	WorldState.resolve_grief(&"peri_nene")   # not a core arc
	_check("grief:<npc> condition", WorldState.check("grief:sona") and not WorldState.check("grief:sabir"))
	_check("the hearth counts core arcs only", WorldState.core_grief_resolved_count() == 2 and HubData.hearth_scale() > base)
	_check("services are closed until their people live here", HubData.services_available().is_empty())
	WorldState.rescue_npc(&"ibrahim")
	WorldState.rescue_npc(&"nermin")
	_check("rescuing İbrahim and Nermin opens ash upgrades and the shop (placeholder hooks)",
		HubData.service_available("ash_upgrades") and HubData.service_available("shop") and not HubData.service_available("training"))


# --- Lost ones and night events ---------------------------------------------------------------------

func _lost_ones() -> void:
	var looks: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/looks.json"))
	var ok := true
	for id in CORE + [&"domrul"]:
		var d: Resource = NpcRegistry.get_def(id)
		var has_npc: bool = d.lost_one_npc != &"" and NpcRegistry.has(d.lost_one_npc)
		var has_placeholder: bool = d.lost_one_name_key != "" and tr(d.lost_one_name_key) != d.lost_one_name_key and looks.has(d.lost_one_look_id)
		if not (has_npc or has_placeholder):
			ok = false
			print("   no lost one: ", id)
	_check("every core NPC (and Domrul) has a lost one", ok)
	_check("Sona's lost one is Narin; Eşref's is his wife (placeholder)", NpcRegistry.get_def(&"sona").lost_one_npc == &"narin"
		and tr(NpcRegistry.get_def(&"esref").lost_one_name_key).contains("karısı"))
	var events: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/hub/night_events.json"))["events"]
	var named := true
	for e in events:
		var id := StringName(e["npc"])
		if not NpcRegistry.has(id) or (NpcRegistry.get_def(id).lost_one_npc == &"" and NpcRegistry.get_def(id).lost_one_name_key == ""):
			named = false
	_check("night events name NPCs that have a lost one", named)


# --- Save migration ----------------------------------------------------------------------------------

func _migration() -> void:
	var v5 := {"meta": {"save_version": 5}, "player": {"stats": {}, "memories": {}}, "story": {}, "flags": {}, "npcs": {},
		"world": {"hub_stage": 2, "time_of_day": 20.0}}
	var clean := WorldState.normalize(SaveManager.migrate(JSON.parse_string(JSON.stringify(v5))))
	_check("migration v5 → v6: hub_stage retired, doors start empty", not clean["world"].has("hub_stage")
		and clean["world"]["doors"] == {} and int(clean["meta"]["save_version"]) == 6)
	WorldState.new_game()
	WorldState.set_door_override(&"door_sahbaz", "closed")
	var bad := WorldState.to_dict()
	bad["world"]["doors"]["door_x"] = "ajar"
	var norm := WorldState.normalize(JSON.parse_string(JSON.stringify(bad)))
	_check("door overrides survive a save; invalid states are dropped", norm["world"]["doors"] == {"door_sahbaz": "closed"})


func _check(label: String, ok: bool, detail := "") -> void:
	print(("PASS  " if ok else "FAIL  ") + label + ("" if detail == "" else "  (" + detail + ")"))
	if not ok:
		_fails += 1
