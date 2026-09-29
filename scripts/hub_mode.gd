extends "res://scripts/chapter_base.gd"
## Son Ocaq, the hub (scenes/son_ocaq.tscn). The caravanserai courtyard with the last
## hearth (scripts/hub/hub_level.gd); residents stand at their own doors by day and are
## behind them at night. The clock does not run here: it moves only when the protagonist
## waits at the hearth (until night / until morning) or when the story sets it; waiting
## autosaves. The road leads back to the valley (HubTravel).
## Talking: by day face to face; at night through the doors (scripts/hub/door_talk.gd).
## Region "son_ocaq": Continue on a save made here comes back here.

const HubLevel := preload("res://scripts/hub/hub_level.gd")
const HubData := preload("res://scripts/hub/hub_data.gd")
const HubHearthMenu := preload("res://scripts/ui/hub_hearth_menu.gd")
const Protagonist := preload("res://scripts/player_v3/protagonist.gd")
const TPCamera := preload("res://scripts/camera/third_person_camera.gd")
const NpcSpawner := preload("res://scripts/npc/npc_spawner.gd")
const DebugMenu := preload("res://scripts/debug/debug_menu.gd")
const DoorTalk := preload("res://scripts/hub/door_talk.gd")
const HubNights := preload("res://scripts/hub/hub_nights.gd")
const HubShade := preload("res://scripts/hub/hub_shade.gd")
const NpcRegistry := preload("res://scripts/core/npc_registry.gd")

const HEARTH_RANGE := 2.9
const DOOR_RANGE := 1.9          # from the point just in front of a door
const TALK_RANGE_DAY := 2.4
const GATE_RANGE := 2.6
const ENTRY_PITCH := -8.0   # on entry the camera looks up a little: sky, hearth and upper storey in view

var npcs                          # NpcSpawner
var hearth_menu
var debug
var door_talk                     # DoorTalk
var _night_guests := {}           # NPCs at their open door at night (Peri Nene)
var shades: Array = []            # HubShade — only at night


func _make_level() -> Node3D:
	return HubLevel.new()


func _make_player() -> Node3D:
	return Protagonist.new()


func _make_camera() -> Node3D:
	return TPCamera.new()


func _setup() -> void:
	npcs = NpcSpawner.new()
	npcs.name = "Npcs"
	npcs.player = player
	npcs.place_npc = _npc_spot
	add_child(npcs)
	hearth_menu = HubHearthMenu.new()
	add_child(hearth_menu)
	hearth_menu.wait_requested.connect(wait_until)
	door_talk = DoorTalk.new()
	door_talk.name = "DoorTalk"
	door_talk.dialogue = dialogue
	door_talk.level = level
	door_talk.mode = self
	add_child(door_talk)
	door_talk.finished.connect(func(): player.input_locked = false)
	EventBus.time_of_day_changed.connect(func(_p): npcs.queue_refresh())
	EventBus.time_of_day_changed.connect(_on_phase)
	EventBus.flag_changed.connect(func(_k, _o, _n): npcs.queue_refresh())
	debug = DebugMenu.new()
	add_child(debug)
	debug.section("Son Ocak")
	debug.button("Gece (21:00)", func(): wait_until(HubHearthMenu.NIGHT_HOUR))
	debug.button("Sabah (07:00)", func(): wait_until(HubHearthMenu.MORNING_HOUR))
	debug.button("Rüfet katılsın / ayrılsın", func():
		WorldState.move_npc(&"rufet", "" if WorldState.get_npc_location(&"rufet") == WorldState.PARTY else WorldState.PARTY))
	debug.button("Sessiz gece (herkes uyusun)", func():
		if WorldState.has_flag(&"hub_all_asleep"):
			WorldState.clear_flag(&"hub_all_asleep")
		else:
			WorldState.set_flag(&"hub_all_asleep"))
	debug.button("Herkesi kurtar", func():
		for p in HubData.places():
			for r in p["residents"]:
				if r != HubData.PROTAGONIST and r != "rufet":
					WorldState.rescue_npc(StringName(r)))
	Audio.music("ambient", 3.0)


func _begin(mode: String) -> void:
	if Settings.demo != "":
		WorldState.new_game()   # in memory only: SaveManager never writes during a --demo
	elif not WorldState.session_active:
		var slot := SaveManager.most_recent_slot()
		if slot == 0 or not SaveManager.load_slot(slot):
			SaveManager.active_slot = SaveManager.first_empty_slot()
			WorldState.new_game()
	var continued := mode == "checkpoint" and WorldState.get_region() == &"son_ocaq"
	WorldState.set_region(&"son_ocaq")
	_apply_saved_state()
	if continued:
		player.global_position = WorldState.get_player_position() + Vector3(0, 0.2, 0)
	else:
		player.global_position = level.player_spawn
		player.face_towards(level.hearth_pos)
		rig.yaw = 0.0   # facing north, into the courtyard, from the gate
		rig.pitch = deg_to_rad(ENTRY_PITCH)
	rig.snap()
	player.wake()
	npcs.queue_refresh()
	_on_phase(WorldState.get_phase())
	hud.title_card(tr("HUB_TITLE"), "", 2.0)
	_demo_setup()


func _apply_saved_state() -> void:
	level.day_night.set_hour(WorldState.get_time_of_day())
	var max_flasks: Variant = WorldState.get_player_stat(&"max_flasks")
	if max_flasks != null:
		player.max_flasks = int(max_flasks)
		player.refill_flasks()
	var weapon_id: Variant = WorldState.get_player_stat(&"weapon")
	if weapon_id != null and String(weapon_id) != "" and String(weapon_id) != String(player.weapon.get("id", "")):
		player.equip(String(weapon_id))
	var hp: Variant = WorldState.get_player_stat(&"health")
	if hp != null and float(hp) > 0.0:
		player.health = minf(float(hp), player.max_health)
		player.health_changed.emit(player.health, player.max_health)
	set_controls(true)


## Time passes only here: set the hour (the phase event follows), rest, and autosave.
## Waiting through the night is when its door deaths happen — off-screen.
func wait_until(hour: float) -> void:
	if hour < 12.0 and WorldState.get_phase() == &"night":
		HubNights.resolve_morning()
	WorldState.set_time_of_day(hour)   # emits time_of_day_changed on a new phase (wraps into the next day)
	level.day_night.set_hour(hour)
	player.heal(player.max_health)
	player.refill_flasks()
	EventBus.checkpoint_rested.emit(&"son_ocaq_hearth")   # SaveManager autosaves


## Where a resident of Son Ocaq stands: by day at their workplace or their own door; at night
## behind their door (nowhere).
func _npc_spot(npc_id: StringName, location_id: String) -> Variant:
	if location_id != WorldState.SON_OCAQ:
		return null
	if WorldState.get_phase() == &"night" and not _night_guests.has(npc_id):
		return null
	var place := HubData.day_place_of(String(npc_id))   # a workplace (smithy, bakery) or their room
	return level.stand_point(place) if place != "" else null


## Night falls: warnings, and the shades come (roamers, the lost ones at warned doors,
## the small one at Aras's door). Any other phase: they are gone.
func _on_phase(phase: StringName) -> void:
	for s in shades:
		if is_instance_valid(s):
			s.queue_free()
	shades.clear()
	if phase != &"night":
		return
	HubNights.on_nightfall()
	var cfg: Dictionary = HubData.data()["night_shades"]
	for i in int(cfg["count"]):
		var d = level.doors.values().pick_random()
		_add_shade(HubShade.Kind.ROAMER, cfg["look"], cfg, d.global_position + d.global_basis.z * 1.5)
	for e in HubNights.events():
		var id := StringName(e["npc"])
		if HubNights.is_warned(id) and WorldState.get_npc_location(id) == WorldState.SON_OCAQ:
			var door = level.doors.get(HubData.place(HubData.room_of(String(id))).get("door", ""))
			if door != null:
				_add_shade(HubShade.Kind.LOST, _lost_look(id), cfg, door.global_position + door.global_basis.z * 0.9, door)
	var own = level.doors["door_protagonist"]
	_add_shade(HubShade.Kind.NARIN, NpcRegistry.get_def(&"narin").look_id, cfg, own.global_position + own.global_basis.z * 0.9, own)


func _lost_look(id: StringName) -> String:
	var def: Resource = NpcRegistry.get_def(id)
	if def.lost_one_npc != &"":
		return NpcRegistry.get_def(def.lost_one_npc).look_id
	return def.lost_one_look_id


func _add_shade(kind: int, look: String, cfg: Dictionary, at: Vector3, door = null) -> void:
	var s = HubShade.new()
	s.setup(kind, look, level, player, cfg, door)
	add_child(s)
	s.global_position = Vector3(at.x, 0.02, at.z)
	shades.append(s)


## Someone who opens their door at night (allows_night_open) stands in it for the talk.
func night_guest(npc_id: StringName, on: bool) -> void:
	if on:
		_night_guests[npc_id] = true
	else:
		_night_guests.erase(npc_id)
	npcs.queue_refresh()


func _tick(_delta: float) -> void:
	_update_mouse()
	if player.dead or get_tree().paused or dialogue.is_active():
		return
	_interact()


func _update_mouse() -> void:
	var free: bool = get_tree().paused or radial.is_open or debug.is_open() or dialogue.is_active() or hearth_menu.is_open
	var want := Input.MOUSE_MODE_VISIBLE if free or Settings.capture_path != "" else Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != want:
		Input.mouse_mode = want


func _interact() -> void:
	if near_prompt(level.hearth_pos, HEARTH_RANGE, tr("HUB_PROMPT_HEARTH")):
		hearth_menu.open()
		return
	if player.global_position.distance_to(level.hearth_pos) < HEARTH_RANGE:
		return
	if near_prompt(level.gate_pos, GATE_RANGE, tr("HUB_PROMPT_GATE")):
		HubTravel.leave(get_tree())
		return
	if WorldState.get_phase() == &"night":
		var door = nearest_door()
		if door != null:
			var own := HubData.residents_of(door.place_id).has(HubData.PROTAGONIST)
			if near_prompt(door_front(door), DOOR_RANGE, tr("HUB_PROMPT_LISTEN") if own else tr("HUB_PROMPT_KNOCK")):
				knock(door)
			return
	else:
		var who = nearest_resident()
		if who != null and near_prompt(who.global_position, TALK_RANGE_DAY, tr("HUB_PROMPT_TALK")):
			player.input_locked = true
			player.face_towards(who.global_position)
			door_talk.talk(who.npc_id)
			return
	hud.set_prompt("")


## Knock on (or, his own, listen at) a door at night.
func knock(door) -> String:
	player.input_locked = true
	player.face_towards(door.global_position)
	var outcome: String = door_talk.knock(door)
	if outcome in ["silent", "listen"]:
		player.input_locked = false
	return outcome


func door_front(door) -> Vector3:
	return door.global_position + door.global_basis.z * 1.0


func nearest_door():
	var best = null
	var best_d := DOOR_RANGE
	for d in level.doors.values():
		var dist: float = player.global_position.distance_to(door_front(d))
		if dist < best_d:
			best_d = dist
			best = d
	return best


func nearest_resident():
	var best = null
	var best_d := TALK_RANGE_DAY
	for b in npcs.bodies.values():
		if is_instance_valid(b) and b.get("npc_id") != null and not b.has_method("help_up"):
			var dist: float = player.global_position.distance_to(b.global_position)
			if dist < best_d:
				best_d = dist
				best = b
	return best


# --- Capture demos -------------------------------------------------------------------------------

## hub_day | hub_night | hub_doors (the north row by day) | hub_leave (out to the valley) |
## hub_door_talk (night: knock on Sona's door and answer) | hub_door_burned (the same, name burned)
func _demo_setup() -> void:
	match Settings.demo:
		"hub_day", "hub_doors":
			WorldState.set_time_of_day(10.5)
			level.day_night.set_hour(10.5)
			WorldState.move_npc(&"rufet", WorldState.PARTY)
			if Settings.demo == "hub_doors":
				_demo_view(Vector3(0.5, 0, 1.6), Vector3(-4.0, 1.4, -6.0))
			else:
				_demo_view(Vector3(0, 0, 2.4), Vector3(0, 1.5, -6.0))
		"hub_leave":
			# Walk out of the gate: back to the valley, at the road's sign
			_demo_view(Vector3(0, 0, 9.0), Vector3(0, 1.5, 14.0))
			get_tree().create_timer(1.5).timeout.connect(func(): HubTravel.leave(get_tree()))
		"hub_door_talk", "hub_door_burned":
			# Night: knock on Sona's door and answer who is there (burned: the name is gone)
			if Settings.demo == "hub_door_burned":
				WorldState.burn_memory(&"own_name", &"echo")
			WorldState.set_time_of_day(22.0)
			level.day_night.set_hour(22.0)
			get_tree().create_timer(1.2).timeout.connect(func():
				var door = level.doors["door_sona"]
				player.global_position = door_front(door) - door.global_basis.x * 0.9 + Vector3(0, 0.1, 0)
				knock(door)
				get_tree().create_timer(2.4).timeout.connect(func():
					if dialogue.is_active() and dialogue.choice_texts().size() > 0:
						dialogue.choose(0)))
		"hub_morning_after":
			# Eşref warned last night, gone this morning (placeholder flags)
			WorldState.rescue_npc(&"esref")
			WorldState.set_flag(&"esref_quest_failing")
			WorldState.set_flag(&"esref_quest_failed")
			wait_until(21.0)
			wait_until(7.0)
			wait_until(21.0)
			wait_until(7.0)
			WorldState.set_time_of_day(9.0)
			level.day_night.set_hour(9.0)
			# A still of the morning after: the ajar door, the ash, the footprints from the gate
			var door = level.doors["door_esref"]
			player.global_position = Vector3(-4.0, 0.1, -2.0)
			var shot := Camera3D.new()
			shot.fov = 62.0
			add_child(shot)
			shot.global_position = Vector3(1.6, 2.3, 4.6)
			shot.look_at(door.global_position + Vector3(-1.2, 0.4, 0.4))
			shot.make_current()
		"hub_shades":
			WorldState.set_time_of_day(22.5)
			level.day_night.set_hour(22.5)
			_demo_view(Vector3(0, 0, 2.4), Vector3(0, 1.2, -6.0))
		"hub_night":
			WorldState.set_time_of_day(22.0)
			level.day_night.set_hour(22.0)
			_demo_view(Vector3(0, 0, 2.4), Vector3(0, 1.5, -6.0))


func _demo_view(at: Vector3, look: Vector3) -> void:
	player.global_position = at + Vector3(0, 0.1, 0)
	player.face_towards(look)
	var to := look - at
	rig.snap()   # (snap resets the yaw to the body's: set it after)
	rig.yaw = atan2(-to.x, -to.z)
	rig.pitch = deg_to_rad(-6.0)
