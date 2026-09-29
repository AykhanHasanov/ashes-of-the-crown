extends "res://scripts/chapter_base.gd"
## Kartal Yamacı (scenes/kartal_yamaci.tscn): Eşref's hut on the mountain slope
## (scripts/world/kartal_level.gd). Reached from the valley by the trail sign at Karaağaç
## Ocağı (HubTravel, like Son Ocak); the sign at the trail's top leads back down. The clock
## does not run here. Region "kartal_yamaci": Continue on a save made here comes back here.
## The S8 scene itself (the shades, Eşref's lines, the choice) is played by StoryDirector
## beats in phase B; this mode gives it the stage: spots (story_spot), encounters
## (start_encounter), the yazma pickup and Eşref at his door.

const KartalLevel := preload("res://scripts/world/kartal_level.gd")
const Protagonist := preload("res://scripts/player_v3/protagonist.gd")
const TPCamera := preload("res://scripts/camera/third_person_camera.gd")
const NpcSpawner := preload("res://scripts/npc/npc_spawner.gd")
const DebugMenu := preload("res://scripts/debug/debug_menu.gd")
const Encounter := preload("res://scripts/world/encounter.gd")
const Foe := preload("res://scripts/enemies/foe.gd")

const REGION := &"kartal_yamaci"
const TRAIL_RANGE := 2.4
const TALK_RANGE_DAY := 2.4

var npcs                          # NpcSpawner
var debug
var _dead_handled := false


func _make_level() -> Node3D:
	return KartalLevel.new()


func _make_player() -> Node3D:
	return Protagonist.new()


func _make_camera() -> Node3D:
	return TPCamera.new()


func _setup() -> void:
	npcs = NpcSpawner.new()
	npcs.name = "Npcs"
	npcs.player = player
	npcs.height_at = level.height_at
	npcs.place_npc = _npc_spot
	add_child(npcs)
	EventBus.encounter_started.connect(func(_id: StringName): player.begin_encounter())
	EventBus.encounter_wave_started.connect(_on_encounter_wave)
	EventBus.encounter_finished.connect(func(_id: StringName):
		hud.banner(tr("ENC_CLEARED"))
		Audio.music("ambient", 3.0))
	EventBus.saving.connect(func(_slot: int): WorldState.set_time_of_day(level.day_night.hour))
	debug = DebugMenu.new()
	add_child(debug)
	debug.section("Kartal Yamacı")
	debug.button("Slice: slice_s8_hut", func(): start_encounter(&"slice_s8_hut", level.arena_center))
	debug.button("Eşref burada / gitsin", func():
		WorldState.move_npc(&"esref", "" if WorldState.get_npc_location(&"esref") == String(REGION) else String(REGION)))
	debug.button("Rüfet katılsın / ayrılsın", func():
		WorldState.move_npc(&"rufet", "" if WorldState.get_npc_location(&"rufet") == WorldState.PARTY else WorldState.PARTY))
	debug.button("Tam can + şerbet", func():
		player.heal(player.max_health)
		player.refill_flasks())
	Audio.music("ambient", 3.0)


func _begin(mode: String) -> void:
	if Settings.demo != "":
		WorldState.new_game()   # in memory only: SaveManager never writes during a --demo
	elif not WorldState.session_active:
		var slot := SaveManager.most_recent_slot()
		if slot == 0 or not SaveManager.load_slot(slot):
			SaveManager.active_slot = SaveManager.first_empty_slot()
			WorldState.new_game()
	var continued := mode == "checkpoint" and WorldState.get_region() == REGION
	WorldState.set_region(REGION)
	level.day_night.set_hour(WorldState.get_time_of_day())
	var hp: Variant = WorldState.get_player_stat(&"health")
	if hp != null and float(hp) > 0.0:
		player.health = minf(float(hp), player.max_health)
		player.health_changed.emit(player.health, player.max_health)
	var fire: Variant = WorldState.get_player_stat(&"fire")
	if fire != null:
		player.ember = float(fire)
		player.ember_changed.emit(player.ember, player.ember_max())
	if continued:
		player.global_position = WorldState.get_player_position() + Vector3(0, 0.2, 0)
	else:
		arrive()
	set_controls(true)
	player.wake()
	npcs.queue_refresh()
	hud.title_card(tr("KARTAL_TITLE"), "", 2.0)
	_demo_setup()


## At the top of the trail, facing up the slope to the hut.
func arrive() -> void:
	player.global_position = level.player_spawn
	player.velocity = Vector3.ZERO
	player.face_towards(level.hut_door)
	var ahead: Vector3 = (level.hut_door - level.player_spawn) * Vector3(1, 0, 1)
	rig.yaw = atan2(-ahead.x, -ahead.z)
	rig.pitch = deg_to_rad(-6.0)
	rig.snap()


## Eşref stands at his door while he lives here.
func _npc_spot(npc_id: StringName, location_id: String) -> Variant:
	if location_id != String(REGION):
		return null
	return level.hut_door if npc_id == &"esref" else null


## Named places for StoryDirector beats ("near:<spot>", "encounter:<id>:<spot>").
func story_spot(id: String) -> Variant:
	match id:
		"hut", "hut_door":
			return level.hut_door
		"hearth":
			return level.hearth_pos
		"trail":
			return level.trail_pos
		"arena":
			return level.arena_center
	return null


# --- Frame ---------------------------------------------------------------------------------------

func _tick(_delta: float) -> void:
	var free: bool = get_tree().paused or radial.is_open or debug.is_open() or dialogue.is_active()
	var want := Input.MOUSE_MODE_VISIBLE if free or Settings.capture_path != "" else Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != want:
		Input.mouse_mode = want
	if player.dead:
		if not _dead_handled:
			_dead_handled = true
			_show_death()
		elif Input.is_action_just_pressed("restart"):
			_respawn()
		return
	if get_tree().paused or dialogue.is_active():
		return
	_interact()


func _interact() -> void:
	if player.global_position.distance_to(level.trail_pos) < TRAIL_RANGE:
		if near_prompt(level.trail_pos, TRAIL_RANGE, tr("KARTAL_PROMPT_TRAIL")):
			HubTravel.leave(get_tree())
		return
	var y = level.yazma
	if y != null and not y.is_taken() and player.global_position.distance_to(y.global_position) < y.use_range:
		if near_prompt(y.global_position, y.use_range, y.prompt()):
			y.take()
		return
	hud.set_prompt("")


func _show_death() -> void:
	Audio.music("", 1.0)
	Audio.play("sting_defeat", -2.0, 0.0)
	await get_tree().create_timer(1.2).timeout
	hud.show_card(tr("DEATH_TITLE"), tr("KARTAL_DEATH_SUB"), tr("DEATH_RETRY"), 0.75)


## Up again at the top of the trail (placeholder: the soulslike loop comes with the valley's).
func _respawn() -> void:
	_dead_handled = false
	hud._card.visible = false
	player.dead = false
	player.health = player.max_health
	player.health_changed.emit(player.health, player.max_health)
	player.stamina = player.max_stamina
	player._enter(player.S.MOVE)
	player._model.cancel_action()
	player.refill_flasks()
	for f in get_tree().get_nodes_in_group("enemies"):
		f.queue_free()
	arrive()


# --- Encounters ----------------------------------------------------------------------------------

func start_encounter(id: StringName, center: Vector3) -> Node:
	var e := Encounter.new()
	e.spawner = func(eid: String, pos: Vector3, lv: int, opts: Dictionary):
		pos.y = level.height_at(pos.x, pos.z) + 0.1
		return spawn_foe(eid, pos, lv, opts)
	add_child(e)
	if not e.start(id, center):
		e.queue_free()
		return null
	return e


func spawn_foe(id: String, pos: Vector3, lv: int, opts: Dictionary):
	var f = Foe.new()
	f.configure(id, lv, opts)
	f.aggro_range = 0.0 if opts.get("hunt", false) else 16.0
	f.home = pos
	f.ground_query = level.height_at
	add_child(f)
	f.global_position = pos
	f.target = player
	return f


func _on_encounter_wave(_id: StringName, _wave: int, _total: int, banner_key: String) -> void:
	if banner_key != "":
		hud.banner(tr(banner_key))
	Fx.shake(0.35)
	Audio.music("battle", 1.2)


# --- Capture demos -------------------------------------------------------------------------------

## kartal (arrival, the hut up the slope) | kartal_hut (Eşref at his door, the cold hearth) |
## kartal_lit (the same still at dusk with the hearth lit: the lit HearthFire variant, debug only)
func _demo_setup() -> void:
	if Settings.demo.begins_with("kartal"):
		player.input_locked = true   # a still: keys typed into the focused window must not move him
	match Settings.demo:
		"kartal_hut", "kartal_lit":
			WorldState.set_time_of_day(15.5)
			level.day_night.set_hour(15.5)
			WorldState.move_npc(&"esref", String(REGION))
			WorldState.move_npc(&"rufet", WorldState.PARTY)
			var at: Vector3 = level.hearth_pos + Vector3(-2.2, 0.2, 2.0)
			player.global_position = at
			player.face_towards(level.hut_door)
			rig.snap()
			npcs.queue_refresh()
			# A still: the hut's door (Eşref), the cold hearth and the red yazma on its stones
			var shot := Camera3D.new()
			shot.fov = 60.0
			add_child(shot)
			var mid: Vector3 = level.hearth_pos.lerp(level.hut_door, 0.45)
			shot.global_position = level.hearth_pos + Vector3(3.2, 2.3, 4.6)
			shot.look_at(mid + Vector3(0, 0.6, 0))
			shot.make_current()
			if Settings.demo == "kartal_lit":
				level.show_hearth(true)
				WorldState.set_time_of_day(19.2)   # dusk, so the fire's light reads
				level.day_night.set_hour(19.2)
		"kartal":
			WorldState.set_time_of_day(15.5)
			level.day_night.set_hour(15.5)
