extends "res://scripts/chapter_base.gd"
## Son Ocaq, the hub (scenes/son_ocaq.tscn). The caravanserai courtyard with the last
## hearth (scripts/hub/hub_level.gd); residents stand at their own doors by day and are
## behind them at night. The clock does not run here: it moves only when the protagonist
## waits at the hearth (until night / until morning) or when the story sets it; waiting
## autosaves. The road leads back to the valley (HubTravel).
## Region "son_ocaq": Continue on a save made here comes back here.

const HubLevel := preload("res://scripts/hub/hub_level.gd")
const HubData := preload("res://scripts/hub/hub_data.gd")
const HubHearthMenu := preload("res://scripts/ui/hub_hearth_menu.gd")
const Protagonist := preload("res://scripts/player_v3/protagonist.gd")
const TPCamera := preload("res://scripts/camera/third_person_camera.gd")
const NpcSpawner := preload("res://scripts/npc/npc_spawner.gd")
const DebugMenu := preload("res://scripts/debug/debug_menu.gd")

const HEARTH_RANGE := 3.4
const GATE_RANGE := 2.6

var npcs                          # NpcSpawner
var hearth_menu
var debug


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
	EventBus.time_of_day_changed.connect(func(_p): npcs.queue_refresh())
	EventBus.flag_changed.connect(func(_k, _o, _n): npcs.queue_refresh())
	debug = DebugMenu.new()
	add_child(debug)
	debug.section("Son Ocak")
	debug.button("Gece (21:00)", func(): wait_until(HubHearthMenu.NIGHT_HOUR))
	debug.button("Sabah (07:00)", func(): wait_until(HubHearthMenu.MORNING_HOUR))
	debug.button("Rüfet katılsın / ayrılsın", func():
		WorldState.move_npc(&"rufet", "" if WorldState.get_npc_location(&"rufet") == WorldState.PARTY else WorldState.PARTY))
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
	rig.snap()
	player.wake()
	npcs.queue_refresh()
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
func wait_until(hour: float) -> void:
	WorldState.set_time_of_day(hour)   # emits time_of_day_changed on a new phase (wraps into the next day)
	level.day_night.set_hour(hour)
	player.heal(player.max_health)
	player.refill_flasks()
	EventBus.checkpoint_rested.emit(&"son_ocaq_hearth")   # SaveManager autosaves


## Where a resident of Son Ocaq stands: at their own door by day, behind it (nowhere) at night.
func _npc_spot(npc_id: StringName, location_id: String) -> Variant:
	if location_id != WorldState.SON_OCAQ or WorldState.get_phase() == &"night":
		return null
	var room := HubData.room_of(String(npc_id))
	return level.stand_point(room) if room != "" else null


func _tick(_delta: float) -> void:
	_update_mouse()
	if player.dead or get_tree().paused:
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


# --- Capture demos -------------------------------------------------------------------------------

## hub_day | hub_night | hub_doors (the north row by day) | hub_leave (out to the valley)
func _demo_setup() -> void:
	match Settings.demo:
		"hub_day", "hub_doors":
			WorldState.set_time_of_day(10.5)
			level.day_night.set_hour(10.5)
			WorldState.move_npc(&"rufet", WorldState.PARTY)
			if Settings.demo == "hub_doors":
				_demo_view(Vector3(0, 0, 1.5), Vector3(0, 1.6, -9.0))
			else:
				_demo_view(Vector3(0, 0, 6.0), Vector3(0, 1.5, -6.0))
		"hub_leave":
			# Walk out of the gate: back to the valley, at the road's sign
			_demo_view(Vector3(0, 0, 7.5), Vector3(0, 1.5, 12.0))
			get_tree().create_timer(1.5).timeout.connect(func(): HubTravel.leave(get_tree()))
		"hub_night":
			WorldState.set_time_of_day(22.0)
			level.day_night.set_hour(22.0)
			_demo_view(Vector3(0, 0, 6.0), Vector3(0, 1.5, -6.0))


func _demo_view(at: Vector3, look: Vector3) -> void:
	player.global_position = at + Vector3(0, 0.1, 0)
	player.face_towards(look)
	var to := look - at
	rig.yaw = atan2(-to.x, -to.z)
	rig.pitch = deg_to_rad(-6.0)
	rig.snap()
