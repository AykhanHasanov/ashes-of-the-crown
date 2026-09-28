extends Node
## Headless checks for Son Ocaq (the hub): its data, who lives where, derived door states,
## stepped time phases, grief arcs and the hearth, hub services, lost ones, night events
## and the v6 save migration. Later stages add the scene, door mode, shades and growth.
## Run: godot --headless --path . res://scenes/tests/hub_test.tscn   (exit code = failures)

const HubData := preload("res://scripts/hub/hub_data.gd")
const Door := preload("res://scripts/hub/door.gd")
const NpcRegistry := preload("res://scripts/core/npc_registry.gd")
const HubTravel := preload("res://scripts/hub/hub_travel.gd")
const HubLevel := preload("res://scripts/hub/hub_level.gd")
const ControlHints := preload("res://scripts/ui/control_hints.gd")
const Names := preload("res://scripts/core/names.gd")
const HUB := "res://scenes/son_ocaq.tscn"
const HOST := "res://scenes/tests/echo_host.tscn"
const TEST_DIR := "user://test_hub_saves/"

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
	SaveManager.directory = TEST_DIR
	SaveManager.allow_in_demo = true
	# Scene changes must not free the test: hand the "current scene" role to a dummy
	var dummy := Node.new()
	get_tree().root.add_child.call_deferred(dummy)
	_start.call_deferred(dummy)


func _start(dummy: Node) -> void:
	get_tree().current_scene = dummy
	_run()


func _run() -> void:
	_data()
	await _doors_and_time()
	_grief_and_services()
	_lost_ones()
	_migration()
	for d in _doors.values():
		d.queue_free()
	await _scene()
	await _travel()
	_wipe()
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
	_check("Kemal and Gülçin sleep in a caravanserai room", HubData.room_of("kemal") == "room_kemal_gulcin" and HubData.room_of("gulcin") == "room_kemal_gulcin"
		and HubData.place("room_kemal_gulcin")["kind"] == "room")
	_check("... the smithy and the bakery outside are their day workplaces", HubData.day_place_of("kemal") == "smithy"
		and HubData.day_place_of("gulcin") == "bakery" and HubData.place("smithy")["kind"] == "outside" and HubData.place("smithy")["residents"].is_empty())


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
	_check("by day, the doors of people at home are open", _open("door_sona") and _open("door_ehliman") and _open("door_kemal_gulcin") and _open("door_smithy"))
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
	_check("... and each announces it (door_changed)", open_before == 8 and _door_events.size() == open_before and _door_events.all(func(e): return e[1] == false), str(_door_events))
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
	_check("Sabir's lost one is Kür; Elvin's his mother, Nermin's her husband (placeholders)", NpcRegistry.get_def(&"sabir").lost_one_npc == &"kur"
		and tr(NpcRegistry.get_def(&"elvin").lost_one_name_key).contains("annesi") and tr(NpcRegistry.get_def(&"nermin").lost_one_name_key).contains("kocası"))
	var living_lost: Array = NpcRegistry.all().filter(func(d): return d.lost_one_npc != &"" and NpcRegistry.get_def(d.lost_one_npc).npc_kind == "human")
	_check("no lost one is a living person: Samir's shade never comes to Nermin's door", living_lost.is_empty(), str(living_lost.map(func(d): return d.id)))
	var lines: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/hub/door_lines.json"))["lines"]
	_check("placeholder hook: Nermin notices Samir's shade never knocks", lines.any(func(l): return l["npc"] == "nermin" and tr(l["key"]) != l["key"]))
	WorldState.new_game()
	_check("Sabir calls Aras by his own name ...", Names.fill("{PROTAGONIST}", &"sabir") == "Aras")
	WorldState.set_flag(&"sabir_confused")
	_check("... and, when the story says so, 'Kür' (condition-based hook)", Names.fill("{PROTAGONIST}", &"sabir") == "Kür"
		and Names.fill("{PROTAGONIST}", &"sona") == "Aras")
	WorldState.clear_flag(&"sabir_confused")
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


# --- The hub scene (stage 2) --------------------------------------------------------------------

func _scene() -> void:
	WorldState.new_game()
	SaveManager.active_slot = 1
	WorldState.set_time_of_day(10.0)
	var hub := await _go(HUB)
	var lvl = hub.level
	var room_doors: Array = HubData.places().filter(func(p): return p["kind"] == "room").map(func(p): return p["door"])
	_check("the scene builds a live Door for every place", lvl.doors.keys().size() == HubData.places().size()
		and HubData.places().all(func(p): return lvl.doors.has(p["door"]) and lvl.doors[p["door"]].place_id == p["id"]))
	_check("entering Son Ocaq sets the region", WorldState.get_region() == &"son_ocaq")
	# From the hearth every courtyard door is in sight: nothing between the fire and the door
	var space: PhysicsDirectSpaceState3D = hub.get_world_3d().direct_space_state
	var eye: Vector3 = lvl.hearth_pos + Vector3(0, 1.6, 0)
	var hidden: Array = []
	for id in room_doors:
		var door: Node3D = lvl.doors[id]
		var target: Vector3 = door.global_position + Vector3(0, 1.2, 0) + door.global_basis.z * 0.25
		var q := PhysicsRayQueryParameters3D.create(eye, target)
		q.exclude = [hub.player.get_rid()] + hub.get_tree().get_nodes_in_group("npcs").map(func(n): return n.get_rid())   # the buildings, not people
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and hit["position"].distance_to(target) > 0.6:
			hidden.append("%s (%s)" % [id, hit["collider"].get_parent().name])
	_check("from the hearth, every courtyard door is visible", hidden.is_empty(), str(hidden))
	var outside: Array = HubData.places().filter(func(p): return p["kind"] == "outside")
	_check("outside the walls: the smithy and the bakery", outside.size() == 2 and outside.all(func(p): return lvl.doors[p["door"]].global_position.z > HubLevel.SOUTH_Z))
	await _frames(4)
	var sona = hub.npcs.body(&"sona")
	_check("by day, residents stand at their own door", sona != null and sona.global_position.distance_to(lvl.stand_point("room_sona")) < 0.5
		and hub.npcs.body(&"sabir") == null)
	var kemal = hub.npcs.body(&"kemal")
	_check("... Kemal at his smithy", kemal != null and kemal.global_position.distance_to(lvl.stand_point("smithy")) < 0.5)
	# The same controller, input map and HUD hints as the valley
	var valley = load("res://scripts/world_mode.gd").new()
	var valley_player = valley._make_player()
	_check("the hub and the valley use the same player controller", valley_player.get_script() == hub.player.get_script())
	valley_player.free()
	valley.free()
	var hint: String = hub.hud._hint.text
	_check("the HUD hints come from the live input map (same builder as the valley)", hint == ControlHints.protagonist()
		and hint.contains("J/LMB") and hint.contains("RMB") and hint.contains("Space"))
	_check("no mode writes its own control hints", not FileAccess.get_file_as_string("res://scripts/world_mode.gd").contains("set_hint(")
		and not FileAccess.get_file_as_string("res://scripts/hub_mode.gd").contains("set_hint("))
	# Entering: nothing between the camera and the protagonist
	var cam: Camera3D = hub.rig.camera
	var head: Vector3 = hub.player.global_position + Vector3(0, 1.5, 0)
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, head)
	q.exclude = [hub.player.get_rid()]
	var blocked: Dictionary = hub.get_world_3d().direct_space_state.intersect_ray(q)
	_check("on entry the camera sees the protagonist (no wall or pier between)", blocked.is_empty(), str(blocked.get("collider", "")))
	# Rüfət beside or a little behind, never between the camera and the protagonist
	WorldState.move_npc(&"rufet", WorldState.PARTY)
	await _seconds(2.0)
	var ally = hub.npcs.body(&"rufet")
	var fwd: Vector3 = -cam.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var rel: Vector3 = ally.global_position - hub.player.global_position
	var seg_a: Vector3 = cam.global_position
	var seg_b: Vector3 = head
	var t_seg: float = clampf((ally.global_position + Vector3(0, 1.2, 0) - seg_a).dot(seg_b - seg_a) / (seg_b - seg_a).length_squared(), 0.0, 1.0)
	var off_line: float = (ally.global_position + Vector3(0, 1.2, 0)).distance_to(seg_a.lerp(seg_b, t_seg))
	_check("Rüfət walks beside/behind him, out of the camera's line", rel.dot(fwd) < 0.4 and off_line > 0.8,
		"ahead %.2f, off the line %.2f" % [rel.dot(fwd), off_line])
	WorldState.move_npc(&"rufet", "")
	var t: float = WorldState.get_time_of_day()
	await _seconds(1.0)
	_check("the hub's clock does not run", is_equal_approx(WorldState.get_time_of_day(), t) and is_equal_approx(lvl.day_night.hour, t))
	_phases.clear()
	hub.wait_until(21.0)
	await _frames(4)
	_check("waiting at the hearth until night: the phase changes, the doors close", _phases == [&"night"]
		and lvl.doors.values().all(func(d): return not d.is_open) and is_equal_approx(lvl.day_night.hour, 21.0))
	_check("at night residents are behind their doors (no bodies)", hub.npcs.body(&"sona") == null)
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.slot_path(1)))
	_check("resting at the hearth autosaves (clock, region)", saved is Dictionary and is_equal_approx(float(saved["world"]["time_of_day"]), 21.0)
		and saved["player"]["current_region"] == "son_ocaq")
	var day := WorldState.get_day_count()
	hub.wait_until(7.0)
	await _frames(4)
	_check("waiting until morning: a new day, doors open, people out", WorldState.get_day_count() == day + 1
		and lvl.doors["door_sona"].is_open and hub.npcs.body(&"sona") != null)


func _travel() -> void:
	# From another place to Son Ocaq and back (the valley does the same through its road sign)
	WorldState.new_game()
	var host := await _go(HOST)
	var at := Vector3(3.0, host.player.global_position.y, -4.0)
	host.player.global_position = at
	await _frames(20)
	at = host.player.global_position
	HubTravel.enter(host, host.player, 19.5)
	var hub := await _scene_loaded(HUB)
	_check("the road leads to Son Ocaq, keeping the clock", hub != null and is_equal_approx(WorldState.get_time_of_day(), 19.5)
		and is_equal_approx(hub.level.day_night.hour, 19.5))
	_check("... and he arrives at the gate", hub.player.global_position.distance_to(hub.level.player_spawn) < 1.0)
	HubTravel.leave(get_tree())
	var back := await _scene_loaded(HOST)
	_check("leaving puts him back where he took the road", back.player.global_position.distance_to(at) < 0.3,
		"%s vs %s" % [back.player.global_position, at])
	_check("Continue knows the hub: a save made there reopens it", load("res://scripts/main.gd").REGION_SCENES.get(&"son_ocaq") == HUB)
	# Leaving a hub that was continued from a save goes to the valley's road sign
	HubTravel._ctx = {}
	HubTravel.returning = false
	_check("without a remembered spot (a save continued in the hub), the road leads to the valley", HubTravel.return_scene() == HubTravel.VALLEY_SCENE)


func _go(path: String) -> Node:
	get_tree().change_scene_to_file(path)
	return await _scene_loaded(path)


func _scene_loaded(path: String) -> Node:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 20000:
		var c = get_tree().current_scene
		if c != null and c.scene_file_path == path and c.get("player") != null and c.player.is_inside_tree():
			await _frames(5)
			return get_tree().current_scene
		await get_tree().process_frame
	_check("scene %s came up" % path, false)
	return null


func _seconds(s: float) -> void:
	var start := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - start) / 1000.0 < s:
		await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wipe() -> void:
	var full := ProjectSettings.globalize_path(TEST_DIR)
	if DirAccess.dir_exists_absolute(full):
		for f in DirAccess.get_files_at(TEST_DIR):
			DirAccess.remove_absolute(full.path_join(f))
		DirAccess.remove_absolute(full)


func _check(label: String, ok: bool, detail := "") -> void:
	print(("PASS  " if ok else "FAIL  ") + label + ("" if detail == "" else "  (" + detail + ")"))
	if not ok:
		_fails += 1
