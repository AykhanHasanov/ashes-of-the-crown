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
const HubShade := preload("res://scripts/hub/hub_shade.gd")
const HubNights := preload("res://scripts/hub/hub_nights.gd")
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
	await _door_talk()
	await _nights()
	await _names_in_lines()
	await _growth()
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
	_check("Sona's lost one is Narin; Eşref's is his wife, Şirin", NpcRegistry.get_def(&"sona").lost_one_npc == &"narin"
		and tr(NpcRegistry.get_def(&"esref").lost_one_name_key) == "Şirin")
	_check("Sabir's lost one is Kür; Elvin's his mother, Nermin's her husband (placeholders)", NpcRegistry.get_def(&"sabir").lost_one_npc == &"kur"
		and tr(NpcRegistry.get_def(&"elvin").lost_one_name_key).contains("annesi") and tr(NpcRegistry.get_def(&"nermin").lost_one_name_key).contains("kocası"))
	var living_lost: Array = NpcRegistry.all().filter(func(d): return d.lost_one_npc != &"" and NpcRegistry.get_def(d.lost_one_npc).npc_kind == "human")
	_check("no lost one is a living person: Samir's shade never comes to Nermin's door", living_lost.is_empty(), str(living_lost.map(func(d): return d.id)))
	var talk_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/hub/door_talk.json"))
	var nermin_night: Array = talk_data["npcs"]["nermin"]["night"]
	_check("placeholder hook: Nermin notices Samir's shade never knocks", nermin_night.any(func(e): return e is Dictionary and e["key"] == "HUB_NERMIN_NO_SAMIR_PLACEHOLDER" and tr(e["key"]) != e["key"]))
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
		and clean["world"]["doors"] == {} and int(clean["meta"]["save_version"]) == WorldState.SAVE_VERSION)
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
	# The top third of the first frame: sky and distant walls, no ceiling or pillar close by
	var vp := hub.get_viewport().get_visible_rect().size
	var near: Array = []
	for fy in [0.04, 0.18, 0.32]:
		for fx in [0.08, 0.3, 0.5, 0.7, 0.92]:
			var sp := Vector2(vp.x * fx, vp.y * fy)
			var from := cam.project_ray_origin(sp)
			var rq := PhysicsRayQueryParameters3D.create(from, from + cam.project_ray_normal(sp) * 60.0)
			rq.exclude = [hub.player.get_rid()]
			var h: Dictionary = hub.get_world_3d().direct_space_state.intersect_ray(rq)
			if not h.is_empty() and from.distance_to(h["position"]) < 7.0:
				near.append("%.2f,%.2f" % [fx, fy])
	_check("... from the open courtyard: nothing close in the top third of the frame (no ceiling, no pillars)", near.is_empty(), str(near))
	var open_sky := 0
	for fx in [0.08, 0.3, 0.5, 0.7, 0.92]:
		var sp_top := Vector2(vp.x * fx, vp.y * 0.04)
		var sky := PhysicsRayQueryParameters3D.create(cam.project_ray_origin(sp_top), cam.project_ray_origin(sp_top) + cam.project_ray_normal(sp_top) * 200.0)
		if hub.get_world_3d().direct_space_state.intersect_ray(sky).is_empty():
			open_sky += 1
	_check("... and sky along the top of the frame", open_sky >= 3, "%d of 5" % open_sky)
	_check("the upper storey is in the frame", cam.is_position_in_frustum(Vector3(0, HubLevel.ROOM_H + 2.0, HubLevel.NORTH_Z)))
	_check("the hearth is in the frame", cam.is_position_in_frustum(lvl.hearth_pos + Vector3(0, 0.6, 0)))
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


# --- Through-the-door conversations (stage 3) -----------------------------------------------------

func _door_talk() -> void:
	WorldState.new_game()
	var hub := await _go(HUB)
	var lvl = hub.level
	var talk = hub.door_talk
	var dlg = hub.dialogue
	hub.wait_until(21.0)
	await _frames(3)
	# He wakes without his name: "who is there?" — "Bilmiyorum..."
	var first_door = lvl.doors["door_sona"]
	hub.player.global_position = hub.door_front(first_door)
	hub.knock(first_door)
	await _typed(dlg)
	_check("name unknown: the answer reads 'Bilmiyorum...' and can be chosen", dlg.choice_texts() == [tr("HUB_NAME_UNKNOWN_ANSWER")] and dlg.choice_enabled(0))
	_check("door mode: the whole HUD is hidden (memory diamonds too)", not hub.hud.visible)
	dlg.choose(0)
	await _typed(dlg)
	_check("... it leads to a placeholder response", dlg.node_id == "unknown" and dlg._node.get("text_key", "") == "HUB_NAME_UNKNOWN_RESPONSE")
	dlg._advance()
	await _frames(3)
	_check("... and the HUD comes back after the door", hub.hud.visible)
	WorldState.apply("reveal_name:protagonist")   # the story tells him [TBD: Rüfət]
	await _frames(4)
	var sona_door = lvl.doors["door_sona"]
	_check("B: a warm light under an occupied door at night", sona_door.is_lit)
	_check("... none under an empty room's door", not lvl.doors["door_sabir"].is_lit)
	WorldState.kill_npc(&"ehliman", "test")
	await _frames(2)
	_check("... none for the dead", not lvl.doors["door_ehliman"].is_lit)
	# UI priority: nothing talks over a conversation — not even a card already on screen
	hub.hud.title_card("ALREADY UP", "", 3.0)
	await _frames(2)
	hub.player.global_position = hub.door_front(sona_door)
	var out: String = hub.knock(sona_door)
	await _typed(dlg)
	hub.hud.title_card("TEST", "", 0.5)
	hub.hud.banner("banner")
	WorldState.burn_memory(&"mother_name")   # a burn notice
	await _frames(2)
	_check("UI: a card already on screen gives way when the conversation begins", not hub.hud._card.visible or hub.hud._card_title.text != "ALREADY UP")
	_check("UI: title cards, banners and burn notices wait while a dialogue is open", hub.hud.queued() == ["title_card", "banner", "show_whisper"]
		and hub.hud._card_title.text != "TEST" and hub.hud._banner.text != "banner", "%s %s %.2f" % [hub.hud.queued(), hub.hud._card_title.text, hub.hud._whisper.modulate.a])
	# Door scene: almost dark, the strip the only warm light; Aras out of frame
	var cam: Camera3D = talk.door_camera
	_check("door scene: the courtyard goes almost dark", lvl.day_night.mood_scale <= 0.1 and not lvl.hearth_light.visible and not lvl.far_light.visible)
	var others_dark: bool = lvl.doors.values().all(func(d): return d == sona_door or d.strip_light_energy() == 0.0)
	var windows_dark: bool = lvl.growth.values().all(func(g): return g["window"].material_override == lvl._dark)
	_check("... the only warm light is the strip under this door (no lit windows, no other strips)", others_dark and windows_dark and sona_door.strip_light_energy() > 0.0)
	var rim: DirectionalLight3D = lvl.moon_rim
	_check("... and a faint cool moonlight rim lets the door's silhouette read", rim.visible and rim.light_color.b > rim.light_color.r
		and rim.light_energy < 0.5 and (-rim.global_basis.z).dot(-sona_door.global_basis.z) > 0.3)
	var spot: Node3D = sona_door._strip_light
	_check("... it shines out from under the door onto the floor, away from the door's face",
		(-spot.global_basis.z).dot(sona_door.global_basis.z) > 0.6 and (-spot.global_basis.z).y < -0.2)
	var vp: Vector2 = hub.get_viewport().get_visible_rect().size
	var door_c: Vector2 = cam.unproject_position(sona_door.global_position + Vector3(0, 1.0, 0)) / vp
	var sill: Vector2 = cam.unproject_position(sona_door.global_position + Vector3(0, 0.03, 0.1)) / vp
	_check("framing: the door is centred; the light under it sits above the subtitles", absf(door_c.x - 0.5) < 0.12 and sill.y < 0.86 and sill.y > 0.12,
		"door %s, sill %s" % [door_c, sill])
	var p: Vector3 = hub.player.global_position
	var parts := [p + Vector3(0, 0.2, 0), p + Vector3(0, 1.0, 0), p + Vector3(0, 1.6, 0)]
	_check("framing: Aras is out of the frame — no cut-off body or sword", parts.all(func(v): return not cam.is_position_in_frustum(v)))
	_check("framing: through a door the words are subtitles (no panel)", dlg.subtitles_only)
	_check("A: knocking at night starts a conversation through the door", out == "door" and dlg.is_active() and dlg.check("door_mode"))
	_check("A: who is there? — the answer is his name as the UI resolves it", dlg.node_id == "start" and dlg.choice_texts() == ["Aras"] and dlg.choice_enabled(0))
	_check("the camera closes on the door; the NPC is not seen", talk.door_camera != null and talk.door_camera.current and hub.npcs.body(&"sona") == null)
	var bus_idx := AudioServer.get_bus_index("Door")
	_check("F: the NPC's voice goes through the muffled Door bus", talk.last_bus.get("sona") == "Door" and bus_idx >= 0
		and AudioServer.get_bus_effect(bus_idx, 0) is AudioEffectLowPassFilter)
	_check("F: Aras's own answer is not muffled", talk.last_bus.get("protagonist") == "Voice" and talk.bus_for(&"protagonist", true) == "Voice")
	var x0: float = sona_door.shadow_x()
	await _seconds(0.5)
	_check("B: while she speaks, a shadow crosses the light", sona_door.speaking and absf(sona_door.shadow_x() - x0) > 0.05, "speaking %s lit %s x %.2f→%.2f vis %s" % [sona_door.speaking, sona_door.is_lit, x0, sona_door.shadow_x(), sona_door._shadow.visible])
	dlg.choose(0)
	await _typed(dlg)
	var night_key: String = dlg._node.get("text_key", "")
	_check("G: the answer comes from her night pool, not the day pool", talk.pool(&"sona", "night").has(night_key) and not talk.pool(&"sona", "day").has(night_key))
	dlg._advance()
	await _frames(3)
	_check("after the talk the player's camera and controls come back", talk.door_camera == null and hub.rig.camera.current and not hub.player.input_locked)
	_check("... and the night's light", is_equal_approx(lvl.day_night.mood_scale, 1.0) and lvl.hearth_light.visible and not lvl.moon_rim.visible)
	_check("UI: afterwards the waiting messages come, one at a time", hub.hud._card.visible and hub.hud._card_title.text == "TEST"
		and hub.hud.queued() == ["banner", "show_whisper"])
	await _seconds(2.2)
	_check("... next in line", hub.hud.queued() == ["show_whisper"])
	# A: a burned name cannot answer; the door refuses and stays silent this night
	WorldState.burn_memory(&"own_name", &"echo")
	hub.knock(sona_door)
	await _typed(dlg)
	_check("A: with his name burned the answer is the blank and cannot be chosen", dlg.choice_texts() == [tr("NAME_FORGOTTEN")] and not dlg.choice_enabled(0))
	dlg.choose(0)
	await _frames(2)
	_check("... choosing it does nothing", dlg.node_id == "start")
	await _until(func(): return dlg.node_id == "refuse", 4.0)
	_check("... the NPC refuses (placeholder)", dlg.node_id == "refuse" and dlg._node.get("text_key", "") == "HUB_NAME_REFUSED")
	await _typed(dlg)
	dlg._advance()
	await _frames(3)
	_check("... and the door stays silent for the rest of the night (no dialogue box)", hub.knock(sona_door) == "silent" and not dlg.is_active())
	# C: silence from data
	WorldState.set_flag(&"domrul_sleeps")
	_check("C: a silent_if condition: no answer, no dialogue", hub.knock(lvl.doors["door_domrul"]) == "silent" and not dlg.is_active())
	WorldState.clear_flag(&"domrul_sleeps")
	WorldState.set_flag(&"hub_all_asleep")
	_check("C: the default silence (everyone asleep)", hub.knock(lvl.doors["door_kemal_gulcin"]) == "silent")
	WorldState.clear_flag(&"hub_all_asleep")
	_check("C: an empty room is silent too", hub.knock(lvl.doors["door_sahbaz"]) == "silent")
	# Conditional lines: Nermin and Sabir (his name back first)
	WorldState.new_game()
	WorldState.set_flag(&"protagonist_name_known")
	hub.wait_until(21.0)
	WorldState.rescue_npc(&"nermin")
	WorldState.rescue_npc(&"sabir")
	WorldState.set_flag(&"sabir_confused")
	await _frames(3)
	hub.knock(lvl.doors["door_nermin"])
	await _typed(dlg)
	dlg.choose(0)
	await _typed(dlg)
	_check("hook: at night Nermin's first line is that Samir's shade never comes", dlg._node.get("text_key", "") == "HUB_NERMIN_NO_SAMIR_PLACEHOLDER")
	dlg._advance()
	await _frames(3)
	hub.knock(lvl.doors["door_sabir"])
	await _typed(dlg)
	dlg.choose(0)
	await _typed(dlg)
	_check("hook: Sabir calls him 'Kür' through the door", dlg._text.text.contains("Kür") and not dlg._text.text.contains("Aras"))
	dlg._advance()
	await _frames(3)
	# E: Peri Nene opens at night; face to face
	var peri_door = lvl.doors["door_peri_nene"]
	var peri_out: String = hub.knock(peri_door)
	await _frames(4)
	await _typed(dlg)
	_check("E: Peri Nene opens her door at night (allows_night_open)", peri_out == "open" and peri_door.is_open and NpcRegistry.get_def(&"peri_nene").allows_night_open)
	_check("E: ... and talks face to face: she is there, not muffled, no door camera", hub.npcs.body(&"peri_nene") != null
		and not dlg.check("door_mode") and talk.door_camera == null and talk.last_bus.get("peri_nene") == "Voice")
	dlg._advance()
	await _frames(4)
	_check("E: afterwards her door closes again", not peri_door.is_open and hub.npcs.body(&"peri_nene") == null)
	_check("only Peri Nene opens at night", NpcRegistry.all().filter(func(d): return d.allows_night_open).map(func(d): return d.id) == [&"peri_nene"])
	# D: Aras's own door: listen; the small shade's rhythm
	var own = lvl.doors["door_protagonist"]
	var rhythm: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/hub/door_talk.json"))["knocks"]["narin"]["rhythm"]
	_check("D: his own door at night is only listened at", hub.knock(own) == "listen" and not dlg.is_active() and not own.is_open)
	await _seconds(float(rhythm.back()) + 0.4)
	var intervals_ok: bool = talk.knock_log.size() == rhythm.size()
	for i in range(1, mini(rhythm.size(), talk.knock_log.size())):
		var want: float = float(rhythm[i]) - float(rhythm[i - 1])
		var got: float = float(talk.knock_log[i]) - float(talk.knock_log[i - 1])
		if absf(want - got) > 0.12:
			intervals_ok = false
	_check("D: the knock follows the rhythm in data (placeholder for the lullaby)", intervals_ok, str(talk.knock_log))
	# G: by day, face to face from the day pool
	hub.wait_until(7.0)
	await _frames(4)
	talk.talk(&"sona")
	await _typed(dlg)
	var day_key: String = dlg._node.get("text_key", "")
	_check("G: by day she talks face to face from her day pool", talk.pool(&"sona", "day").has(day_key) and not dlg.check("door_mode") and talk.last_bus.get("sona") == "Voice")
	dlg._advance()
	await _frames(2)


# --- Night shades and door deaths (stage 4) ------------------------------------------------------

func _nights() -> void:
	WorldState.new_game()
	SaveManager.active_slot = 1
	var hub := await _go(HUB)
	var lvl = hub.level
	var cfg: Dictionary = HubData.data()["night_shades"]
	_check("A: no shades by day", hub.shades.is_empty())
	hub.wait_until(21.0)
	await _frames(4)
	var roamers: Array = hub.shades.filter(func(x): return x.kind == HubShade.Kind.ROAMER)
	var narin_list: Array = hub.shades.filter(func(x): return x.kind == HubShade.Kind.NARIN)
	_check("A: at night shades roam the courtyard, and a small one stands at Aras's door", roamers.size() == int(cfg["count"]) and narin_list.size() == 1
		and narin_list[0].home_door == lvl.doors["door_protagonist"])
	var peaceful := true
	for x in hub.shades:
		if x.is_in_group("enemies") or x.is_in_group("combatants") or x.has_method("receive_hit") or x.has_method("take_damage"):
			peaceful = false
	_check("A: shades are not in the combat system", peaceful)
	var r0 = roamers[0]
	r0.global_position = r0._goal
	await _frames(4)
	_check("A: a shade knocks on doors", r0.knocks >= 1)
	var hp: float = hub.player.health
	hub.player.global_position = r0.global_position + Vector3(1.2, 0, 0)
	await _frames(4)
	_check("A: when Aras comes close it breaks into ash", r0.state == HubShade.S.GONE and not r0._model.visible)
	hub.player.global_position = Vector3(0, 0.1, 2.4)
	r0.reform_in = 0.3
	await _seconds(0.7)
	_check("... and re-forms elsewhere, out of his way", r0.is_present() and r0.global_position.distance_to(hub.player.global_position) > float(cfg["break_range"]))
	var narin = narin_list[0]
	hub.player.global_position = narin.global_position + Vector3(0.8, 0, 0.8)
	await _seconds(1.0)
	_check("D: Narin's shade does not break into ash", narin.is_present())
	hub.player.global_position = Vector3(0, 0.1, 2.4)
	await _seconds(1.5)
	_check("E: shades never deal damage", is_equal_approx(hub.player.health, hp))
	hub.wait_until(7.0)
	await _frames(3)
	_check("D: by morning every shade is gone, Narin's too", hub.shades.is_empty() and get_tree().get_nodes_in_group("hub_shades").all(func(x): return x.is_queued_for_deletion()))
	# B / C: the warning night, then the death night — off-screen
	var died: Array = []
	var on_died := func(id, cause): died.append([id, cause])
	EventBus.npc_died.connect(on_died)
	WorldState.rescue_npc(&"esref")
	WorldState.set_flag(&"esref_quest_failing")
	WorldState.set_flag(&"esref_quest_failed")   # death condition already true: still only after the warning night
	hub.wait_until(21.0)
	await _frames(4)
	_check("B: the warning night: Eşref is warned", HubNights.is_warned(&"esref"))
	_check("B: ... his night line turns into the warning (placeholder key)", hub.door_talk._pick(&"esref", "night") == "HUB_WARNING_ESREF")
	var lost: Array = hub.shades.filter(func(x): return x.kind == HubShade.Kind.LOST)
	var esref_door = lvl.doors["door_esref"]
	_check("C: the shade at his door is his own lost one (placeholder look)", lost.size() == 1 and lost[0].home_door == esref_door and lost[0].identity == "lost_esref")
	hub.wait_until(7.0)
	await _frames(3)
	_check("E: no death on the warning night itself", WorldState.is_npc_alive(&"esref") and died.is_empty())
	hub.wait_until(21.0)
	await _frames(2)
	WorldState.set_time_of_day(7.0)   # the story moves the clock: nobody waited at the hearth
	await _frames(2)
	_check("E: death resolves only while waiting until morning", WorldState.is_npc_alive(&"esref"))
	hub.wait_until(21.0)
	await _frames(2)
	hub.wait_until(7.0)
	await _frames(4)
	_check("B: the death night passes off-screen: npc_died, cause 'door'", not WorldState.is_npc_alive(&"esref") and died == [[&"esref", "door"]]
		and WorldState.get_npc_death_cause(&"esref") == "door")
	EventBus.npc_died.disconnect(on_died)
	_check("morning: Peri Nene's lament sounds at that door (placeholder audio)", lvl.lament.playing
		and lvl.lament.global_position.distance_to(esref_door.global_position) < 2.5)
	await _frames(4)
	var peri = hub.npcs.body(&"peri_nene")
	_check("... she stands there, at the open door", peri != null and peri.global_position.distance_to(esref_door.global_position) < 2.5)
	_check("... and nothing on screen says so", hub.hud.queued().is_empty() and hub.hud._whisper.modulate.a < 0.05)
	var ash_c: Color = lvl._snow.albedo_color
	var step_c: Color = lvl._step_mat.albedo_color
	var scorch_c: Color = lvl._scorch.albedo_color
	var warm_c: Color = lvl._cleared.albedo_color
	_check("ground language: ambient ash-snow light grey, the footprints pale ash, the threshold scorched dark",
		ash_c.v > 0.75 and absf(ash_c.r - ash_c.b) < 0.06 and step_c.v > 0.75 and scorch_c.v < 0.12
		and lvl.get_node("Aftermath_door_esref/Scorch") != null)
	var burn_img: Image = lvl._scorch.albedo_texture.get_image()
	var edge_alphas: Array = []
	for i in 16:
		var ang := TAU * i / 16.0
		edge_alphas.append(burn_img.get_pixel(int(48 + cos(ang) * 30.0), int(48 + sin(ang) * 30.0)).a)
	_check("the scorch mark is an irregular burn, not a circle", edge_alphas.max() - edge_alphas.min() > 0.3, str(edge_alphas))
	_check("... cleared (resolved) stones are warm — none of the three look alike", warm_c.r - warm_c.b > 0.35
		and absf(warm_c.v - ash_c.v) > 0.0 and (warm_c.r - warm_c.b) - (ash_c.r - ash_c.b) > 0.3 and ash_c.v - scorch_c.v > 0.6)
	_check("the footprints are footprint-shaped", lvl._step_mat.albedo_texture.get_image().get_pixel(16, 44).a > 0.5
		and lvl._step_mat.albedo_texture.get_image().get_pixel(1, 1).a < 0.1)
	_check("B: morning: the door is ajar, ash on the threshold, footprints from the gate", esref_door.is_ajar and not esref_door.is_open
		and lvl.footprint_count("door_esref") > 5 and lvl.get_node_or_null("Aftermath_door_esref") != null,
		"ajar %s open %s steps %d" % [esref_door.is_ajar, esref_door.is_open, lvl.footprint_count("door_esref")])
	var first_step: Vector3 = lvl.footprints("door_esref")[0].global_position
	_check("... the trail starts at the gate", first_step.distance_to(Vector3(0, 0, HubLevel.SOUTH_Z)) < 1.5)
	hub.wait_until(21.0)
	await _frames(3)
	_check("B: that room's light never returns", not esref_door.is_lit and not lost.any(func(x): return is_instance_valid(x)))
	_check("the lament ends with that day", not lvl.lament.playing)
	SaveManager.save(1)
	WorldState.new_game()
	await _frames(3)
	SaveManager.load_slot(1)
	await _frames(4)
	_check("E: the aftermath persists through save and load", esref_door.is_ajar and lvl.footprint_count("door_esref") > 5
		and WorldState.get_npc_death_cause(&"esref") == "door")


# --- Names inside lines; the protagonist's own name ------------------------------------------------

func _names_in_lines() -> void:
	WorldState.new_game()
	var keys: Array = []
	for l in FileAccess.get_file_as_string("res://localization/strings.csv").split("\n"):
		var k := l.get_slice(",", 0)
		if k.begins_with("HUB_") or (k.begins_with("NPC_") and k.ends_with("_LOST_ONE")):
			keys.append(k)
	var leaks := _raw_names(keys)
	_check("{NPC:id}: no raw name of someone he does not know appears in any hub line", leaks.is_empty(), str(leaks))
	for d in NpcRegistry.all():
		WorldState.reveal_name(d.id)
	var shown := Names.fill(tr("HUB_ESREF_NIGHT_1"))
	_check("{NPC:id}: once known, the name shows in the line", shown.contains("Eşref"))
	WorldState.burn_memory(&"rufet_face", &"echo")
	WorldState.burn_memory(&"narin", &"echo")
	_check("{NPC:id}: a burned name never shows", Names.fill("{NPC:rufet} / {NPC:narin}") == "%s / %s" % [tr("NAME_FORGOTTEN"), tr("NAME_FORGOTTEN")])
	_check("Kül Şahı is known by his title", Names.npc(&"kul_sahi") == "Kül Şahı")
	WorldState.new_game()
	_check("the protagonist: unknown → 'Bilmiyorum...', known → Aras, burned → the blank", Names.protagonist_answer() == tr("HUB_NAME_UNKNOWN_ANSWER"))
	WorldState.apply("reveal_name:protagonist")
	var known_ok := Names.protagonist_answer() == "Aras"
	WorldState.burn_memory(Names.PROTAGONIST_MEMORY, &"echo")
	_check("... (all three states)", known_ok and Names.protagonist_answer() == tr("NAME_FORGOTTEN"))


## Lines (keys) in which a raw NPC name shows although Aras does not know it (or it burned).
func _raw_names(keys: Array) -> Array:
	var leaks: Array = []
	for d in NpcRegistry.all():
		var raw := tr(d.name_key)
		if WorldState.is_name_known(d.id) and not (d.name_memory_id != &"" and WorldState.has_burned(d.name_memory_id)):
			continue
		var re := RegEx.create_from_string("(?<![\\p{L}])" + raw + "(?![\\p{L}])")
		for k in keys:
			if re.search(Names.fill(tr(k))) != null:
				leaks.append("%s in %s" % [raw, k])
	return leaks


# --- Rescue and growth (stage 5, slim) -------------------------------------------------------------

func _growth() -> void:
	WorldState.new_game()
	WorldState.set_time_of_day(10.0)
	var hub := await _go(HUB)
	var lvl = hub.level
	var door = lvl.doors["door_esref"]
	_check("before the rescue Eşref's room is dark and shut", lvl.room_state_shown("room_esref") == "dark" and not door.is_open
		and hub.npcs.body(&"esref") == null)
	var scale0: float = lvl.hearth_fire.scale.x
	WorldState.rescue_npc(&"esref")
	await _frames(4)
	var body = hub.npcs.body(&"esref")
	_check("rescued: Eşref appears at his room, his door opens by day", body != null and body.global_position.distance_to(lvl.stand_point("room_esref")) < 0.5
		and door.is_open and lvl.room_state_shown("room_esref") == "lit")
	hub.wait_until(21.0)
	await _frames(3)
	_check("... and at night the light shows under his door", door.is_lit and not door.is_open)
	hub.wait_until(7.0)
	WorldState.resolve_grief(&"esref")
	await _frames(3)
	_check("growth: his grief resolved, warm stones show through the ash-snow at his door", lvl.room_state_shown("room_esref") == "melted"
		and lvl.growth["room_esref"]["cleared"].visible and not lvl.growth["room_sona"]["cleared"].visible)
	_check("growth: the hearth grows with the resolved core arcs (data)", lvl.hearth_fire.scale.x > scale0
		and is_equal_approx(lvl.hearth_fire.scale.x, float(HubData.data()["hearth"]["stages"][1])))


func _typed(dlg) -> void:
	await _until(func(): return not dlg._typing, 5.0)
	await _frames(2)


func _until(cond: Callable, timeout: float) -> bool:
	var start := Time.get_ticks_msec()
	while (Time.get_ticks_msec() - start) / 1000.0 < timeout:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())


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
