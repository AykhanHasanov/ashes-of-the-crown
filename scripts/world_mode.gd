extends "res://scripts/chapter_base.gd"
## V3 Faza B: the Kür Vadisi slice as an open world. the protagonist starts by the western pass
## next to a cold hearth. Places are discovered by walking near them, hearths are
## lit to become rest and fast-travel points, chests hold nar toxumu (+1 flask), echo
## stones tell the valley's story, enemies guard their homes and return when you
## rest. [M] map, compass on top, F10 debug (teleport, time, weather), F6 streaming.

const Names := preload("res://scripts/core/names.gd")
const OpenWorld := preload("res://scripts/world/open_world.gd")
const Protagonist := preload("res://scripts/player_v3/protagonist.gd")
const TPCamera := preload("res://scripts/camera/third_person_camera.gd")
const Foe := preload("res://scripts/enemies/foe.gd")
const DebugMenu := preload("res://scripts/debug/debug_menu.gd")
const Compass := preload("res://scripts/ui/compass.gd")
const WorldMap := preload("res://scripts/ui/world_map.gd")
const HearthMenu := preload("res://scripts/ui/hearth_menu.gd")
const Interactable := preload("res://scripts/world/interactable.gd")
const AiOverlay := preload("res://scripts/debug/ai_overlay.gd")
const Villager := preload("res://scripts/npc/villager.gd")
const NpcSpawner := preload("res://scripts/npc/npc_spawner.gd")
const Encounter := preload("res://scripts/world/encounter.gd")
const Wildlife := preload("res://scripts/world/wildlife.gd")
const Effects := preload("res://scripts/world/effects.gd")

const HINT := "WASD hareket · Shift koşu · Space kaçış · LMB/F saldırı · RMB blok · C kilit\nE kullan · R şerbet · M harita · F10 debug · F6 streaming · F3 FPS"
const AUTOSAVE_SECONDS := 300.0

var debug
var compass
var world_map
var hearth_menu
var _stream_label: Label
var _foes := {}                   # spawn key -> Foe
## Elite affixes on world enemies (the world self-test turns them off: a random
## "Kül Şahının gözü" guard would see the protagonist anywhere and fail the calm/leash checks).
var roll_affixes := true
var _villagers := {}               # poi id -> [Villager]
var npcs                          # NpcSpawner: named NPCs, built from WorldState
var _loaded_pois := {}            # poi id -> poi (fully loaded: named NPCs may stand there)
var _last_hearth := ""
var _discover_t := 0.0
var _autosave_t := 0.0
var _was_night := false
var _travelling := false
var _dead_handled := false


func _make_level() -> Node3D:
	return OpenWorld.new()


func _make_player() -> Node3D:
	return Protagonist.new()


func _make_camera() -> Node3D:
	return TPCamera.new()


func _setup() -> void:
	level.attach_camera(rig.camera)
	level.streamer.focus = player
	player.water_query = level.water.surface_at
	level.streamer.actor_requested.connect(_on_actor_requested)
	level.streamer.actors_released.connect(_on_actors_released)
	level.streamer.poi_full.connect(_on_poi_full)
	EventBus.saving.connect(_on_world_saving)
	EventBus.encounter_started.connect(func(_id: StringName): player.begin_encounter())
	EventBus.encounter_wave_started.connect(_on_encounter_wave)
	EventBus.encounter_finished.connect(_on_encounter_finished)
	# Deer herds graze away from settlements
	var wild := Wildlife.new()
	wild.height_at = level.height_at
	wild.water_at = level.water.surface_at
	wild.player = player
	for p in level.meta["pois"]:
		if p["type"] in ["village", "castle", "camp", "grove", "hearth", "den", "lair", "ruins"]:
			wild.avoid.append([Vector3(p["pos"][0], 0, p["pos"][2]), 70.0])
	level.add_child(wild)
	npcs = NpcSpawner.new()
	npcs.name = "Npcs"
	npcs.player = player
	npcs.height_at = level.height_at
	npcs.place = _npc_place
	add_child(npcs)
	hud.set_hint(HINT)
	hud._place(hud._objective, Vector4(0.5, 0, 0.5, 0), Vector4(-420, 64, 420, 96))
	compass = Compass.new()
	hud._root.add_child(compass)
	world_map = WorldMap.new()
	add_child(world_map)
	world_map.setup(level.meta, DataDB.balance("world")["map"]["fog_cell"])
	world_map.player = player
	world_map.travel_requested.connect(_travel_to)
	hearth_menu = HearthMenu.new()
	add_child(hearth_menu)
	hearth_menu.rest_requested.connect(_rest)
	hearth_menu.travel_requested.connect(_travel_to)
	hearth_menu.map_requested.connect(func(): world_map.open(true))
	debug = DebugMenu.new()
	add_child(debug)
	_build_debug()
	_stream_label = Label.new()
	_stream_label.add_theme_font_size_override("font_size", 14)
	_stream_label.add_theme_color_override("font_color", Color(0.75, 1.0, 0.8))
	_stream_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_stream_label.position = Vector2(20, 130)
	_stream_label.visible = false
	hud._root.add_child(_stream_label)
	level.day_night.hour_changed.connect(_on_hour)
	var overlay = AiOverlay.new()
	overlay.player = player
	hud._root.add_child(overlay)
	Audio.music("ambient", 3.0)


func _begin(_mode: String) -> void:
	if Settings.demo != "":
		WorldState.new_game()   # in memory only: SaveManager never writes during a --demo
	elif not WorldState.session_active:
		# Started straight from the editor/command line: newest slot, else a new game
		var slot := SaveManager.most_recent_slot()
		if slot == 0 or not SaveManager.load_slot(slot):
			SaveManager.active_slot = SaveManager.first_empty_slot()
			WorldState.new_game()
	WorldState.set_region(&"kur_vadisi")
	_apply_saved_state()
	npcs.queue_refresh()


## Back from Son Ocaq: where he stood when he left, or at the road's sign by Geçit Ocağı.
func _arrive_from_hub(ctx: Dictionary) -> void:
	var at: Vector3 = ctx["position"] if ctx.has("position") else hub_gate_position()
	player.global_position = at + Vector3(0, 0.3, 0)
	player.velocity = Vector3.ZERO
	player._fall_from = NAN
	if ctx.has("facing"):
		player.face_towards(at - Vector3(ctx["facing"]))   # turned away from the road
	rig.snap()
	level.streamer.refresh()


## The valley end of the road to Son Ocaq (the hearth prefab's hub_gate entry).
func hub_gate_position() -> Vector3:
	for d in DataDB.prefab("hearth").get("interact", []):
		if d["kind"] == "hub_gate":
			var p: Dictionary = level.streamer.poi_by_id(d["only"])
			var at := Vector3(float(p["pos"][0]) + float(d["p"][0]), 0, float(p["pos"][2]) + float(d["p"][2]))
			at.y = level.height_at(at.x, at.z)
			return at
	return level.player_spawn

## Puts the saved player stats, clock, map and last hearth back into the running world.
func _apply_saved_state() -> void:
	world_map.fog_from_string(String(WorldState.get_world_value(&"fog", "")))
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
	var fire: Variant = WorldState.get_player_stat(&"fire")
	if fire != null:
		player.ember = float(fire)
		player.ember_changed.emit(player.ember, DataDB.balance("combat")["ember"]["max"])
	level.day_night.set_hour(WorldState.get_time_of_day())
	_last_hearth = String(WorldState.get_world_value(&"last_hearth", ""))
	if _last_hearth != "":
		_place_at_hearth(_last_hearth)
	level.refresh_braziers()
	set_controls(true)
	player.wake()
	if WorldState.has_world_entry("hearths", "hearth_west"):
		hud.set_objective("")
	else:
		hud.set_objective("Geçit Ocağı'nı yak [E]")
	hud.title_card("KÜR VADİSİ", "Közkale'nin ötesinde", 2.2)
	_demo_setup()


# --- Frame -------------------------------------------------------------------------------------

func _tick(delta: float) -> void:
	_update_mouse()
	RenderingServer.global_shader_parameter_set("player_position", player.global_position)
	if player.dead:
		if not _dead_handled:
			_dead_handled = true
		if Input.is_action_just_pressed("restart"):
			_respawn()
		return
	if Input.is_action_just_pressed("map") and not hearth_menu.is_open and not get_tree().paused:
		world_map.open(false)
	if Input.is_action_just_pressed("debug_stream"):
		_stream_label.visible = not _stream_label.visible
	_discover_t -= delta
	if _discover_t <= 0.0:
		_discover_t = 0.4
		_discover()
	_interact()
	_update_compass()
	if _stream_label.visible:
		_update_stream_label()
	_autosave_t += delta
	if _autosave_t > AUTOSAVE_SECONDS and not _in_combat():
		_autosave_t = 0.0
		_save()


func _update_mouse() -> void:
	var free: bool = get_tree().paused or radial.is_open or debug.is_open() or dialogue.is_active() \
		or player.dead or world_map.is_open or hearth_menu.is_open
	var want := Input.MOUSE_MODE_VISIBLE if free else Input.MOUSE_MODE_CAPTURED
	if Settings.capture_path != "":
		want = Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want:
		Input.mouse_mode = want
	pause_menu.enabled = not (world_map.is_open or hearth_menu.is_open)


func _in_combat() -> bool:
	for f in _foes.values():
		if is_instance_valid(f) and f.is_engaged() and f.global_position.distance_to(player.global_position) < 25.0:
			return true
	return false


# --- Discovery ---------------------------------------------------------------------------------

func _discover() -> void:
	var pos: Vector3 = player.global_position
	world_map.reveal(pos, DataDB.balance("world")["map"]["reveal_radius"])   # written to WorldState on save
	for p in level.meta["pois"]:
		if WorldState.has_world_entry("discovered", p["id"]):
			continue
		var prefab: Dictionary = DataDB.prefab(p["type"])
		var r: float = prefab.get("discover_radius", 35.0)
		var pp := Vector3(p["pos"][0], p["pos"][1], p["pos"][2])
		if Vector2(pos.x, pos.z).distance_to(Vector2(pp.x, pp.z)) < r:
			WorldState.add_world_entry("discovered", p["id"])
			Fx.notify("Keşfedildi: " + p["name"])
			Audio.play("memory_burn", -14.0, 0.0)


# --- Interaction -------------------------------------------------------------------------------

func _interact() -> void:
	var best = null
	var best_d := 1e9
	for it in get_tree().get_nodes_in_group("interactables"):
		var d: float = player.global_position.distance_to(it.global_position)
		if d < it.use_range and d < best_d:
			best = it
			best_d = d
	var exec := _execution_prompt()
	if exec != "":
		hud.set_prompt(exec)
		return
	# A downed companion: help him up (allowed mid-fight)
	for b in npcs.bodies.values():
		if is_instance_valid(b) and b.has_method("help_up") and b.is_down() \
				and player.global_position.distance_to(b.global_position) < b.help_range():
			hud.set_prompt(tr("ALLY_HELP_PROMPT") % b.display_name)
			if Input.is_action_just_pressed("interact"):
				b.help_up()
			return
	for f in _foes.values():
		if is_instance_valid(f) and f.surrendered and not f.dead and player.global_position.distance_to(f.global_position) < 2.8:
			hud.set_prompt("[E]  Serbest bırak (teslim oldu)   ·   vur — öldür")
			if Input.is_action_just_pressed("interact"):
				f.spare()
				WorldState.add_world_entry("killed", f.spawn_key)
				Fx.notify("Haydut serbest bırakıldı. Ordu açıldığında teslim olanları saflarına katabileceksin.")
			return
	if best == null:
		hud.set_prompt("")
		return
	var text: String = best.prompt()
	hud.set_prompt(text)
	if text != "" and Input.is_action_just_pressed("interact") and not _in_combat_close():
		_use(best)


func _execution_prompt() -> String:
	for c in get_tree().get_nodes_in_group("enemies"):
		if c.has_method("is_executable") and c.is_executable() and player.global_position.distance_to(c.global_position) < 2.8:
			return "[E]  Köz İnfazı"
	return ""


func _in_combat_close() -> bool:
	for f in _foes.values():
		if is_instance_valid(f) and f.is_engaged() and f.global_position.distance_to(player.global_position) < 10.0:
			return true
	return false


func _use(it) -> void:
	match it.kind:
		"hearth":
			var id: String = it.hearth_id()
			if not WorldState.has_world_entry("hearths", id):
				WorldState.add_world_entry("hearths", id)
				WorldState.add_world_entry("discovered", id)
				it.refresh()
				level.refresh_braziers()
				Fx.fire_nova(it.global_position, 3.0)
				Fx.shake(0.3)
				Audio.play("memory_burn", -4.0, 0.0)
				hud.banner("Ocak yandı — " + it.poi["name"])
				if hud._objective.text != "":
					hud.set_objective("")
				_last_hearth = id
				_save()
			else:
				_last_hearth = id
				var others: Array = level.hearth_pois().filter(func(p): return p["id"] != id and WorldState.has_world_entry("hearths", p["id"]))
				hearth_menu.open(it.poi, others)
		"chest":
			WorldState.add_world_entry("chests", it.key)
			it.open_chest()
			Audio.play("drink", -6.0, 0.0)
			match it.data.get("reward", "ember"):
				"flask_seed":
					player.max_flasks = mini(player.max_flasks + 1, int(DataDB.balance("combat")["flask"]["max_charges"]))
					player.refill_flasks()
					WorldState.set_player_stats({"max_flasks": player.max_flasks})
					Fx.notify("Nar tohumu: Nar Şerbeti +1 (%d)" % player.max_flasks)
				_:
					player.gain_ember(40.0)
					Fx.notify("Köz kırıntıları: köz +40")
			_save()
		"memory_echo":
			EchoDirector.enter(StringName(it.data["echo"]), self, player, level.day_night.hour)
		"hub_gate":
			HubTravel.enter(self, player, level.day_night.hour)
		"echo":
			WorldState.add_world_entry("echoes", it.key)
			hud.show_whisper(Names.fill(it.data["text"]))
			Audio.play("memory_burn", -10.0, 0.0)


# --- Hearths: rest, travel, death --------------------------------------------------------------

func _rest() -> void:
	player.heal(player.max_health)
	player.refill_flasks()
	# Everything you killed comes back, like the ash always does
	WorldState.clear_world_list(&"killed")
	for f in _foes.values():
		if is_instance_valid(f):
			f.queue_free()
	_foes.clear()
	for p in level.meta["pois"]:
		if level.streamer.is_full(p["id"]):
			level.streamer.spawn_actors(p)
	hud.banner("Dinlendin. Kül yine kalktı.")
	Fx.fire_nova(player.global_position, 2.0)
	EventBus.checkpoint_rested.emit(StringName(_last_hearth))   # SaveManager autosaves


func _travel_to(id: String) -> void:
	if _travelling:
		return
	_travelling = true
	player.input_locked = true
	hud.title_card("", "", 0.6)
	await get_tree().create_timer(0.35).timeout
	_place_at_hearth(id)
	_last_hearth = id
	for f in _foes.values():
		if is_instance_valid(f) and f.global_position.distance_to(player.global_position) > 80.0:
			f.queue_free()
	player.input_locked = false
	_travelling = false
	_save()


func _place_at_hearth(id: String) -> void:
	var p: Dictionary = level.streamer.poi_by_id(id)
	if p.is_empty():
		return
	var pos := Vector3(p["pos"][0] + 2.5, p["pos"][1] + 0.6, p["pos"][2] + 3.0)
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player.face_towards(Vector3(p["pos"][0], pos.y, p["pos"][2]))
	rig.snap()
	level.streamer.refresh()


func _on_player_died() -> void:
	var near: Array = get_tree().get_nodes_in_group("enemies").filter(func(e): return e.global_position.distance_to(player.global_position) < 25.0)
	if not near.is_empty():
		near.pick_random().bark("victory")
	Audio.music("", 1.0)
	Audio.play("sting_defeat", -2.0, 0.0)
	await get_tree().create_timer(1.2).timeout
	hud.show_card("KÖZ SÖNDÜ", "Son ocağında uyanacaksın.", "[R] — uyan", 0.75)


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
	var at := _last_hearth if _last_hearth != "" else "hearth_west"
	_place_at_hearth(at)
	_rest()
	Audio.music("ambient", 2.0)


func _save() -> void:
	SaveManager.save()


## Just before a save is written: the clock, last hearth and map fog into WorldState.
func _on_world_saving(_slot: int) -> void:
	WorldState.set_time_of_day(level.day_night.hour)
	WorldState.set_world_value(&"last_hearth", _last_hearth)
	WorldState.set_world_value(&"fog", world_map.fog_to_string())


# --- Enemies -----------------------------------------------------------------------------------

func _on_actor_requested(_poi: Dictionary, actor: Dictionary, key: String, pos: Vector3) -> void:
	if WorldState.has_world_entry("killed", key):
		return
	if actor.get("night_only", false) and not level.day_night.is_night():
		return
	if _foes.has(key) and is_instance_valid(_foes[key]):
		return
	var f = _spawn(actor["enemy"], pos, int(actor.get("level", 1)), {"roll": roll_affixes})
	f.spawn_key = key
	_foes[key] = f
	f.killed.connect(func(_x): _on_foe_killed(key))


## Any enemy in the world: perception tuned by light and fog, night bonus for ash,
## summons (shamans, "Çağıran") and boss bars wired up.
func _spawn(id: String, pos: Vector3, lv: int, opts: Dictionary):
	var o := opts.duplicate()
	o["night"] = level.day_night.is_night()
	var f = Foe.new()
	f.configure(id, lv, o)
	f.aggro_range = 0.0 if o.get("hunt", false) else 16.0   # encounter enemies attack at once
	f.home = pos
	f.ground_query = level.height_at
	f.world_visibility = _visibility
	add_child(f)
	f.global_position = pos
	f.target = player
	f.summon_requested.connect(func(eid: String, p: Vector3, l: int, so: Dictionary):
		var h = _spawn(eid, p, l, so)
		h.alarm(player.global_position))
	f.engaged.connect(_on_engaged)
	return f


## 1 on a clear day, towards 0 at night and in fog (sight 25 m → 12 m).
func _visibility() -> float:
	var n: float = level.day_night.night_amount()
	var fog: float = level.weather._cur["fog"] + level.weather.forest_fog * 0.5
	return clampf((1.0 - n * 0.85) * (1.0 - fog * 0.6), 0.0, 1.0)


## Starts an encounter (data/encounters/<id>.json) around `center`; returns it, or null.
func start_encounter(id: StringName, center: Vector3) -> Node:
	var e := Encounter.new()
	e.spawner = func(eid: String, pos: Vector3, lv: int, opts: Dictionary):
		pos.y = level.height_at(pos.x, pos.z) + 0.1
		return _spawn(eid, pos, lv, opts)
	add_child(e)
	if not e.start(id, center):
		e.queue_free()
		return null
	return e


func _on_encounter_wave(_id: StringName, _wave: int, _total: int, banner_key: String) -> void:
	if banner_key != "":
		hud.banner(tr(banner_key))
	Fx.shake(0.35)
	Audio.play("horn", -3.0, 0.0)
	Audio.music("battle", 1.2)


func _on_encounter_finished(_id: StringName) -> void:
	hud.banner(tr("ENC_CLEARED"))
	Audio.music("ambient", 3.0)


func _on_engaged(f) -> void:
	if f.tier == "boss":
		hud.track_boss(f)
		hud.banner(f.display_name)
		Audio.music("battle", 0.5)


func _on_foe_killed(key: String) -> void:
	WorldState.add_world_entry("killed", key)
	_foes.erase(key)


## Villagers of a loaded village (data/world/villagers.json) take up their routine.
func _on_poi_full(p: Dictionary) -> void:
	_light_chimneys(p)
	_loaded_pois[p["id"]] = p
	npcs.queue_refresh()
	var all: Dictionary = DataDB.world("villagers")
	if not all.has(p["type"]) or _villagers.has(p["id"]):
		return
	var town: Dictionary = all[p["type"]]
	var list: Array = []
	for v in town["villagers"]:
		var npc = Villager.new()
		npc.setup(v, town["spots"], level.streamer.poi_pos(p), town["hub"], level.height_at, level.day_night, player)
		add_child(npc)
		list.append(npc)
	_villagers[p["id"]] = list


## Smoke from every chimney of a loaded settlement (houses carry their chimney top as meta).
func _light_chimneys(p: Dictionary) -> void:
	var c: Vector3 = level.streamer.poi_pos(p)
	for n: Node3D in level.streamer.find_children("*", "MeshInstance3D", true, false):
		if n.has_meta("chimney") and not n.has_node("ChimneySmoke") and n.global_position.distance_to(c) < 80.0:
			var smoke := Effects.chimney_smoke()
			smoke.name = "ChimneySmoke"
			n.add_child(smoke)
			smoke.position = n.get_meta("chimney") / n.scale


## Where named NPCs at `location_id` stand: a loaded POI (its square for villages), else null.
func _npc_place(location_id: String) -> Variant:
	if not _loaded_pois.has(location_id):
		return null
	var p: Dictionary = _loaded_pois[location_id]
	var c: Vector3 = level.streamer.poi_pos(p)
	var town: Dictionary = DataDB.world("villagers").get(p["type"], {})
	if town.has("hub"):
		c += Vector3(float(town["hub"][0]), 0, float(town["hub"][1]))
	return c


func _on_actors_released(poi_id: String) -> void:
	_loaded_pois.erase(poi_id)
	npcs.queue_refresh()
	for npc in _villagers.get(poi_id, []):
		if is_instance_valid(npc):
			npc.queue_free()
	_villagers.erase(poi_id)
	for key in _foes.keys():
		if key.begins_with(poi_id + "@"):
			var f = _foes[key]
			if is_instance_valid(f) and not f.is_engaged():
				f.queue_free()
				_foes.erase(key)


## Night-only foes rise at dusk and sink back at dawn.
## Back from an echo: the clock he left at, then the common return (position, fire).
func _return_from_echo(ctx: Dictionary) -> void:
	if ctx.is_empty():
		return
	level.day_night.set_hour(float(ctx["hour"]))
	super._return_from_echo(ctx)


func _on_hour(_h: int) -> void:
	WorldState.set_time_of_day(level.day_night.hour)   # emits time_of_day_changed on a new phase
	var night: bool = level.day_night.is_night()
	if night == _was_night:
		return
	_was_night = night
	if night:
		Fx.notify("Gece çöktü. Gölgeler kalkıyor.")
		for p in level.meta["pois"]:
			if level.streamer.is_full(p["id"]):
				level.streamer.spawn_actors(p)
	else:
		for key in _foes.keys():
			var f = _foes[key]
			if is_instance_valid(f) and not f.is_engaged() and f.level >= 1 and _is_night_only(key):
				f.queue_free()
				_foes.erase(key)


func _is_night_only(key: String) -> bool:
	var parts := key.split("@")
	var p: Dictionary = level.streamer.poi_by_id(parts[0])
	if p.is_empty():
		return false
	var actors: Array = DataDB.prefab(p["type"]).get("actors", [])
	var i := int(parts[1])
	return i < actors.size() and actors[i].get("night_only", false)


# --- Compass and overlays ----------------------------------------------------------------------

func _update_compass() -> void:
	var f: Vector3 = rig.flat_forward()
	compass.heading = atan2(f.x, -f.z)
	var pos: Vector3 = player.global_position
	var list: Array = []
	for p in level.meta["pois"]:
		var pp := Vector3(p["pos"][0], p["pos"][1], p["pos"][2])
		var dist := Vector2(pos.x, pos.z).distance_to(Vector2(pp.x, pp.z))
		var is_hearth: bool = p["type"] == "hearth"
		var known := WorldState.has_world_entry("discovered", p["id"])
		if is_hearth and (known or WorldState.has_world_entry("hearths", p["id"])):
			list.append({"bearing": Compass.bearing(pos, pp), "dist": dist, "label": p["name"],
				"kind": "hearth" if WorldState.has_world_entry("hearths", p["id"]) else "hearth_cold"})
		elif known and dist < 400.0 and dist > 12.0:
			list.append({"bearing": Compass.bearing(pos, pp), "dist": dist, "label": p["name"], "kind": "place"})
	if world_map.marker != null:
		var m: Vector3 = world_map.marker
		list.append({"bearing": Compass.bearing(pos, m), "dist": Vector2(pos.x, pos.z).distance_to(Vector2(m.x, m.z)), "label": "İşaret", "kind": "marker"})
	if not WorldState.has_world_entry("hearths", "hearth_west"):
		var h: Dictionary = level.streamer.poi_by_id("hearth_west")
		var hp := Vector3(h["pos"][0], 0, h["pos"][2])
		list.append({"bearing": Compass.bearing(pos, hp), "dist": Vector2(pos.x, pos.z).distance_to(Vector2(hp.x, hp.z)), "label": "Ocaq", "kind": "objective"})
	compass.markers = list


func _update_stream_label() -> void:
	var c: Dictionary = level.streamer.loaded_count()
	var st: Dictionary = level.streamer.stats
	var cell: Vector2i = level.streamer.cell_of(player.global_position)
	_stream_label.text = "STREAMING (F6)\nhücre %d,%d  ·  tam %d  ·  görsel %d  ·  ağaç çarpışması %d  ·  bekleyen %d\nson yükleme: thread %.1f ms, ana %.1f ms, kuyruk %d, toplam %d\nFPS %d  ·  draw calls %d  ·  primitif %dk  ·  nesne %d\nsaat %s  ·  hava: %s  ·  düşman %d  ·  konum (%.0f, %.1f, %.0f)" % [
		cell.x, cell.y, c["full"], c["visual"], c["trees"], c["pending"],
		st["worker_ms"], st["last_ms"], st["jobs"], st["loads"],
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		level.day_night.clock_text(), level.weather.label(), _foes.size(),
		player.global_position.x, player.global_position.y, player.global_position.z]


# --- Debug (F10) -------------------------------------------------------------------------------

func _build_debug() -> void:
	debug.section("Teleport")
	for p in level.meta["pois"]:
		var id: String = p["id"]
		debug.button(p["name"], func(): _teleport(id))
	debug.section("Vaxt")
	for pair in [["Sabah 06:00", 6.0], ["Öğle 12:00", 12.0], ["Akşam 19:00", 19.0], ["Gece 00:00", 0.0]]:
		var h: float = pair[1]
		debug.button(pair[0], func(): level.day_night.set_hour(h))
	debug.button("Zamanı durdur / devam", func(): level.day_night.paused = not level.day_night.paused)
	debug.section("Hava")
	for s in ["clear", "cloudy", "rain", "fog"]:
		var state: String = s
		debug.button(level.weather.NAMES[s], func(): level.weather.set_state(state, true))
	debug.section("Dünya")
	debug.button("Tüm ocakları yak", func():
		for p in level.hearth_pois():
			WorldState.add_world_entry("hearths", p["id"])
		level.refresh_braziers()
		for it in get_tree().get_nodes_in_group("interactables"):
			it.refresh())
	debug.button("Haritayı tamamen aç", func():
		for p in level.meta["pois"]:
			WorldState.add_world_entry("discovered", p["id"])
		world_map.fog.fill(1))
	debug.button("Dinlen (düşmanlar geri döner)", _rest)
	debug.section("Karşılaşma")
	debug.button("Deneme karşılaşması (placeholder)", func():
		start_encounter(&"test_ash_rising", player.global_position))
	debug.section("NPC")
	debug.button("Rüfet katılsın / ayrılsın", func():
		WorldState.move_npc(&"rufet", "" if WorldState.get_npc_location(&"rufet") == WorldState.PARTY else WorldState.PARTY))
	debug.button("Sakinler: en yakın yere", func(): _npcs_to(_nearest_loaded_poi()))
	debug.section("Oyuncu")
	debug.button("Tam can + şerbet", func():
		player.heal(player.max_health)
		player.refill_flasks())
	debug.button("Köz 100", func(): player.gain_ember(100.0))
	for id in ["sword", "sword_shield", "mace"]:
		debug.button(DataDB.weapon(id)["name"], func(): player.equip(id))


## Debug: every non-companion NPC moves to `location_id`.
func _npcs_to(location_id: String) -> void:
	if location_id == "":
		return
	for def in NpcSpawner.NpcRegistry.all():
		if not def.companion and def.npc_kind == "human":
			WorldState.move_npc(def.id, location_id)


func _nearest_loaded_poi() -> String:
	var best := ""
	var best_d := 1e9
	for id in _loaded_pois:
		var d: float = player.global_position.distance_to(level.streamer.poi_pos(_loaded_pois[id]))
		if d < best_d:
			best_d = d
			best = id
	return best


func _teleport(id: String) -> void:
	var p: Dictionary = level.streamer.poi_by_id(id)
	var pos := Vector3(p["pos"][0] + 4.0, 0, p["pos"][2] + 6.0)
	pos.y = level.height_at(pos.x, pos.z) + 1.0
	player.global_position = pos
	player.velocity = Vector3.ZERO
	player._fall_from = NAN
	rig.snap()
	level.streamer.refresh()


# --- Capture demos -----------------------------------------------------------------------------

## world_start | world_village | world_castle | world_lake | world_night | world_rain | world_map |
## world_meadow | world_forest | world_dusk | world_hearth | world_selftest (automated checks)
func _demo_setup() -> void:
	match Settings.demo:
		"world_selftest":
			var t = load("res://scripts/debug/world_selftest.gd").new()
			t.mode = self
			t.player = player
			add_child(t)
			t.run()
		"world_village":
			_demo_view(Vector3(290, 0, 380), Vector3(304, 14, 342), 12.0)
		"world_square":
			# The village at work: stalls, forge, water carrier, the patrol (10:30)
			level.day_night.set_hour(10.5)
			_demo_view(Vector3(300, 0, 362), Vector3(304, 14.5, 344), 12.0)
		"world_deer":
			# Stand still in a meadow until a herd shows up, then look at it
			level.day_night.set_hour(9.0)
			get_tree().create_timer(2.5).timeout.connect(func():
				for w in level.get_children():
					if w is Wildlife and not w._herds.is_empty():
						var a = w._herds[0]["animals"][0]["node"]
						var at: Vector3 = a.global_position
						player.global_position = at + Vector3(0, 0.5, 34)
						_demo_view(player.global_position, at + Vector3(0, 1, 0), 10.0))
		"world_encounter":
			# The placeholder test encounter rising around the protagonist in the valley
			player.make_invulnerable(60.0)
			get_tree().create_timer(1.0).timeout.connect(func(): start_encounter(&"test_ash_rising", player.global_position))
		"world_echo":
			# Walk up to the placeholder memory ember by Köprü Taşı and enter its echo
			var ep: Dictionary = {}
			for p in level.meta["pois"]:
				if p["type"] == "echo":
					ep = p
			_demo_view(Vector3(ep["pos"][0] + 3.5, 0, ep["pos"][2] + 1.0), Vector3(ep["pos"][0] + 3.5, ep["pos"][1] + 1.0, ep["pos"][2] - 2.5), 8.0)
			get_tree().create_timer(2.5).timeout.connect(func(): EchoDirector.enter(&"test_echo", self, player, level.day_night.hour))
		"world_hub_gate":
			# The road to Son Ocaq by Geçit Ocağı; walk it after a moment
			level.day_night.set_hour(10.5)
			var g := hub_gate_position()
			_demo_view(g + Vector3(-3.0, 0, 4.0), g + Vector3(0, 1.5, 0), 8.0)
			get_tree().create_timer(2.5).timeout.connect(func(): HubTravel.enter(self, player, level.day_night.hour))
		"world_ally":
			# Rüfət joins; a bandit comes at them both
			level.day_night.set_hour(11.0)
			player.make_invulnerable(60.0)
			WorldState.move_npc(&"rufet", WorldState.PARTY)
			get_tree().create_timer(2.0).timeout.connect(func():
				var at: Vector3 = player.global_position + player.facing() * 9.0
				at.y = level.height_at(at.x, at.z) + 0.5
				_spawn("bandit_sword", at, 1, {"roll": false, "hunt": true}))
		"world_npcs":
			# Everyone who is not a companion stands in Kürköy's square; Rüfət with the protagonist
			level.day_night.set_hour(11.0)
			WorldState.move_npc(&"rufet", WorldState.PARTY)
			_npcs_to("kurkend")
			_demo_view(Vector3(304, 0, 357), Vector3(304, 14.5, 348), 12.0)
		"world_evening":
			# Villagers round the fire, the guard's lantern (20:30)
			level.day_night.set_hour(20.5)
			_demo_view(Vector3(301, 0, 362), Vector3(304, 14.5, 353), 12.0)
		"world_castle":
			_demo_view(Vector3(318, 0, 168), Vector3(395, 40, 106), 11.0)
		"world_fort":
			_demo_view(Vector3(372, 0, 104), Vector3(395, 36, 106), 11.0)
			var overlay = hud._root.get_children().filter(func(n): return n.get_script() == AiOverlay)
			if not overlay.is_empty():
				overlay[0].visible = true
		"world_hearth":
			WorldState.add_world_entry("hearths", "hearth_west")
			level.day_night.set_hour(20.2)
			_demo_view(Vector3(118, 0, 318), Vector3(128, 12, 298), 11.0)
			get_tree().create_timer(0.8).timeout.connect(func():
				for it in get_tree().get_nodes_in_group("interactables"):
					it.refresh())
		"world_lake":
			_demo_view(Vector3(345, 0, 350), Vector3(400, 7, 400), 15.0)
		"world_night":
			level.day_night.set_hour(23.0)
			_demo_view(Vector3(300, 0, 300), Vector3(304, 16, 342), 12.0)
		"world_rain":
			level.weather.set_state("rain", true)
			_demo_view(Vector3(200, 0, 300), Vector3(258, 20, 224), 11.0)
		"world_meadow":
			_demo_view(Vector3(292, 0, 250), Vector3(258, 20, 224), 11.0)
		"world_forest":
			_demo_view(Vector3(400, 0, 470), Vector3(446, 20, 468), 11.0)
		"world_dusk":
			level.day_night.set_hour(19.0)
			_demo_view(Vector3(160, 0, 260), Vector3(258, 25, 224), 11.0)
		"world_map":
			for p in level.meta["pois"]:
				WorldState.add_world_entry("discovered", p["id"])
			WorldState.add_world_entry("hearths", "hearth_west")
			world_map.reveal(Vector3(256, 0, 256), 200.0)
			process_mode = Node.PROCESS_MODE_ALWAYS
			get_tree().create_timer(1.0).timeout.connect(func(): world_map.open(false))
	if Settings.demo.begins_with("world"):
		level.day_night.paused = Settings.demo != "world_start"


func _demo_view(at: Vector3, look: Vector3, h := 10.0) -> void:
	var pos := Vector3(at.x, level.height_at(at.x, at.z) + 1.0, at.z)
	player.global_position = pos
	player.face_towards(look)
	var to := look - pos
	rig.yaw = atan2(-to.x, -to.z)
	rig.pitch = deg_to_rad(-8.0)
	rig.snap()
	rig.yaw = atan2(-to.x, -to.z)
	level.streamer.refresh()
