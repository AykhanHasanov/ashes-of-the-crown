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
	EventBus.npc_died.connect(func(_id, _c): _refresh_lament())
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
	var mourned := HubNights.mourned()
	if npc_id == &"peri_nene" and mourned != &"":
		# the morning after a door death she sings at that door
		var d = level.doors.get(HubData.place(HubData.room_of(String(mourned))).get("door", ""))
		if d != null:
			return d.global_position + d.global_basis.z * 1.6 + d.global_basis.x * 0.6
	var place := HubData.day_place_of(String(npc_id))   # a workplace (smithy, bakery) or their room
	return level.stand_point(place) if place != "" else null


## Night falls: warnings, and the shades come (roamers, the lost ones at warned doors,
## the small one at Aras's door). Any other phase: they are gone.
func _on_phase(phase: StringName) -> void:
	_refresh_lament()
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


## Peri Nene's lament at the mourned door, the morning after a door death (while she lives
## here). Heard on entering the hub; nothing on screen.
func _refresh_lament() -> void:
	var mourned := HubNights.mourned()
	var singer := HubData.is_home("peri_nene")
	var d = level.doors.get(HubData.place(HubData.room_of(String(mourned))).get("door", "")) if mourned != &"" else null
	level.set_lament(d if singer else null)
	npcs.queue_refresh()


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
	_process_rest()
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
		if level.in_room(player.global_position):
			# In his own room at night: listen at the door, or step out
			if near_prompt(level.room_spots["inside_door"].origin, DOOR_RANGE, tr("HUB_PROMPT_ROOM_DOOR")):
				room_door_choice()
			return
		var door = nearest_door()
		if door != null:
			var own := HubData.residents_of(door.place_id).has(HubData.PROTAGONIST)
			if near_prompt(door_front(door), DOOR_RANGE, tr("HUB_PROMPT_ENTER_ROOM") if own else tr("HUB_PROMPT_KNOCK")):
				if own:
					enter_room()
				else:
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


## At night his door is shut: he slips into his room (the door opens and closes behind him).
func enter_room() -> void:
	_place(level.room_spots["inside_door"], true)
	Audio.play("door_hush", -10.0, 0.05)


## At night, inside his room at the door: "Dinle" (the small shade's knock) or "Dışarı çık".
func room_door_choice() -> void:
	player.input_locked = true
	dialogue.start({"start": {"text": "", "choices": [
		{"text_key": "HUB_ROOM_LISTEN", "event": "listen"},
		{"text_key": "HUB_ROOM_OUT", "event": "out"}]}})
	var ev: String = await dialogue.finished
	player.input_locked = false
	if ev == "listen":
		knock(level.doors["door_protagonist"])
	elif ev == "out":
		leave_room()


func leave_room() -> void:
	var door = level.doors["door_protagonist"]
	_place(Transform3D(door.global_basis, door_front(door)), false)
	Audio.play("door_hush", -10.0, 0.05)


## Puts the protagonist at `spot`; `inward`: facing into the room (away from the door).
func _place(spot: Transform3D, inward: bool) -> void:
	player.global_position = spot.origin + Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	var ahead: Vector3 = -spot.basis.z if inward else spot.basis.z
	player.face_towards(player.global_position + ahead)
	rig.yaw = atan2(-ahead.x, -ahead.z)
	rig.snap()


## Rüfət (in the party) sits awake on his bed at night (STORY_SLICE §S4) and follows again by day.
func _process_rest() -> void:
	var ally = npcs.bodies.get(&"rufet")
	if ally == null or not is_instance_valid(ally) or not ally.has_method("rest_at"):
		return
	var night: bool = WorldState.get_phase() == &"night"
	if night and ally.rest_spot == null:
		ally.rest_at(level.room_spots["bed_rufet"])
	elif not night and ally.rest_spot != null:
		ally.rest_at(null)


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
			WorldState.set_flag(&"protagonist_name_known")
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
			# Eşref's warning heard on hub night 2 at his door; night 3 he opens it
			WorldState.rescue_npc(&"esref")
			for n in 3:
				wait_until(21.0)
				if n == 1:
					HubNights.mark_heard(&"esref")
				wait_until(7.0)
			WorldState.set_time_of_day(9.0)
			level.day_night.set_hour(9.0)
			# A still of the morning after: the ajar door, the ash, the footprints from the gate
			var door = level.doors["door_esref"]
			player.global_position = Vector3(-4.0, 0.1, -2.0)
			var shot := Camera3D.new()
			shot.fov = 62.0
			add_child(shot)
			shot.global_position = Vector3(3.2, 2.1, 5.6)
			shot.look_at(door.global_position + Vector3(-1.0, 0.2, 0.2))
			shot.make_current()
		"hub_shades":
			WorldState.set_time_of_day(22.5)
			level.day_night.set_hour(22.5)
			_demo_view(Vector3(0, 0, 2.4), Vector3(0, 1.2, -6.0))
		"hub_night":
			WorldState.set_time_of_day(22.0)
			level.day_night.set_hour(22.0)
			_demo_view(Vector3(0, 0, 2.4), Vector3(0, 1.5, -6.0))
		"hub_light_hearth", "hub_light_corner":
			# Night readability stills (fixed cameras): him by the hearth, and in the far corner
			WorldState.set_time_of_day(22.0)
			level.day_night.set_hour(22.0)
			player.input_locked = true
			var shot := Camera3D.new()
			shot.fov = 60.0
			add_child(shot)
			if Settings.demo == "hub_light_hearth":
				# as the game's camera sees him: from behind, the fire beyond him (the silhouette case)
				player.global_position = level.hearth_pos + Vector3(0.4, 0.1, 3.4)
				player.face_towards(level.hearth_pos)
				shot.global_position = level.hearth_pos + Vector3(1.6, 1.9, 6.8)
				shot.look_at(player.global_position + Vector3(0, 1.0, 0))
			else:
				var corner := Vector3(-HubLevel.SIDE_X + 2.6, 0.1, HubLevel.SOUTH_Z - 1.6)   # far from the fire
				player.global_position = corner
				player.face_towards(corner + Vector3(-3, 0, 1))   # his back to the camera here too
				shot.global_position = corner + Vector3(3.6, 1.7, -1.2)
				shot.look_at(corner + Vector3(0, 1.0, 0))
			rig.snap()
			shot.make_current()
		"hub_room", "hub_room_day":
			# Aras's room: at night Rüfət on his bed, the lamp lit; by day the door open
			var hour := 10.5 if Settings.demo == "hub_room_day" else 22.0
			WorldState.set_time_of_day(hour)
			level.day_night.set_hour(hour)
			WorldState.move_npc(&"rufet", WorldState.PARTY)
			npcs.queue_refresh()
			var room: Transform3D = level.room_xf
			var beds: Vector3 = level.room_spots["bed_rufet"].origin.lerp(level.room_spots["bed_protagonist"].origin, 0.5)
			var shot := Camera3D.new()
			shot.fov = 68.0
			add_child(shot)
			if Settings.demo == "hub_room":
				# From the front corner by the door, high: Aras in the middle of the room, Rüfət on his bed
				enter_room()
				player.global_position = room * Vector3(-0.9, 0.1, -2.5)
				player.face_towards(level.room_spots["bed_rufet"].origin)
				shot.global_position = room * Vector3(-1.75, 2.55, -0.45)
			else:
				# By day, from the gallery through the open door; he is at the hearth, out of view
				_demo_view(Vector3(0, 0, 2.4), Vector3(0, 1.5, -6.0))
				shot.global_position = room * Vector3(-1.0, 1.65, 2.6)
			shot.look_at(beds + Vector3(0, 0.6, 0))
			shot.make_current()
		"hub_journal":
			# The Közcü journal after a little of the story (placeholder state for the capture)
			WorldState.set_time_of_day(10.5)
			level.day_night.set_hour(10.5)
			WorldState.set_flag(&"protagonist_name_known")
			for pair in [["rufet", ""], ["sona", "HUB_SONA_DAY_1"], ["esref", "HUB_ESREF_DAY_1"], ["domrul", "HUB_DOMRUL_DAY_1"]]:
				WorldState.set_npc_flag(StringName(pair[0]), &"met", true)
				if pair[1] != "":
					WorldState.set_npc_flag(StringName(pair[0]), &"last_line", pair[1])
			WorldState.rescue_npc(&"esref")
			WorldState.apply("thread:JOURNAL_ESREF_THREAD")
			WorldState.keep_memory(&"first_sword")
			WorldState.burn_memory(&"mother_name", &"combat")
			WorldState.burn_memory(&"hearth_lesson", &"echo")
			_demo_view(Vector3(0, 0, 2.4), Vector3(0, 1.5, -6.0))
			process_mode = Node.PROCESS_MODE_ALWAYS   # keep counting frames for the capture while the journal pauses
			get_tree().create_timer(2.5).timeout.connect(journal.open)


func _demo_view(at: Vector3, look: Vector3) -> void:
	player.global_position = at + Vector3(0, 0.1, 0)
	player.face_towards(look)
	var to := look - at
	rig.snap()   # (snap resets the yaw to the body's: set it after)
	rig.yaw = atan2(-to.x, -to.z)
	rig.pitch = deg_to_rad(-6.0)
